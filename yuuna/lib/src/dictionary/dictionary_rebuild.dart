import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';

/// What [rebuildYomitanZipHelper] needs, sent to another isolate.
class RebuildDictionaryParams {
  /// Describe a rebuild.
  RebuildDictionaryParams({
    required this.dictionaryId,
    required this.directoryPath,
    required this.resourcePath,
    required this.outPath,
  });

  /// The dictionary to rebuild.
  final int dictionaryId;

  /// Where the database is.
  final String directoryPath;

  /// The dictionary's resource folder, for its pictures, if it still exists.
  final String resourcePath;

  /// Where to write the zip.
  final String outPath;
}

/// Rows per bank file, as Yomitan's own dictionaries use.
const int _bankSize = 10000;

/// A stored definition as Yomitan glossary: structured content was stored
/// as its JSON, everything else as text.
Object _glossaryOf(String definition) {
  String trimmed = definition.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      Object? content = jsonDecode(definition);
      if (content is List || content is Map) {
        return {'type': 'structured-content', 'content': content};
      }
    } on FormatException {
      // Plain text that happens to start with a bracket.
    }
  }
  return definition;
}

/// Writes a Yomitan zip for an imported dictionary from what the app stored
/// of it, for a dictionary whose original files are gone. Terms, tags,
/// frequencies, pitch accents and pictures come back; kanji dictionaries
/// come back as terms, since they were stored as text.
Future<void> rebuildYomitanZipHelper(RebuildDictionaryParams params) async {
  final Isar isar = await Isar.open(
    globalSchemas,
    directory: params.directoryPath,
    maxSizeMiB: 8192,
  );
  Dictionary dictionary = isar.dictionarys.getSync(params.dictionaryId)!;
  int id = dictionary.id;

  ZipFileEncoder encoder = ZipFileEncoder()..create(params.outPath);
  void addJson(String name, Object value) {
    // As UTF-8 bytes: ArchiveFile.string doesn't encode text beyond Latin-1.
    List<int> bytes = utf8.encode(jsonEncode(value));
    encoder.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
  }

  addJson('index.json', {
    'title': dictionary.name,
    'revision': 'rebuilt',
    'format': 3,
    'sequenced': false,
  });

  List<DictionaryTag> tags =
      dictionary.tags.filter().nameIsNotEmpty().findAllSync();
  if (tags.isNotEmpty) {
    addJson('tag_bank_1.json', [
      for (DictionaryTag tag in tags)
        [tag.name, tag.category, tag.sortingOrder, tag.notes, tag.popularity],
    ]);
  }

  List<String> ownTags(Iterable<DictionaryTag> tags) => tags
      .where((tag) => tag.dictionaryId == id)
      .map((tag) => tag.name)
      .toList();

  int bank = 1;
  int lastId = -1 << 62;
  while (true) {
    List<DictionaryEntry> entries = dictionary.entries
        .filter()
        .idGreaterThan(lastId)
        .limit(_bankSize)
        .findAllSync();
    if (entries.isEmpty) {
      break;
    }
    // Pages follow ids, which a scan returns in order.
    lastId = entries.map((entry) => entry.id!).reduce(max);
    List<List<Object>> rows = [];
    for (DictionaryEntry entry in entries) {
      entry.heading.loadSync();
      DictionaryHeading? heading = entry.heading.value;
      if (heading == null) {
        continue;
      }
      entry.tags.loadSync();
      heading.tags.loadSync();
      rows.add([
        heading.term,
        heading.reading,
        ownTags(entry.tags).join(' '),
        '',
        entry.popularity,
        entry.definitions.map(_glossaryOf).toList(),
        0,
        ownTags(heading.tags).join(' '),
      ]);
    }
    addJson('term_bank_${bank++}.json', rows);
  }

  List<List<Object>> meta = [];
  int metaBank = 1;
  void flushMeta({bool all = false}) {
    if (meta.isNotEmpty && (all || meta.length >= _bankSize)) {
      addJson('term_meta_bank_${metaBank++}.json', meta);
      meta = [];
    }
  }

  for (DictionaryFrequency frequency in dictionary.frequencies
      .filter()
      .valueGreaterThan(double.negativeInfinity)
      .findAllSync()) {
    frequency.heading.loadSync();
    DictionaryHeading? heading = frequency.heading.value;
    if (heading == null) {
      continue;
    }
    Map<String, Object> value = {
      'value': frequency.value,
      if (frequency.displayValue.isNotEmpty)
        'displayValue': frequency.displayValue,
    };
    meta.add([
      heading.term,
      'freq',
      if (heading.reading.isEmpty)
        value
      else
        {'reading': heading.reading, 'frequency': value},
    ]);
    flushMeta();
  }

  Map<int, List<int>> downstepsByHeading = {};
  Map<int, DictionaryHeading> headings = {};
  for (DictionaryPitch pitch in dictionary.pitches
      .filter()
      .downstepGreaterThan(-1 << 30)
      .findAllSync()) {
    pitch.heading.loadSync();
    DictionaryHeading? heading = pitch.heading.value;
    if (heading == null) {
      continue;
    }
    headings[heading.id] = heading;
    downstepsByHeading.putIfAbsent(heading.id, () => []).add(pitch.downstep);
  }
  for (MapEntry<int, List<int>> pitches in downstepsByHeading.entries) {
    DictionaryHeading heading = headings[pitches.key]!;
    meta.add([
      heading.term,
      'pitch',
      {
        'reading': heading.reading.isEmpty ? heading.term : heading.reading,
        'pitches': [
          for (int downstep in pitches.value) {'position': downstep},
        ],
      },
    ]);
    flushMeta();
  }
  flushMeta(all: true);

  // Pictures used by structured content, under the paths entries refer to.
  Directory resources = Directory(params.resourcePath);
  if (resources.existsSync()) {
    for (FileSystemEntity file in resources.listSync(recursive: true)) {
      if (file is! File) {
        continue;
      }
      String name =
          path.relative(file.path, from: resources.path).replaceAll(r'\', '/');
      bool data = name == 'index.json' ||
          RegExp(r'^\w+_bank_\d+\.json$').hasMatch(name);
      if (!data) {
        await encoder.addFile(file, name, 0);
      }
    }
  }
  encoder.close();
}
