import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Pages are asked for as a phone's Chrome, which video hosts expect.
const String videoPageUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/129.0.0.0 Mobile Safari/537.36';

/// A WebView's settings for pages whose videos are found: no downloads,
/// pop-ups or other apps, and adverts not loaded.
InAppWebViewSettings videoPageSettings({String? userAgent}) =>
    InAppWebViewSettings(
      userAgent: userAgent ?? videoPageUserAgent,
      useShouldInterceptRequest: true,
      useShouldOverrideUrlLoading: true,
      // Windows are asked for, and refused, rather than opening in place.
      // Scripts can't open them unasked, and videos wait for a tap, as by
      // default.
      supportMultipleWindows: true,
      allowFileAccess: false,
      allowContentAccess: false,
    );

/// Gathers what a page loads into [finder], and leaves adverts out.
Future<WebResourceResponse?> noteVideoPageRequest(
  PageMediaFinder finder,
  WebResourceRequest request,
) async {
  if (PageMediaFinder.isAdvert(request.url.host)) {
    return WebResourceResponse(
      contentType: 'text/plain',
      data: Uint8List(0),
      statusCode: 204,
      reasonPhrase: 'No Content',
    );
  }
  finder.noteRequest(request.url, request.headers);
  return null;
}

/// Lets a page go only to other web pages: links to other apps, app
/// installers and the like are not followed.
Future<NavigationActionPolicy> allowVideoPageNavigation(
    NavigationAction action) async {
  WebUri? url = action.request.url;
  if (url == null) {
    return NavigationActionPolicy.CANCEL;
  }
  bool web = const ['http', 'https', 'about', 'data', 'blob']
      .contains(url.scheme.toLowerCase());
  bool installer = url.path.toLowerCase().endsWith('.apk');
  return web && !installer
      ? NavigationActionPolicy.ALLOW
      : NavigationActionPolicy.CANCEL;
}

/// Opens a new window a page asks for: a link the user tapped opens in the
/// page itself, and windows a page opens by itself, as pop-ups, don't.
Future<bool> openVideoPageWindow(
  InAppWebViewController controller,
  CreateWindowAction action,
) async {
  WebUri? url = action.request.url;
  if (action.hasGesture == true &&
      url != null &&
      await allowVideoPageNavigation(action) == NavigationActionPolicy.ALLOW) {
    await controller.loadUrl(urlRequest: URLRequest(url: url));
  }
  return false;
}

/// Finds the videos and subtitle tracks of the players on a page, for
/// those its requests don't show: files in a page's own `<video>`, and what
/// common players say they play, as JW Player's and Video.js's playlists,
/// whose `<video>` only has a `blob:` address of the page's making.
const String videoPageScan = '''
(() => {
  const found = [];
  const add = (source, track, label, language, type) => {
    if (typeof source !== 'string' || !source ||
        source.startsWith('blob:') || source.startsWith('data:')) {
      return;
    }
    try {
      found.push({ source: new URL(source, document.baseURI).href, track,
        label: label || null, language: language || null,
        type: type || null });
    } catch (e) {}
  };
  for (const media of document.querySelectorAll('video, audio')) {
    add(media.currentSrc, false);
    add(media.src, false);
    for (const source of media.querySelectorAll('source')) {
      add(source.src, false, null, null, source.type);
    }
    for (const track of media.querySelectorAll('track')) {
      add(track.src, true, track.label, track.srclang);
    }
  }
  try {
    if (typeof window.jwplayer === 'function') {
      for (const element of document.querySelectorAll('.jwplayer')) {
        const player = window.jwplayer(element.id || element);
        if (!player || typeof player.getPlaylistItem !== 'function') {
          continue;
        }
        const item = player.getPlaylistItem() || {};
        for (const source of item.sources || [{ file: item.file }]) {
          add(source.file, false, source.label, null, source.type);
        }
        for (const track of item.tracks || []) {
          if (!track.kind || track.kind === 'captions' ||
              track.kind === 'subtitles') {
            add(track.file, true, track.label, track.language);
          }
        }
      }
    }
  } catch (e) {}
  try {
    if (window.videojs && typeof window.videojs.getPlayers === 'function') {
      for (const player of Object.values(window.videojs.getPlayers())) {
        if (!player) {
          continue;
        }
        add(player.currentSrc(), false, null, null, player.currentType());
        const tracks = player.remoteTextTracks();
        for (let i = 0; i < tracks.length; i++) {
          if (tracks[i].kind === 'captions' || tracks[i].kind === 'subtitles') {
            add(tracks[i].src, true, tracks[i].label, tracks[i].language);
          }
        }
      }
    }
  } catch (e) {}
  return JSON.stringify(found);
})()
''';

