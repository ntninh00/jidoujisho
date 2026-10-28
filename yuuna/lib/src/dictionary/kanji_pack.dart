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
  const KanjiPart(this.character, this.parts, [this.strokes = const []]);

  /// Read a part from the pack's `[character, [parts], [strokes]]` form.
  factory KanjiPart.fromJson(List<dynamic> json) => KanjiPart(
        json[0] as String,
        (json[1] as List)
            .map((part) => KanjiPart.fromJson(part as List))
            .toList(),
        json.length > 2 ? (json[2] as List).cast<int>() : const [],
      );

  /// The part, as a character.
  final String character;

  /// What the part is made of.
  final List<KanjiPart> parts;

  /// The kanji's strokes that draw this part, counted from 0.
  final List<int> strokes;
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

/// Which reading of a kanji a word uses, and where it sits in the word's
/// reading, from `start` up to `end`.
typedef KanjiWordReading = ({String reading, int start, int end});

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

  /// The strokes that draw [part] wherever it appears in this kanji, as
  /// 口 twice in 品.
  Set<int> strokesOf(String part) {
    Set<int> found = {};
    void look(List<KanjiPart> parts) {
      for (KanjiPart candidate in parts) {
        if (candidate.character == part) {
          found.addAll(candidate.strokes);
        } else {
          look(candidate.parts);
        }
      }
    }

    look(parts);
    return found;
  }

  /// Which of its readings [word] reads it with, or null when none fits, as
  /// in 今日 (きょう). Sound changes count, as in 曜日 (ようび) and 日記
  /// (にっき), and a kun reading may carry okurigana the word leaves
  /// unwritten, as 物語 (ものがたり) does.
  KanjiWordReading? readingIn(KanjiWord word) {
    int at = word.word.indexOf(character);
    if (at < 0) {
      return null;
    }
    String text = _hiragana(word.reading);
    String before = _hiragana(word.word.substring(0, at));
    String after = _hiragana(word.word.substring(at + character.length));
    bool kanaBefore = _isKana(before);
    bool kanaAfter = _isKana(after);

    // Where form and unwritten more kana sit in the word's reading.
    int? place(String form, int unwritten) {
      int length = form.length + unwritten;
      if (kanaBefore && kanaAfter) {
        return text.length == before.length + length + after.length &&
                text.startsWith(before + form) &&
                text.endsWith(after)
            ? before.length
            : null;
      }
      if (unwritten > 0 && !kanaAfter) {
        return null;
      }
      if (kanaBefore) {
        return text.length > before.length + length &&
                text.startsWith(before + form)
            ? before.length
            : null;
      }
      if (kanaAfter) {
        int start = text.length - after.length - length;
        return start > 0 && text.startsWith(form, start) && text.endsWith(after)
            ? start
            : null;
      }
      int start = text.indexOf(form, 1);
      return start > 0 && start + length < text.length ? start : null;
    }

    KanjiWordReading? best;
    int bestScore = 0;
    for (String reading in [...onReadings, ...kunReadings]) {
      bool kun = kunReadings.contains(reading);
      List<String> halves = _hiragana(reading.replaceAll('-', '')).split('.');
      String stem = halves.first;
      String okurigana = halves.length > 1 ? halves[1] : '';
      if (stem.isEmpty) {
        continue;
      }
      for (String form in _soundChanges(stem)) {
        for (int unwritten = 0; unwritten <= (kun ? 2 : 0); unwritten++) {
          int? start = place(form, unwritten);
          if (start == null) {
            continue;
          }
          // Longer readings first, then ones read as written, then ones
          // whose okurigana the word writes out.
          int score = 1 +
              stem.length * 4 +
              (form == stem ? 2 : 0) -
              unwritten * 2 +
              (okurigana.isNotEmpty && after.startsWith(okurigana) ? 3 : 0);
          if (score > bestScore) {
            bestScore = score;
            best = (
              reading: reading,
              start: start,
              end: start + form.length + unwritten,
            );
          }
        }
      }
    }
    return best;
  }

  static String _hiragana(String text) => String.fromCharCodes(text.codeUnits
      .map((unit) => unit >= 0x30A1 && unit <= 0x30F6 ? unit - 0x60 : unit));

  static bool _isKana(String text) => text.codeUnits
      .every((unit) => (unit >= 0x3041 && unit <= 0x309F) || unit == 0x30FC);

  static const String _plain = 'かきくけこさしすせそたちつてとはひふへほちつ';
  static const String _voiced = 'がぎぐげござじずぜぞだぢづでどばびぶべぼじず';

  /// [stem] as it may sound in a word: voiced at the start (春 in 青春 is
  /// not, 日 in 曜日 is), or cut short before another sound (日 in 日記).
  static Iterable<String> _soundChanges(String stem) {
    String first = stem[0];
    String rest = stem.substring(1);
    Set<String> starts = {stem};
    for (int i = 0; i < _plain.length; i++) {
      if (_plain[i] == first) {
        starts.add(_voiced[i] + rest);
      }
    }
    int half = 'はひふへほ'.indexOf(first);
    if (half >= 0) {
      starts.add('ぱぴぷぺぽ'[half] + rest);
    }
    return {
      ...starts,
      if (stem.length > 1 && 'つくきち'.contains(stem[stem.length - 1]))
        for (String start in starts) '${start.substring(0, start.length - 1)}っ',
    };
  }
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
  static const int format = 2;

  /// Where the pack downloads from: a release of the app's fork.
  static const String url = 'https://github.com/ntninh00/jidoujisho/releases'
      '/download/kanji-pack-$format/kanji-pack-$format.bin.gz';

  /// The download's size in bytes.
  static const int downloadSize = 4270564;

  /// The download's SHA-256, to check it by.
  static const String downloadSha256 =
      'a5f8dead9326952eba04f9cc898a5880f40589dfe95d223c4369ad478ee89a2b';

  /// Where the pack is kept.
  final Directory directory;

  File get _file => File(path.join(directory.path, 'kanji-pack-$format.bin'));

  Uint8List? _index;
  int _records = 0;

  /// What the pack says about itself: its sources and when it was built.
  Map<String, dynamic> meta = const {};

  /// Whether the pack is on the phone.
  bool get isInstalled => _file.existsSync();

  /// Whether an earlier pack is on the phone, which the app can no longer
  /// read; the download replaces it.
  bool get hasOlder =>
      !isInstalled &&
      directory.existsSync() &&
      directory.listSync().any((entry) => _isOlder(entry.path));

  bool _isOlder(String file) {
    String name = path.basename(file);
    return name.startsWith('kanji-pack-') &&
        !name.startsWith('kanji-pack-$format.');
  }

  /// What the pack knows about [character], or null when it has nothing.
  Future<KanjiInfo?> lookup(String character) async =>
      (await lookupAll([character]))[character];

  /// What the pack knows about each of [characters] that it has, read with
  /// the file opened once.
  Future<Map<String, KanjiInfo>> lookupAll(Iterable<String> characters) async {
    Map<String, KanjiInfo> found = {};
    if (!isInstalled) {
      return found;
    }
    RandomAccessFile file = await _file.open();
    try {
      if (_index == null) {
        await _readIndex(file);
      }
      for (String character in characters) {
        if (character.runes.length == 1 && !found.containsKey(character)) {
          KanjiInfo? info = await _read(file, character.runes.first);
          if (info != null) {
            found[character] = info;
          }
        }
      }
      return found;
    } finally {
      await file.close();
    }
  }

  Future<KanjiInfo?> _read(RandomAccessFile file, int code) async {
    ByteData index = ByteData.sublistView(_index!);
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
    for (FileSystemEntity entry in directory.listSync()) {
      if (_isOlder(entry.path)) {
        entry.deleteSync();
      }
    }
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
