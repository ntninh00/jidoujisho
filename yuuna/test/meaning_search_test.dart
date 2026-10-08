import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';

/// Finding words by what they mean, in a real Isar database: a Japanese-
/// English and a Japanese-Vietnamese dictionary, their meanings indexed in
/// the background as after an update.
void main() {
  group('meaning words', () {
    test('are folded, without accents or common English words', () {
      expect(foldMeaningText('Mèo ĐEN Ünïcode'), 'meo den unicode');
      List<int> origins = [];
      expect(foldMeaningText('mèo', origins), 'meo');
      expect(origins, [0, 1, 3]);
      expect(
        meaningWordsOfText('to eat (food); con mèo, 猫, a ô x'),
        ['eat', 'food', 'con', 'meo', 'o'],
      );
    });

    test('leave out examples, notes and tags, but keep brackets', () {
      String jitendex = jsonEncode([
        {
          'tag': 'span',
          'data': {'content': 'part-of-speech-info'},
          'content': 'noun',
        },
        {
          'tag': 'ul',
          'data': {'content': 'glossary'},
          'content': [
            {'tag': 'li', 'content': 'cat (esp. the domestic cat)'},
            {'tag': 'li', 'content': 'shamisen'},
          ],
        },
        {
          'tag': 'div',
          'data': {'content': 'example-sentence'},
          'content': 'The dog chased the cat.',
        },
      ]);
      expect(meaningWordsOf([jitendex]),
          ['cat', 'esp', 'domestic', 'shamisen']);
      expect(meaningUnitsOf([jitendex]), ['cat', 'shamisen']);
      expect(meaningUnitsOf(['to eat; to drink, (formal) to dine']),
          ['eat', 'drink', 'dine']);
      expect(meaningUnitsOf(['dog (Canis (lupus) familiaris); canine']),
          ['dog', 'canine']);
    });
  });

  test('marks the words found, as written', () {
    String html = definitionHtml(
      'con mèo đen; MEO',
      css: const [],
      theme: const DictionaryCssTheme(
        text: Colors.black,
        background: Colors.white,
        fontSize: 15,
      ),
      marks: const MeaningMarks(words: ['meo'], color: Color(0xFFFFEE00)),
    );
    expect(
      html,
      contains('con <span style="background-color:#ffee00;">mèo</span> đen; '
          '<span style="background-color:#ffee00;">MEO</span>'),
    );
  });

  group('in a database', () {
    late Directory directory;
    late Isar isar;

    Future<void> install(int id, String name, List<List<Object>> words) async {
      Directory resources = Directory(path.join(directory.path, 'res$id'))
        ..createSync();
      File(path.join(resources.path, 'index.json'))
          .writeAsStringSync(jsonEncode({'title': name, 'revision': '1'}));
      File(path.join(resources.path, 'term_bank_1.json'))
          .writeAsStringSync(jsonEncode(words));
      ReceivePort port = ReceivePort()..listen((_) {});
      await compute(
        depositDictionaryDataHelper,
        PrepareDictionaryParams(
          dictionary:
              Dictionary(id: id, name: name, formatKey: 'yomichan', order: id),
          dictionaryFormat: YomichanFormat.instance,
          resourceDirectory: resources,
          directoryPath: directory.path,
          sendPort: port.sendPort,
          alertSendPort: port.sendPort,
        ),
      );
      port.close();
    }

    List<Object> word(String term, String reading, List<Object> meanings,
            {int score = 0}) =>
        [term, reading, '', '', score, meanings, 0, ''];

    setUpAll(() async {
      await Isar.initializeIsarCore(
        download: true,
        libraries: {
          Abi.current(): path.join(Directory.current.path, 'isar.dll'),
        },
      );
      directory = Directory.systemTemp.createTempSync('jdj_meaning_');
      await install(1, 'English', [
        word('猫', 'ねこ', ['cat'], score: 9),
        word('猫舌', 'ねこじた', ["cat's tongue", 'aversion to hot food']),
        word('キャット', '', ['cat (esp. as a pet)']),
        word('犬', 'いぬ', ['dog'], score: 9),
        word('食べる', 'たべる', ['to eat'], score: 9),
        word('薔薇', 'ばら', ['rose (plant of the genus Rosa or its flower)']),
      ]);
      await install(2, 'Vietnamese', [
        word('猫', 'ねこ', ['con mèo']),
        word('鳴く', 'なく', ['kêu (mèo, chim)']),
        word('明るい', 'あかるい', ['sáng sủa']),
      ]);

      /// As after the update: the entries are there, their words not yet.
      ReceivePort port = ReceivePort();
      List<double> progress = [];
      port.listen((message) => progress.add((message as List)[1] as double));
      await compute(
        indexMeaningsHelper,
        IndexMeaningsParams(
          directoryPath: directory.path,
          after: 0,
          sendPort: port.sendPort,
        ),
      );
      port.close();
      expect(progress.last, 1);

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

    /// The words found for [text], as `term (dictionary)`, best first.
    Future<List<String>> search(String text, {bool typed = false}) async {
      DictionarySearchOutcome? outcome = await prepareSearchResultsByMeaning(
        DictionarySearchParams(
          searchTerm: text,
          maximumDictionarySearchResults: 20,
          maximumDictionaryTermsInResult: 10,
          enabledDictionaryIds: const [],
          searchWithWildcards: typed,
          sendPort: ReceivePort().sendPort,
          directoryPath: directory.path,
        ),
      );
      return [
        for (DictionaryHeading? heading in isar.dictionaryHeadings
            .getAllSync(outcome?.headingIds ?? const []))
          heading!.term,
      ];
    }

    test('a meaning that is the word comes before one that has it', () async {
      expect(await search('cat'), ['猫', 'キャット', '猫舌']);
      expect(await search('eat'), ['食べる']);
      expect(await search('to eat'), ['食べる']);
      expect(await search('hot food'), ['猫舌']);
    });

    test('words in brackets are found too', () async {
      expect(await search('flower'), ['薔薇']);
      expect(await search('chim'), ['鳴く']);
    });

    test('accents may be left out', () async {
      expect(await search('mèo'), ['猫', '鳴く']);
      expect(await search('meo'), ['猫', '鳴く']);
      expect(await search('sang sua'), ['明るい']);
    });

    test('the last word typed may be unfinished', () async {
      expect(await search('con mè', typed: true), ['猫']);
      expect(await search('con mè'), isEmpty);
      expect(await search('xyz'), isEmpty);
    });

    test('ranges of entries are indexed apart, each to its end', () async {
      int before = isar.dictionaryMeanings.countSync();
      List<int> ids = isar.dictionaryEntrys.where().idProperty().findAllSync();
      isar.writeTxnSync(() => isar.dictionaryMeanings.clearSync());
      int middle = ids[ids.length ~/ 2];
      for (var (after, through) in [(0, middle), (middle, null)]) {
        ReceivePort port = ReceivePort()..listen((_) {});
        await compute(
          indexMeaningsHelper,
          IndexMeaningsParams(
            directoryPath: directory.path,
            after: after,
            through: through,
            sendPort: port.sendPort,
          ),
        ).timeout(const Duration(seconds: 20));
        port.close();
      }
      expect(isar.dictionaryMeanings.countSync(), before);
    });

    test('words go with their dictionary', () async {
      int before = isar.dictionaryMeanings.countSync();
      deleteDictionaryData(isar, 2);
      expect(isar.dictionaryMeanings.countSync(), before - 3);
      expect(await search('meo'), isEmpty);
      expect(await search('cat'), ['猫', 'キャット', '猫舌']);
    });
  });
}
