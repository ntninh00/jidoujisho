import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/language.dart';
import 'package:yuuna/models.dart';

/// Runs the dictionary search worker against a real Isar database with a
/// small Japanese dictionary.
void main() {
  late Directory directory;
  late Isar isar;
  final ReceivePort log = ReceivePort();

  DictionarySearchParams params(String term) => DictionarySearchParams(
        searchTerm: term,
        maximumDictionarySearchResults: 200,
        maximumDictionaryTermsInResult: 10,
        enabledDictionaryIds: [],
        searchWithWildcards: false,
        sendPort: log.sendPort,
        directoryPath: directory.path,
      );

  setUpAll(() async {
    /// The worker isolate loads isar.dll by name, which finds it here.
    await Isar.initializeIsarCore(
      download: true,
      libraries: {
        Abi.current(): path.join(Directory.current.path, 'isar.dll'),
      },
    );
    directory = Directory.systemTemp.createTempSync('jdj_search_');
    isar = await Isar.open(
      globalSchemas,
      directory: directory.path,
      maxSizeMiB: 256,
    );

    Dictionary dictionary = Dictionary(
      id: 1,
      name: 'Test',
      formatKey: 'yomichan',
      order: 0,
    );
    List<List<String>> words = [
      ['食べる', 'たべる', 'to eat'],
      ['食べ物', 'たべもの', 'food'],
      ['猫', 'ねこ', 'cat'],
      ['名前', 'なまえ', 'name'],
    ];
    isar.writeTxnSync(() {
      isar.dictionarys.putSync(dictionary);
      for (List<String> word in words) {
        DictionaryHeading heading =
            DictionaryHeading(term: word[0], reading: word[1]);
        isar.dictionaryHeadings.putSync(heading);
        DictionaryEntry entry =
            DictionaryEntry(definitions: [word[2]], popularity: 1);
        entry.heading.value = heading;
        entry.dictionary.value = dictionary;
        isar.dictionaryEntrys.putSync(entry);
      }
    });
  });

  tearDownAll(() async {
    DictionarySearchWorker.instance.shutdown();
    log.close();
    await isar.close(deleteFromDisk: true);
  });

  test('finds a deinflected word and stores it for history', () async {
    Stopwatch first = Stopwatch()..start();
    DictionarySearchReply? reply = await DictionarySearchWorker.instance.search(
      function: prepareSearchResultsJapaneseLanguage,
      params: params('食べたい'),
    );
    first.stop();

    expect(reply, isNotNull);
    DictionarySearchOutcome outcome = reply!.outcome!;
    int eat = DictionaryHeading.hash(term: '食べる', reading: 'たべる');
    expect(outcome.headingIds.first, eat);

    /// 食べたい deinflects to 食べる across all four characters.
    expect(outcome.bestLength, 4);

    int? stored = await reply.persisted;
    expect(stored, isNotNull);
    DictionarySearchResult result =
        isar.dictionarySearchResults.getSync(stored!)!;
    expect(result.headingIds, outcome.headingIds);
    expect(result.headings.length, outcome.headingIds.length);

    Stopwatch second = Stopwatch()..start();
    DictionarySearchReply? again = await DictionarySearchWorker.instance.search(
      function: prepareSearchResultsJapaneseLanguage,
      params: params('猫が'),
    );
    second.stop();
    expect(again!.outcome!.headingIds.first,
        DictionaryHeading.hash(term: '猫', reading: 'ねこ'));

    // ignore: avoid_print
    print('first search ${first.elapsedMilliseconds} ms (starts worker), '
        'second ${second.elapsedMilliseconds} ms');
  });

  test('a newer search on the same channel replaces a queued one', () async {
    Future<DictionarySearchReply?> a = DictionarySearchWorker.instance.search(
      function: prepareSearchResultsJapaneseLanguage,
      params: params('名前は'),
      channel: 'popup',
    );
    Future<DictionarySearchReply?> b = DictionarySearchWorker.instance.search(
      function: prepareSearchResultsJapaneseLanguage,
      params: params('食べ物を'),
      channel: 'popup',
    );
    Future<DictionarySearchReply?> c = DictionarySearchWorker.instance.search(
      function: prepareSearchResultsJapaneseLanguage,
      params: params('猫'),
      channel: 'popup',
    );

    DictionarySearchReply? first = await a;
    DictionarySearchReply? replaced = await b;
    DictionarySearchReply? latest = await c;

    expect(first, isNotNull);
    expect(replaced, isNull);
    expect(latest!.outcome!.headingIds.first,
        DictionaryHeading.hash(term: '猫', reading: 'ねこ'));
  });

  test('a search with no match returns nothing and stores nothing', () async {
    DictionarySearchReply? reply = await DictionarySearchWorker.instance.search(
      function: prepareSearchResultsJapaneseLanguage,
      params: params('ぬぬぬ'),
    );
    expect(reply, isNotNull);
    expect(reply!.outcome, isNull);
    expect(await reply.persisted, isNull);
  });

  test('English search runs on the same worker', () async {
    isar.writeTxnSync(() {
      Dictionary dictionary = isar.dictionarys.getSync(1)!;
      DictionaryHeading heading = DictionaryHeading(term: 'run');
      isar.dictionaryHeadings.putSync(heading);
      DictionaryEntry entry =
          DictionaryEntry(definitions: ['to move fast'], popularity: 1);
      entry.heading.value = heading;
      entry.dictionary.value = dictionary;
      isar.dictionaryEntrys.putSync(entry);
    });

    DictionarySearchReply? reply = await DictionarySearchWorker.instance.search(
      function: prepareSearchResultsEnglishLanguage,
      params: params('running fast'),
    );
    expect(reply!.outcome!.headingIds,
        contains(DictionaryHeading.hash(term: 'run', reading: '')));
  });

  test('a word in My words is listed before other dictionaries', () async {
    isar.writeTxnSync(() {
      Dictionary dictionary = isar.dictionarys.getSync(1)!;
      DictionaryHeading heading = DictionaryHeading(term: 'rag');
      isar.dictionaryHeadings.putSync(heading);
      DictionaryEntry entry =
          DictionaryEntry(definitions: ['a piece of cloth'], popularity: 5);
      entry.heading.value = heading;
      entry.dictionary.value = dictionary;
      isar.dictionaryEntrys.putSync(entry);
    });

    int entryId = MyWords.save(
      isar,
      term: 'RAG',
      meaning:
          'Retrieval-augmented generation\nLooks things up before answering',
    );
    int mine = DictionaryHeading.hash(term: 'RAG', reading: '');

    DictionarySearchReply? reply = await DictionarySearchWorker.instance.search(
      function: prepareSearchResultsEnglishLanguage,
      params: params('RAG is useful'),
    );
    expect(reply!.outcome!.headingIds.first, mine);
    expect(reply.outcome!.headingIds,
        contains(DictionaryHeading.hash(term: 'rag', reading: '')));

    /// The dictionary comes first in order and keeps the user's lines.
    expect(isar.dictionarys.getSync(MyWords.dictionaryId)!.order, 0);
    MyWord word = MyWords.all(isar).single;
    expect(word.term, 'RAG');
    expect(word.meaning,
        'Retrieval-augmented generation\nLooks things up before answering');

    /// Editing stores a new entry; deleting removes the heading made for it.
    int edited = MyWords.save(
      isar,
      term: 'RAG',
      meaning: 'Retrieval-augmented generation',
      replaceEntryId: entryId,
    );
    expect(edited, isNot(entryId));
    expect(isar.dictionaryEntrys.getSync(entryId), isNull);
    MyWords.delete(isar, edited);
    expect(MyWords.all(isar), isEmpty);
    expect(isar.dictionaryHeadings.getSync(mine), isNull);
  });

  test('Latin text searched in Japanese finds English terms and romaji',
      () async {
    int entryId = MyWords.save(
      isar,
      term: 'SaaS',
      meaning: 'software as a service',
    );

    DictionarySearchReply? saas = await DictionarySearchWorker.instance.search(
      function: prepareSearchResultsLatinForJapanese,
      params: params('SaaS'),
    );
    expect(saas!.outcome!.headingIds.first,
        DictionaryHeading.hash(term: 'SaaS', reading: ''));

    DictionarySearchReply? neko = await DictionarySearchWorker.instance.search(
      function: prepareSearchResultsLatinForJapanese,
      params: params('neko'),
    );
    expect(neko!.outcome!.headingIds.first,
        DictionaryHeading.hash(term: '猫', reading: 'ねこ'));

    expect(isLatinOnly('SaaS'), isTrue);
    expect(isLatinOnly('SaaSとは'), isFalse);
    MyWords.delete(isar, entryId);
  });

  test('a selection like "software as a service (SaaS)" splits into a term',
      () {
    expect(MyWords.split('software as a\nservice (SaaS)'),
        (term: 'SaaS', meaning: 'software as a service'));
    expect(MyWords.split('RAG (retrieval-augmented generation).'),
        (term: 'RAG', meaning: 'retrieval-augmented generation'));
    expect(MyWords.split('サービスとしてのソフトウェア（SaaS）'),
        (term: 'SaaS', meaning: 'サービスとしてのソフトウェア'));
    expect(MyWords.split('just a phrase'), isNull);
  });

  test('terms keep the book they came from, and list by book', () {
    TermOrigin origin = const TermOrigin(
      bookKey: '52160/3',
      bookTitle: 'Designing Data-Intensive Applications',
      characters: 1200,
      progress: 0.42,
      excerpt: 'software as a service (SaaS)',
    );
    int first = MyWords.save(
      isar,
      term: 'SaaS',
      meaning: 'software as a service',
      origin: origin,
      fromLabel: 'From Designing Data-Intensive Applications',
    );
    int second = MyWords.save(
      isar,
      term: 'OLTP',
      origin:
          const TermOrigin(bookKey: '52160/3', bookTitle: 'D', progress: 0.1),
    );
    int other =
        MyWords.save(isar, term: 'ETL', meaning: 'extract, transform, load');

    List<MyWord> fromBook = MyWords.fromBook(isar, '52160/3');
    expect(fromBook.map((word) => word.term), ['OLTP', 'SaaS']);
    MyWord saas = fromBook.last;
    expect(saas.meaning, 'software as a service');
    expect(saas.origin!.excerpt, 'software as a service (SaaS)');
    expect(saas.origin!.characters, 1200);
    expect(fromBook.first.meaning, isEmpty);

    /// The line naming the book is shown small and in italics.
    DictionaryEntry entry = isar.dictionaryEntrys.getSync(first)!;
    dom.Element node = StructuredContent.processContent(
      jsonDecode(entry.definitions.last),
    )!
        .toNode() as dom.Element;
    String html = node.outerHtml;
    expect(html, contains('From Designing Data-Intensive Applications'));
    expect(html, contains('italic'));

    for (int id in [first, second, other]) {
      MyWords.delete(isar, id);
    }
  });

  test('the dictionary called My words is renamed My terms', () {
    int id = MyWords.save(isar, term: 'X', meaning: 'x');
    Dictionary mine = isar.dictionarys.getSync(MyWords.dictionaryId)!;
    isar.writeTxnSync(() {
      isar.dictionarys.putSync(Dictionary(
        id: mine.id,
        name: 'My words',
        formatKey: mine.formatKey,
        order: mine.order,
      ));
    });
    MyWords.rename(isar);
    expect(isar.dictionarys.getSync(MyWords.dictionaryId)!.name, 'My terms');
    expect(MyWords.all(isar).single.term, 'X');
    MyWords.delete(isar, id);
  });

  test('English matches whole words, not the start of a longer word', () async {
    isar.writeTxnSync(() {
      Dictionary dictionary = isar.dictionarys.getSync(1)!;
      DictionaryHeading heading = DictionaryHeading(term: 'boo');
      isar.dictionaryHeadings.putSync(heading);
      DictionaryEntry entry =
          DictionaryEntry(definitions: ['to bellow'], popularity: 1);
      entry.heading.value = heading;
      entry.dictionary.value = dictionary;
      isar.dictionaryEntrys.putSync(entry);
    });

    DictionarySearchReply? book = await DictionarySearchWorker.instance.search(
      function: prepareSearchResultsEnglishLanguage,
      params: params('book has been'),
    );
    expect(book!.outcome, isNull);

    DictionarySearchReply? boo = await DictionarySearchWorker.instance.search(
      function: prepareSearchResultsEnglishLanguage,
      params: params('boo, she said'),
    );
    expect(boo!.outcome!.headingIds.first,
        DictionaryHeading.hash(term: 'boo', reading: ''));
  });
}
