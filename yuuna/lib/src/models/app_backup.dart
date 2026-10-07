import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/language.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/utils.dart';

/// A step of making or restoring a backup, for the progress shown.
class BackupProgress {
  /// Describe a step, and how far along it is from 0 to 1 when known.
  const BackupProgress(this.step, [this.fraction]);

  /// What is happening, such as "Books (Japanese)".
  final String step;

  /// How far along the step is.
  final double? fraction;
}

/// What a backup holds, read before restoring it.
class BackupManifest {
  /// Describe a backup.
  BackupManifest({
    required this.format,
    required this.appVersion,
    required this.created,
    required this.books,
    required this.dictionariesIncluded,
    required this.dictionariesOnline,
    required this.memos,
    required this.terms,
  });

  /// Read a manifest written by [toJson].
  factory BackupManifest.fromJson(Map<String, dynamic> json) => BackupManifest(
        format: (json['format'] as num).toInt(),
        appVersion: json['appVersion'] as String? ?? '',
        created: DateTime.tryParse(json['created'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        books: Map<String, int>.from((json['books'] as Map? ?? const {})
            .map((key, value) => MapEntry('$key', (value as num).toInt()))),
        dictionariesIncluded:
            (json['dictionariesIncluded'] as num?)?.toInt() ?? 0,
        dictionariesOnline: (json['dictionariesOnline'] as num?)?.toInt() ?? 0,
        memos: (json['memos'] as num?)?.toInt() ?? 0,
        terms: (json['terms'] as num?)?.toInt() ?? 0,
      );

  /// The backup file's format; newer formats are refused.
  final int format;

  /// The app version that made it.
  final String appVersion;

  /// When it was made.
  final DateTime created;

  /// Books by language code.
  final Map<String, int> books;

  /// Dictionaries carried in the backup itself.
  final int dictionariesIncluded;

  /// Dictionaries to download again from the dictionary server.
  final int dictionariesOnline;

  /// Memos.
  final int memos;

  /// My terms.
  final int terms;

  /// The manifest as JSON.
  Map<String, dynamic> toJson() => {
        'format': format,
        'appVersion': appVersion,
        'created': created.toIso8601String(),
        'books': books,
        'dictionariesIncluded': dictionariesIncluded,
        'dictionariesOnline': dictionariesOnline,
        'memos': memos,
        'terms': terms,
      };
}

/// A backup that can't be read or restored, said for the person using the
/// app.
class BackupException implements Exception {
  /// Describe the problem.
  BackupException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// Turns settings values into JSON and back. Hive stores a few types JSON
/// lacks, and maps whose keys aren't strings, so those are tagged.
class BackupValues {
  BackupValues._();

  static const String _tag = r'$hive';

  /// [value] as JSON. Throws [UnsupportedError] for values of types it
  /// doesn't know, which the caller leaves out.
  static Object? encode(Object? value) {
    if (value == null || value is bool || value is String) {
      return value;
    }
    if (value is num) {
      return value.isFinite ? value : {_tag: 'number', 'v': '$value'};
    }
    if (value is DateTime) {
      return {
        _tag: 'date',
        'v': value.microsecondsSinceEpoch,
        'utc': value.isUtc
      };
    }
    if (value is Uint8List) {
      return {_tag: 'bytes', 'v': base64Encode(value)};
    }
    if (value is List) {
      return value.map(encode).toList();
    }
    if (value is Map) {
      return {
        _tag: 'map',
        'v': [
          for (MapEntry entry in value.entries)
            [encode(entry.key), encode(entry.value)],
        ],
      };
    }
    throw UnsupportedError('Not a settings value: ${value.runtimeType}');
  }

  /// A value written by [encode].
  static Object? decode(Object? value) {
    if (value is List) {
      return value.map(decode).toList();
    }
    if (value is! Map) {
      return value;
    }
    switch (value[_tag]) {
      case 'number':
        return double.parse(value['v'] as String);
      case 'date':
        return DateTime.fromMicrosecondsSinceEpoch(
          (value['v'] as num).toInt(),
          isUtc: value['utc'] == true,
        );
      case 'bytes':
        return base64Decode(value['v'] as String);
      case 'map':
        return {
          for (List pair in (value['v'] as List).cast<List>())
            decode(pair[0]): decode(pair[1]),
        };
    }
    return value.map((key, item) => MapEntry(key, decode(item)));
  }
}

/// Makes and restores backups of everything the app keeps: settings, the
/// server link and token, books with reading positions, ッツ's settings and
/// fonts, memos, My terms, history, Anki profiles, and dictionaries.
///
/// Dictionaries that are on the user's dictionary server are downloaded
/// again on restore; the rest travel in the backup, as the files they were
/// imported from.
class AppBackup {
  /// Work with backups of [appModel]'s data.
  AppBackup({required this.appModel, required this.ref});

  /// The app's data.
  final AppModel appModel;

  /// For starting ッツ's local servers.
  final WidgetRef ref;

  /// The format this version writes and the newest it can read.
  static const int format = 1;

  /// The backup file's extension.
  static const String extension = 'jdjbackup';

  ReaderTtuSource get _ttu => ReaderTtuSource.instance;

  static void _writeJson(Directory folder, String name, Object value) {
    File file = File(path.join(folder.path, name));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(value));
  }

  static Object? _readJson(Directory folder, String name) {
    File file = File(path.join(folder.path, name));
    return file.existsSync() ? jsonDecode(file.readAsStringSync()) : null;
  }

  /// The revision a Yomitan dictionary's own index gives, if any.
  static String? _revisionOf(Directory files) {
    File index = File(path.join(files.path, 'index.json'));
    if (!index.existsSync()) {
      return null;
    }
    try {
      Object? revision =
          (jsonDecode(index.readAsStringSync()) as Map)['revision'];
      return revision == null ? null : '$revision';
    } catch (_) {
      return null;
    }
  }

  /// Whether [folder] still holds the banks the dictionary was imported
  /// from. Imports now remove them once they are in the database, keeping
  /// only pictures and the like, so such dictionaries are rebuilt from the
  /// database instead.
  static bool _hasFiles(Directory folder) =>
      folder.existsSync() &&
      folder.listSync().any((entity) =>
          entity is File &&
          RegExp(r'^\w+_bank_\d+\.json$').hasMatch(path.basename(entity.path)));

  /* ---------- making a backup ---------- */

  /// Writes a backup to a file in the app's temporary folder, ready to be
  /// saved elsewhere.
  Future<File> create(void Function(BackupProgress) onProgress) async {
    DateTime now = DateTime.now();
    String stamp = now.toIso8601String().substring(0, 19).replaceAll(':', '-');
    Directory work =
        Directory(path.join(appModel.temporaryDirectory.path, 'backup-$stamp'));
    if (work.existsSync()) {
      work.deleteSync(recursive: true);
    }
    work.createSync(recursive: true);

    try {
      onProgress(BackupProgress(t.backup_step_settings));
      Map<String, Object> settings = {};
      appModel.settingsForBackup().forEach((store, values) {
        List<List<Object?>> entries = [];
        values.forEach((key, value) {
          try {
            entries.add([BackupValues.encode(key), BackupValues.encode(value)]);
          } on UnsupportedError catch (error) {
            debugPrint('Backup leaves out $store/$key: $error');
          }
        });
        settings[store] = entries;
      });
      _writeJson(work, 'settings.json', settings);

      onProgress(BackupProgress(t.backup_step_memos));
      Map<String, List<Map<String, dynamic>>> records =
          appModel.recordsForBackup();
      _writeJson(work, 'records.json', records);
      List<MyWord> words = appModel.myWords;
      _writeJson(work, 'terms.json', [
        for (MyWord word in words)
          {
            'term': word.term,
            'reading': word.reading,
            'meaning': word.meaning,
            'origin': word.origin?.toJson(),
          },
      ]);

      ({int included, int online}) dictionaries =
          await _backUpDictionaries(work, onProgress);

      Map<String, int> books = {};
      for (Language language in _ttu.shelfLanguages) {
        String step = t.backup_step_books(language: language.languageName);
        onProgress(BackupProgress(step));
        await ref.read(ttuServerProvider(language).future);
        books[language.languageCode] = await TtuLibrary.backUpStorage(
          port: _ttu.getPortForLanguage(language),
          directory:
              Directory(path.join(work.path, 'books', language.languageCode)),
          onProgress: (done, total) => onProgress(
              BackupProgress(step, total == 0 ? null : done / total)),
        );
      }

      BackupManifest manifest = BackupManifest(
        format: format,
        appVersion: appModel.packageInfo.version,
        created: now,
        books: books,
        dictionariesIncluded: dictionaries.included,
        dictionariesOnline: dictionaries.online,
        memos: records['readerMemos']?.length ?? 0,
        terms: words.length,
      );
      _writeJson(work, 'manifest.json', manifest.toJson());

      onProgress(BackupProgress(t.backup_step_packing));
      String day = stamp.substring(0, 10);
      File file = File(path.join(
          appModel.temporaryDirectory.path, 'jidoujisho-$day.$extension'));
      if (file.existsSync()) {
        file.deleteSync();
      }
      ZipFileEncoder encoder = ZipFileEncoder()
        ..create(file.path, level: Deflate.BEST_SPEED);
      await encoder.addDirectory(work, includeDirName: false);
      encoder.close();
      return file;
    } finally {
      if (work.existsSync()) {
        work.deleteSync(recursive: true);
      }
    }
  }

  /// Lists every dictionary with its place, and either where to download it
  /// again or the file it travels as.
  Future<({int included, int online})> _backUpDictionaries(
    Directory work,
    void Function(BackupProgress) onProgress,
  ) async {
    DictionaryServer? server = appModel.dictionaryServer;
    List<CatalogDictionary>? catalog;
    try {
      catalog = await server?.list();
    } catch (error) {
      // Unreachable: every dictionary travels in the backup instead.
      debugPrint('Backup could not reach the dictionary server: $error');
    }

    List<Dictionary> dictionaries = appModel.dictionaries
        .where((dictionary) => dictionary.id != MyWords.dictionaryId)
        .toList();
    List<Map<String, dynamic>> listed = [];
    int included = 0;
    int online = 0;
    Directory folder = Directory(path.join(work.path, 'dictionaries'))
      ..createSync(recursive: true);

    for (int i = 0; i < dictionaries.length; i++) {
      Dictionary dictionary = dictionaries[i];
      onProgress(BackupProgress(
        t.backup_step_dictionary(name: dictionary.name),
        i / dictionaries.length,
      ));
      Directory files = appModel.dictionaryFilesOf(dictionary);
      String? revision = _revisionOf(files);
      CatalogDictionary? remote = catalog?.firstWhereOrNull((entry) =>
          entry.isReady &&
          entry.title == dictionary.name &&
          (revision == null || entry.revision == revision));

      Map<String, dynamic> source;
      if (server != null && remote != null) {
        source = {
          'kind': 'server',
          'url': server.url,
          'id': remote.id,
          'title': remote.title,
          'revision': remote.revision,
        };
        online++;
      } else {
        String format = dictionary.formatKey;
        File dsl = File(path.join(files.path, 'dictionary.dsl'));
        late String name;
        if (format == AbbyyLingvoFormat.instance.uniqueKey &&
            dsl.existsSync()) {
          name = 'dictionaries/$i.dsl';
          dsl.copySync(path.join(work.path, name));
        } else if (format != AbbyyLingvoFormat.instance.uniqueKey &&
            _hasFiles(files)) {
          name = 'dictionaries/$i.zip';
          ZipFileEncoder zip = ZipFileEncoder()
            ..create(path.join(work.path, name));
          await zip.addDirectory(files, includeDirName: false);
          zip.close();
        } else {
          name = 'dictionaries/$i.zip';
          format = YomichanFormat.instance.uniqueKey;
          await compute(
            rebuildYomitanZipHelper,
            RebuildDictionaryParams(
              dictionaryId: dictionary.id,
              directoryPath: appModel.databaseDirectory.path,
              resourcePath: files.path,
              outPath: path.join(work.path, name),
            ),
          );
        }
        source = {'kind': 'file', 'file': name, 'format': format};
        included++;
      }

      listed.add({
        'name': dictionary.name,
        'order': dictionary.order,
        'hiddenLanguages': dictionary.hiddenLanguages,
        'collapsedLanguages': dictionary.collapsedLanguages,
        'source': source,
      });
    }
    if (folder.listSync().isEmpty) {
      folder.deleteSync();
    }
    _writeJson(work, 'dictionaries.json', listed);
    return (included: included, online: online);
  }

  /* ---------- restoring ---------- */

  /// Unpacks a backup into a temporary folder and reads what it holds.
  /// Paths that would lead outside the folder are refused.
  static Future<(BackupManifest, Directory)> open(
    File file,
    Directory temporary,
  ) async {
    Directory target = Directory(path.join(
        temporary.path, 'restore-${DateTime.now().millisecondsSinceEpoch}'));
    target.createSync(recursive: true);
    InputFileStream input = InputFileStream(file.path);
    try {
      Archive archive;
      try {
        archive = ZipDecoder().decodeBuffer(input);
      } catch (_) {
        throw BackupException(t.backup_not_a_backup);
      }
      String root = path.normalize(target.absolute.path);
      for (ArchiveFile entry in archive.files) {
        String name = entry.name.replaceAll(r'\', '/');
        String destination =
            path.normalize(path.join(root, path.joinAll(name.split('/'))));
        if (name.startsWith('/') ||
            name.split('/').contains('..') ||
            !path.isWithin(root, destination)) {
          throw BackupException(t.backup_not_a_backup);
        }
        if (!entry.isFile) {
          Directory(destination).createSync(recursive: true);
          continue;
        }
        File(destination).parent.createSync(recursive: true);
        OutputFileStream output = OutputFileStream(destination);
        entry.writeContent(output);
        await output.close();
      }
    } finally {
      await input.close();
    }

    Object? manifest = _readJson(target, 'manifest.json');
    if (manifest is! Map) {
      target.deleteSync(recursive: true);
      throw BackupException(t.backup_not_a_backup);
    }
    BackupManifest read =
        BackupManifest.fromJson(Map<String, dynamic>.from(manifest));
    if (read.format > format) {
      target.deleteSync(recursive: true);
      throw BackupException(t.backup_too_new);
    }
    return (read, target);
  }

  /// Replaces this device's settings, books, memos, terms and records with
  /// the backup unpacked in [folder], and installs its dictionaries that
  /// aren't here yet. Resolves to the dictionaries that couldn't be
  /// installed.
  Future<List<String>> restore(
    Directory folder,
    void Function(BackupProgress) onProgress,
  ) async {
    try {
      onProgress(BackupProgress(t.backup_step_settings));
      Object? settings = _readJson(folder, 'settings.json');
      if (settings is Map) {
        await appModel.restoreSettings({
          for (MapEntry store in settings.entries)
            '${store.key}': {
              for (List pair in (store.value as List).cast<List>())
                BackupValues.decode(pair[0]): BackupValues.decode(pair[1]),
            },
        });
      }

      onProgress(BackupProgress(t.backup_step_memos));
      Object? records = _readJson(folder, 'records.json');
      if (records is Map) {
        appModel.restoreRecords({
          for (MapEntry collection in records.entries)
            '${collection.key}': (collection.value as List)
                .map((row) => Map<String, dynamic>.from(row as Map))
                .toList(),
        });
      }
      Object? terms = _readJson(folder, 'terms.json');
      if (terms is List) {
        appModel.restoreMyWords([
          for (Map word in terms.cast<Map>())
            MyWord(
              entryId: 0,
              term: word['term'] as String,
              reading: word['reading'] as String? ?? '',
              meaning: word['meaning'] as String? ?? '',
              origin: TermOrigin.fromJson(word['origin'] as String?),
            ),
        ]);
      }

      for (Language language in _ttu.shelfLanguages) {
        Directory books =
            Directory(path.join(folder.path, 'books', language.languageCode));
        if (!books.existsSync()) {
          continue;
        }
        String step = t.backup_step_books(language: language.languageName);
        onProgress(BackupProgress(step));
        await ref.read(ttuServerProvider(language).future);
        await TtuLibrary.restoreStorage(
          port: _ttu.getPortForLanguage(language),
          directory: books,
          onProgress: (done, total) => onProgress(
              BackupProgress(step, total == 0 ? null : done / total)),
        );
      }
      ref.invalidate(ttuShelfProvider);

      return await _restoreDictionaries(folder, onProgress);
    } finally {
      if (folder.existsSync()) {
        folder.deleteSync(recursive: true);
      }
    }
  }

  Future<List<String>> _restoreDictionaries(
    Directory folder,
    void Function(BackupProgress) onProgress,
  ) async {
    Object? raw = _readJson(folder, 'dictionaries.json');
    if (raw is! List) {
      return const [];
    }
    List<Map<String, dynamic>> listed = raw
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList()
      ..sort((a, b) =>
          ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
    List<String> failed = [];

    for (int i = 0; i < listed.length; i++) {
      Map<String, dynamic> entry = listed[i];
      String name = entry['name'] as String;
      if (appModel.hasDictionaryNamed(name)) {
        continue;
      }
      Map<String, dynamic> source =
          Map<String, dynamic>.from(entry['source'] as Map);
      double fraction = i / listed.length;
      File? file;
      DictionaryFormat? format;
      File? downloaded;

      if (source['kind'] == 'server') {
        onProgress(
            BackupProgress(t.backup_step_download(name: name), fraction));
        try {
          downloaded = await _download(source);
          file = downloaded;
          format = YomichanFormat.instance;
        } catch (error) {
          debugPrint('Restore could not download $name: $error');
        }
      } else {
        File included = File(path.join(folder.path, source['file'] as String));
        if (included.existsSync()) {
          file = included;
          format = appModel.dictionaryFormats[source['format']];
        }
      }

      if (file == null || format == null) {
        failed.add(name);
        continue;
      }

      onProgress(BackupProgress(t.backup_step_install(name: name), fraction));
      bool installed = false;
      await appModel.importDictionary(
        file: file,
        format: format,
        progressNotifier: ValueNotifier<String>(''),
        onImportSuccess: () => installed = true,
      );
      if (downloaded != null && downloaded.existsSync()) {
        downloaded.deleteSync();
      }
      if (!installed) {
        failed.add(name);
      } else if (source['kind'] == 'server') {
        await appModel.setDictionarySource(name, source);
      }
    }

    appModel.restoreDictionaryLayout(listed);
    return failed;
  }

  /// Downloads a dictionary the backup lists from the dictionary server,
  /// found by id, or by title and revision if it was uploaded again since.
  Future<File> _download(Map<String, dynamic> source) async {
    DictionaryServer? configured = appModel.dictionaryServer;
    if (configured == null) {
      throw BackupException('No dictionary server is set up.');
    }
    DictionaryServer server = DictionaryServer(
      url: source['url'] as String? ?? configured.url,
      token: configured.token,
    );
    CatalogDictionary? remote;
    try {
      remote = await server.get(source['id'] as String);
    } catch (_) {
      remote = (await server.list()).firstWhereOrNull((entry) =>
          entry.isReady &&
          entry.title == source['title'] &&
          entry.revision == source['revision']);
    }
    if (remote == null || !remote.isReady) {
      throw BackupException('Not on the server any more.');
    }
    File target = File(path.join(
        appModel.temporaryDirectory.path, 'restore-${remote.id}.zip'));
    await server.download(remote, target);
    return target;
  }
}
