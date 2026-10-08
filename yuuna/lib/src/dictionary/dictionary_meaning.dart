import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:isar/isar.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';

part 'dictionary_meaning.g.dart';

/// The words of a [DictionaryEntry]'s meanings, for finding a word by what
/// it means. Kept apart from the entry, under the entry's id, so entries
/// already stored get theirs without being written again.
@Collection()
class DictionaryMeaning {
  /// Words for the entry with [id].
  DictionaryMeaning({required this.id, required this.words});

  /// The id of the entry these words are from.
  final Id id;

  /// Lower case and without accents, each once. See [meaningWordsOf].
  @Index(type: IndexType.value)
  final List<String> words;
}

/// Most words kept for one entry, so a long article costs no more than a
/// short one.
const int _maximumWords = 100;

/// Parts of structured content that are not the meaning: examples, notes,
/// tags, forms, readings and the like, as dictionaries name them in their
/// `data`. A name is taken apart at its hyphens, so `example-sentence` and
/// `part-of-speech-info` are left out but `sense-groups` is not.
const Set<String> _notMeaning = {
  'example', 'examples', 'note', 'notes', 'attribution', 'form', 'forms', //
  'xref', 'xrefs', 'reference', 'references', 'antonym', 'antonyms',
  'info', 'facts', 'ipa', 'label', 'translation', 'pill', 'idiom',
  'tag', 'tags',
};

/// Words too common in English glosses to find anything by.
const Set<String> _stopWords = {
  'a', 'an', 'the', 'of', 'to', 'in', 'on', 'at', 'for', 'and', 'or', //
  'as', 'by', 'with', 'from', 'that', 'this', 'it', 'its', 'sb', 'sth',
  'etc',
};

/// Scripts written without spaces between words, which are not split into
/// words here.
final RegExp _unspaced = RegExp(
  r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Thai}'
  r'\p{Script=Lao}\p{Script=Khmer}\p{Script=Myanmar}]',
  unicode: true,
);
final RegExp _word = RegExp(r'[\p{L}\p{M}]+', unicode: true);

/// Lower-case letters with accents, and what each is without them: Latin,
/// Greek and Cyrillic, from Unicode's decompositions.
const String _accented = 'àáâãäåçèéêëìíîïñòóôõöøùúûüýÿāăąćĉċčďđēĕė'
    'ęěĝğġģĥħĩīĭįıĵķĺļľŀłńņňōŏőŕŗřśŝşšţťŧũūŭů'
    'űųŵŷźżžƀơưƶǎǐǒǔǖǘǚǜǟǡǣǥǧǩǫǭǯǰǵǹǻǽǿȁȃȅȇȉȋ'
    'ȍȏȑȓȕȗșțȟȧȩȫȭȯȱȳɍɏΐάέήίΰϊϋόύώйѐёѓїќѝўѷӂӑ'
    'ӓӗӛӝӟӣӥӧӫӭӯӱӳӵӹḁḃḅḇḉḋḍḏḑḓḕḗḙḛḝḟḡḣḥḧḩḫḭḯḱ'
    'ḳḵḷḹḻḽḿṁṃṅṇṉṋṍṏṑṓṕṗṙṛṝṟṡṣṥṧṩṫṭṯṱṳṵṷṹṻṽṿẁ'
    'ẃẅẇẉẋẍẏẑẓẕẖẗẘẙẛạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏố'
    'ồổỗộớờởỡợụủứừửữựỳỵỷỹἀἁἂἃἄἅἆἇἐἑἒἓἔἕἠἡἢἣἤἥ'
    'ἦἧἰἱἲἳἴἵἶἷὀὁὂὃὄὅὐὑὒὓὔὕὖὗὠὡὢὣὤὥὦὧὰάὲέὴήὶί'
    'ὸόὺύὼώᾀᾁᾂᾃᾄᾅᾆᾇᾐᾑᾒᾓᾔᾕᾖᾗᾠᾡᾢᾣᾤᾥᾦᾧᾰᾱᾲᾳᾴᾶᾷῂῃῄ'
    'ῆῇῐῑῒΐῖῗῠῡῢΰῤῥῦῧῲῳῴῶῷ';
