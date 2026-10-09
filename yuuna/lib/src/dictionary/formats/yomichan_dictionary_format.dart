import 'dart:convert';
import 'dart:io';

import 'package:async_zip/async_zip.dart';
import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'package:file_picker/file_picker.dart';
import 'package:html/dom.dart' as dom;
import 'package:isar/isar.dart';
import 'package:list_counter/list_counter.dart';
import 'package:path/path.dart' as path;
import 'package:recase/recase.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/utils.dart';

/// A dictionary format for archives following the latest Yomichan bank schema.
/// Example dictionaries for this format may be downloaded from the Yomichan
/// website.
///
/// Details on the format can be found here:
/// https://github.com/FooSoft/yomichan/blob/master/ext/data/schemas/dictionary-term-bank-v3-schema.json
class YomichanFormat extends DictionaryFormat {
  /// Define a format with the given metadata that has its behaviour for
  /// import, search and display defined with af set of top-level helper methods.
  YomichanFormat._privateConstructor()
      : super(
          uniqueKey: 'yomichan',
          name: 'Yomichan Dictionary',
          icon: Ui.auto_stories_rounded,
          allowedExtensions: const ['zip'],
          isTextFormat: false,
          fileType: FileType.custom,
          prepareDirectory: prepareDirectoryYomichanFormat,
          prepareName: prepareNameYomichanFormat,
          prepareEntries: prepareEntriesYomichanFormat,
          prepareTags: prepareTagsYomichanFormat,
          preparePitches: preparePitchesYomichanFormat,
          prepareFrequencies: prepareFrequenciesYomichanFormat,
          writesInBatches: true,
        );

  /// Get the singleton instance of this dictionary format.
  static YomichanFormat get instance => _instance;

  static final YomichanFormat _instance = YomichanFormat._privateConstructor();

