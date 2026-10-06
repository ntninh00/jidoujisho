import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/models.dart';

/// The parts of a backup that don't need a device: settings values, the
/// database's own JSON, rebuilding a dictionary, and reading backup files.
void main() {
  late Directory directory;
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      download: true,
      libraries: {
        Abi.current(): path.join(Directory.current.path, 'isar.dll'),
      },
    );
    directory = Directory.systemTemp.createTempSync('jdj_backup_');
    isar = await Isar.open(globalSchemas,
        directory: directory.path, maxSizeMiB: 256);
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('settings values survive a trip through JSON', () {
    Map<Object?, Object?> values = {
      'name': 'jidoujisho',
      'count': 3,
      'ratio': 0.25,
      'on': true,
      'nothing': null,
      'infinite': double.infinity,
      'when': DateTime.utc(2026, 10, 6, 12, 30),
      'bytes': Uint8List.fromList([0, 1, 254, 255]),
      'list': [1, 'two', 3.0],
      'nested': {
        'a': [1, 2],
        7: 'int key'
      },
      42: 'int key at the top',
    };
    Object? json = jsonDecode(jsonEncode(BackupValues.encode(values)));
    Map back = BackupValues.decode(json) as Map;
    expect(back['name'], 'jidoujisho');
    expect(back['count'], 3);
    expect(back['ratio'], 0.25);
    expect(back['on'], isTrue);
    expect(back.containsKey('nothing'), isTrue);
    expect(back['infinite'], double.infinity);
    expect(back['when'], DateTime.utc(2026, 10, 6, 12, 30));
    expect(back['bytes'], Uint8List.fromList([0, 1, 254, 255]));
    expect(back['list'], [1, 'two', 3.0]);
    expect((back['nested'] as Map)[7], 'int key');
    expect(back[42], 'int key at the top');
    expect(() => BackupValues.encode(Object()), throwsUnsupportedError);
  });

  test('memos come back from the database\'s own JSON', () {
    ReaderMemo memo = ReaderMemo(
      bookKey: '52160/3',
      bookTitle: 'Sapiens',
      exploredCharCount: 13571,
      progress: 0.0192,
      memo: 'line one\nline two',
      excerpt: 'primate',
      createdAt: DateTime(2026, 10, 6, 12),
      color: 'sky',
    );
    isar.writeTxnSync(() => isar.readerMemos.putSync(memo));
    List<Map<String, dynamic>> json =
        (jsonDecode(jsonEncode(isar.readerMemos.where().exportJsonSync()))
                as List)
            .cast<Map<String, dynamic>>();
    isar.writeTxnSync(() {
      isar.readerMemos.clearSync();
      isar.readerMemos.importJsonSync(json);
    });
    ReaderMemo back = isar.readerMemos.where().findFirstSync()!;
    expect(back.id, memo.id);
    expect(back.memo, 'line one\nline two');
    expect(back.createdAt, DateTime(2026, 10, 6, 12));
    expect(back.color, 'sky');
    expect(back.progress, closeTo(0.0192, 1e-12));
  });

  test('a dictionary whose files are gone is rebuilt as a Yomitan zip',
      () async {
    Dictionary dictionary =
        Dictionary(id: 7, name: 'Rebuilt', formatKey: 'yomichan', order: 0);
    DictionaryTag noun = DictionaryTag(
      dictionaryId: 7,
      name: 'n',
      category: 'partOfSpeech',
      sortingOrder: 0,
      notes: 'noun',
      popularity: 0,
    );
    DictionaryTag popular = DictionaryTag(
      dictionaryId: 7,
      name: 'P',
      category: 'popular',
      sortingOrder: -1,
      notes: 'common word',
      popularity: 10,
    );
    DictionaryTag foreign = DictionaryTag(
      dictionaryId: 99,
      name: 'X',
      category: 'other',
      sortingOrder: 0,
      notes: 'from another dictionary',
      popularity: 0,
    );

    isar.writeTxnSync(() {
      isar.dictionarys.putSync(dictionary);
      for (DictionaryTag tag in [noun, popular]) {
        tag.dictionary.value = dictionary;
        isar.dictionaryTags.putSync(tag);
      }
      isar.dictionaryTags.putSync(foreign);

      DictionaryHeading cat = DictionaryHeading(term: '猫', reading: 'ねこ');
      cat.tags.addAll([popular, foreign]);
      isar.dictionaryHeadings.putSync(cat);
      DictionaryEntry catEntry =
          DictionaryEntry(definitions: ['cat', 'feline'], popularity: 5);
      catEntry.heading.value = cat;
      catEntry.dictionary.value = dictionary;
      catEntry.tags.add(noun);
      isar.dictionaryEntrys.putSync(catEntry);

      DictionaryHeading dog = DictionaryHeading(term: '犬', reading: 'いぬ');
      isar.dictionaryHeadings.putSync(dog);
      DictionaryEntry dogEntry = DictionaryEntry(
        definitions: [
          jsonEncode({
            'tag': 'span',
            'content': [
              'dog ',
              {'tag': 'img', 'path': 'img/dog.png'}
            ],
          }),
          '[not json] text',
        ],
        popularity: 1,
      );
      dogEntry.heading.value = dog;
      dogEntry.dictionary.value = dictionary;
      isar.dictionaryEntrys.putSync(dogEntry);

      DictionaryFrequency frequency =
          DictionaryFrequency(value: 120, displayValue: '120');
      frequency.heading.value = cat;
      frequency.dictionary.value = dictionary;
      isar.dictionaryFrequencys.putSync(frequency);
      for (int downstep in [1, 0]) {
        DictionaryPitch pitch = DictionaryPitch(downstep: downstep);
        pitch.heading.value = cat;
        pitch.dictionary.value = dictionary;
        isar.dictionaryPitchs.putSync(pitch);
      }
    });

    Directory resources = Directory(path.join(directory.path, 'res7'))
      ..createSync();
    File(path.join(resources.path, 'img', 'dog.png'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([137, 80, 78, 71]);
    File(path.join(resources.path, 'term_bank_9.json'))
        .writeAsStringSync('[["stale"]]');

    String out = path.join(directory.path, 'rebuilt.zip');
    await compute(
      rebuildYomitanZipHelper,
      RebuildDictionaryParams(
        dictionaryId: 7,
        directoryPath: directory.path,
        resourcePath: resources.path,
        outPath: out,
      ),
    );
    String? keep = Platform.environment['JDJ_REBUILD_OUT'];
    if (keep != null) {
      File(out).copySync(keep);
    }

    Archive zip = ZipDecoder().decodeBytes(File(out).readAsBytesSync());
    Object? read(String name) =>
        jsonDecode(utf8.decode(zip.findFile(name)!.content as List<int>));

    expect(read('index.json'), {
      'title': 'Rebuilt',
      'revision': 'rebuilt',
      'format': 3,
      'sequenced': false
    });
    expect(zip.findFile('term_bank_9.json'), isNull);
    expect(zip.findFile('img/dog.png'), isNotNull);

    List<List<dynamic>> terms =
        (read('term_bank_1.json') as List).cast<List<dynamic>>();
    List catRow = terms.firstWhere((row) => row[0] == '猫');
    expect(catRow, [
      '猫',
      'ねこ',
      'n',
      '',
      5.0,
      ['cat', 'feline'],
      0,
      'P'
    ]);
    List dogRow = terms.firstWhere((row) => row[0] == '犬');
    expect(dogRow[5], [
      {
        'type': 'structured-content',
        'content': {
          'tag': 'span',
          'content': [
            'dog ',
            {'tag': 'img', 'path': 'img/dog.png'}
          ],
        },
      },
      '[not json] text',
    ]);

    List<List<dynamic>> tags =
        (read('tag_bank_1.json') as List).cast<List<dynamic>>();
    expect(tags.map((row) => row[0]).toSet(), {'n', 'P'});

    List<List<dynamic>> meta =
        (read('term_meta_bank_1.json') as List).cast<List<dynamic>>();
    expect(
        meta,
        anyElement(equals([
          '猫',
          'freq',
          {
            'reading': 'ねこ',
            'frequency': {'value': 120.0, 'displayValue': '120'},
          },
        ])));
    Map pitch = meta.firstWhere((row) => row[1] == 'pitch')[2] as Map;
    expect(pitch['reading'], 'ねこ');
    expect(
        (pitch['pitches'] as List)
            .cast<Map>()
            .map((p) => p['position'])
            .toSet(),
        {1, 0});
  });

  group('reading a backup file', () {
    File zipOf(Map<String, String> files) {
      File file = File(path.join(
          directory.path, 'b${DateTime.now().microsecondsSinceEpoch}.zip'));
      Archive archive = Archive();
      files.forEach(
          (name, text) => archive.addFile(ArchiveFile.string(name, text)));
      file.writeAsBytesSync(ZipEncoder().encode(archive)!);
      return file;
    }

    String manifest(int format) => jsonEncode(BackupManifest(
          format: format,
          appVersion: '2.9.1-dev.5',
          created: DateTime(2026, 10, 6, 15),
          books: {'ja': 12, 'en': 3},
          dictionariesIncluded: 2,
          dictionariesOnline: 5,
          memos: 40,
          terms: 9,
        ).toJson());

    test('opens a backup and reads what it holds', () async {
      File file = zipOf({
        'manifest.json': manifest(1),
        'books/ja/description.json': '{}',
      });
      (BackupManifest, Directory) opened =
          await AppBackup.open(file, directory);
      expect(opened.$1.books, {'ja': 12, 'en': 3});
      expect(opened.$1.dictionariesOnline, 5);
      expect(opened.$1.created, DateTime(2026, 10, 6, 15));
      expect(
          File(path.join(opened.$2.path, 'books', 'ja', 'description.json'))
              .existsSync(),
          isTrue);
      opened.$2.deleteSync(recursive: true);
    });

    test('refuses paths that lead out of its folder', () async {
      File file = zipOf({
        'manifest.json': manifest(1),
        '../outside.txt': 'escaped',
      });
      await expectLater(
          AppBackup.open(file, directory), throwsA(isA<BackupException>()));
      expect(File(path.join(directory.parent.path, 'outside.txt')).existsSync(),
          isFalse);
    });

    test('refuses backups from a newer format, and files that aren\'t backups',
        () async {
      await expectLater(
          AppBackup.open(zipOf({'manifest.json': manifest(99)}), directory),
          throwsA(isA<BackupException>()));
      await expectLater(AppBackup.open(zipOf({'readme.txt': 'hi'}), directory),
          throwsA(isA<BackupException>()));
      File notZip = File(path.join(directory.path, 'not.zip'))
        ..writeAsStringSync('just text');
      await expectLater(
          AppBackup.open(notZip, directory), throwsA(isA<BackupException>()));
    });
  });
}
