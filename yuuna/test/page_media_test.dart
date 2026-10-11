import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/utils.dart';

void main() {
  test("what a page loads is told from its address", () {
    PageMediaKind? kind(String url) => PageMediaFinder.kindOf(Uri.parse(url));
    expect(kind('https://cdn.example.com/v/abc/master.m3u8'),
        PageMediaKind.stream);
    expect(kind('https://cdn.example.com/hls/index.m3u8?token=x'),
        PageMediaKind.stream);
    expect(kind('https://cdn.example.com/manifest.mpd'), PageMediaKind.dash);
    expect(kind('https://cdn.example.com/files/episode5.mp4'),
        PageMediaKind.file);
    expect(kind('https://cdn.example.com/subs/ja.vtt'), PageMediaKind.subtitle);
    expect(kind('https://cdn.example.com/timedtext?lang=ja&fmt=vtt'),
        PageMediaKind.subtitle);
    // Parts of streams, adverts and everything else are left out.
    expect(kind('https://cdn.example.com/hls/seg-12.ts'), isNull);
    expect(kind('https://cdn.example.com/dash/init.mp4'), isNull);
    expect(kind('https://cdn.example.com/dash/segment_00012.mp4'), isNull);
    expect(kind('https://cdn.example.com/v.mp4?range=0-1000'), isNull);
    expect(kind('https://pubads.g.doubleclick.net/preroll.mp4'), isNull);
    expect(kind('https://cdn.example.com/app.js'), isNull);
    expect(kind('blob:https://example.com/abc'), isNull);
  });

  test("a player's own name for a source's type tells what it is", () {
    PageMediaFinder finder = PageMediaFinder();
    Uri page = Uri.parse('https://site.example.com/watch/5');
    // An address without an ending, which only the player's type explains.
    finder.noteElement(
      page: page,
      source: 'https://cdn.example.com/play/abc123?token=x',
      track: false,
      type: 'hls',
    );
    finder.noteElement(
      page: page,
      source: 'https://cdn.example.com/v/clip',
      track: false,
      type: 'video/mp4',
    );
    finder.noteElement(
      page: page,
      source: 'https://imasdk.googleapis.com/preroll',
      track: false,
      type: 'video/mp4',
    );
    expect(finder.videos.map((media) => media.kind),
        [PageMediaKind.stream, PageMediaKind.file]);
    expect(PageMediaFinder.kindOfType('application/x-mpegURL'),
        PageMediaKind.stream);
    expect(PageMediaFinder.kindOfType('application/dash+xml'),
        PageMediaKind.dash);
    expect(PageMediaFinder.kindOfType('text/html'), isNull);
  });

  test("a stream's playlist of qualities lists its parts", () {
    PlaylistQualities qualities = PlaylistQualities.parse(
      Uri.parse('https://cdn.example.com/v/master.m3u8'),
      '#EXTM3U\n'
      '#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360\n'
      '360p/index.m3u8\n'
      '#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080\n'
      'https://cdn2.example.com/1080p/index.m3u8\n',
    );
    expect(qualities.isMaster, isTrue);
    expect(qualities.heights, [1080, 360]);
    expect(qualities.variants.map((uri) => uri.toString()), [
      'https://cdn.example.com/v/360p/index.m3u8',
      'https://cdn2.example.com/1080p/index.m3u8',
    ]);
    expect(
      PlaylistQualities.parse(Uri.parse('https://x.com/a.m3u8'),
              '#EXTM3U\n#EXTINF:4.0,\nseg1.ts\n')
          .isMaster,
      isFalse,
    );
  });

  test('requests and players on a page are collected once', () {
    PageMediaFinder finder = PageMediaFinder();
    int changes = 0;
    finder.addListener(() => changes++);
    finder.noteRequest(Uri.parse('https://cdn.example.com/a/episode.mp4'),
        {'Referer': 'https://site.example.com/watch/5'});
    finder.noteRequest(Uri.parse('https://cdn.example.com/a/episode.mp4'), {});
    finder.noteElement(
      page: Uri.parse('https://site.example.com/watch/5'),
      source: 'https://cdn.example.com/subs/ja.vtt',
      track: true,
      label: '日本語',
      language: 'ja',
    );
    finder.noteElement(
      page: Uri.parse('https://site.example.com/watch/5'),
      source: 'blob:https://site.example.com/1234',
      track: false,
    );
    expect(finder.videos.single.referer, 'https://site.example.com/watch/5');
    expect(finder.subtitles.single.label, '日本語');
    expect(changes, 2);
    finder.clear();
    expect(finder.hasVideo, isFalse);
  });
}
