import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/utils.dart';

void main() {
  test("a video's name gives its show and episode", () {
    for (var (name, show, episode) in [
      (
        '[SubsPlease] Kusuriya no Hitorigoto - 05 (1080p) [ABCD1234].mkv',
        'Kusuriya no Hitorigoto',
        5
      ),
      (
        'Kusuriya.no.Hitorigoto.S01E12.1080p.WEB.x264.mp4',
        'Kusuriya no Hitorigoto',
        12
      ),
      ('薬屋のひとりごと 第3話.mp4', '薬屋のひとりごと', 3),
      ('Frieren EP07 [1080p].mkv', 'Frieren', 7),
      ('Your Name (2016).mkv', 'Your Name', null),
      ('lecture.mp4', 'lecture', null),
    ]) {
      SubtitleGuess guess = SubtitleGuess.of(name);
      expect(guess.show, show, reason: name);
      expect(guess.episode, episode, reason: name);
    }
  });
}