const String _plain = 'aaaaaaceeeeiiiinoooooouuuuyyaaaccccddeee'
    'eegggghhiiiiijklllllnnnooorrrsssstttuuuu'
    'uuwyzzzbouzaiouuuuuaaæggkooʒjgnaæøaaeeii'
    'oorruusthaeooooyryιαεηιυιυουωиеегікиуѵжа'
    'аеәжзииоөэууучыabbbcdddddeeeeefghhhhhiik'
    'kkllllmmmnnnnoooopprrrrsssssttttuuuuuvvw'
    'wwwwxxyzzzhtwyſaaaaaaaaaaaaeeeeeeeeiiooo'
    'ooooooooouuuuuuuyyyyααααααααεεεεεεηηηηηη'
    'ηηιιιιιιιιοοοοοουυυυυυυυωωωωωωωωααεεηηιι'
    'οουυωωααααααααηηηηηηηηωωωωωωωωαααααααηηη'
    'ηηιιιιιιυυυυρρυυωωωωω';

final Map<int, int> _folds = Map.fromIterables(_accented.runes, _plain.runes);

/// [text] in lower case without accents, one character for each of its
/// own, with accents written apart dropped. [origins], when given, gets the
/// position in [text] each character of the result came from.
String foldMeaningText(String text, [List<int>? origins]) {
  StringBuffer folded = StringBuffer();
  int at = 0;
  for (int rune in text.runes) {
    int width = rune > 0xFFFF ? 2 : 1;
    if (rune >= 0x300 && rune <= 0x36F) {
      at += width;
      continue;
    }
    String lower = String.fromCharCode(rune).toLowerCase();
    int lowered = lower.runes.length == 1 ? lower.runes.first : rune;
    int plain = _folds[lowered] ?? lowered;
    folded.writeCharCode(plain);
    if (origins != null) {
      origins.add(at);
      if (plain > 0xFFFF) {
        origins.add(at);
      }
    }
    at += width;
  }
  return folded.toString();
}

/// The words of [text] as the meaning index keeps them, in order, each
/// once: folded with [foldMeaningText], without words of scripts written
/// without spaces, common English words, or single plain letters.
List<String> meaningWordsOfText(String text) {
  Set<String> words = {};
  for (Match match in _word.allMatches(text.toLowerCase())) {
    String word = match.group(0)!;
    bool ascii = word.codeUnits.every((unit) => unit < 0x80);
    if (ascii ? word.length == 1 : _unspaced.hasMatch(word)) {
      continue;
    }
    String folded = ascii ? word : foldMeaningText(word);
    if (_stopWords.contains(folded)) {
      continue;
    }
    words.add(folded);
  }
  return words.toList();
}

/// The meanings of stored definitions as blocks of text: each line of
/// text, and what each list item or block of structured content says,
/// without its examples, notes and tags.
List<String> _meaningBlocks(List<String> definitions) {
  List<String> blocks = [];
  for (String definition in definitions) {
    Object? content = _structured(definition);
    if (content == null) {
      blocks.addAll(definition.split('\n'));
      continue;
    }
    StringBuffer current = StringBuffer();
    void flush() {
      if (current.isNotEmpty) {
        blocks.add(current.toString());
        current.clear();
      }
    }

    void walk(Object? node) {
      if (node is String) {
        current.write(node);
      } else if (node is List) {
        node.forEach(walk);
      } else if (node is Map) {
        if (node['type'] == 'structured-content') {
          walk(node['content']);
          return;
        }
        if (node['type'] == 'text') {
          current.write('${node['text'] ?? ''}');
          return;
        }
        String tag = '${node['tag'] ?? ''}';
        if (tag == 'img' || tag == 'rt' || tag == 'rp') {
          return;
        }
        Object? data = node['data'];
        if (data is Map &&
            data.values.any((value) => '$value'
                .toLowerCase()
                .split(RegExp('[-_ ]'))
                .any(_notMeaning.contains))) {
          return;
        }
        bool block = const {
          'div', 'li', 'ol', 'ul', 'p', 'td', 'th', 'tr', 'table', 'br', //
          'details', 'summary',
        }.contains(tag);
        if (block) {
          flush();
        }
        walk(node['content']);
        if (block) {
          flush();
        }
      }
    }

    walk(content);
    flush();
  }
  return blocks;
}

/// Innermost brackets, which [meaningUnitsOf] removes until none are left.
final RegExp _bracketed = RegExp(r'\([^()]*\)|\[[^\[\]]*\]');

