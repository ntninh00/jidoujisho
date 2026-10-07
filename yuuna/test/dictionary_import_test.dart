import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';

/// Every other word is marked popular.
String _popular(int i) => i.isEven ? 'P' : '';

/// Importing a Yomitan dictionary into a real Isar database, which writes
/// entries a batch at a time: all of it arrives, and a failure partway
/// leaves none of it.
void main() {
  late Directory directory;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      download: true,
      libraries: {
        Abi.current(): path.join(Directory.current.path, 'isar.dll'),
      },
    );
  });

  setUp(() {
    directory = Directory.systemTemp.createTempSync('jdj_import_');
  });

  tearDown(() {
    try {
      directory.deleteSync(recursive: true);
    } on FileSystemException {
      // Isar may still hold its file until the test ends.
    }
  });

  /// A dictionary of [count] words in one bank, and [extra] as another.
  Directory banks(int count, {String? extra}) {
    Directory resources = Directory(path.join(directory.path, 'res'))
      ..createSync();
    File(path.join(resources.path, 'index.json'))
        .writeAsStringSync(jsonEncode({'title': 'Test', 'revision': '1'}));
    File(path.join(resources.path, 'tag_bank_1.json')).writeAsStringSync(
        jsonEncode([
      ['n', 'partOfSpeech', 0, 'noun', 0],
      ['P', 'popular', 0, 'common', 0],
    ]));
    File(path.join(resources.path, 'term_bank_1.json')).writeAsStringSync(
      jsonEncode([
        for (int i = 0; i < count; i++)
          ['語$i', 'ご$i', 'n', '', i, ['word $i'], i, _popular(i)],
        // The same heading again, from another entry.
        ['語0', 'ご0', '', '', 0, ['word 0 again'], count, ''],
      ]),
    );
    if (extra != null) {
      File(path.join(resources.path, 'term_bank_2.json'))
          .writeAsStringSync(extra);
    }
    return resources;
  }

  Future<Object?> deposit(Directory resources) async {
    ReceivePort port = ReceivePort()..listen((_) {});
    try {
      await compute(
        depositDictionaryDataHelper,
        PrepareDictionaryParams(
          dictionary: Dictionary(
              id: 1, name: 'Test', formatKey: 'yomichan', order: 0),
          dictionaryFormat: YomichanFormat.instance,
          resourceDirectory: resources,
          directoryPath: directory.path,
          sendPort: port.sendPort,
          alertSendPort: port.sendPort,
        ),
      );
      return null;
    } catch (error) {
      return error;
    } finally {
      port.close();
    }
  }

  Future<Isar> open() => Isar.open(
        globalSchemas,
        directory: directory.path,
        maxSizeMiB: 256,
      );

  test('every entry arrives, over several batches', () async {
    expect(await deposit(banks(2500)), isNull);
    Isar isar = await open();
    expect(isar.dictionarys.countSync(), 1);
    expect(isar.dictionaryEntrys.countSync(), 2501);
    expect(isar.dictionaryHeadings.countSync(), 2500);
    DictionaryHeading first = isar.dictionaryHeadings
        .getSync(DictionaryHeading.hash(term: '語0', reading: 'ご0'))!;
    expect(first.entries.countSync(), 2);
    expect(first.tags.filter().nameEqualTo('P').countSync(), 1);
    DictionaryEntry entry = first.entries.filter().findFirstSync()!;
    entry.tags.loadSync();
    entry.dictionary.loadSync();
    expect(entry.dictionary.value!.id, 1);
    await isar.close();
  });

  test('a failure partway leaves nothing of the dictionary', () async {
    expect(await deposit(banks(2500, extra: '[["broken"')), isNotNull);
    Isar isar = await open();
    expect(isar.dictionarys.countSync(), 0);
    expect(isar.dictionaryEntrys.countSync(), 0);
    expect(isar.dictionaryHeadings.countSync(), 0);
    await isar.close();
  });
}
