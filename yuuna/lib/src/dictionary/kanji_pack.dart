import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:yuuna/models.dart';

/// One part of a kanji, as KanjiVG draws it, with the parts it is made of.
class KanjiPart {
  /// Describe a part.
  const KanjiPart(this.character, this.parts);

  /// Read a part from the pack's `[character, [parts]]` form.
  factory KanjiPart.fromJson(List<dynamic> json) => KanjiPart(
        json[0] as String,
        (json[1] as List)
            .map((part) => KanjiPart.fromJson(part as List))
            .toList(),
      );

  /// The part, as a character.
  final String character;

  /// What the part is made of.
  final List<KanjiPart> parts;
}

/// A common word written with a kanji.
class KanjiWord {
  /// Describe a word.
  const KanjiWord(this.word, this.reading, this.gloss);

  /// The word as written.
  final String word;

  /// Its reading in kana.
  final String reading;

  /// Its first English meanings, from JMdict.
  final String gloss;
}

/// What the kanji pack knows about one character.
class KanjiInfo {
  /// Describe a character.
  const KanjiInfo({
    required this.character,
    this.strokes,
    this.grade,
    this.jlpt,
    this.bookRank,
    this.onReadings = const [],
    this.kunReadings = const [],
    this.hanViet = const [],
    this.meanings = const [],
    this.variants = const [],
    this.radical,
    this.parts = const [],
    this.strokePaths = const [],
    this.words = const [],
    this.usedIn = '',
  });

  /// Read a record of the pack. Its keys are kept short to keep it small.
  factory KanjiInfo.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        (json[key] as List?)?.cast<String>() ?? const [];
    return KanjiInfo(
      character: json['k'] as String,
      strokes: json['s'] as int?,
      grade: json['g'] as int?,
      jlpt: json['j'] as int?,
      bookRank: json['a'] as int?,
      onReadings: strings('on'),
      kunReadings: strings('kun'),
      hanViet: strings('hv'),
      meanings: strings('m'),
      variants: strings('v'),
      radical: json['r'] as String?,
      parts: (json['p'] as List? ?? const [])
          .map((part) => KanjiPart.fromJson(part as List))
          .toList(),
      strokePaths: strings('d'),
      words: (json['w'] as List? ?? const []).map((word) {
        List<String> parts = (word as List).cast<String>();
        return KanjiWord(parts[0], parts[1], parts.length > 2 ? parts[2] : '');
      }).toList(),
      usedIn: json['u'] as String? ?? '',
    );
  }

  /// The character.
  final String character;

  /// How many strokes it is written with.
  final int? strokes;

  /// Its school grade in KANJIDIC2: 1 to 6 taught in primary school, 8 the
  /// rest of the jōyō kanji, 9 and 10 jinmeiyō kanji for names.
  final int? grade;

  /// Its JLPT level, 5 (N5) to 1 (N1).
  final int? jlpt;

  /// Its place among the kanji of Aozora Bunko's books, 1 the most used.
  final int? bookRank;

  /// Its Chinese-derived readings, in katakana.
  final List<String> onReadings;

  /// Its Japanese readings, in hiragana; a dot sets off the okurigana.
  final List<String> kunReadings;

  /// Its Sino-Vietnamese readings.
  final List<String> hanViet;

  /// Its English meanings.
  final List<String> meanings;

  /// Other forms of the same character.
  final List<String> variants;

  /// The part it is filed under in dictionaries.
  final String? radical;

  /// The parts it is made of, as KanjiVG draws them.
  final List<KanjiPart> parts;

  /// Its strokes in writing order, as SVG paths in a 109 by 109 box.
  final List<String> strokePaths;

  /// Common words written with it, most used first.
  final List<KanjiWord> words;

  /// Kanji with it as a part, most used first.
  final String usedIn;
}

/// The downloadable kanji data behind the kanji sheet: one file, found by
/// code point through an index read once, each kanji read when asked for.
class KanjiPack {
  /// Keep the pack in [directory].
  KanjiPack(this.directory);

