import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';

/// Deleting one dictionary from a real Isar database: its rows go, rows of
/// others stay, headings go only when nothing is left on them, and search
/// history stays.
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
  });

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('jdj_delete_');
    isar = await Isar.open(
      globalSchemas,
      directory: directory.path,
      maxSizeMiB: 256,
      name: 'delete_test',
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    directory.deleteSync(recursive: true);
  });

  Dictionary dictionary(int id, String name) =>
      Dictionary(id: id, name: name, formatKey: 'yomichan', order: id);

  DictionaryHeading heading(String term, String reading) {
    DictionaryHeading heading = DictionaryHeading(term: term, reading: reading);
    isar.dictionaryHeadings.putSync(heading);
    return heading;
  }

  void entry(Dictionary dictionary, DictionaryHeading heading, String text) {
    DictionaryEntry entry = DictionaryEntry(definitions: [text], popularity: 1);
    entry.heading.value = heading;
    entry.dictionary.value = dictionary;
    isar.dictionaryEntrys.putSync(entry);
  }

  test('only the dictionary and what it alone had go', () {
    Dictionary english = dictionary(1, 'English');
    Dictionary japanese = dictionary(2, 'Japanese');
    late DictionaryHeading cat;
    late DictionaryHeading dog;
    late DictionaryHeading only;
    isar.writeTxnSync(() {
      isar.dictionarys.putAllSync([english, japanese]);
      cat = heading('猫', 'ねこ');
      dog = heading('犬', 'いぬ');
      only = heading('狐', 'きつね');
      entry(english, cat, 'cat');
      entry(english, dog, 'dog');
      entry(english, only, 'fox');
      entry(japanese, cat, 'ネコ科の動物');
      entry(japanese, dog, 'イヌ科の動物');

      DictionaryPitch pitch = DictionaryPitch(downstep: 1);
      pitch.heading.value = only;
      pitch.dictionary.value = english;
      isar.dictionaryPitchs.putSync(pitch);

      DictionarySearchResult kept = DictionarySearchResult(
        searchTerm: '猫',
        bestLength: 1,
        headingIds: [cat.id],
      )..headings.add(cat);
      DictionarySearchResult emptied = DictionarySearchResult(
        searchTerm: '狐',
        bestLength: 1,
        headingIds: [only.id],
      )..headings.add(only);
      isar.dictionarySearchResults.putAllSync([kept, emptied]);
    });

    deleteDictionaryData(isar, english.id);

    expect(isar.dictionarys.getSync(english.id), isNull);
    expect(isar.dictionarys.getSync(japanese.id), isNotNull);
    List<DictionaryEntry> left = isar.dictionaryEntrys.where().findAllSync();
    expect(left.map((entry) => entry.definitions.single),
        unorderedEquals(['ネコ科の動物', 'イヌ科の動物']));
    expect(isar.dictionaryPitchs.countSync(), 0);
    expect(isar.dictionaryHeadings.getSync(cat.id), isNotNull);
    expect(isar.dictionaryHeadings.getSync(dog.id), isNotNull);
    expect(isar.dictionaryHeadings.getSync(only.id), isNull);
    List<DictionarySearchResult> history =
        isar.dictionarySearchResults.where().findAllSync();
    expect(history.map((result) => result.searchTerm), ['猫']);
  });

  test('a dictionary that is not there is left alone', () {
    isar.writeTxnSync(() => isar.dictionarys.putSync(dictionary(1, 'A')));
    deleteDictionaryData(isar, 9);
    expect(isar.dictionarys.countSync(), 1);
  });
}