  /// If true, uses the [customDefinitionWidget] instead.
  @override
  bool shouldUseCustomDefinitionWidget(String definition) {
    try {
      jsonDecode(definition);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  String getCustomDefinitionText(String meaning) {
    final node =
        StructuredContent.processContent(jsonDecode(meaning))?.toNode();
    if (node == null) {
      return '';
    }

    final document = dom.Document.html('');
    document.body?.append(node);
    for (final e in document.querySelectorAll('li')) {
      final css = e.bs4.findParent('ul')?.attributes['style'] ?? '';
      final text = e.text;
      final name = css
              .split(';')
              .firstWhere((e) => e.contains('list-style-type'))
              .split(':')
              .lastOrNull ??
          'square';

      final counterStyle = CounterStyleRegistry.lookup(name);
      final counter = counterStyle.generateMarkerContent(0);
      e.text = '$counter $text';
    }
    document.querySelectorAll('table').map((e) => e.remove());
    final html = document.body?.innerHtml ?? '';

    return BeautifulSoup(html).getText(separator: '\n');
  }

  /// Recursively get HTML for a structured content definition.
  static String getStructuredContentHtml(dynamic content) {
    if (content is Map) {
      return getNodeHtml(
        tag: content['tag'],
        content: getStructuredContentHtml(content['content']),
        style: getStyle(
          content['style'] ?? {},
        ),
      );
    } else if (content is List) {
      return content.map(getStructuredContentHtml).join();
    }

    return content;
  }

  /// Convert style to appropriate format.
  static Map<String, String> getStyle(Map<String, dynamic> styleMap) {
    return Map<String, String>.fromEntries(
      styleMap.entries.map(
        (e) => MapEntry(
          ReCase(e.key).paramCase,
          e.value.toString(),
        ),
      ),
    );
  }

  /// Get the HTML for a certain node.
  static String getNodeHtml({
    required String content,
    String? tag,
    Map<String, String> style = const {},
  }) {
    if (tag == null) {
      return content;
    }

    dom.Element element = dom.Element.tag(tag);
    element.attributes.addAll(style);

    element.innerHtml = content;

    return element.outerHtml;
  }

  /// For [prepareEntriesYomichanFormat]: a row's definitions. A row that
  /// only has inflected forms' pointers, which Yomitan follows, gets links
  /// to their words instead of nothing. Jitendex's redirects have a link of
  /// their own beside the pointer, so a row with anything else keeps that.
  static List<String> processDefinitions(List<dynamic> definitions) {
    List<String> processed =
        definitions.map(processDefinition).whereType<String>().toList();
    if (processed.isNotEmpty) {
      return processed;
    }
    return definitions.map(_formOf).whereType<String>().toList();
  }

  /// For [prepareEntriesYomichanFormat].
  static String? processDefinition(var definition) {
    if (definition is String) {
      final plainText = definition;
      return plainText;
    } else if (definition is Map) {
      final type = definition['type'];

      switch (type) {
        case 'text':
          final plainText = definition['text'];
          return plainText;
        case 'structured-content':
        case 'image':
          return jsonEncode(definition['content']);
      }
    }

    return null;
  }

  /// An inflected form's pointer to its word as a link to the word, with
  /// what kind of form it is.
  static String? _formOf(var definition) {
    if (definition is! List ||
        definition.length != 2 ||
        definition[0] is! String ||
        definition[1] is! List) {
      return null;
    }
    final String word = definition[0];
    final String kinds = (definition[1] as List).whereType<String>().join('; ');
    return jsonEncode([
      {
        'tag': 'div',
        'data': {'jdj': 'form-of'},
        'content': [
          '→ ',
          {
            'tag': 'a',
            'href': '?query=${Uri.encodeQueryComponent(word)}&wildcards=off',
            'content': word,
          },
          if (kinds.isNotEmpty) ' ($kinds)',
        ],
      }
    ]);
  }
}

/// Top-level function for use in compute. See [DictionaryFormat] for details.
Future<void> prepareDirectoryYomichanFormat(
    PrepareDirectoryParams params) async {
  int n = 0;
  extractZipArchiveSync(params.file, params.resourceDirectory,
      callback: (_, __) {
    n++;
    params.send(t.import_extract_count(n: n));
  });
}

/// Top-level function for use in compute. See [DictionaryFormat] for details.
Future<String> prepareNameYomichanFormat(PrepareDirectoryParams params) async {
  /// Get the index, which contains the name of the dictionary contained by
  /// the archive.
  String indexFilePath = path.join(params.resourceDirectory.path, 'index.json');
  File indexFile = File(indexFilePath);
  String indexJson = indexFile.readAsStringSync();
  Map<String, dynamic> index = jsonDecode(indexJson);

  String dictionaryName = (index['title'] as String).trim();
  return dictionaryName;
}

/// Entries written to the database at a time while importing.
const int _importBatch = 1000;

/// Top-level function for use in compute. See [DictionaryFormat] for details.
///
/// Each bank is read once; the total shown while importing is estimated
/// from the banks' sizes until all are read. Entries and their headings go
/// to the database a thousand at a time, each batch committed on its own,
/// and a heading is written fresh
/// rather than read first: its id comes from its term and reading, and
/// writing it adds tags without touching the links it has.
void prepareEntriesYomichanFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) {
  final List<File> files =
      params.resourceDirectory.listSync().whereType<File>().where((file) {
    String name = path.basename(file.path);
    return name.startsWith('term_bank') || name.startsWith('kanji_bank');
  }).toList();

  int totalBytes = files.fold(0, (sum, file) => sum + file.lengthSync());
  int readBytes = 0;
  int readItems = 0;
  int n = 0;
  int total = 0;

  /// The total so far, or an estimate from the share of bytes read.
  int estimate() => readBytes == 0
      ? 0
      : readBytes >= totalBytes
          ? readItems
          : (readItems * totalBytes / readBytes).round();

  void progress({bool last = false}) {
    if (last || n % _importBatch == 0) {
      params.send(t.import_write_entry(count: n, total: total));
    }
  }

  /// Tags of this dictionary by id, read once each.
  Map<int, DictionaryTag?> tags = {};
  List<DictionaryTag> tagsNamed(List<String> names) {
    List<DictionaryTag> found = [];
    for (String name in names) {
      int id =
          DictionaryTag.hash(dictionaryId: params.dictionary.id, name: name);
      DictionaryTag? tag =
          tags.putIfAbsent(id, () => isar.dictionaryTags.getSync(id));
      if (tag != null) {
        found.add(tag);
      }
    }
    return found;
  }

  List<DictionaryEntry> entries = [];
  Map<int, DictionaryHeading> headings = {};
  void flush() {
    if (entries.isEmpty) {
      return;
    }
    List<DictionaryHeading> batch = headings.values.toList();
    List<DictionaryEntry> written = entries;
    isar.writeTxnSync(() {
      isar.dictionaryHeadings.putAllSync(batch);
      isar.dictionaryEntrys.putAllSync(written);
    });
    entries = [];
    headings = {};
  }

  for (File file in files) {
    String filename = path.basename(file.path);
    String json = file.readAsStringSync();
    List<dynamic> items = jsonDecode(json);
    readBytes += file.lengthSync();
    readItems += items.length;
    total = estimate();

    if (filename.startsWith('term_bank')) {
      for (List<dynamic> item in items) {
        final String term = item[0];
        final String reading = item[1];
        final String? spaceSeparatedDefinitionTags = item[2];
        // final String ruleIdentifier = item[3];
        final num rawPopularity = item[4];
        final List<dynamic> rawDefinitions = item[5];
        // final int sequenceNumber = item[6];
        final String spaceSeparatedTermTags = item[7];

        double popularity = rawPopularity.toDouble();
        List<String> entryTagNames =
            spaceSeparatedDefinitionTags?.split(' ') ?? [];
        List<String> headingTagNames = spaceSeparatedTermTags.split(' ');
        final List<String> definitions =
            YomichanFormat.processDefinitions(rawDefinitions);

        int headingId = DictionaryHeading.hash(
          term: term,
          reading: reading,
        );

        final entry = DictionaryEntry(
          definitions: definitions,
          popularity: popularity,
          entryTagNames: entryTagNames,
          headingTagNames: headingTagNames,
        );

        DictionaryHeading heading = headings.putIfAbsent(
          headingId,
          () => DictionaryHeading(term: term, reading: reading),
        );
        heading.tags.addAll(tagsNamed(headingTagNames));

        entry.tags.addAll(tagsNamed(entryTagNames));
        entry.heading.value = heading;
        entry.dictionary.value = params.dictionary;
        entries.add(entry);

        n++;
        if (entries.length >= _importBatch) {
          flush();
        }
        progress();
      }
      flush();
    } else if (filename.startsWith('kanji_bank')) {
      isar.writeTxnSync(() {
        for (List<dynamic> item in items) {
          String term = item[0] as String;
          List<String> onyomis = (item[1] as String).split(' ');
          List<String> kunyomis = (item[2] as String).split(' ');
          List<String> headingTagNames = (item[3] as String).split(' ');
          List<String> meanings = List<String>.from(item[4]);

          StringBuffer buffer = StringBuffer();
          if (onyomis.join().trim().isNotEmpty) {
            buffer.write('音読み\n');
            for (String onyomi in onyomis) {
              buffer.write('  • $onyomi\n');
            }
            buffer.write('\n');
          }
          if (kunyomis.join().trim().isNotEmpty) {
            buffer.write('訓読み\n');
            for (String kun in kunyomis) {
              buffer.write('  • $kun\n');
            }
            buffer.write('\n');
          }
          if (meanings.isNotEmpty) {
            buffer.write('意味\n');
            for (String meaning in meanings) {
              buffer.write('  • $meaning\n');
            }
            buffer.write('\n');
          }

          String definition = buffer.toString().trim();

          if (definition.isNotEmpty) {
            int headingId = DictionaryHeading.hash(term: term, reading: '');

            final entry = DictionaryEntry(
              definitions: [definition],
              popularity: 0,
              headingTagNames: headingTagNames,
            );

            DictionaryHeading heading =
                isar.dictionaryHeadings.getSync(headingId) ??
                    DictionaryHeading(term: term);

            entry.heading.value = heading;
            entry.dictionary.value = params.dictionary;
            List<int> headingTagHashes = headingTagNames.map((name) {
              int dictionaryId = params.dictionary.id;
              return DictionaryTag.hash(dictionaryId: dictionaryId, name: name);
            }).toList();

            List<DictionaryTag> headingTags = isar.dictionaryTags
                .getAllSync(headingTagHashes)
                .whereType<DictionaryTag>()
                .toList();

            isar.dictionaryEntrys.putSync(entry);

            heading.entries.add(entry);
            heading.tags.addAll(headingTags);
            isar.dictionaryHeadings.putSync(heading);

            n++;
            progress();
          }
        }
      });
    }
  }
  total = n;
  progress(last: true);
}

/// Top-level function for use in compute. See [DictionaryFormat] for details.
Future<void> prepareTagsYomichanFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {
  final List<FileSystemEntity> entities = params.resourceDirectory.listSync();
  final Iterable<File> files = entities.whereType<File>();

  int n = 0;
  int count = 0;

  for (File file in files) {
    String filename = path.basename(file.path);
    if (filename.startsWith('tag_bank')) {
      String json = file.readAsStringSync();
      List<dynamic> items = jsonDecode(json);
      count += items.length;

      params.send(t.import_found_tag(count: count));
    }
  }

  for (File file in files) {
    String filename = path.basename(file.path);
    if (!filename.startsWith('tag_bank')) {
      continue;
    }

    String json = file.readAsStringSync();
    List<dynamic> items = jsonDecode(json);

    for (List<dynamic> item in items) {
      String name = item[0] as String;
      String category = item[1] as String;
      int sortingOrder = item[2] as int;
      String notes = item[3] as String;
      double popularity = (item[4] as num).toDouble();

      DictionaryTag tag = DictionaryTag(
        dictionaryId: params.dictionary.id,
        name: name,
        category: category,
        sortingOrder: sortingOrder,
        notes: notes,
        popularity: popularity,
      );

      n++;
      isar.dictionaryTags.putSync(tag);
      params.send(t.import_write_tag(
        count: n,
        total: count,
      ));
    }
  }
}

/// Top-level function for use in compute. See [DictionaryFormat] for details.
Future<void> preparePitchesYomichanFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {
  final List<FileSystemEntity> entities = params.resourceDirectory.listSync();
  final Iterable<File> files = entities.whereType<File>();

  int n = 0;
  int count = 0;

  for (File file in files) {
    String filename = path.basename(file.path);
    if (filename.startsWith('term_meta_bank')) {
      String json = file.readAsStringSync();
      List<dynamic> items = jsonDecode(json);
      count += items.length;

      params.send(t.import_found_pitch(count: count));
    }
  }

  for (File file in files) {
    String filename = path.basename(file.path);
    if (!filename.startsWith('term_meta_bank')) {
      continue;
    }

    String json = file.readAsStringSync();
    List<dynamic> items = jsonDecode(json);

    for (List<dynamic> item in items) {
      String term = item[0] as String;
      String type = item[1] as String;

      if (type == 'pitch') {
        Map<String, dynamic> data = Map<String, dynamic>.from(item[2]);
        String reading = data['reading'] ?? '';
        int headingId = DictionaryHeading.hash(term: term, reading: reading);
        DictionaryHeading heading =
            isar.dictionaryHeadings.getSync(headingId) ??
                DictionaryHeading(term: term);

        List<Map<String, dynamic>> distinctPitchJsons =
            List<Map<String, dynamic>>.from(data['pitches']);
        for (Map<String, dynamic> distinctPitch in distinctPitchJsons) {
          int downstep = distinctPitch['position'];
          DictionaryPitch pitch = DictionaryPitch(downstep: downstep);

          pitch.dictionary.value = params.dictionary;
          isar.dictionaryPitchs.putSync(pitch);
          heading.pitches.add(pitch);
        }

        isar.dictionaryHeadings.putSync(heading);
      } else {
        continue;
      }
    }

    params.send(t.import_write_pitch(count: n, total: count));
  }
}

/// Top-level function for use in compute. See [DictionaryFormat] for details.
Future<void> prepareFrequenciesYomichanFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {
  final List<FileSystemEntity> entities = params.resourceDirectory.listSync();
  final Iterable<File> files = entities.whereType<File>();

  int n = 0;
  int count = 0;

  for (File file in files) {
    String filename = path.basename(file.path);
    if (filename.startsWith('term_meta_bank')) {
      String json = file.readAsStringSync();
      List<dynamic> items = jsonDecode(json);
      count += items.length;

      params.send(t.import_found_frequency(count: count));
    }
  }

  for (File file in files) {
    String filename = path.basename(file.path);
    if (!filename.startsWith('term_meta_bank')) {
      continue;
    }

    String json = file.readAsStringSync();
    List<dynamic> items = jsonDecode(json);

    for (List<dynamic> item in items) {
      String term = item[0] as String;
      String type = item[1] as String;

      if (type == 'freq') {
        int? headingId;
        late double value;
        late String? displayValue;

        if (item[2] is double) {
          double number = item[2] as double;

          headingId = DictionaryHeading.hash(term: term, reading: '');
          value = number;
          displayValue =
              (number % 1 == 0) ? number.toInt().toString() : number.toString();
        } else if (item[2] is int) {
          int number = item[2] as int;
          headingId = DictionaryHeading.hash(term: term, reading: '');
          value = number.toDouble();
          displayValue = number.toString();
        } else if (item[2] is Map) {
          Map<String, dynamic> data = Map<String, dynamic>.from(item[2]);

          if (data['reading'] != null && data['frequency'] is Map) {
            Map<String, dynamic> frequencyData =
                Map<String, dynamic>.from(data['frequency']);

            String reading = data['reading'] ?? '';
            headingId = DictionaryHeading.hash(term: term, reading: reading);

            num number = frequencyData['value'] ?? 0;

            value = number.toDouble();
            displayValue = frequencyData['displayValue'];
          } else if (data['displayValue'] != null) {
            String reading = data['reading'] ?? '';
            headingId = DictionaryHeading.hash(term: term, reading: reading);

            num number = data['value'] ?? 0;

            value = number.toDouble();
            displayValue = data['displayValue'];
          } else if (data['value'] != null) {
            String reading = data['reading'] ?? '';
            headingId = DictionaryHeading.hash(term: term, reading: reading);

            num number = data['value'] ?? 0;

            value = number.toDouble();
            displayValue = number.toInt().toString();
          } else if (data['frequency'] is num) {
            num frequencyValue = data['frequency'];
            String reading = data['reading'] ?? '';
            headingId = DictionaryHeading.hash(term: term, reading: reading);

            value = frequencyValue.toDouble();
            displayValue = (frequencyValue % 1 == 0)
                ? frequencyValue.toInt().toString()
                : frequencyValue.toDouble().toString();
          }
        } else {
          headingId = DictionaryHeading.hash(term: term, reading: '');

          value = 0;
          displayValue = item[2].toString();
        }

        if (headingId != null) {
          DictionaryHeading heading =
              isar.dictionaryHeadings.getSync(headingId) ??
                  DictionaryHeading(term: term);

          final frequency = DictionaryFrequency(
            displayValue: displayValue ?? '',
            value: value,
          );

          n++;
          frequency.dictionary.value = params.dictionary;
          frequency.heading.value = heading;
          isar.dictionaryFrequencys.putSync(frequency);
          heading.frequencies.add(frequency);

          params.send(t.import_write_frequency(count: n, total: count));
        }
      } else {
        continue;
      }
    }
  }
}
