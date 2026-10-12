import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle/subtitle.dart';
import 'package:yuuna/utils.dart';

void main() {
  Subtitle cue(int start, int end, String text) => Subtitle(
        start: Duration(milliseconds: start),
        end: Duration(milliseconds: end),
        data: text,
        index: start,
      );

  test('the lines showing at a time, nudged by the timing', () {
    PageSubtitles subtitles = PageSubtitles([
      cue(5000, 7000, '壬氏様が'),
      cue(1000, 3000, '猫猫、薬を作る。'),
      // Lines can overlap, as a sign shown while someone speaks.
      cue(6000, 8000, '後宮'),
    ]);
    expect(subtitles.at(const Duration(milliseconds: 500)), '');
    expect(subtitles.at(const Duration(seconds: 2)), '猫猫、薬を作る。');
    expect(subtitles.at(const Duration(milliseconds: 6500)), '壬氏様が\n後宮');
    // Later by a second and a half: the first line shows from 2.5 s.
    subtitles.offset = const Duration(milliseconds: 1500);
    expect(subtitles.at(const Duration(seconds: 2)), '');
    expect(subtitles.at(const Duration(milliseconds: 2600)), '猫猫、薬を作る。');
  });

  test("the page's video time is read from what the page reports", () {
    PageVideoTime? time = PageVideoTime.parse('{"time":12.345,"paused":false}');
    expect(time?.position, const Duration(milliseconds: 12345));
    expect(time?.paused, isFalse);
    expect(PageVideoTime.parse(null), isNull);
    expect(PageVideoTime.parse('null'), isNull);
    expect(PageVideoTime.parse('{"oops"'), isNull);
  });

  test('lines are stepped through: again, before and after', () {
    PageSubtitles subtitles = PageSubtitles([
      cue(1000, 3000, 'one'),
      cue(5000, 7000, 'two'),
      cue(9000, 11000, 'three'),
    ]);
    Duration at(int milliseconds) => Duration(milliseconds: milliseconds);
    // Within the second line.
    expect(subtitles.replayFrom(at(6000)), at(5000));
    expect(subtitles.previousFrom(at(6000)), at(1000));
    expect(subtitles.nextFrom(at(6000)), at(9000));
    // After it has ended, back is the line just gone.
    expect(subtitles.previousFrom(at(8000)), at(5000));
    // Before the first and after the last.
    expect(subtitles.previousFrom(at(500)), at(1000));
    expect(subtitles.nextFrom(at(500)), at(1000));
    expect(subtitles.nextFrom(at(10000)), isNull);
    // With the timing nudged, times are the video's.
    subtitles.offset = at(1000);
    expect(subtitles.replayFrom(at(6500)), at(6000));
  });

  test('subtitles kept for a page are read back as kept', () {
    String page = RememberedSubtitles.keyOf(
        Uri.parse('https://example.com/watch/ep-3?server=2#player'));
    expect(page, 'https://example.com/watch/ep-3?server=2');

    RememberedSubtitles kept = RememberedSubtitles(
      page: page,
      title: 'Episode 3',
      name: '[Group] Show - 03.srt',
      path: '/data/pageSubtitles/1a2b.srt',
    ).withOffset(const Duration(milliseconds: -1500));
    RememberedSubtitles read =
        RememberedSubtitles.fromJson(Map.of(kept.toJson()));
    expect(read.page, page);
    expect(read.title, 'Episode 3');
    expect(read.name, '[Group] Show - 03.srt');
    expect(read.path, '/data/pageSubtitles/1a2b.srt');
    expect(read.offset, const Duration(milliseconds: -1500));

    // Kept before timing could be nudged.
    expect(
      RememberedSubtitles.fromJson({'page': page, 'path': 'a.srt'}).offset,
      Duration.zero,
    );
  });
}
