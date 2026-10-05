import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:yuuna/dictionary.dart';

/// A word the user defined, as listed in My words.
class MyWord {
  /// Describe a word the user defined.
  const MyWord({
    required this.entryId,
    required this.term,
    required this.reading,
    required this.meaning,
  });

  /// The dictionary entry holding the meaning.
  final int entryId;

  /// The word or phrase, such as `RAG`.
  final String term;

  /// An optional reading, used for Japanese.
  final String reading;

  /// What the user wrote, one line per definition.
  final String meaning;
}

/// The user's own dictionary. Words added here are ordinary dictionary
/// entries, so every search finds them, and they are listed first.
class MyWords {
  MyWords._();

  /// A fixed id, far above the ids imported dictionaries are given.
  static const int dictionaryId = 4000000000001;

  /// Shown as the dictionary name above each meaning.
  static const String dictionaryName = 'My words';

  /// Meanings are stored as plain structured content strings.
  static const String formatKey = 'yomichan';

  /// One definition per non-empty line. Each line is stored as a JSON string
  /// so it is shown as text, never read as HTML.
  static List<String> definitionsOf(String meaning) => meaning
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map(jsonEncode)
      .toList();

  /// The meaning as the user wrote it.
  static String meaningOf(DictionaryEntry entry) {
    return entry.definitions.map((definition) {
      try {
        Object? value = jsonDecode(definition);
        return value is String ? value : definition;
      } catch (_) {
        return definition;
      }
    }).join('\n');
  }

  /// The dictionary, if any word was ever added.
  static Dictionary? dictionaryIn(Isar database) =>
      database.dictionarys.getSync(dictionaryId);

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

  /// Every word, newest first.
  static List<MyWord> all(Isar database) {
    Dictionary? dictionary = dictionaryIn(database);
    if (dictionary == null) {
      return const [];
    }
    List<DictionaryEntry> entries = dictionary.entries.filter().findAllSync()
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));

    return entries.map((entry) {
      entry.heading.loadSync();
      DictionaryHeading? heading = entry.heading.value;
      return MyWord(
        entryId: entry.id!,
        term: heading?.term ?? '',
        reading: heading?.reading ?? '',
        meaning: meaningOf(entry),
      );
    }).toList();
  }

  /// The word the user defined for [heading], if any.
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
    return MyWord(
      entryId: entry.id!,
      term: heading.term,
      reading: heading.reading,
      meaning: meaningOf(entry),
    );
  }

  /// Adds a word, or replaces the entry [replaceEntryId]. An edit is stored
  /// as a new entry so no cached rendering of the old meaning is shown.
  static int save(
    Isar database, {
    required String term,
    required String meaning,
    String reading = '',
    int? replaceEntryId,
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
        definitions: definitionsOf(meaning),
        popularity: 0,
      );
      entry.heading.value = heading;
      entry.dictionary.value = mine;
      return database.dictionaryEntrys.putSync(entry);
    });
  }

  /// Removes a word.
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

    /// A heading made only for this word goes with it.
    if (heading != null &&
        heading.entries.countSync() == 0 &&
        heading.pitches.countSync() == 0 &&
        heading.frequencies.countSync() == 0) {
      database.dictionaryHeadings.deleteSync(heading.id);
    }
  }

  /// Moves headings the user defined in My words to the front, keeping the
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
