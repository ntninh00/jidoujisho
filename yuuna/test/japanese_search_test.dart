import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/language.dart';
import 'package:yuuna/models.dart';

/// Searching Japanese in a real Isar database. Typed in the search bar, the
/// text is a word or the start of one; tapped in a book, the longest word it
/// starts with comes first. Spellings listed one by one with the same
/// meanings show once.
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
    directory = Directory.systemTemp.createTempSync('jdj_search_');
    Directory resources = Directory(path.join(directory.path, 'res'))
      ..createSync();
    File(path.join(resources.path, 'index.json'))
        .writeAsStringSync(jsonEncode({'title': 'Test', 'revision': '1'}));
    List<Object> word(String term, String reading, String meaning,
            {int score = 0, String rules = ''}) =>
        [
          term,
          reading,
          '',
          rules,
          score,
          [meaning],
          0,
          ''
        ];
    File(path.join(resources.path, 'term_bank_1.json')).writeAsStringSync(
      jsonEncode([
        word('図々しい', 'ずうずうしい', 'impudent', score: 5, rules: 'adj-i'),
        word('図図しい', 'ずうずうしい', 'impudent', rules: 'adj-i'),
        word('図', 'ず', 'drawing', score: 9),
        word('兵士', 'へいし', 'soldier', score: 9),
        word('閉止', 'へいし', 'stopping'),
        word('兵舎', 'へいしゃ', 'barracks'),
        word('閉所恐怖症', 'へいしょきょうふしょう', 'claustrophobia'),
        word('塀', 'へい', 'wall', score: 9),
        word('食べる', 'たべる', 'to eat', score: 9, rules: 'v1'),
        word('コーヒー', '', 'coffee', score: 9),
      ]),
    );
    ReceivePort port = ReceivePort()..listen((_) {});
    await compute(
      depositDictionaryDataHelper,
      PrepareDictionaryParams(
        dictionary:
            Dictionary(id: 1, name: 'Test', formatKey: 'yomichan', order: 0),
        dictionaryFormat: YomichanFormat.instance,
        resourceDirectory: resources,
        directoryPath: directory.path,
        sendPort: port.sendPort,
        alertSendPort: port.sendPort,
      ),
    );
    port.close();
    isar = await Isar.open(globalSchemas,
        directory: directory.path, maxSizeMiB: 256);
  });

  tearDownAll(() async {
    await isar.close();
    try {
      directory.deleteSync(recursive: true);
    } on FileSystemException {
      // Isar may still hold its file until the test ends.
    }
  });

  /// The words found for [text], as `term【reading】`.
  Future<List<String>> search(String text,
      {required bool typed, List<int> hidden = const []}) async {
    DictionarySearchOutcome? outcome =
        await prepareSearchResultsJapaneseLanguage(DictionarySearchParams(
      searchTerm: text,
      maximumDictionarySearchResults: 200,
      maximumDictionaryTermsInResult: 10,
      enabledDictionaryIds: const [1],
      searchWithWildcards: typed,
      sendPort: ReceivePort().sendPort,
      directoryPath: directory.path,
      hiddenDictionaryIds: hidden,
    ));
    return [
      for (int id in outcome?.headingIds ?? const <int>[])
        () {
          DictionaryHeading heading = isar.dictionaryHeadings.getSync(id)!;
          return '${heading.term}【${heading.reading}】';
        }(),
    ];
  }

  test('the start of a word finds it by its reading', () async {
    expect(await search('ずうず', typed: true), ['図々しい【ずうずうしい】']);
  });

  test('a word shows longer words after it, not shorter ones', () async {
    List<String> found = await search('へいし', typed: true);
    expect(found.take(2), containsAll(['兵士【へいし】', '閉止【へいし】']));
    expect(found, contains('兵舎【へいしゃ】'));
    expect(found, isNot(contains('塀【へい】')));
    expect(await search('へいしょ', typed: true), ['閉所恐怖症【へいしょきょうふしょう】']);
  });

  test('spellings with the same meanings show once', () async {
    expect(await search('ずうずうしい', typed: true), ['図々しい【ずうずうしい】']);
  });

  test('hiragana finds words written in katakana', () async {
    expect(await search('こーひ', typed: true), ['コーヒー【】']);
  });

  test('typed text still deinflects, and a sentence finds its first word',
      () async {
    expect(await search('たべた', typed: true), ['食べる【たべる】']);
    expect((await search('食べたい気分', typed: true)).first, '食べる【たべる】');
  });

  test("a hidden dictionary's words are left out", () async {
    expect(await search('へいし', typed: true, hidden: [1]), isEmpty);
    expect(await search('へいし', typed: true, hidden: [2]),
        await search('へいし', typed: true));
  });

  test('tapped in a book, the longest word comes first', () async {
    List<String> found = await search('へいしは', typed: false);
    expect(found.first, '兵士【へいし】');
    expect(found, contains('塀【へい】'));
    expect((await search('ずうずうしいな', typed: false)).first, '図々しい【ずうずうしい】');
  });
}
