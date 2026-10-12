import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle/subtitle.dart';
import 'package:yuuna/src/media/sources/player_youtube_source_util.dart';

void main() {
  test('YouTube captions become subtitles the player reads, line by line',
      () async {
    const String xml = '<?xml version="1.0" encoding="utf-8" ?><transcript>'
        '<text start="3.959" dur="4.161">はい、始まりました。\n'
        '西田亮介です。</text>'
        '<text start="8.12" dur="7.08">今日は&#39;NHK&#39;について&amp;'
        '&#x3042;</text>'
        '<text start="3725.5" dur="2">[音楽]</text>'
        '</transcript>';

    List<Caption> captions = CaptionParser.parseXml(xml);
    expect(captions.map((caption) => caption.text), [
      'はい、始まりました。\n西田亮介です。',
      "今日は'NHK'について&あ",
      '[音楽]',
    ]);

    StringBuffer vtt = StringBuffer('WEBVTT\n');
    for (Caption caption in captions) {
      vtt.write(caption.vtt);
    }
    SubtitleController controller = SubtitleController(
      provider: SubtitleProvider.fromString(
        data: vtt.toString().trim(),
        type: SubtitleType.vtt,
      ),
    );
    await controller.initial();

    expect(controller.subtitles.length, 3);
    expect(controller.subtitles.first.start,
        const Duration(seconds: 3, milliseconds: 959));
    expect(controller.subtitles.first.data.trim(), 'はい、始まりました。\n西田亮介です。');
    expect(controller.subtitles.last.start,
        const Duration(hours: 1, minutes: 2, seconds: 5, milliseconds: 500));
  });
}
