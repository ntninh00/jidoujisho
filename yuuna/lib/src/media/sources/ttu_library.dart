import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/language.dart';
import 'package:yuuna/media.dart';

/// A book stored in ッツ Ebook Reader, as shown on the shelf.
class TtuBook {
  /// Describe a book in ッツ's storage for one language.
  TtuBook({
    required this.language,
    required this.port,
    required this.id,
    required this.title,
    required this.characters,
    required this.lastBookOpen,
    required this.lastBookModified,
    required this.exploredCharCount,
    required this.progress,
    required this.coverPath,
  });

  /// The language words in this book are looked up in. This is the language
  /// of the copy of ッツ that stores it, unless the user chose another.
  final Language language;

  /// Port of the local ッツ server for [language].
  final int port;

  /// ッツ's id for the book.
  final int id;

  /// Title from the book's metadata.
  final String title;

  /// Characters in the book, as counted by ッツ. Zero for old imports.
  final int characters;

  /// When the book was last opened, in milliseconds since epoch.
  final int lastBookOpen;

  /// When the book was imported or changed, in milliseconds since epoch.
  final int lastBookModified;

  /// ッツ's saved reading position in characters.
  final int exploredCharCount;

  /// ッツ's saved reading position as a fraction from 0 to 1.
  final double progress;

  /// Path to the cached cover thumbnail, if the book has a cover.
  final String? coverPath;

  /// Identifies the book across both languages.
  String get key => '$port/$id';

  /// The same book, looked up in [language].
  TtuBook withLanguage(Language language) => copyWith(language: language);

  /// The same book with the given details changed.
  TtuBook copyWith({
    Language? language,
    int? lastBookOpen,
    int? exploredCharCount,
    double? progress,
  }) {
    return TtuBook(
      language: language ?? this.language,
      port: port,
      id: id,
      title: title,
      characters: characters,
      lastBookOpen: lastBookOpen ?? this.lastBookOpen,
      lastBookModified: lastBookModified,
      exploredCharCount: exploredCharCount ?? this.exploredCharCount,
      progress: progress ?? this.progress,
      coverPath: coverPath,
    );
  }

  /// Characters in the book, worked out from the position when ッツ did not
  /// record a count.
  int get totalCharacters {
    if (characters > 0) {
      return characters;
    }
    if (progress > 0) {
      return (exploredCharCount / progress).round();
    }
    return 0;
  }

  /// The address ッツ uses for this book.
  String get readerUrl => 'http://localhost:$port/b.html?id=$id&?title=$title';

  /// The media item used to open the book and keep title and cover edits.
  MediaItem toMediaItem() {
    return MediaItem(
      mediaIdentifier: readerUrl,
      title: title,
      imageUrl: coverPath == null ? null : 'file://$coverPath',
      mediaTypeIdentifier: ReaderTtuSource.instance.mediaType.uniqueKey,
      mediaSourceIdentifier: ReaderTtuSource.instance.uniqueKey,
      position: exploredCharCount,
      duration: max(totalCharacters, 1),
      canDelete: false,
      canEdit: true,
    );
  }
}

/// A saved position to open a book at.
class TtuPosition {
  /// Describe a position in a book.
  const TtuPosition({
    required this.characters,
    required this.progress,
  });

  /// ッツ's character position.
  final int characters;

  /// Position as a fraction from 0 to 1.
  final double progress;
}

/// What the reader should do the next time it opens a book.
class TtuLaunch {
  /// Open [book], optionally at a memo, remembering where the reader was.
  TtuLaunch({
    required this.book,
    this.target,
    this.excerpt,
    this.memo,
    this.returnTo,
    this.keepPlace = false,
  });

  /// Opened to look at a memo or term: ッツ's saved reading position is left
  /// where it was, instead of moving to wherever this visit ends.
  final bool keepPlace;

  /// The book to open.
  final TtuBook book;

  /// Where to open the book. Null opens at ッツ's saved position.
  final TtuPosition? target;

