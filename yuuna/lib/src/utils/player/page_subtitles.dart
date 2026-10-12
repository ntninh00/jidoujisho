import 'dart:convert';

import 'package:subtitle/subtitle.dart';

/// Runs in every frame of a video page, from before the page's own code.
///
/// A player asking for full screen fills the page instead, as Android
/// would otherwise show it above the app, where the app's subtitles can't
/// be; the app hides its own bars meanwhile. A player in a frame of another
/// site fills its frame, and the frame fills the page. The playing video's
/// time is kept for the app to show subtitles by, frames telling the page
/// above them.
const String pageSubtitleScript = '''
(() => {
  if (window.__jdj) {
    return;
  }
  const jdj = window.__jdj = { fullscreen: null, saved: null };
  const isTop = window.top === window;
  const fill = 'position:fixed!important;inset:0!important;' +
    'width:100vw!important;height:100vh!important;max-width:none!important;' +
    'max-height:none!important;margin:0!important;transform:none!important;' +
    'z-index:2147483647!important;background:#000!important;';
  const changed = () => {
    for (const name of ['fullscreenchange', 'webkitfullscreenchange']) {
      document.dispatchEvent(new Event(name));
      if (jdj.fullscreen) {
        jdj.fullscreen.dispatchEvent(new Event(name, { bubbles: true }));
      }
    }
  };
  const tell = (on) => {
    if (isTop) {
      try {
        window.flutter_inappwebview.callHandler('jdjFullscreen', on);
      } catch (e) {}
    } else {
      window.parent.postMessage({ jdjFullscreen: on }, '*');
    }
  };
  const leave = (quiet) => {
    const element = jdj.fullscreen;
    if (!element) {
      return;
    }
    if (jdj.saved === null) {
      element.removeAttribute('style');
    } else {
      element.setAttribute('style', jdj.saved);
    }
    jdj.fullscreen = null;
    document.documentElement.style.removeProperty('overflow');
    if (!quiet) {
      changed();
      tell(false);
    }
  };
  const enter = (element) => {
    if (jdj.fullscreen === element) {
      return;
    }
    leave(true);
    jdj.fullscreen = element;
    jdj.saved = element.getAttribute('style');
    element.setAttribute('style', (jdj.saved || '') + ';' + fill);
    document.documentElement.style.setProperty('overflow', 'hidden', 'important');
    changed();
    tell(true);
  };
  jdj.exit = () => leave(false);

  const request = function () {
    enter(this);
    return Promise.resolve();
  };
  for (const name of ['requestFullscreen', 'webkitRequestFullscreen',
      'webkitRequestFullScreen']) {
    Element.prototype[name] = request;
  }
  HTMLVideoElement.prototype.webkitEnterFullscreen = function () {
    enter(this);
  };
  const exit = function () {
    leave(false);
    return Promise.resolve();
  };
  for (const name of ['exitFullscreen', 'webkitExitFullscreen',
      'webkitCancelFullScreen']) {
    Document.prototype[name] = exit;
  }
  const getter = (name, get) => {
    try {
      Object.defineProperty(Document.prototype, name,
        { configurable: true, get });
    } catch (e) {}
  };
  for (const name of ['fullscreenElement', 'webkitFullscreenElement',
      'webkitCurrentFullScreenElement']) {
    getter(name, () => jdj.fullscreen);
  }
  getter('fullscreenEnabled', () => true);
  getter('webkitFullscreenEnabled', () => true);
  getter('fullscreen', () => !!jdj.fullscreen);
  getter('webkitIsFullScreen', () => !!jdj.fullscreen);

  const areaOf = (element) => {
    const box = element.getBoundingClientRect();
    return box.width * box.height;
  };
  /// The video subtitles follow, of those given: the one filling the page,
  /// then one playing, then the largest.
  const best = (videos) => videos.sort((a, b) =>
    (b.full - a.full) || (a.paused - b.paused) || (b.area - a.area))[0];
  const playing = () => best([...document.querySelectorAll('video')]
    .filter((video) => video.readyState > 0)
    .map((video) => ({ video, time: video.currentTime, paused: video.paused,
      area: areaOf(video),
      full: !!jdj.fullscreen && (jdj.fullscreen === video ||
        jdj.fullscreen.contains(video)) })));
  /// What frames below report, by the frame of this page each came from.
  jdj.frames = new Map();
  const frames = () => [...document.querySelectorAll('iframe')]
    .map((frame) => frame.contentWindow).filter(Boolean);
  jdj.control = (command) => {
    for (const video of document.querySelectorAll('video')) {
      try {
        if (command === 'pause') {
          video.pause();
        } else if (!video.ended && video.readyState > 0) {
          video.play();
        }
      } catch (e) {}
    }
    for (const frame of frames()) {
      frame.postMessage({ jdjControl: command }, '*');
    }
  };

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data !== 'object') {
      return;
    }
    if (typeof data.jdjFullscreen === 'boolean') {
      const frame = [...document.querySelectorAll('iframe')]
        .find((frame) => frame.contentWindow === event.source);
      if (frame) {
        if (data.jdjFullscreen) {
          enter(frame);
        } else if (jdj.fullscreen === frame) {
          leave(false);
        }
      }
    } else if (typeof data.jdjTime === 'number') {
      const frame = [...document.querySelectorAll('iframe')]
        .find((frame) => frame.contentWindow === event.source);
      if (frame) {
        jdj.frames.set(frame, { time: data.jdjTime, paused: data.jdjPaused,
          at: Date.now() });
      }
    } else if (typeof data.jdjControl === 'string') {
      jdj.control(data.jdjControl);
    } else if (typeof data.jdjSeek === 'number') {
      jdj.seek(data.jdjSeek);
    }
  });

  /// The video of this page or of a frame below it that is followed.
  const followed = () => {
    const videos = [];
    const own = playing();
    if (own) {
      videos.push(own);
    }
    for (const [frame, time] of jdj.frames) {
      if (Date.now() - time.at < 2000 && frame.isConnected) {
        videos.push({ frame, time: time.time, paused: time.paused,
          area: areaOf(frame), full: jdj.fullscreen === frame });
      }
    }
    return best(videos);
  };

  /// Frames tell the page above them what they follow.
  if (!isTop) {
    setInterval(() => {
      const video = followed();
      if (video) {
        window.parent.postMessage(
          { jdjTime: video.time, jdjPaused: video.paused }, '*');
      }
    }, 200);
  }

  jdj.now = () => {
    const video = followed();
    return video ? JSON.stringify({ time: video.time, paused: video.paused })
      : null;
  };

  /// Moves the followed video to [time] seconds, in a frame below too.
  jdj.seek = (time) => {
    const video = followed();
    if (!video) {
      return;
    }
    if (video.video) {
      try {
        video.video.currentTime = time;
      } catch (e) {}
    } else if (video.frame) {
      video.frame.contentWindow.postMessage({ jdjSeek: time }, '*');
    }
  };

  /// Blurs a part of the screen, as subtitles burnt into the video, given
  /// as shares of it: { x, y, width, height, blur }; null takes it away.
  /// Drawn by the page, as only the page can blur what its video shows.
  jdj.blur = (box) => {
    if (!box) {
      if (jdj.blurBox) {
        jdj.blurBox.remove();
      }
      jdj.blurBox = null;
      return;
    }
    const element = jdj.blurBox || document.createElement('div');
    jdj.blurBox = element;
    const px = (share, of) => Math.round(share * of) + 'px!important;';
    element.setAttribute('style', 'position:fixed!important;' +
      'left:' + px(box.x, window.innerWidth) +
      'top:' + px(box.y, window.innerHeight) +
      'width:' + px(box.width, window.innerWidth) +
      'height:' + px(box.height, window.innerHeight) +
      'z-index:2147483647!important;pointer-events:none!important;' +
      'border-radius:8px!important;background:rgba(0,0,0,0.2)!important;' +
      'backdrop-filter:blur(' + box.blur + 'px)!important;' +
      '-webkit-backdrop-filter:blur(' + box.blur + 'px)!important;');
    /// Last in the page, so it is above even what fills the screen.
    document.documentElement.appendChild(element);
  };
})();
''';

