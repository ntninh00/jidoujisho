import 'package:path/path.dart' as path;

/// What a video is, guessed from its file or page name, for finding its
/// subtitles: the show's name and the episode.
class SubtitleGuess {
  SubtitleGuess._(this.show, this.episode);

  /// Guesses from a name such as
  /// `[Group] Kusuriya no Hitorigoto - 05 (1080p) [ABCD1234].mkv`.
  factory SubtitleGuess.of(String name) {
    String stem = path.basenameWithoutExtension(name.trim());
    if (stem.isEmpty) {
      stem = name.trim();
    }
    int? episode = episodeOf(stem);

    String show = stem
        // Groups, hashes and tags in brackets.
        .replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)|【[^】]*】'), ' ')
        .replaceAll(RegExp('[._]'), ' ');
    for (RegExp pattern in _episodes) {
      Match? match = pattern.firstMatch(show);
      if (match != null) {
        show = show.substring(0, match.start);
        break;
      }
    }
    show = show
        .replaceAll(_notEpisode, ' ')
        .replaceAll(RegExp(r'\s[-–—]\s*$'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return SubtitleGuess._(show, episode);
  }

  /// The show's name, or empty when nothing is left of it.
  final String show;

  /// The episode, when the name has one.
  final int? episode;

  /// Episode numbers in names, tried in this order: S01E05, E05 or EP05,
  /// #05, 第5話, ` - 05`, `[05]`.
  static final List<RegExp> _episodes = [
    RegExp(r'[Ss]\d{1,2}[ ._-]?[Ee](\d{1,4})'),
    RegExp(r'(?:^|[^A-Za-z])(?:EP?|Episode)[ ._-]?(\d{1,4})(?!\d)',
        caseSensitive: false),
    RegExp(r'#(\d{1,4})(?!\d)'),
    RegExp(r'第\s*(\d{1,4})\s*[話话回]'),
    RegExp(r'\s[-–—]\s(\d{1,4})(?!\d)'),
    RegExp(r'\[(\d{1,4})(?:v\d)?\]'),
  ];

  /// Numbers in names that are rarely episodes.
  static final RegExp _notEpisode = RegExp(
      '(?:480|540|576|720|1080|2160)[pP]|[xh]26[45]|10.?bit|HEVC|AAC',
      caseSensitive: false);

  /// The episode a file or page name is for, when it says.
  static int? episodeOf(String name) {
    for (RegExp pattern in _episodes) {
      Match? match = pattern.firstMatch(name);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    }
    Iterable<Match> numbers = RegExp(r'(?<![\dA-Za-z])(\d{1,3})(?![\dA-Za-z])')
        .allMatches(name.replaceAll(_notEpisode, ' '));
    return numbers.length == 1 ? int.parse(numbers.first.group(1)!) : null;
  }
}
