import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:yuuna/dictionary.dart';

/// Where a term was saved from: the book, the place in it, and the text
/// that was selected, so the term can lead back there.
class TermOrigin {
  /// Describe where a term was saved from.
  const TermOrigin({
    required this.bookKey,
    required this.bookTitle,
    this.characters = 0,
    this.progress = 0,
    this.excerpt = '',
  });

  /// The book's key, see `TtuBook.key`.
  final String bookKey;

  /// The book's title when the term was saved.
  final String bookTitle;

  /// ッツ's character position of the place.
  final int characters;

  /// The place as a fraction of the book.
  final double progress;

  /// The text selected or looked up there.
  final String excerpt;

  /// Whether the place in the book is known.
  bool get hasPlace => characters > 0 || progress > 0;

  /// Stored in the entry's spare field.
  String toJson() => jsonEncode({
        'book': bookKey,
        'title': bookTitle,
        'c': characters,
        'p': progress,
        'x': excerpt,
      });

  /// Reads an origin stored by [toJson], or null.
  static TermOrigin? fromJson(String? text) {
    if (text == null || text.isEmpty) {
      return null;
    }
    try {
      Map<String, dynamic> map = jsonDecode(text) as Map<String, dynamic>;
      return TermOrigin(
        bookKey: map['book'] as String,
        bookTitle: (map['title'] as String?) ?? '',
        characters: (map['c'] as num?)?.toInt() ?? 0,
        progress: (map['p'] as num?)?.toDouble() ?? 0,
        excerpt: (map['x'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// A term the user defined, as listed in My terms.
class MyWord {
  /// Describe a term the user defined.
  const MyWord({
    required this.entryId,
    required this.term,
    required this.reading,
    required this.meaning,
    this.origin,
  });

  /// The dictionary entry holding the meaning.
  final int entryId;

  /// The term, such as `SaaS`.
  final String term;

  /// An optional reading, used for Japanese.
  final String reading;

  /// What the user wrote, one line per definition. May be empty.
  final String meaning;

  /// The book it was saved from, if any.
  final TermOrigin? origin;
}

/// The user's own dictionary, My terms. Terms added here are ordinary
/// dictionary entries, so every search finds them, and they are listed first.
class MyWords {
  MyWords._();

  /// A fixed id, far above the ids imported dictionaries are given.
  static const int dictionaryId = 4000000000001;

  /// Shown as the dictionary name above each meaning.
  static const String dictionaryName = 'My terms';

  /// The name used before terms were called terms.
  static const String _oldDictionaryName = 'My words';

  /// Meanings are stored as plain structured content strings.
  static const String formatKey = 'yomichan';

  /// Splits a selection written as "software as a service (SaaS)" or
  /// "RAG (retrieval-augmented generation)" into the term and its meaning.
  /// The shorter side is the term. Null when the text has no such form.
  static ({String term, String meaning})? split(String selection) {
    String text = selection.replaceAll(RegExp(r'\s+'), ' ').trim();
    RegExpMatch? match =
        RegExp(r'^(.+?)\s*[(（]([^()（）]+)[)）]\s*[.,;:、。]?$').firstMatch(text);
    if (match == null) {
      return null;
    }
    String outside = match.group(1)!.trim();
    String inside = match.group(2)!.trim();
    if (outside.isEmpty || inside.isEmpty) {
      return null;
    }
    return inside.length <= outside.length
        ? (term: inside, meaning: outside)
        : (term: outside, meaning: inside);
  }

  /// One definition per non-empty line. Each line is stored as a JSON string
  /// so it is shown as text, never read as HTML. A line naming the book the
  /// term came from follows, in small italics.
  static List<String> definitionsOf(String meaning, {String? fromLabel}) => [
        ...meaning
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .map(jsonEncode),
        if (fromLabel != null)
          jsonEncode({
            'tag': 'span',
            'style': {'fontStyle': 'italic', 'fontSize': 'small'},
            'content': fromLabel,
          }),
      ];

  /// The meaning as the user wrote it, without the line naming the book.
  static String meaningOf(DictionaryEntry entry) {
    List<String> lines = [];
    for (String definition in entry.definitions) {
      try {
        Object? value = jsonDecode(definition);
        if (value is String) {
          lines.add(value);
        }
      } catch (_) {
        lines.add(definition);
      }
    }
    return lines.join('\n');
  }

  /// The dictionary, if any term was ever added.
  static Dictionary? dictionaryIn(Isar database) =>
      database.dictionarys.getSync(dictionaryId);

  /// Renames the dictionary from My words to My terms, once.
  static void rename(Isar database) {
    Dictionary? mine = dictionaryIn(database);
    if (mine == null || mine.name != _oldDictionaryName) {
      return;
    }
    bool taken = database.dictionarys
        .where()
        .findAllSync()
        .any((dictionary) => dictionary.name == dictionaryName);
    database.writeTxnSync(() {
      database.dictionarys.putSync(Dictionary(
        id: mine.id,
        name: taken ? '$dictionaryName (jidoujisho)' : dictionaryName,
        formatKey: mine.formatKey,
        order: mine.order,
        hiddenLanguages: mine.hiddenLanguages,
        collapsedLanguages: mine.collapsedLanguages,
      ));
    });
  }

  /// Creates the dictionary as the first one. Call inside a write transaction.
  static Dictionary _ensure(Isar database) {
    Dictionary? existing = database.dictionarys.getSync(dictionaryId);
    if (existing != null) {
      return existing;
    }

    List<Dictionary> others = database.dictionarys.where().findAllSync();
    for (Dictionary dictionary in others) {
      dictionary.order += 1;
    }
    database.dictionarys.putAllSync(others);

    /// Names are unique, so an imported dictionary already called this keeps
    /// its name.
    bool taken = others.any((dictionary) => dictionary.name == dictionaryName);
    Dictionary mine = Dictionary(
      id: dictionaryId,
      name: taken ? '$dictionaryName (jidoujisho)' : dictionaryName,
      formatKey: formatKey,
      order: 0,
    );
    database.dictionarys.putSync(mine);
    return mine;
  }

  static MyWord _wordOf(DictionaryEntry entry, DictionaryHeading? heading) {
    return MyWord(
      entryId: entry.id!,
      term: heading?.term ?? '',
      reading: heading?.reading ?? '',
      meaning: meaningOf(entry),
      origin: TermOrigin.fromJson(entry.extra),
    );
  }

  /// Every term, newest first.
  static List<MyWord> all(Isar database) {
    Dictionary? dictionary = dictionaryIn(database);
    if (dictionary == null) {
      return const [];
    }
    List<DictionaryEntry> entries = dictionary.entries.filter().findAllSync()
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));

    return entries.map((entry) {
      entry.heading.loadSync();
      return _wordOf(entry, entry.heading.value);
    }).toList();
  }

  /// Terms saved from the book with [bookKey], in reading order.
  static List<MyWord> fromBook(Isar database, String bookKey) {
    return all(database)
        .where((word) => word.origin?.bookKey == bookKey)
        .toList()
      ..sort((a, b) => a.origin!.characters.compareTo(b.origin!.characters));
  }

  /// The term the user defined for [heading], if any.
  static MyWord? forHeading(Isar database, DictionaryHeading heading) {
    if (dictionaryIn(database) == null) {
      return null;
    }
    DictionaryEntry? entry = heading.entries
        .filter()
        .dictionary((q) => q.idEqualTo(dictionaryId))
        .findFirstSync();
    if (entry == null) {
      return null;
    }
    return _wordOf(entry, heading);
  }

  /// Adds a term, or replaces the entry [replaceEntryId]. An edit is stored
  /// as a new entry so no cached rendering of the old meaning is shown.
  /// [fromLabel] is shown under the meaning, such as "From Some Book".
  static int save(
    Isar database, {
    required String term,
    String meaning = '',
    String reading = '',
    int? replaceEntryId,
    TermOrigin? origin,
    String? fromLabel,
  }) {
    return database.writeTxnSync(() {
      Dictionary mine = _ensure(database);
      if (replaceEntryId != null) {
        _delete(database, replaceEntryId);
      }

      int headingId = DictionaryHeading.hash(term: term, reading: reading);
      DictionaryHeading? heading =
          database.dictionaryHeadings.getSync(headingId);
      if (heading == null) {
        heading = DictionaryHeading(term: term, reading: reading);
        database.dictionaryHeadings.putSync(heading);
      }

      DictionaryEntry entry = DictionaryEntry(
        definitions: definitionsOf(meaning, fromLabel: fromLabel),
        popularity: 0,
        extra: origin?.toJson(),
      );
      entry.heading.value = heading;
      entry.dictionary.value = mine;
      int id = database.dictionaryEntrys.putSync(entry);
      List<String> words = meaningWordsOf(entry.definitions);
      if (words.isNotEmpty) {
        database.dictionaryMeanings
            .putSync(DictionaryMeaning(id: id, words: words));
      }
      return id;
    });
  }

  /// Removes a term.
  static void delete(Isar database, int entryId) {
    database.writeTxnSync(() => _delete(database, entryId));
  }

  static void _delete(Isar database, int entryId) {
    DictionaryEntry? entry = database.dictionaryEntrys.getSync(entryId);
    if (entry == null) {
      return;
    }
    entry.heading.loadSync();
    DictionaryHeading? heading = entry.heading.value;
    database.dictionaryEntrys.deleteSync(entryId);
    database.dictionaryMeanings.deleteSync(entryId);

    /// A heading made only for this term goes with it.
    if (heading != null &&
        heading.entries.countSync() == 0 &&
        heading.pitches.countSync() == 0 &&
        heading.frequencies.countSync() == 0) {
      database.dictionaryHeadings.deleteSync(heading.id);
    }
  }

  /// Moves headings the user defined in My terms to the front, keeping the
  /// order of the rest.
  static List<int> putFirst(Isar database, List<int> headingIds) {
    if (headingIds.length < 2 || dictionaryIn(database) == null) {
      return headingIds;
    }
    List<int> mine = [];
    List<int> rest = [];
    for (int id in headingIds) {
      DictionaryHeading? heading = database.dictionaryHeadings.getSync(id);
      bool defined = heading != null &&
          !heading.entries
              .filter()
              .dictionary((q) => q.idEqualTo(dictionaryId))
              .isEmptySync();
      (defined ? mine : rest).add(id);
    }
    if (mine.isEmpty) {
      return headingIds;
    }
    return [...mine, ...rest];
  }
}