  /// The quoted line to highlight once the page shows.
  final String? excerpt;

  /// The memo text to show while the book loads.
  final String? memo;

  /// The position before the jump, offered as a way back.
  final TtuPosition? returnTo;

  /// The first address to load.
  String get initialUrl {
    TtuPosition? position = target;
    if (position == null) {
      return book.readerUrl;
    }
    return jumpUrl(book: book, position: position);
  }

  /// The address that sets ッツ's position and then opens [book].
  static String jumpUrl({
    required TtuBook book,
    required TtuPosition position,
  }) {
    return Uri.http('localhost:${book.port}', '/jidoujisho/jump.html', {
      'id': '${book.id}',
      'c': '${position.characters}',
      'p': position.progress.toStringAsFixed(5),
      'title': book.title,
    }).toString();
  }
}

/// Page settings for books in one language. ッツ reads these from its local
/// storage when a book opens, so they are written there before ッツ starts.
class TtuPagePreset {
  /// Describe the page settings for one language.
  TtuPagePreset({
    required this.theme,
    required this.fontSize,
    required this.vertical,
    required this.paginated,
    required this.furigana,
    this.fontFamily = '',
    this.lineHeight = 1.65,
    this.margin = 0,
    this.columns = 0,
    this.furiganaStyle = 'partial',
    this.avoidPageBreak = false,
    this.blurImages = true,
  });

  /// ッツ's font for the text, or empty for its default serif.
  String fontFamily;

  /// Line height as a multiple of the font size.
  double lineHeight;

  /// Space at the page edges in CSS pixels: top and bottom for horizontal
  /// text, left and right for vertical text.
  int margin;

  /// Page columns in Pages layout, or 0 to let ッツ choose.
  int columns;

  /// How hidden furigana shows: `partial` greyed out, `full` hidden, or
  /// `toggle` shown on tap.
  String furiganaStyle;

  /// Keeps a paragraph on one page instead of splitting it.
  bool avoidPageBreak;

  /// Covers pictures until tapped, as ッツ does for spoilers.
  bool blurImages;

  /// ッツ's built-in fonts, with the empty name meaning its default serif.
  /// Fonts the user added in ッツ's settings can be chosen too.
  static const List<String> fontFamilies = [
    '',
    'Noto Sans JP',
    'Shippori Mincho',
    'Klee One',
    'Genei Koburi Mincho v5',
  ];

  /// ッツ theme name without the `-theme` suffix, or null to leave ッツ's own.
  String? theme;

  /// Font size in CSS pixels.
  int fontSize;

  /// Vertical, right-to-left text when true.
  bool vertical;

  /// Pages when true, continuous scrolling when false.
  bool paginated;

  /// Show furigana when true.
  bool furigana;

  /// The themes ッツ offers, in its own order.
  static const List<String> themes = [
    'light',
    'ecru',
    'water',
    'gray',
    'dark',
    'black',
  ];

  /// Background and text colours of each ッツ theme.
  static const Map<String, List<int>> themeColors = {
    'light': [0xFFF9F9F9, 0xDE000000],
    'ecru': [0xFFF7F6EB, 0xDE000000],
    'water': [0xFFDFECF4, 0xDE000000],
    'gray': [0xFF23272A, 0xDBFFFFFF],
    'dark': [0xFF121212, 0xDBFFFFFF],
    'black': [0xFF000000, 0xDBFFFFFF],
  };

