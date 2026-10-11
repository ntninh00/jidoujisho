import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle/subtitle.dart';

void main() {
  test('WebVTT subtitles, as pages and Jimaku have them, are read', () async {
    SubtitleController controller = SubtitleController(
      provider: SubtitleProvider.fromString(
        data: 'WEBVTT\n'
            'Kind: captions\n'
            'Language: ja\n'
            '\n'
            '1\n'
            '00:00:01.000 --> 00:00:02.500 align:start position:10%\n'
            '<c.japanese>猫猫、薬を作る。</c>\n'
            '\n'
            'cue-2\n'
            '00:01:02.000 --> 00:01:04.000\n'
            '壬氏様が\n'
            '来られた。\n'
            '\n'
            '00:01:05.000 --> 00:01:06.000\n'
            'ありがとう\n',
        type: SubtitleType.vtt,
      ),
    );
    await controller.initial();
    List<Subtitle> subtitles = controller.subtitles;
    expect(subtitles.length, 3);
    expect(subtitles[0].start, const Duration(seconds: 1));
    expect(subtitles[0].end, const Duration(milliseconds: 2500));
    // Styling tags are left out.
    expect(subtitles[0].data, '猫猫、薬を作る。');
    expect(subtitles[1].data, contains('壬氏様が'));
    expect(subtitles[2].start, const Duration(minutes: 1, seconds: 5));
  });
}