/// The meanings of stored definitions one at a time, as compared with a
/// search: blocks from [_meaningBlocks] split where they list several,
/// as in `nhà ở, căn nhà`, without what is in brackets, and without the
/// `to` of an English verb.
List<String> meaningUnitsOf(List<String> definitions) {
  List<String> units = [];
  for (String block in _meaningBlocks(definitions)) {
    String bare = block;
    for (String last = ''; last != bare;) {
      last = bare;
      bare = bare.replaceAll(_bracketed, ' ');
    }
    for (String part in bare.split(RegExp('[;,/]|、|；|，'))) {
      String unit = part.replaceAll(RegExp(r'\s+'), ' ').trim();
      unit = unit.replaceFirst(RegExp('^to ', caseSensitive: false), '');
      if (unit.isNotEmpty) {
        units.add(unit);
      }
    }
  }
  return units;
}

/// The words of an entry's meanings for the meaning index, brackets and
/// all. See [meaningWordsOfText] and [_meaningBlocks].
List<String> meaningWordsOf(List<String> definitions) {
  Set<String> words = {};
  for (String block in _meaningBlocks(definitions)) {
    words.addAll(meaningWordsOfText(block));
    if (words.length >= _maximumWords) {
      break;
    }
  }
  return words.take(_maximumWords).toList();
}

/// Structured content stored as its JSON, or null for text.
Object? _structured(String definition) {
  String trimmed = definition.trimLeft();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
    return null;
  }
  try {
    Object? content = jsonDecode(definition);
    return content is List || content is Map ? content : null;
  } on FormatException {
    return null;
  }
}

/// What [indexMeaningsHelper] needs, sent to another isolate.
class IndexMeaningsParams {
  /// Index entries after [after], up to [through] if given.
  IndexMeaningsParams({
    required this.directoryPath,
    required this.after,
    required this.sendPort,
    this.through,
  });

  /// Where the database is.
  final String directoryPath;

  /// Entries up to this id have their words already.
  final int after;

  /// The last entry for this to index, so several can index a range each;
  /// null for every entry after [after], those added meanwhile too.
  final int? through;

  /// Gets `[id, progress]` after each batch: the entries up to `id` have
  /// their words, and `progress` is the share done, from 0 to 1.
  final SendPort sendPort;
}

/// Entries handled in one transaction: each is written to disk, so fewer
/// and larger ones are quicker, four times so from 1000 to 10000.
const int _batch = 5000;

/// Gives the entries after [IndexMeaningsParams.after] their words, a
/// batch at a time, in id order: new entries have higher ids than those
/// before them. Returns the highest id done.
Future<int> indexMeaningsHelper(IndexMeaningsParams params) async {
  final Isar isar = Isar.getInstance() ??
      await Isar.open(
        globalSchemas,
        directory: params.directoryPath,
        maxSizeMiB: 8192,
      );
  int? through = params.through;
  int last = through ??
      isar.dictionaryEntrys
          .where(sort: Sort.desc)
          .anyId()
          .idProperty()
          .findFirstSync() ??
      0;
  int start = params.after;
  int done = params.after;
  /// Isar gives the upper bound again when asked for what lies between it
  /// and itself, so the range's end is checked here.
  while (through == null || done < through) {
    List<DictionaryEntry> entries = (through == null
            ? isar.dictionaryEntrys.where().idGreaterThan(done)
            : isar.dictionaryEntrys
                .where()
                .idBetween(done + 1, through))
        .limit(_batch)
        .findAllSync();
    if (entries.isEmpty || entries.last.id! <= done) {
      break;
    }
    List<DictionaryMeaning> meanings = [];
    for (DictionaryEntry entry in entries) {
      List<String> words = meaningWordsOf(entry.definitions);
      if (words.isNotEmpty) {
        meanings.add(DictionaryMeaning(id: entry.id!, words: words));
      }
    }
    isar.writeTxnSync(() => isar.dictionaryMeanings.putAllSync(meanings));
    done = entries.last.id!;
    last = max(last, done);
    double progress = last == start ? 1 : (done - start) / (last - start);
    params.sendPort.send([done, progress.clamp(0, 1)]);
  }
  return done;
}