  /// Script that writes these settings to ッツ's local storage. Runs before
  /// ッツ's own scripts.
  String toScript({required bool autoBookmark}) {
    String? currentTheme = theme;
    return '''
(function () {
  try {
    var s = window.localStorage;
    ${currentTheme == null ? '' : "s.setItem('theme', '$currentTheme-theme');"}
    s.setItem('fontSize', '$fontSize');
    s.setItem('writingMode', '${vertical ? 'vertical-rl' : 'horizontal-tb'}');
    s.setItem('viewMode', '${paginated ? 'paginated' : 'continuous'}');
    s.setItem('hideFurigana', '${furigana ? '0' : '1'}');
    s.setItem('furiganaStyle', '${const [
      'partial',
      'full',
      'toggle'
    ].contains(furiganaStyle) ? furiganaStyle : 'partial'}');
    s.setItem('autoBookmark', '${autoBookmark ? '1' : '0'}');
    s.setItem('fontFamilyGroupOne', ${jsonEncode(fontFamily)});
    s.setItem('lineHeight', '$lineHeight');
    s.setItem('firstDimensionMargin', '$margin');
    s.setItem('pageColumns', '$columns');
    s.setItem('avoidPageBreak', '${avoidPageBreak ? '1' : '0'}');
    s.setItem('hideSpoilerImage', '${blurImages ? '1' : '0'}');
  } catch (e) {}
})();
''';
  }
}

/// Reads and changes ッツ's library from the app, without showing ッツ's pages.
/// Each call runs a hidden WebView on the ッツ origin for one language.
class TtuLibrary {
  TtuLibrary._();

  static String? _libraryScript;
  static String? _readerScript;
  static String? _fitScript;

  /// Keeps wide formulas, tables and code inside the page. Runs before ッツ.
  static Future<String> get fitScript async {
    return _fitScript ??= await rootBundle
        .loadString('assets/ttu-ebook-reader/jidoujisho/fit.js');
  }

  /// The library bridge script.
  static Future<String> get libraryScript async {
    return _libraryScript ??= await rootBundle
        .loadString('assets/ttu-ebook-reader/jidoujisho/library.js');
  }

  /// The reader bridge script injected into book pages.
  static Future<String> get readerScript async {
    return _readerScript ??= await rootBundle
        .loadString('assets/ttu-ebook-reader/jidoujisho/reader.js');
  }