/// Subtitles shown over a page's video, kept to show again when the page
/// opens: a copy of their file, and their timing.
class RememberedSubtitles {
  /// Subtitles kept at [path] for [page].
  RememberedSubtitles({
    required this.page,
    required this.title,
    required this.name,
    required this.path,
    this.offset = Duration.zero,
  });

  /// Reads what [toJson] wrote.
  factory RememberedSubtitles.fromJson(Map<String, dynamic> json) =>
      RememberedSubtitles(
        page: json['page'] as String,
        title: json['title'] as String? ?? '',
        name: json['name'] as String? ?? '',
        path: json['path'] as String,
        offset: Duration(milliseconds: (json['offset'] as num?)?.toInt() ?? 0),
      );

  /// The page's address, as [keyOf] gives it.
  final String page;

  /// The page's title when they were loaded.
  final String title;

  /// The subtitle file's own name.
  final String name;

  /// Where the copy is kept.
  final String path;

  /// Their timing, as [PageSubtitles.offset].
  final Duration offset;

  /// To keep as JSON.
  Map<String, dynamic> toJson() => {
        'page': page,
        'title': title,
        'name': name,
        'path': path,
        'offset': offset.inMilliseconds,
      };

  /// These subtitles timed by [offset].
  RememberedSubtitles withOffset(Duration offset) => RememberedSubtitles(
        page: page,
        title: title,
        name: name,
        path: path,
        offset: offset,
      );

