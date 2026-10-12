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
        videos.push({ time: time.time, paused: time.paused,
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
})();
''';

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
}