/// Notes what [videoPageScan] found on [page].
void noteVideoPageScan(PageMediaFinder finder, Uri page, Object? result) {
  try {
    for (Map<String, dynamic> found in List<Map<String, dynamic>>.from(
        jsonDecode(result as String? ?? '[]') as List)) {
      finder.noteElement(
        page: page,
        source: found['source'] as String,
        track: found['track'] == true,
        label: found['label'] as String?,
        language: found['language'] as String?,
        type: found['type'] as String?,
      );
    }
  } catch (error) {
    debugPrint('Page players not read: $error');
  }
}

/// Stops the page's own players, before its video plays in the app.
const String videoPagePause =
    "document.querySelectorAll('video, audio').forEach((media) => "
    '{ try { media.pause(); } catch (e) {} });';

/// Plays [media] found on [page], titled [title], in the app's player,
/// with the subtitles the page had.
Future<void> playPageMedia({
  required WidgetRef ref,
  required AppModel appModel,
  required PageMedia media,
  required List<PageMedia> subtitles,
  required Uri page,
  required String title,
}) async {
  String referer = media.referer ?? page.toString();
  String userAgent = media.userAgent ?? videoPageUserAgent;
  PlayerNetworkStreamSource source = PlayerNetworkStreamSource.instance;
  MediaItem item = source.getMediaItemFromUrl(
    videoUrl: media.url.toString(),
    title: title,
    extra: jsonEncode({
      'subs': subtitles.map((subtitle) => subtitle.url.toString()).toList(),
      'subs.name': subtitles
          .map((subtitle) =>
              subtitle.label ?? subtitle.language ?? subtitle.name)
          .toList(),
      'headers': {'Referer': referer, 'User-Agent': userAgent},
      'page': page.toString(),
    }),
  );

  /// The browser's page stays open under the player, for its own media.
  if (appModel.isMediaOpen) {
    await appModel.openMediaOver(ref: ref, mediaSource: source, item: item);
  } else {
    await appModel.openMedia(ref: ref, mediaSource: source, item: item);
  }
}

/// What a found video is, in a few words.
String pageMediaLabel(PageMedia media) {
  switch (media.kind) {
    case PageMediaKind.stream:
      return media.heights.isNotEmpty
          ? t.video_finder_auto(height: media.heights.first)
          : t.video_finder_stream;
    case PageMediaKind.dash:
      return t.video_finder_stream;
    case PageMediaKind.file:
    case PageMediaKind.subtitle:
      return t.video_finder_file;
  }
}

/// The pill that shows a page has videos, and plays them.
class VideoFoundButton extends StatelessWidget {
  /// Shows what [finder] found; [onPressed] plays it.
  const VideoFoundButton({
    required this.finder,
    required this.onPressed,
    super.key,
  });

  /// What the page has.
  final PageMediaFinder finder;