  /// The address subtitles for [page] are remembered by: the same page
  /// scrolled to another part is the same.
  static String keyOf(Uri page) => page.removeFragment().toString();
}

/// The page's video, as [pageSubtitleScript] reports it.
class PageVideoTime {
  PageVideoTime._(this.position, this.paused);

  /// Reads what `__jdj.now()` gave, or null when no video plays.
  static PageVideoTime? parse(Object? result) {
    if (result is! String || result.isEmpty || result == 'null') {
      return null;
    }
    try {
      Map<String, dynamic> json =
          Map<String, dynamic>.from(jsonDecode(result) as Map);
      return PageVideoTime._(
        Duration(milliseconds: ((json['time'] as num) * 1000).round()),
        json['paused'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  /// How far the video is.
  final Duration position;

  /// Whether it is paused.
  final bool paused;
}

/// Subtitles shown over a page's own video, with their timing nudged by
/// [offset] when they were made for a slightly different release.
class PageSubtitles {
  /// Subtitles of [cues], in order.
  PageSubtitles(List<Subtitle> cues)
      : cues = [...cues]..sort((a, b) => a.start.compareTo(b.start));

  /// Each line and when it shows.
  final List<Subtitle> cues;

  /// Added to each line's times: later when positive.
  Duration offset = Duration.zero;

  /// The lines showing at [position] of the video, top to bottom, as one
  /// text; empty when none is. Lines can overlap, so all are looked at.
  String at(Duration position) {
    Duration time = position - offset;
    return cues
        .where((cue) => cue.start <= time && time < cue.end)
        .map((cue) => cue.data.trim())
        .where((text) => text.isNotEmpty)
        .join('\n');
  }

  /// The last line started by [position] of the video, or -1 before the
  /// first.
  int indexAt(Duration position) {
    Duration time = position - offset;
    int found = -1;
    for (int i = 0; i < cues.length; i++) {
      if (cues[i].start <= time) {
        found = i;
      } else {
        break;
      }
    }
    return found;
  }

  /// Where in the video line [index] starts.
  Duration startOf(int index) => cues[index].start + offset;

  /// Where in the video the line at [position] starts again.
  Duration? replayFrom(Duration position) {
    if (cues.isEmpty) {
      return null;
    }
    int index = indexAt(position);
    return startOf(index < 0 ? 0 : index);
  }

  /// Where the line before the one showing at [position] starts; after a
  /// line has ended, that line's own start.
  Duration? previousFrom(Duration position) {
    if (cues.isEmpty) {
      return null;
    }
    int index = indexAt(position);
    if (index < 0) {
      return startOf(0);
    }
    bool showing = position - offset < cues[index].end;
    return startOf(showing ? (index - 1).clamp(0, cues.length - 1) : index);
  }

  /// Where the line after [position] starts, if there is one.
  Duration? nextFrom(Duration position) {
    int index = indexAt(position) + 1;
    return index < cues.length ? startOf(index) : null;
  }
}
