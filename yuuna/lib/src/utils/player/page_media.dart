import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// What a page loads that can be played or read along with it.
enum PageMediaKind {
  /// A stream that plays in parts, as an HLS playlist (`.m3u8`).
  stream,

  /// A stream described for DASH (`.mpd`).
  dash,

  /// A whole video file, as an `.mp4`.
  file,

  /// Subtitles, as a `.vtt` or `.srt`.
  subtitle,
}

/// A video or subtitle file a page was seen loading.
class PageMedia {
  /// Something [url] is, as a page asked for it with these headers.
  PageMedia({
    required this.url,
    required this.kind,
    this.referer,
    this.userAgent,
    this.label,
    this.language,
  });

  /// Where it is.
  final Uri url;

  /// What it is.
  final PageMediaKind kind;

  /// The page that asked for it, which some hosts insist on.
  final String? referer;

  /// The browser the page said it was.
  final String? userAgent;

  /// A name the page gave it, as a subtitle track's.
  String? label;

  /// The language a subtitle track is in, when the page says.
  final String? language;

  /// The heights of the qualities a stream has, highest first, once its
  /// playlist has been read.
  List<int> heights = const [];

  /// Whether the stream's playlist lists others, of each quality.
  bool isMaster = false;

  /// Its file name, for showing.
  String get name {
    String last = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
    return last.isEmpty ? url.host : Uri.decodeComponent(last);
  }
}

/// Collects the videos and subtitles a page loads, from the requests it
/// makes and the players on it. Streams are read once to tell a playlist
/// of qualities from the parts it lists, which are left out.
class PageMediaFinder extends ChangeNotifier {
  final Map<String, PageMedia> _found = {};

  /// Playlists another found playlist lists, of one quality each.
  final Set<String> _variants = {};