  /// Plays, or lists, what was found.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return AnimatedBuilder(
      animation: finder,
      builder: (context, _) {
        int count = finder.videos.length;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: count == 0
              ? const SizedBox.shrink()
              : Material(
                  key: const ValueKey('found'),
                  color: theme.colorScheme.primary,
                  shape: const StadiumBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: onPressed,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Ui.play_arrow_rounded,
                              size: 20, color: theme.colorScheme.onPrimary),
                          const SizedBox(width: 6),
                          Text(
                            count == 1
                                ? t.video_finder_play
                                : t.video_finder_count(n: count),
                            style: theme.textTheme.labelLarge!.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (finder.subtitles.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Ui.closed_caption,
                                size: 18, color: theme.colorScheme.onPrimary),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// Lists the videos found, and closes with the one picked.
Future<PageMedia?> pickPageMedia(BuildContext context, PageMediaFinder finder) {
  return showTtuSheet<PageMedia>(
    context: context,
    builder: (context) {
      ThemeData theme = Theme.of(context);
      List<PageMedia> videos = finder.videos;
      int subtitles = finder.subtitles.length;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TtuSheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                t.video_finder_pick,
                style: theme.textTheme.titleLarge!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (subtitles > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  t.video_finder_subtitles(n: subtitles),
                  style: theme.textTheme.bodySmall!
                      .copyWith(color: theme.unselectedWidgetColor),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (PageMedia media in videos)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 3),
                      child: Material(
                        color: theme.dividerColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, media),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              children: [
                                Icon(
                                  media.kind == PageMediaKind.file
                                      ? Ui.play_circle_outline
                                      : Ui.podcasts,
                                  size: 22,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pageMediaLabel(media),
                                        style: theme.textTheme.bodyLarge!
                                            .copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        '${media.url.host} · ${media.name}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall!
                                            .copyWith(
                                                color: theme
                                                    .unselectedWidgetColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// A web page opened to play its video in the app: the video the page
/// loads is found and offered, with the page's subtitles.
class VideoFinderPage extends BasePage {
  /// Open [url].
  const VideoFinderPage({required this.url, super.key});

  /// The page's address.
  final String url;

  @override
  BasePageState<VideoFinderPage> createState() => _VideoFinderPageState();
}

class _VideoFinderPageState extends BasePageState<VideoFinderPage> {
  final PageMediaFinder _finder = PageMediaFinder();
  late final TextEditingController _address =
      TextEditingController(text: widget.url);
  InAppWebViewController? _controller;
  Uri? _page;
  String _title = '';
  double _progress = 0;
  Timer? _scan;

  /// Whether the page's player fills the screen, with the app's bars away.
  bool _fullscreen = false;

  /// Subtitles shown over the page's video, if any.
  PageSubtitles? _subtitles;

  /// The subtitle line showing now.
  final ValueNotifier<String> _line = ValueNotifier('');

  /// Follows the page's video for [_subtitles].
  Timer? _follow;

  final GlobalKey _lineKey = GlobalKey();

  /// How subtitles look, as in the player.
  late SubtitleOptions _style = appModelNoUpdate.subtitleOptions;

  /// How high the line sits, as a share of the screen.
  late double _lineHeight = appModelNoUpdate.pageSubtitleHeight;

  @override
  void initState() {
    super.initState();
    _scan = Timer.periodic(const Duration(seconds: 3), (_) => _scanPage());
  }

  @override
  void dispose() {
    _scan?.cancel();
    _follow?.cancel();
    _address.dispose();
    _finder.dispose();
    _line.dispose();
    if (_fullscreen) {
      _restoreScreen();
    }
    super.dispose();
  }

  Future<void> _scanPage() async {
    InAppWebViewController? controller = _controller;
    Uri? page = _page;
    if (controller == null || page == null) {
      return;
    }
    try {
      noteVideoPageScan(_finder, page,
          await controller.evaluateJavascript(source: videoPageScan));
    } catch (_) {}
  }

  void _go(String text) {
    String address = text.trim();
    if (address.isEmpty) {
      return;
    }
    if (!address.contains('://')) {
      address = 'https://$address';
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(address)));
  }

  Future<void> _play() async {
    PageMedia? media = _finder.videos.length == 1
        ? _finder.videos.single
        : await pickPageMedia(context, _finder);
    if (media == null || !mounted) {
      return;
    }
    await _controller?.evaluateJavascript(source: videoPagePause);
    await playPageMedia(
      ref: ref,
      appModel: appModel,
      media: media,
      subtitles: _finder.subtitles,
      page: _page ?? Uri.parse(widget.url),
      title: _title.isNotEmpty ? _title : media.name,
    );
  }

  /// The page's player asked to fill the screen, or stopped: the app's bars
  /// go, and the phone turns on its side.
  Future<void> _setFullscreen(bool on) async {
    if (_fullscreen == on || !mounted) {
      return;
    }
    setState(() => _fullscreen = on);
    if (on) {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await _restoreScreen();
    }
  }

  Future<void> _restoreScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Back leaves the page's full screen first.
  Future<bool> _onWillPop() async {
    if (!_fullscreen) {
      return true;
    }
    await _controller?.evaluateJavascript(
        source: 'window.__jdj && window.__jdj.exit()');
    await _setFullscreen(false);
    return false;
  }

  /// Shows the subtitles in [file] over the page's video.
  Future<void> _loadSubtitles(File file) async {
    SubtitleItem item = await SubtitleUtils.subtitlesFromFile(
      file: file,
      type: SubtitleItemType.externalSubtitle,
    );
    await item.controller.initial();
    if (!mounted) {
      return;
    }
    if (item.controller.subtitles.isEmpty) {
      Fluttertoast.showToast(msg: t.page_subtitles_empty);
      return;
    }
    _subtitles = PageSubtitles(item.controller.subtitles);
    _follow?.cancel();
    _follow = Timer.periodic(
        const Duration(milliseconds: 200), (_) => _followVideo());
    setState(() {});
  }

  void _removeSubtitles() {
    _follow?.cancel();
    _follow = null;
    _subtitles = null;
    _line.value = '';
    setState(() {});
  }

  Future<PageVideoTime?> _videoTime() async {
    try {
      return PageVideoTime.parse(await _controller?.evaluateJavascript(
          source: 'window.__jdj ? window.__jdj.now() : null'));
    } catch (_) {
      return null;
    }
  }

  Future<void> _followVideo() async {
    PageSubtitles? subtitles = _subtitles;
    if (subtitles == null) {
      return;
    }
    PageVideoTime? time = await _videoTime();
    if (mounted && identical(subtitles, _subtitles)) {
      String line = time == null ? '' : subtitles.at(time.position);
      String filter = _style.regexFilter;
      if (filter.isNotEmpty && line.isNotEmpty) {
        try {
          line = line.replaceAll(RegExp(filter), '').trim();
        } catch (_) {}
      }
      _line.value = line;
    }
  }

  /// Looks up the line from the character tapped, with the video paused
  /// meanwhile.
  Future<void> _lookUp(TapUpDetails details) async {
    String line = _line.value;
    RenderObject? paragraph = _lineKey.currentContext?.findRenderObject();
    if (line.isEmpty || paragraph is! RenderParagraph) {
      return;
    }
    int index = paragraph
        .getPositionForOffset(details.localPosition)
        .offset
        .clamp(0, line.length);
    String text = line.substring(index).replaceAll('\n', '');
    if (text.trim().isEmpty) {
      return;
    }
    PageVideoTime? time = await _videoTime();
    bool wasPlaying = time != null && !time.paused;
    await _controller?.evaluateJavascript(
        source: "window.__jdj && window.__jdj.control('pause')");
    await appModel.openRecursiveDictionarySearch(
      searchTerm: text,
      killOnPop: false,
    );
    if (wasPlaying && mounted) {
      await _controller?.evaluateJavascript(
          source: "window.__jdj && window.__jdj.control('play')");
    }
  }

  /// A row of [_subtitleMenu].
  Widget _menuRow(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.bodyMedium!
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _findSubtitles() async {
    File? file = await showTtuSheet<File>(
      context: context,
      builder: (_) => SubtitleSearchSheet(
        name: _title.isNotEmpty ? _title : _page?.pathSegments.lastOrNull ?? '',
        fillQuery: false,
      ),
    );
    if (file != null) {
      await _loadSubtitles(file);
    }
  }

  Future<void> _pickSubtitles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    String? path = result?.files.singleOrNull?.path;
    if (path != null) {
      await _loadSubtitles(File(path));
    }
  }

  /// Finding, loading, timing and removing the subtitles shown.
  Future<void> _subtitleMenu() async {
    await showTtuSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          PageSubtitles? subtitles = _subtitles;
          void nudge(int milliseconds) {
            subtitles!.offset += Duration(milliseconds: milliseconds);
            setSheet(() {});
            _followVideo();
          }

          double seconds = (subtitles?.offset.inMilliseconds ?? 0) / 1000;
          String timing =
              '${seconds > 0 ? '+' : ''}${seconds.toStringAsFixed(1)} s';
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TtuSheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.page_subtitles,
                            style: textTheme.titleLarge!
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        JidoujishoInfoButton(message: t.page_subtitles_info),
                      ],
                    ),
                  ),
                  _menuRow(Ui.manage_search, t.player_option_find_subtitles,
                      () {
                    Navigator.pop(sheetContext);
                    _findSubtitles();
                  }),
                  _menuRow(Ui.upload_file, t.player_option_load_subtitles, () {
                    Navigator.pop(sheetContext);
                    _pickSubtitles();
                  }),
                  _menuRow(Ui.text_fields, t.subtitle_appearance, () {
                    Navigator.pop(sheetContext);
                    _changeAppearance();
                  }),
                  if (subtitles != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
                      child: Row(
                        children: [
                          Icon(Ui.timer,
                              size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              t.page_subtitles_timing,
                              style: textTheme.bodyMedium!
                                  .copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                          IconButton(
                            tooltip: t.page_subtitles_earlier,
                            icon: const Icon(Ui.remove, size: 18),
                            onPressed: () => nudge(-500),
                          ),
                          SizedBox(
                            width: 64,
                            child: Text(
                              timing,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium!.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: t.page_subtitles_later,
                            icon: const Icon(Ui.add, size: 18),
                            onPressed: () => nudge(500),
                          ),
                        ],
                      ),
                    ),
                    _menuRow(Ui.subtitles_off_outlined, t.page_subtitles_remove,
                        () {
                      Navigator.pop(sheetContext);
                      _removeSubtitles();
                    }),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _changeAppearance() async {
    await showTtuSheet<void>(
      context: context,
      builder: (_) => SubtitleAppearanceSheet(
        showHeight: true,
        onChanged: () {
          setState(() {
            _style = appModel.subtitleOptions;
            _lineHeight = appModel.pageSubtitleHeight;
          });
          _followVideo();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _fullscreen ? Colors.black : null,
        body: SafeArea(
          top: !_fullscreen,
          bottom: !_fullscreen,
          left: !_fullscreen,
          right: !_fullscreen,
          child: Column(
            children: [
              if (!_fullscreen) ...[
                _bar(),
                if (_progress < 1)
                  LinearProgressIndicator(value: _progress, minHeight: 2)
                else
                  const SizedBox(height: 2),
              ],
              Expanded(
                child: Stack(
                  children: [
                    _webView(),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: _fullscreen
                          ? 8 + MediaQuery.of(context).size.height * _lineHeight
                          : 84,
                      child: Center(child: _subtitleLine()),
                    ),
                    if (!_fullscreen)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 24,
                        child: Center(
                          child: VideoFoundButton(
                            finder: _finder,
                            onPressed: _play,
                          ),
                        ),
                      )
                    else
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _subtitleButton(faint: true),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _webView() {
    return InAppWebView(
      initialSettings: videoPageSettings(),
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: pageSubtitleScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      ]),
      initialUrlRequest: URLRequest(url: WebUri(_address.text.trim())),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'jdjFullscreen',
          callback: (arguments) =>
              _setFullscreen(arguments.isNotEmpty && arguments.first == true),
        );
      },
      shouldInterceptRequest: (controller, request) =>
          noteVideoPageRequest(_finder, request),
      shouldOverrideUrlLoading: (controller, action) =>
          allowVideoPageNavigation(action),
      onCreateWindow: openVideoPageWindow,
      onDownloadStartRequest: (controller, request) {
        Fluttertoast.showToast(msg: t.video_finder_no_downloads);
      },
      onLoadStart: (controller, url) {
        if (url != null &&
            url.removeFragment().toString() !=
                _page?.removeFragment().toString()) {
          _finder.clear();
          _setFullscreen(false);
        }
        _page = url;
        if (url != null) {
          _address.text = url.toString();
        }
      },
      onProgressChanged: (controller, progress) =>
          setState(() => _progress = progress / 100),
      onLoadStop: (controller, url) async {
        _page = url;
        _title = await controller.getTitle() ?? '';
        if (url != null) {
          appModel.rememberVideoPage(url: url.toString(), title: _title);
        }
        _scanPage();
      },
    );
  }

  /// The subtitle line over the page's video, as the player draws its own;
  /// a tap looks a word up.
  Widget _subtitleLine() {
    return ValueListenableBuilder<String>(
      valueListenable: _line,
      builder: (context, line, _) {
        if (line.isEmpty) {
          return const SizedBox.shrink();
        }
        return SubtitleBox(
          options: _style,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _lookUp,
            child: SubtitleText(
              text: line,
              options: _style,
              scale: _fullscreen ? 1 : 0.85,
              textKey: _lineKey,
            ),
          ),
        );
      },
    );
  }

  /// Opens [_subtitleMenu]; [faint] over a full screen video.
  Widget _subtitleButton({bool faint = false}) {
    bool shown = _subtitles != null;
    Widget button = IconButton(
      tooltip: t.page_subtitles,
      icon: Icon(
        Ui.closed_caption,
        color: shown
            ? theme.colorScheme.primary
            : faint
                ? Colors.white
                : null,
      ),
      onPressed: _subtitleMenu,
    );
    if (!faint) {
      return button;
    }
    return Opacity(
      opacity: 0.6,
      child: Material(
        color: Colors.black.withOpacity(0.4),
        shape: const CircleBorder(),
        child: button,
      ),
    );
  }

  Widget _bar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: t.dialog_close,
            icon: const Icon(Ui.close),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: TextField(
              controller: _address,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: _go,
              style: textTheme.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: theme.dividerColor.withOpacity(0.08),
                prefixIcon: Icon(Ui.globe,
                    size: 16, color: theme.unselectedWidgetColor),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 40, minHeight: 36),
                contentPadding: const EdgeInsets.fromLTRB(0, 10, 16, 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          _subtitleButton(),
          IconButton(
            tooltip: t.video_finder_reload,
            icon: const Icon(Ui.replay),
            onPressed: () => _controller?.reload(),
          ),
        ],
      ),
    );
  }
}