/// Finds words by what they mean: the entries whose meanings have every
/// word of the search term, each with accents or without. Best first:
/// - a meaning that is the search term, then one that has it, then entries
///   with its words apart;
/// - written with the same accents;
/// - in the entry's first meanings;
/// - more common.
///
/// The last word, while typed, may be the start of one when nothing has
/// the whole word.
Future<DictionarySearchOutcome?> prepareSearchResultsByMeaning(
    DictionarySearchParams params) async {
  String term = params.searchTerm.trim();
  List<String> words = meaningWordsOfText(term);
  if (words.isEmpty) {
    return null;
  }

  /// The search worker keeps the database open between searches.
  final Isar database = Isar.getInstance() ??
      await Isar.open(
        globalSchemas,
        directory: params.directoryPath,
        maxSizeMiB: 8192,
      );

  List<int> ids = _entriesWith(database, words, lastIsStart: false);
  if (ids.isEmpty && params.searchWithWildcards && !term.endsWith(' ')) {
    ids = _entriesWith(database, words, lastIsStart: true);
  }
  if (ids.isEmpty) {
    return DictionarySearchOutcome(
      searchTerm: term,
      bestLength: 0,
      headingIds: const [],
    );
  }

  String query = meaningUnitsOf([term]).join(' ').toLowerCase();
  String folded = foldMeaningText(query);
  RegExp within = RegExp(
    '(?<![\\p{L}\\p{M}\\p{N}])${RegExp.escape(folded)}(?![\\p{L}\\p{M}\\p{N}])',
    unicode: true,
  );

  List<(DictionaryEntry, List<num>)> ranked = [];
  for (int at = 0; at < ids.length; at += 500) {
    List<DictionaryEntry?> entries = database.dictionaryEntrys
        .getAllSync(ids.sublist(at, min(at + 500, ids.length)));
    for (DictionaryEntry? entry in entries) {
      if (entry == null) {
        continue;
      }
      List<String> units = meaningUnitsOf(entry.definitions);
      int tier = 2;
      int position = units.length;
      bool sameAccents = false;
      for (int i = 0; i < units.length; i++) {
        String unit = units[i].toLowerCase();
        String foldedUnit = foldMeaningText(unit);
        int unitTier = foldedUnit == folded
            ? 0
            : within.hasMatch(foldedUnit)
                ? 1
                : 2;
        if (unitTier < tier) {
          tier = unitTier;
          position = i;
          sameAccents = unit == query || unit.contains(query);
        }
        if (tier == 0) {
          break;
        }
      }
      int accents = sameAccents ? 0 : 1;
      ranked.add((entry, [tier, accents, min(position, 4), -entry.popularity]));
    }
  }
  ranked.sort((a, b) {
    for (int i = 0; i < a.$2.length; i++) {
      int order = a.$2[i].compareTo(b.$2[i]);
      if (order != 0) {
        return order;
      }
    }
    return 0;
  });

  List<int> headingIds = [];
  Set<int> seen = {};
  for (var (entry, _) in ranked) {
    entry.heading.loadSync();
    int? id = entry.heading.value?.id;
    if (id != null && seen.add(id)) {
      headingIds.add(id);
      if (headingIds.length >= params.maximumDictionaryTermsInResult) {
        break;
      }
    }
  }

  return DictionarySearchOutcome(
    searchTerm: term,
    bestLength: term.length,
    headingIds: headingIds,
  );
}

/// Most entries looked at for one search: those with the rarest word come
/// first.
const int _maximumCandidates = 3000;

/// Ids of entries whose words have all of [words], the last one as the
/// start of a word when [lastIsStart].
List<int> _entriesWith(
  Isar database,
  List<String> words, {
  required bool lastIsStart,
}) {
  QueryBuilder<DictionaryMeaning, DictionaryMeaning, QAfterWhereClause>
      matching(String word, {required bool start}) => start
          ? database.dictionaryMeanings.where().wordsElementStartsWith(word)
          : database.dictionaryMeanings.where().wordsElementEqualTo(word);

  List<(String, bool, int)> counted = [
    for (int i = 0; i < words.length; i++)
      (
        words[i],
        lastIsStart && i == words.length - 1,
        matching(words[i], start: lastIsStart && i == words.length - 1)
            .countSync(),
      ),
  ]..sort((a, b) => a.$3.compareTo(b.$3));
  if (counted.first.$3 == 0) {
    return const [];
  }

  var (rarest, rarestIsStart, _) = counted.first;
  List<int> ids = matching(rarest, start: rarestIsStart)
      .idProperty()
      .findAllSync()
      .toSet()
      .take(_maximumCandidates)
      .toList();
  if (counted.length == 1) {
    return ids;
  }

  List<DictionaryMeaning?> meanings =
      database.dictionaryMeanings.getAllSync(ids);
  return [
    for (DictionaryMeaning? meaning in meanings)
      if (meaning != null &&
          counted.skip(1).every((word) => word.$2
              ? meaning.words.any((have) => have.startsWith(word.$1))
              : meaning.words.contains(word.$1)))
        meaning.id,
  ];
}