  /// The pack the app uses, in its support directory.
  static Future<KanjiPack> get instance async =>
      _instance ??= KanjiPack(Directory(
          path.join((await getApplicationSupportDirectory()).path, 'kanji')));
  static KanjiPack? _instance;

  /// Uses [pack] as the app's pack, for tests.
  @visibleForTesting
  static void useForTests(KanjiPack? pack) => _instance = pack;

  /// The pack's layout; a new one comes with a new download.
  static const int format = 1;

  /// Where the pack downloads from: a release of the app's fork.
  static const String url = 'https://github.com/ntninh00/jidoujisho/releases'
      '/download/kanji-pack-$format/kanji-pack-$format.bin.gz';

  /// The download's size in bytes.
  static const int downloadSize = 4197130;

  /// The download's SHA-256, to check it by.
  static const String downloadSha256 =
      'd375efbb0f5eebf49c0f3b6011e5672ba432704def3b8764c85e7aa618585524';

  /// Where the pack is kept.
  final Directory directory;

  File get _file => File(path.join(directory.path, 'kanji-pack-$format.bin'));

  Uint8List? _index;
  int _records = 0;

  /// What the pack says about itself: its sources and when it was built.
  Map<String, dynamic> meta = const {};

  /// Whether the pack is on the phone.
  bool get isInstalled => _file.existsSync();

  /// What the pack knows about [character], or null when it has nothing.
  Future<KanjiInfo?> lookup(String character) async {
    if (character.runes.length != 1 || !isInstalled) {
      return null;
    }
    RandomAccessFile file = await _file.open();
    try {
      if (_index == null) {
        await _readIndex(file);
      }
      ByteData index = ByteData.sublistView(_index!);
      int code = character.runes.first;
      int low = 0;
      int high = index.lengthInBytes ~/ 12 - 1;
      while (low <= high) {
        int middle = (low + high) >> 1;
        int found = index.getUint32(middle * 12, Endian.little);
        if (found < code) {
          low = middle + 1;
        } else if (found > code) {
          high = middle - 1;
        } else {
          int offset = index.getUint32(middle * 12 + 4, Endian.little);
          int length = index.getUint32(middle * 12 + 8, Endian.little);
          await file.setPosition(_records + offset);
          Uint8List record = await file.read(length);
          return KanjiInfo.fromJson(
              jsonDecode(utf8.decode(record)) as Map<String, dynamic>);
        }
      }
      return null;
    } finally {
      await file.close();
    }
  }

  Future<void> _readIndex(RandomAccessFile file) async {
    await file.setPosition(0);
    ByteData head = ByteData.sublistView(await file.read(16));
    if (String.fromCharCodes(head.buffer.asUint8List(head.offsetInBytes, 4)) !=
            'JDJK' ||
        head.getUint32(4, Endian.little) != format) {
      throw const FormatException('Not a kanji pack of this format.');
    }
    int count = head.getUint32(8, Endian.little);
    int metaLength = head.getUint32(12, Endian.little);
    meta = jsonDecode(utf8.decode(await file.read(metaLength)))
        as Map<String, dynamic>;
    _index = await file.read(count * 12);
    _records = 16 + metaLength + count * 12;
  }

  /// Downloads the pack, carrying on from an earlier try, checks it and
  /// unpacks it. [onProgress] gets the share downloaded, from 0 to 1.
  Future<void> install({
    required void Function(double) onProgress,
    CancelToken? cancelToken,
  }) async {
    directory.createSync(recursive: true);
    File download = File('${_file.path}.gz.part');
    await downloadResuming(
      url: url,
      file: download,
      size: downloadSize,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    if (await compute(sha256OfFile, download.path) != downloadSha256) {
      download.deleteSync();
      throw const FormatException('The kanji pack came out damaged.');
    }
    File unpacked = File('${_file.path}.part');
    await download
        .openRead()
        .transform(gzip.decoder)
        .pipe(unpacked.openWrite());
    unpacked.renameSync(_file.path);
    download.deleteSync();
  }

  /// Removes the pack from the phone.
  Future<void> remove() async {
    _index = null;
    meta = const {};
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }
}