  static Future<T> _onPage<T>({
    required int port,
    required String page,
    required Future<T> Function(InAppWebViewController controller) action,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    Completer<InAppWebViewController> ready = Completer();
    HeadlessInAppWebView view = HeadlessInAppWebView(
      initialUrlRequest:
          URLRequest(url: WebUri('http://localhost:$port/$page')),
      onLoadStop: (controller, url) {
        if (!ready.isCompleted) {
          ready.complete(controller);
        }
      },
      onReceivedError: (controller, request, error) {
        if ((request.isForMainFrame ?? true) && !ready.isCompleted) {
          ready.completeError(StateError(error.description));
        }
      },
    );

    try {
      await view.run();
      InAppWebViewController controller = await ready.future.timeout(timeout);
      return await action(controller).timeout(timeout);
    } finally {
      await view.dispose();
    }
  }

  static Future<Object?> _call(
    InAppWebViewController controller,
    String body,
    Map<String, dynamic> arguments,
  ) async {
    CallAsyncJavaScriptResult? result = await controller.callAsyncJavaScript(
      functionBody: body,
      arguments: arguments,
    );
    if (result?.error != null) {
      throw StateError(result!.error!);
    }
    return result?.value;
  }

  static String? _storageScript;

  /// The storage bridge script, for backups.
  static Future<String> get storageScript async {
    return _storageScript ??= await rootBundle
        .loadString('assets/ttu-ebook-reader/jidoujisho/storage.js');
  }

  /// Text moves between the app and the page in slices of this many
  /// characters, so no single message is huge.
  static const int _slice = 512 * 1024;

  /// Writes everything ッツ keeps for one language into [directory]: its
  /// databases with books, reading positions and statistics, its settings
  /// and the fonts the user added. Resolves to the number of books.
  static Future<int> backUpStorage({
    required int port,
    required Directory directory,
    void Function(int done, int total)? onProgress,
  }) {
    return _onPage(
      port: port,
      page: 'jidoujisho/shelf.html',
      timeout: const Duration(hours: 2),
      action: (controller) async {
        await controller.evaluateJavascript(source: await storageScript);
        Map<String, dynamic> description = Map<String, dynamic>.from(
            await _call(controller,
                'return await window.jdjStorage.describe();', {}) as Map);
        directory.createSync(recursive: true);
        File(path.join(directory.path, 'description.json'))
            .writeAsStringSync(jsonEncode(description));

        int total = 0;
        int books = 0;
        for (Map db in (description['databases'] as List).cast<Map>()) {
          for (Map store in (db['stores'] as List).cast<Map>()) {
            total += (store['count'] as num).toInt();
            if (db['name'] == 'books' && store['name'] == 'data') {
              books = (store['count'] as num).toInt();
            }
          }
        }

        Future<File> readOut(int length, String name) async {
          File file = File(path.join(directory.path, name));
          IOSink sink = file.openWrite();
          for (int at = 0; at < length; at += _slice) {
            Object? text = await _call(
              controller,
              'return window.jdjStorage.slice(from, to);',
              {'from': at, 'to': min(length, at + _slice)},
            );
            sink.write(text as String);
          }
          await sink.close();
          return file;
        }

        List<Map<String, dynamic>> batches = [];
        int done = 0;
        for (Map db in (description['databases'] as List).cast<Map>()) {
          for (Map store in (db['stores'] as List).cast<Map>()) {
            Object? after;
            do {
              Map packed = await _call(
                controller,
                'return await window.jdjStorage.pack(db, store, after, budget);',
                {
                  'db': db['name'],
                  'store': store['name'],
                  'after': after,
                  'budget': 8 * 1024 * 1024,
                },
              ) as Map;
              int count = (packed['count'] as num).toInt();
              if (count > 0) {
                String name = 'records-${batches.length}.json';
                await readOut((packed['length'] as num).toInt(), name);
                batches.add({
                  'database': db['name'],
                  'store': store['name'],
                  'file': name,
                });
                done += count;
                onProgress?.call(done, total);
              }
              after = packed['next'];
            } while (after != null);
          }
        }

        for (Map cache in (description['caches'] as List).cast<Map>()) {
          Object? from = 0;
          do {
            Map packed = await _call(
              controller,
              'return await window.jdjStorage.packCache(cache, from, budget);',
              {'cache': cache['name'], 'from': from, 'budget': 8 * 1024 * 1024},
            ) as Map;
            if ((packed['count'] as num).toInt() > 0) {
              String name = 'cache-${batches.length}.json';
              await readOut((packed['length'] as num).toInt(), name);
              batches.add({'cache': cache['name'], 'file': name});
            }
            from = packed['next'];
          } while (from != null);
        }

        File(path.join(directory.path, 'batches.json'))
            .writeAsStringSync(jsonEncode(batches));
        return books;
      },
    );
  }

  /// Replaces what ッツ keeps for one language with a backup written by
  /// [backUpStorage] into [directory].
  static Future<void> restoreStorage({
    required int port,
    required Directory directory,
    void Function(int done, int total)? onProgress,
  }) {
    return _onPage(
      port: port,
      page: 'jidoujisho/shelf.html',
      timeout: const Duration(hours: 2),
      action: (controller) async {
        await controller.evaluateJavascript(source: await storageScript);
        Map description = jsonDecode(
          File(path.join(directory.path, 'description.json'))
              .readAsStringSync(),
        ) as Map;
        List<Map> batches = (jsonDecode(
          File(path.join(directory.path, 'batches.json')).readAsStringSync(),
        ) as List)
            .cast<Map>();

        await _call(controller,
            'return await window.jdjStorage.prepare(description);', {
          'description': description,
        });

        for (int i = 0; i < batches.length; i++) {
          Map batch = batches[i];
          String text = await File(path.join(directory.path, batch['file']))
              .readAsString();
          for (int at = 0; at < text.length; at += _slice) {
            await _call(controller, 'return window.jdjStorage.receive(chunk);',
                {'chunk': text.substring(at, min(text.length, at + _slice))});
          }
          if (batch['cache'] != null) {
            await _call(
                controller,
                'return await window.jdjStorage.unpackCache(cache);',
                {'cache': batch['cache']});
          } else {
            await _call(
                controller,
                'return await window.jdjStorage.unpack(db, store);',
                {'db': batch['database'], 'store': batch['store']});
          }
          onProgress?.call(i + 1, batches.length);
        }

        await _call(
            controller,
            'return window.jdjStorage.restoreSettings(settings);',
            {'settings': description['localStorage'] ?? {}});
      },
    );
  }

  static final RegExp _coverName = RegExp(r'^(\d+)_(\d+)_(\d+)\.jpg$');

  /// Lists the books of one language. Covers are cached as small JPEG files
  /// in [coverDirectory] and only fetched again when a book changes.
  static Future<List<TtuBook>> listBooks({
    required Language language,
    required int port,
    required Directory coverDirectory,
  }) async {
    Directory directory = Directory(path.join(coverDirectory.path, 'ttu'));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    Map<String, String> known = {};
    Map<int, String> cached = {};
    for (FileSystemEntity file in directory.listSync()) {
      RegExpMatch? match = _coverName.firstMatch(path.basename(file.path));
      if (match != null && int.parse(match.group(1)!) == port) {
        known[match.group(2)!] = match.group(3)!;
        cached[int.parse(match.group(2)!)] = file.path;
      }
    }

    Object? value = await _onPage(
      port: port,
      page: 'jidoujisho/shelf.html',
      action: (controller) => _call(
        controller,
        'return await window.jdjLibrary.list(known);',
        {'known': known},
      ),
    );

    if (value is! Map) {
      return [];
    }
    List<Object?> raw = (value['books'] as List?) ?? [];
    List<TtuBook> books = [];

    for (Object? entry in raw) {
      if (entry is! Map) {
        continue;
      }
      int id = (entry['id'] as num).toInt();
      int modified = ((entry['lastBookModified'] as num?) ?? 0).toInt();
      String? coverPath = cached[id];

      if (entry['coverChanged'] == true) {
        if (coverPath != null) {
          File(coverPath).deleteSync();
          coverPath = null;
        }
        Object? cover = entry['cover'];
        if (cover is String && cover.startsWith('data:')) {
          UriData? data = Uri.tryParse(cover)?.data;
          if (data != null) {
            String file =
                path.join(directory.path, '${port}_${id}_$modified.jpg');
            File(file).writeAsBytesSync(data.contentAsBytes());
            coverPath = file;
          }
        }
      }

      books.add(
        TtuBook(
          language: language,
          port: port,
          id: id,
          title: (entry['title'] as String?) ?? '',
          characters: ((entry['characters'] as num?) ?? 0).toInt(),
          lastBookOpen: ((entry['lastBookOpen'] as num?) ?? 0).toInt(),
          lastBookModified: modified,
          exploredCharCount:
              ((entry['exploredCharCount'] as num?) ?? 0).toInt(),
          progress: ((entry['progress'] as num?) ?? 0).toDouble(),
          coverPath: coverPath,
        ),
      );
    }

    /// Remove covers of books that are gone.
    Set<int> ids = books.map((book) => book.id).toSet();
    cached.forEach((id, file) {
      if (!ids.contains(id) && File(file).existsSync()) {
        File(file).deleteSync();
      }
    });

    return books;
  }

  /// Stores [file] as a font called [name] for the copy of ッツ on [port],
  /// as ッツ's own settings page would. Resolves to the fonts stored now.
  static Future<List<String>> addFont({
    required int port,
    required File file,
    required String name,
  }) {
    return _onPage(
      port: port,
      page: 'manage.html',
      timeout: const Duration(minutes: 2),
      action: (controller) async {
        await controller.evaluateJavascript(source: await libraryScript);
        Uint8List bytes = await file.readAsBytes();
        const int chunk = 3 * 128 * 1024;
        for (int start = 0; start < bytes.length; start += chunk) {
          await _call(
            controller,
            'return window.jdjLibrary.stage(key, chunk);',
            {
              'key': 'font',
              'chunk': base64Encode(
                bytes.sublist(start, min(start + chunk, bytes.length)),
              ),
            },
          );
        }
        await _call(
          controller,
          'return await window.jdjLibrary.addFont(name, fileName, key);',
          {'name': name, 'fileName': path.basename(file.path), 'key': 'font'},
        );
        Object? fonts =
            await _call(controller, 'return window.jdjLibrary.fonts();', {});
        return fonts is List ? fonts.whereType<String>().toList() : const [];
      },
    );
  }

  /// Removes the font called [name] from the copy of ッツ on [port].
  /// Resolves to the fonts stored now.
  static Future<List<String>> removeFont({
    required int port,
    required String name,
  }) {
    return _onPage(
      port: port,
      page: 'manage.html',
      action: (controller) async {
        await controller.evaluateJavascript(source: await libraryScript);
        await _call(
          controller,
          'return await window.jdjLibrary.removeFont(name);',
          {'name': name},
        );
        Object? fonts =
            await _call(controller, 'return window.jdjLibrary.fonts();', {});
        return fonts is List ? fonts.whereType<String>().toList() : const [];
      },
    );
  }

  /// Hands [files] to ッツ's own importer. Returns the ids of the new books.
  static Future<List<int>> importFiles({
    required int port,
    required List<File> files,
  }) {
    return _onPage(
      port: port,
      page: 'manage.html',
      timeout: const Duration(minutes: 4),
      action: (controller) async {
        await controller.evaluateJavascript(source: await libraryScript);

        List<String> names = [];
        for (File file in files) {
          String name = path.basename(file.path);
          while (names.contains(name)) {
            name = '${names.length}_$name';
          }
          names.add(name);

          Uint8List bytes = await file.readAsBytes();
          const int chunk = 3 * 128 * 1024;
          for (int start = 0; start < bytes.length; start += chunk) {
            String encoded = base64Encode(
              bytes.sublist(start, min(start + chunk, bytes.length)),
            );
            await _call(
              controller,
              'return window.jdjLibrary.stage(key, chunk);',
              {'key': name, 'chunk': encoded},
            );
          }
        }

        Object? value = await _call(
          controller,
          'return await window.jdjLibrary.importStaged(names, 200000);',
          {'names': names},
        );

        if (value is! Map) {
          throw StateError('ッツ did not answer');
        }
        List<int> added = ((value['added'] as List?) ?? [])
            .map((id) => (id as num).toInt())
            .toList();
        Object? error = value['error'];
        if (added.isEmpty && error != null) {
          throw StateError(error.toString());
        }
        return added;
      },
    );
  }

  /// Deletes books, with their saved positions, from ッツ.
  static Future<void> deleteBooks({
    required int port,
    required List<int> ids,
  }) {
    return _onPage(
      port: port,
      page: 'jidoujisho/shelf.html',
      action: (controller) => _call(
        controller,
        'return await window.jdjLibrary.deleteBooks(ids);',
        {'ids': ids},
      ),
    );
  }

  /// Reads the language code from an EPUB's or HTMLZ's metadata, falling back
  /// to the script of its title. Returns null when it cannot tell.
  static Future<String?> detectLanguageCode(String filePath) {
    return compute(_detectLanguageCode, filePath);
  }
}

Future<String?> _detectLanguageCode(String filePath) async {
  InputFileStream? input;
  try {
    input = InputFileStream(filePath);
    Archive archive = ZipDecoder().decodeBuffer(input);

    ArchiveFile? opf;
    ArchiveFile? container = archive.findFile('META-INF/container.xml');
    if (container != null) {
      String xml = utf8.decode(
        container.content as List<int>,
        allowMalformed: true,
      );
      String? opfPath =
          RegExp('full-path=["\']([^"\']+)["\']').firstMatch(xml)?.group(1);
      if (opfPath != null) {
        opf = archive.findFile(opfPath);
      }
    }
    opf ??= archive.files
        .firstWhereOrNull((file) => file.name.toLowerCase().endsWith('.opf'));

    String metadata = opf == null
        ? ''
        : utf8.decode(opf.content as List<int>, allowMalformed: true);
    String? declared = _declaredLanguage(metadata);
    String? script = _scriptOfText(archive);

    /// The text decides when it is clear: some books are tagged with the
    /// wrong language, or with none.
    if (script == 'ja') {
      return 'ja';
    }
    if (script == 'latin') {
      return declared != null && declared != 'ja' ? declared : 'en';
    }
    if (declared != null) {
      return declared;
    }

    String title =
        RegExp('<dc:title[^>]*>([^<]*)').firstMatch(metadata)?.group(1) ?? '';
    if (RegExp('[\u3040-\u30ff\u4e00-\u9fff]').hasMatch(title)) {
      return 'ja';
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    await input?.close();
  }
}

/// Three-letter codes some publishers use, such as O'Reilly's `eng`.
const Map<String, String> _threeLetterCodes = {
  'eng': 'en',
  'jpn': 'ja',
  'fre': 'fr',
  'fra': 'fr',
  'ger': 'de',
  'deu': 'de',
  'spa': 'es',
  'chi': 'zh',
  'zho': 'zh',
  'kor': 'ko',
};

/// The language the package metadata declares, as a two-letter code. Reads
/// `<dc:language>` with any or no prefix, then `dcterms:language`.
String? _declaredLanguage(String metadata) {
  List<RegExp> patterns = [
    RegExp(r'<(?:[\w-]+:)?language\b[^>]*>\s*([A-Za-z]{2,3})\b',
        caseSensitive: false),
    RegExp('property=["\']dcterms:language["\'][^>]*>\\s*([A-Za-z]{2,3})\\b',
        caseSensitive: false),
  ];
  for (RegExp pattern in patterns) {
    for (RegExpMatch match in pattern.allMatches(metadata)) {
      String code = match.group(1)!.toLowerCase();
      code = _threeLetterCodes[code] ?? code;
      if (code.length == 2 && code != 'un') {
        return code;
      }
    }
  }
  return null;
}

/// Whether the book's text is mostly Japanese or mostly Latin letters, from
/// its three largest pages. Null when there is too little text to tell, as
/// in a picture book.
String? _scriptOfText(Archive archive) {
  List<ArchiveFile> pages = archive.files.where((file) {
    String name = file.name.toLowerCase();
    return file.isFile &&
        (name.endsWith('.xhtml') ||
            name.endsWith('.html') ||
            name.endsWith('.htm'));
  }).toList()
    ..sort((a, b) => b.size.compareTo(a.size));

  int japanese = 0;
  int latin = 0;
  RegExp tags = RegExp('<[^>]*>');
  RegExp japaneseCharacters = RegExp('[\u3040-\u30ff\u4e00-\u9fff]');
  RegExp latinLetters = RegExp('[A-Za-z]');
  for (ArchiveFile page in pages.take(3)) {
    List<int> bytes = page.content as List<int>;
    String html = utf8.decode(
      bytes.length > 200000 ? bytes.sublist(0, 200000) : bytes,
      allowMalformed: true,
    );
    String text = html
        .replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true), '')
        .replaceAll(tags, ' ');
    japanese += japaneseCharacters.allMatches(text).length;
    latin += latinLetters.allMatches(text).length;
  }

  if (japanese + latin < 200) {
    return null;
  }

  /// One Japanese character carries about as much as a short Latin word, so
  /// a quarter of the letters is plenty to call a book Japanese.
  if (japanese / (japanese + latin) > 0.25) {
    return 'ja';
  }
  return 'latin';
}