  /// Videos found, the most useful first: streams of every quality, then
  /// other streams, then files.
  List<PageMedia> get videos {
    List<PageMedia> videos = _found.values
        .where((media) =>
            media.kind != PageMediaKind.subtitle &&
            !_variants.contains(media.url.toString()))
        .toList();
    int rank(PageMedia media) => switch (media.kind) {
          PageMediaKind.stream => media.isMaster ? 0 : 1,
          PageMediaKind.dash => 1,
          _ => 2,
        };
    return videos..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  /// Subtitles found.
  List<PageMedia> get subtitles => _found.values
      .where((media) => media.kind == PageMediaKind.subtitle)
      .toList();

  /// Whether anything playable was found.
  bool get hasVideo => videos.isNotEmpty;

  /// Forgets what was found, as when the page changes.
  void clear() {
    if (_found.isEmpty) {
      return;
    }
    _found.clear();
    _variants.clear();
    notifyListeners();
  }

  /// Notes a request the page made, with its [headers].
  void noteRequest(Uri url, Map<String, String>? headers) {
    PageMediaKind? kind = kindOf(url);
    if (kind == null) {
      return;
    }
    String? header(String name) => headers?.entries
        .firstWhereOrNullValue((entry) => entry.key.toLowerCase() == name);
    _add(PageMedia(
      url: url,
      kind: kind,
      referer: header('referer'),
      userAgent: header('user-agent'),
    ));
  }

  /// Notes a video or a subtitle track a player on [page] shows. A [type]
  /// the player gives, as `hls` or `video/mp4`, tells what it is when its
  /// address doesn't.
  void noteElement({
    required Uri page,
    required String source,
    required bool track,
    String? label,
    String? language,
    String? type,
  }) {
    Uri? url = Uri.tryParse(source);
    if (url == null ||
        !url.isScheme('http') && !url.isScheme('https') ||
        isAdvert(url.host)) {
      return;
    }
    PageMediaKind kind = track
        ? PageMediaKind.subtitle
        : kindOfType(type) ?? kindOf(url) ?? PageMediaKind.file;
    _add(PageMedia(
      url: url,
      kind: kind,
      referer: page.toString(),
      label: label?.trim().isEmpty ?? true ? null : label!.trim(),
      language: language,
    ));
  }

  void _add(PageMedia media) {
    String key = media.url.toString();
    PageMedia? known = _found[key];
    if (known != null) {
      known.label ??= media.label;
      return;
    }
    _found[key] = media;
    notifyListeners();
    if (media.kind == PageMediaKind.stream) {
      _readPlaylist(media);
    }
  }

  /// Reads a stream's playlist for its qualities, and to leave out the
  /// playlists it lists.
  Future<void> _readPlaylist(PageMedia media) async {
    try {
      http.Response response = await http.get(media.url, headers: {
        if (media.referer != null) 'Referer': media.referer!,
        if (media.userAgent != null) 'User-Agent': media.userAgent!,
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return;
      }
      PlaylistQualities qualities =
          PlaylistQualities.parse(media.url, response.body);
      if (!qualities.isMaster) {
        return;
      }
      media.isMaster = true;
      media.heights = qualities.heights;
      _variants.addAll(qualities.variants.map((uri) => uri.toString()));
      notifyListeners();
    } catch (error) {
      debugPrint('Playlist not read: $error');
    }
  }

  /// What [url] is, from its address alone, or null when it isn't a whole
  /// video, a stream's playlist or subtitles. The parts of streams and
  /// adverts' hosts are left out.
  static PageMediaKind? kindOf(Uri url) {
    if (!url.isScheme('http') && !url.isScheme('https')) {
      return null;
    }
    if (isAdvert(url.host)) {
      return null;
    }
    String file =
        url.pathSegments.isEmpty ? '' : url.pathSegments.last.toLowerCase();
    String extension = path.extension(file);
    String query = url.query.toLowerCase();
    if (extension == '.m3u8' || extension == '.m3u') {
      return PageMediaKind.stream;
    }
    if (extension == '.mpd') {
      return PageMediaKind.dash;
    }
    if (const ['.vtt', '.srt', '.ass', '.ssa'].contains(extension) ||
        RegExp(r'(^|&)(fmt|format)=(vtt|srt|webvtt)(&|$)').hasMatch(query)) {
      return PageMediaKind.subtitle;
    }
    if (const ['.mp4', '.m4v', '.webm', '.mov', '.mkv', '.ogv', '.flv']
        .contains(extension)) {
      // Parts of a stream, rather than a whole video.
      bool part = RegExp('(^|[-_.])(init|seg|segment|frag|fragment|chunk|part)'
                  r'[-_]?\d*([-_.]|$)')
              .hasMatch(path.basenameWithoutExtension(file)) ||
          RegExp('(^|&)(range|bytestart|byterange)=').hasMatch(query);
      return part ? null : PageMediaKind.file;
    }
    if (url.path.toLowerCase().contains('.m3u8')) {
      return PageMediaKind.stream;
    }
    return null;
  }

  /// What a player's name for a source's type, as `hls`,
  /// `application/x-mpegURL` or `video/mp4`, says it is.
  static PageMediaKind? kindOfType(String? type) {
    String value = type?.toLowerCase() ?? '';
    if (value.isEmpty) {
      return null;
    }
    if (value.contains('mpegurl') || value == 'hls' || value == 'm3u8') {
      return PageMediaKind.stream;
    }
    if (value.contains('dash')) {
      return PageMediaKind.dash;
    }
    if (value.startsWith('video/') || const ['mp4', 'webm'].contains(value)) {
      return PageMediaKind.file;
    }
    return null;
  }

  /// Hosts of adverts and trackers, whose videos are never the page's.
  static bool isAdvert(String host) {
    host = host.toLowerCase();
    return advertHosts.any((ad) => host == ad || host.endsWith('.$ad'));
  }

  /// Advert and tracker hosts, left out of what is found and not loaded.
  static const List<String> advertHosts = [
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'google-analytics.com',
    'googletagmanager.com',
    'adservice.google.com',
    'imasdk.googleapis.com',
    'amazon-adsystem.com',
    'adnxs.com',
    'adsrvr.org',
    'taboola.com',
    'outbrain.com',
    'popads.net',
    'popcash.net',
    'propellerads.com',
    'exoclick.com',
    'juicyads.com',
    'adsterra.com',
    'trafficjunky.net',
    'hilltopads.net',
    'a-ads.com',
    'adcash.com',
    'onclickads.net',
    'mgid.com',
    'revcontent.com',
    'criteo.com',
    'scorecardresearch.com',
    'pubmatic.com',
    'rubiconproject.com',
    'openx.net',
  ];
}

/// The qualities an HLS playlist lists, when it lists others.
class PlaylistQualities {
  PlaylistQualities._(this.variants, this.heights);

  /// Reads the playlist at [url] with [text] as its contents.
  factory PlaylistQualities.parse(Uri url, String text) {
    List<Uri> variants = [];
    List<int> heights = [];
    List<String> lines = text.split(RegExp(r'\r?\n'));
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF')) {
        continue;
      }
      Match? resolution = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(line);
      if (resolution != null) {
        heights.add(int.parse(resolution.group(1)!));
      }
      for (int j = i + 1; j < lines.length; j++) {
        String next = lines[j].trim();
        if (next.isEmpty || next.startsWith('#')) {
          continue;
        }
        variants.add(url.resolve(next));
        break;
      }
    }
    heights = heights.toSet().toList()..sort((a, b) => b.compareTo(a));
    return PlaylistQualities._(variants, heights);
  }

  /// The playlists of each quality.
  final List<Uri> variants;

  /// Their heights, highest first.
  final List<int> heights;

  /// Whether it lists others.
  bool get isMaster => variants.isNotEmpty;
}

extension on Iterable<MapEntry<String, String>> {
  String? firstWhereOrNullValue(bool Function(MapEntry<String, String>) test) {
    for (MapEntry<String, String> entry in this) {
      if (test(entry)) {
        return entry.value;
      }
    }
    return null;
  }
}
