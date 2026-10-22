import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/dictionary.dart';

/// Writes a pack laid out as tool/kanji_pack.py writes one.
File writePack(Directory directory, List<Map<String, dynamic>> records,
    {int format = KanjiPack.format}) {
  records.sort((a, b) =>
      (a['k'] as String).runes.first.compareTo((b['k'] as String).runes.first));
  List<int> meta = utf8.encode(jsonEncode({
    'sources': [
      {'name': 'KANJIDIC2', 'by': 'EDRDG', 'licence': 'CC BY-SA 4.0'}
    ]
  }));
  BytesBuilder index = BytesBuilder();
  BytesBuilder blob = BytesBuilder();
  for (Map<String, dynamic> record in records) {
    List<int> data = utf8.encode(jsonEncode(record));
    ByteData entry = ByteData(12)
      ..setUint32(0, (record['k'] as String).runes.first, Endian.little)
      ..setUint32(4, blob.length, Endian.little)
      ..setUint32(8, data.length, Endian.little);
    index.add(entry.buffer.asUint8List());
    blob.add(data);
  }
  ByteData head = ByteData(12)
    ..setUint32(0, format, Endian.little)
    ..setUint32(4, records.length, Endian.little)
    ..setUint32(8, meta.length, Endian.little);
  File file = File('${directory.path}/kanji-pack-${KanjiPack.format}.bin');
  file.writeAsBytesSync([
    ...ascii.encode('JDJK'),
    ...head.buffer.asUint8List(),
    ...meta,
    ...index.toBytes(),
    ...blob.toBytes(),
  ]);
  return file;
}

void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('kanji_pack'));
  tearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  test('nothing is found before the pack is installed', () async {
    KanjiPack pack = KanjiPack(directory);
    expect(pack.isInstalled, isFalse);
    expect(await pack.lookup('語'), isNull);
  });

  test('finds each kanji by code point and reads its record', () async {
    writePack(directory, [
      {
        'k': '語',
        's': 14,
        'j': 5,
        'on': ['ゴ'],
        'kun': ['かた.る'],
        'hv': ['Ngữ'],
        'p': [
          ['言', []],
          [
            '吾',
            [
              ['五', []],
              ['口', []]
            ]
          ]
        ],
        'd': ['M26,15.25c2.82,1.41,7.29,5.8,8,8'],
        'w': [
          ['英語', 'えいご', 'English (language)']
        ],
        'u': '',
      },
      {'k': '口', 's': 3, 'u': '語中'},
      {
        'k': '𠮟',
        's': 5,
        'v': ['叱']
      },
    ]);
    KanjiPack pack = KanjiPack(directory);
    expect(pack.isInstalled, isTrue);

    KanjiInfo info = (await pack.lookup('語'))!;
    expect(info.strokes, 14);
    expect(info.jlpt, 5);
    expect(info.hanViet, ['Ngữ']);
    expect(info.parts.map((p) => p.character), ['言', '吾']);
    expect(info.parts[1].parts.map((p) => p.character), ['五', '口']);
    expect(info.words.single.reading, 'えいご');
    expect(info.strokePaths, hasLength(1));
    expect(pack.meta['sources'], hasLength(1));

    expect((await pack.lookup('口'))!.usedIn, '語中');
    expect((await pack.lookup('𠮟'))!.variants, ['叱']);
    expect(await pack.lookup('猫'), isNull);
    expect(await pack.lookup('語学'), isNull);
  });

  test('a pack of another format is refused', () async {
    writePack(
        directory,
        [
          {'k': '語'}
        ],
        format: KanjiPack.format + 1);
    expect(KanjiPack(directory).lookup('語'), throwsFormatException);
  });

  test('remove takes the pack off the phone', () async {
    writePack(directory, [
      {'k': '語'}
    ]);
    KanjiPack pack = KanjiPack(directory);
    expect(await pack.lookup('語'), isNotNull);
    await pack.remove();
    expect(pack.isInstalled, isFalse);
    expect(await pack.lookup('語'), isNull);
  });
}
