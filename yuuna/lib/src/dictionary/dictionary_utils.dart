import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';

/// FNV-1a 64bit hash algorithm optimized for Dart Strings.
/// This is used to generate integer IDs that can be hard assigned to entities
/// with string IDs with microscopically low collision. This allows for example,
/// a [DictionaryHeading]'s ID to always be determinable by its composite
/// parameters.
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}

/// Performed in another isolate with compute. This is a top-level utility
/// function that makes use of Isar allowing instances to be opened through
/// multiple isolates. The function for preparing entries and tags according to
/// the [DictionaryFormat] is also done in the same isolate, to remove having
/// to communicate potentially hundreds of thousands of entries to another
/// newly opened isolate.
///
/// A format that [DictionaryFormat.writesInBatches] commits its entries a
/// batch at a time, which keeps a large import from slowing down as it
/// grows: Jitendex went from minutes to well under one. Should the import
/// fail, what it wrote is removed again, so nothing of it is left.
Future<void> depositDictionaryDataHelper(PrepareDictionaryParams params) async {
  /// Create a new instance of Isar as this is a different isolate.
  final Isar isar = await Isar.open(
    globalSchemas,
    directory: params.directoryPath,
    maxSizeMiB: 8192,
  );
  DictionaryFormat format = params.dictionaryFormat;
  try {
    isar.writeTxnSync(() {
      isar.dictionarys.putSync(params.dictionary);
      format.prepareTags(params: params, isar: isar);
    });
    if (format.writesInBatches) {
      format.prepareEntries(params: params, isar: isar);
    } else {
      isar.writeTxnSync(() {
        format.prepareEntries(params: params, isar: isar);
      });
    }
    isar.writeTxnSync(() {
      format.preparePitches(params: params, isar: isar);
      format.prepareFrequencies(params: params, isar: isar);
    });
  } catch (e, stack) {
    debugPrint('$e');
    debugPrint('$stack');

    params.send('$stack');
    try {
      deleteDictionaryData(isar, params.dictionary.id);
    } catch (error) {
      debugPrint('Could not remove a failed import: $error');
    }

    rethrow;
  }
}

/// Preloads the entities linked to a search result.
void preloadResultSync(int id) {
  /// Create a new instance of Isar as this is a different isolate.
  final Isar database = Isar.getInstance()!;
  DictionarySearchResult result = database.dictionarySearchResults.getSync(id)!;

  result.headings.loadSync();

  for (DictionaryHeading heading in result.headings) {
    heading.entries.loadSync();
    for (DictionaryEntry entry in heading.entries) {
      entry.dictionary.loadSync();
      entry.tags.loadSync();
    }
    heading.pitches.loadSync();
    heading.frequencies.loadSync();
    for (DictionaryFrequency frequency in heading.frequencies) {
      frequency.dictionary.loadSync();
    }
    heading.tags.loadSync();
  }
}

/// Stores what a search found so it can appear in search history, linking
/// only the headings that are shown. Older results beyond
/// [maximumStoredResults] are removed. Returns the id of the stored result.
int persistSearchOutcome({
  required Isar database,
  required DictionarySearchOutcome outcome,
  required int maximumStoredResults,
}) {
  List<DictionaryHeading> headings = database.dictionaryHeadings
      .getAllSync(outcome.headingIds)
      .whereType<DictionaryHeading>()
      .toList();

  DictionarySearchResult result = DictionarySearchResult(
    searchTerm: outcome.searchTerm,
    bestLength: outcome.bestLength,
    headingIds: outcome.headingIds,
  );

  late int resultId;
  database.writeTxnSync(() {
    database.dictionarySearchResults.deleteBySearchTermSync(outcome.searchTerm);
    result.headings.addAll(headings);
    resultId = database.dictionarySearchResults.putSync(result);

    int count = database.dictionarySearchResults.countSync();
    if (count > maximumStoredResults) {
      database.dictionarySearchResults
          .where()
          .limit(count - maximumStoredResults)
          .build()
          .deleteAllSync();
    }
  });

  return resultId;
}

/// Add a [DictionarySearchResult] to the dictionary history. If the maximum value
/// is exceed, the dictionary history is cut down to the newest values.
Future<void> updateDictionaryHistoryHelper(
  UpdateDictionaryHistoryParams params,
) async {
  final Isar database = await Isar.open(
    globalSchemas,
    directory: params.directoryPath,
    maxSizeMiB: 8192,
  );

  DictionarySearchResult result =
      database.dictionarySearchResults.getSync(params.resultId)!;

  database.writeTxnSync(() {
    result.scrollPosition = params.newPosition;
    database.dictionarySearchResults.putSync(result);
  });
}

/// Clears all data from the dictionary database.
Future<void> deleteDictionariesHelper(DeleteDictionaryParams params) async {
  final Isar database = await Isar.open(
    globalSchemas,
    directory: params.directoryPath,
    maxSizeMiB: 8192,
  );

  database.writeTxnSync(() {
    database.dictionarySearchResults.clearSync();
    database.dictionaryTags.clearSync();
    database.dictionaryEntrys.clearSync();
    database.dictionaryHeadings.clearSync();
    database.dictionaryPitchs.clearSync();
    database.dictionaryFrequencys.clearSync();
    database.dictionarys.clearSync();
  });
}

/// Removes one dictionary's data. Search history is kept; results that
/// only this dictionary filled are removed.
Future<void> deleteDictionaryHelper(DeleteDictionaryParams params) async {
  final Isar database = await Isar.open(
    globalSchemas,
    directory: params.directoryPath,
    maxSizeMiB: 8192,
  );
  deleteDictionaryData(database, params.dictionaryId!);
}

/// Removes the dictionary with [id] and everything that came with it from
/// [database], in one transaction. Isar's own filters over every row are
/// quicker here than following each row's links: 3 seconds rather than 8
/// minutes for Babylon next to Jitendex, measured on a desktop.
void deleteDictionaryData(Isar database, int id) {
  if (database.dictionarys.getSync(id) == null) {
    return;
  }
  database.writeTxnSync(() {
    database.dictionaryEntrys
        .filter()
        .dictionary((q) => q.idEqualTo(id))
        .deleteAllSync();
    /// Tags carry their dictionary's id; imports do not link them to it.
    database.dictionaryTags.filter().dictionaryIdEqualTo(id).deleteAllSync();
    database.dictionaryPitchs
        .filter()
        .dictionary((q) => q.idEqualTo(id))
        .deleteAllSync();
    database.dictionaryFrequencys
        .filter()
        .dictionary((q) => q.idEqualTo(id))
        .deleteAllSync();
    database.dictionaryHeadings
        .filter()
        .entriesIsEmpty()
        .and()
        .tagsIsEmpty()
        .and()
        .pitchesIsEmpty()
        .and()
        .frequenciesIsEmpty()
        .deleteAllSync();
    database.dictionarySearchResults.filter().headingsIsEmpty().deleteAllSync();
    database.dictionarys.deleteSync(id);
  });
}
