import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show FontFeature;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spaces/spaces.dart';
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
/// with the subtitles the page had, and first those [remembered] for it.
Future<void> playPageMedia({
  required WidgetRef ref,
  required AppModel appModel,
  required PageMedia media,
  required List<PageMedia> subtitles,
  required Uri page,
  required String title,
  RememberedSubtitles? remembered,
}) async {
  String referer = media.referer ?? page.toString();
  String userAgent = media.userAgent ?? videoPageUserAgent;
  PlayerNetworkStreamSource source = PlayerNetworkStreamSource.instance;
  String? kept = remembered != null && File(remembered.path).existsSync()
      ? Uri.file(remembered.path).toString()
      : null;
  MediaItem item = source.getMediaItemFromUrl(
    videoUrl: media.url.toString(),
    title: title,
    extra: jsonEncode({
      'subs': [
        if (kept != null) kept,
        ...subtitles.map((subtitle) => subtitle.url.toString()),
      ],
      'subs.name': [
        if (kept != null) remembered!.name,
        ...subtitles.map(
            (subtitle) => subtitle.label ?? subtitle.language ?? subtitle.name),
      ],
      if (kept != null) ...{
        'subs.enable': [kept],
        'subs.delay': -remembered!.offset.inMilliseconds,
      },
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
class VideoFinderPage extends BaseSourcePage {
  /// Open [url].
  const VideoFinderPage({required this.url, super.key}) : super(item: null);

  /// The page's address.
  final String url;

  @override
  BaseSourcePageState<VideoFinderPage> createState() => _VideoFinderPageState();
}

class _VideoFinderPageState extends BaseSourcePageState<VideoFinderPage> {
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

  /// The part of the line being looked up.
  final ValueNotifier<TextRange?> _highlight = ValueNotifier(null);

  /// Whether the dictionary popup shows.
  bool _popupOpen = false;

  /// Whether the video was paused for the popup, to play on when it closes.
  bool _pausedForPopup = false;

  /// How subtitles look, as in the player.
  late SubtitleOptions _style = appModelNoUpdate.subtitleOptions;

  /// How high the line sits in full screen, as a share of the screen.
  late double _lineHeight = appModelNoUpdate.pageSubtitleHeight;

  /// How high the line sits outside full screen, as a share of the page.
  late double _lineHeightInPage = appModelNoUpdate.pageSubtitleHeightInPage;

  /// Where the line was as a long press began to move it.
  double? _dragFrom;

  /// The page the subtitles shown are remembered for.
  String? _subtitlesPage;

  /// Whether the quick buttons beside the subtitle button show.
  bool _quick = false;

  /// Folds the quick buttons away when they go untouched.
  Timer? _quickTimer;

  /// Whether the subtitle line is hidden for now.
  bool _lineHidden = false;

  /// The blur box over subtitles burnt into the video, as shares of the
  /// screen, when there is one.
  Rect? _blurBox;

  /// Whether the blur box is being moved or sized.
  bool _blurEditing = false;

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
    _highlight.dispose();
    appModelNoUpdate.pageSentence = null;
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
    if (_popupOpen) {
      onDictionaryDismiss();
    }
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
      remembered: _subtitles == null || _subtitlesPage == null
          ? null
          : appModel.rememberedSubtitlesOf(_subtitlesPage!),
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

  /// Back closes the popup, leaves the page's full screen, and goes back a
  /// page, before it leaves; ✕ leaves at once.
  Future<bool> _onWillPop() async {
    if (_popupOpen) {
      onDictionaryDismiss();
      return false;
    }
    if (_fullscreen) {
      await _controller?.evaluateJavascript(
          source: 'window.__jdj && window.__jdj.exit()');
      await _setFullscreen(false);
      return false;
    }
    InAppWebViewController? controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }
    return true;
  }

  /// Shows the subtitles in [file] over the page's video, timed by
  /// [offset]; whether there were any.
  Future<bool> _loadSubtitles(File file,
      {Duration offset = Duration.zero}) async {
    SubtitleItem item = await SubtitleUtils.subtitlesFromFile(
      file: file,
      type: SubtitleItemType.externalSubtitle,
    );
    await item.controller.initial();
    if (!mounted) {
      return false;
    }
    if (item.controller.subtitles.isEmpty) {
      Fluttertoast.showToast(msg: t.page_subtitles_empty);
      return false;
    }
    _subtitles = PageSubtitles(item.controller.subtitles)..offset = offset;
    _follow?.cancel();
    _follow = Timer.periodic(
        const Duration(milliseconds: 200), (_) => _followVideo());
    setState(() {});
    return true;
  }

  /// Shows the subtitles in [file], and keeps them for this page.
  Future<void> _useSubtitles(File file) async {
    if (!await _loadSubtitles(file)) {
      return;
    }
    String page = RememberedSubtitles.keyOf(_page ?? Uri.parse(widget.url));
    _subtitlesPage = page;
    try {
      await appModel.rememberSubtitles(page: page, title: _title, file: file);
    } catch (error) {
      debugPrint('Subtitles not kept: $error');
    }
  }

  /// Shows the subtitles kept for [url] when it opens, in place of others.
  Future<void> _restoreSubtitles(Uri? url) async {
    if (url == null) {
      return;
    }
    String page = RememberedSubtitles.keyOf(url);
    RememberedSubtitles? kept = appModel.rememberedSubtitlesOf(page);
    if (kept == null || _subtitlesPage == page) {
      return;
    }
    if (!File(kept.path).existsSync()) {
      await appModel.forgetSubtitles(page);
      return;
    }
    _subtitlesPage = page;
    if (await _loadSubtitles(File(kept.path), offset: kept.offset)) {
      Fluttertoast.showToast(msg: t.page_subtitles_restored);
    }
  }

  void _removeSubtitles() {
    if (_popupOpen) {
      onDictionaryDismiss();
    }
    String? page = _subtitlesPage;
    _subtitlesPage = null;
    if (page != null) {
      appModel.forgetSubtitles(page);
    }
    _follow?.cancel();
    _follow = null;
    _subtitles = null;
    _line.value = '';
    _quick = false;
    setState(() {});
  }

  /// With subtitles shown, the subtitle button unfolds the quick buttons;
  /// without, it offers to find some.
  void _tapSubtitleButton() {
    if (_subtitles == null) {
      _subtitleMenu();
      return;
    }
    setState(() => _quick = !_quick);
    _keepQuick();
  }

  /// Keeps the quick buttons a while longer after one is used.
  void _keepQuick() {
    _quickTimer?.cancel();
    if (_quick) {
      _quickTimer = Timer(const Duration(seconds: 6), () {
        if (mounted && !_blurEditing) {
          setState(() => _quick = false);
        }
      });
    }
  }

  /// Moves the page's video to where [step] says, from where it is.
  Future<void> _seek(
      Duration? Function(PageSubtitles subtitles, Duration position)
          step) async {
    _keepQuick();
    PageSubtitles? subtitles = _subtitles;
    PageVideoTime? time = await _videoTime();
    if (subtitles == null || time == null) {
      return;
    }
    Duration? to = step(subtitles, time.position);
    if (to == null) {
      return;
    }
    double seconds = max(0, to.inMilliseconds / 1000 - 0.05);
    await _controller?.evaluateJavascript(
        source: 'window.__jdj && window.__jdj.seek($seconds)');
    _followVideo();
  }

  void _toggleLine() {
    _keepQuick();
    setState(() => _lineHidden = !_lineHidden);
  }

  /// Draws the blur box in the page, or takes it away.
  Future<void> _applyBlur() async {
    Rect? box = _blurBox;
    await _controller?.evaluateJavascript(
      source: box == null
          ? 'window.__jdj && window.__jdj.blur(null)'
          : 'window.__jdj && window.__jdj.blur({x: ${box.left}, '
              'y: ${box.top}, width: ${box.width}, height: ${box.height}, '
              'blur: 14})',
    );
  }

  /// Puts the blur box where it was last, ready to be moved or sized.
  void _editBlur() {
    _quickTimer?.cancel();
    setState(() {
      _blurBox ??= appModel.pageBlurBox;
      _blurEditing = true;
    });
    _applyBlur();
  }

  void _doneBlur() {
    Rect? box = _blurBox;
    setState(() => _blurEditing = false);
    if (box != null) {
      appModel.setPageBlurBox(box);
    }
    _applyBlur();
    _keepQuick();
  }

  void _removeBlur() {
    setState(() {
      _blurBox = null;
      _blurEditing = false;
    });
    _applyBlur();
    _keepQuick();
  }

  /// Every line, the one showing first in view; one tapped plays from
  /// there.
  Future<void> _transcript() async {
    PageSubtitles? subtitles = _subtitles;
    if (subtitles == null) {
      return;
    }
    _quickTimer?.cancel();
    PageVideoTime? time = await _videoTime();
    if (!mounted) {
      return;
    }
    Duration? picked = await showTtuSheet<Duration>(
      context: context,
      builder: (_) => _TranscriptSheet(
        subtitles: subtitles,
        current: time == null ? -1 : subtitles.indexAt(time.position),
      ),
    );
    if (picked != null) {
      await _controller?.evaluateJavascript(
          source: 'window.__jdj && window.__jdj.seek('
              '${max(0, picked.inMilliseconds / 1000 - 0.05)})');
      _followVideo();
    }
    _keepQuick();
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
      if (line != _line.value) {
        _highlight.value = null;
      }
      _line.value = line;
    }
  }

  /// Looks up the word tapped as the player does: it is marked, the video
  /// pauses, and the dictionary pops up over the page. A tap on the marked
  /// word closes it again.
  Future<void> _lookUp(TapUpDetails details) async {
    String line = _line.value;
    RenderObject? paragraph = _lineKey.currentContext?.findRenderObject();
    if (line.isEmpty || paragraph is! RenderParagraph) {
      return;
    }
    TextPosition position = paragraph
        .getPositionForOffset(paragraph.globalToLocal(details.globalPosition));
    int index = (position.affinity == TextAffinity.upstream
            ? position.offset - 1
            : position.offset)
        .clamp(0, line.length - 1);

    /// A lone surrogate is the second half of the character meant.
    if (index > 0 && _isTrailSurrogate(line.codeUnitAt(index))) {
      index--;
    }

    TextRange? marked = _highlight.value;
    if (_popupOpen &&
        marked != null &&
        marked.start <= index &&
        index < marked.end) {
      onDictionaryDismiss();
      return;
    }

    String searchTerm = appModel.targetLanguage
        .getSearchTermFromIndex(text: line, index: index)
        .replaceAll('\n', '');
    if (searchTerm.trim().isEmpty) {
      return;
    }
    int whitespace = searchTerm.length - searchTerm.trimLeft().length;
    int start =
        appModel.targetLanguage.getStartingIndex(text: line, index: index) +
            whitespace;
    _highlight.value = _rangeOf(
        line,
        start,
        appModel.targetLanguage
            .getGuessHighlightLength(searchTerm: searchTerm));
    if (!_popupOpen) {
      _quickTimer?.cancel();
      setState(() {
        _popupOpen = true;
        _quick = false;
      });
      await _pauseForPopup();
    }

    await searchDictionaryResult(
      searchTerm: searchTerm,
      position: JidoujishoPopupPosition.topThreeFourths,
    );
    if (!mounted || !_popupOpen || _line.value != line) {
      return;
    }
    TextRange range = _rangeOf(
      line,
      start,
      appModel.targetLanguage.getFinalHighlightLength(
        result: currentResult,
        searchTerm: searchTerm,
      ),
    );
    _highlight.value = range;
    appModel.pageSentence = JidoujishoTextSelection(text: line, range: range);
  }

  static bool _isTrailSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

  /// [length] characters of [line] from [start], within it.
  TextRange _rangeOf(String line, int start, int length) {
    int from = start.clamp(0, line.length);
    return TextRange(
        start: from, end: (from + length).clamp(from, line.length));
  }

  /// Pauses the page's video while the popup shows, if it plays.
  Future<void> _pauseForPopup() async {
    PageVideoTime? time = await _videoTime();
    if (time != null && !time.paused) {
      _pausedForPopup = true;
      await _controller?.evaluateJavascript(
          source: "window.__jdj && window.__jdj.control('pause')");
    }
  }

  /// Closes the popup, and plays the video on if it was paused for it.
  @override
  void onDictionaryDismiss() {
    _highlight.value = null;
    appModel.pageSentence = null;
    super.clearDictionaryResult();
    if (_popupOpen && mounted) {
      setState(() => _popupOpen = false);
    }
    if (_pausedForPopup) {
      _pausedForPopup = false;
      _controller?.evaluateJavascript(
          source: "window.__jdj && window.__jdj.control('play')");
    }
  }

  /// Searches from the popup in full, with the phone's bars back meanwhile
  /// when the page's player fills the screen.
  @override
  void onSearch(String searchTerm, {String? sentence = ''}) async {
    if (_fullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    await appModel.openRecursiveDictionarySearch(
      searchTerm: searchTerm,
      killOnPop: false,
    );
    if (_fullscreen && mounted) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
      await _useSubtitles(file);
    }
  }

  Future<void> _pickSubtitles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    String? path = result?.files.singleOrNull?.path;
    if (path != null) {
      await _useSubtitles(File(path));
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
            String? page = _subtitlesPage;
            if (page != null) {
              appModel.setRememberedSubtitlesOffset(page, subtitles.offset);
            }
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
                    if (_popupOpen)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onDictionaryDismiss,
                        ),
                      ),
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, area) => Stack(
                          children: [
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: _fullscreen
                                  ? 8 + area.maxHeight * _lineHeight
                                  : area.maxHeight * _lineHeightInPage,
                              child:
                                  Center(child: _subtitleLine(area.maxHeight)),
                            ),
                          ],
                        ),
                      ),
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
                      ),
                    if (_blurEditing && _blurBox != null)
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, size) => _blurEditor(size),
                        ),
                      ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axis: Axis.horizontal,
                                axisAlignment: 1,
                                child: child,
                              ),
                            ),
                            child: _quick && _subtitles != null
                                ? _quickBar()
                                : const SizedBox.shrink(),
                          ),
                          if (_fullscreen) ...[
                            const SizedBox(width: 8),
                            _subtitleButton(faint: true),
                          ],
                        ],
                      ),
                    ),
                    if (_popupOpen)
                      Positioned.fill(
                        child: Padding(
                          padding: MediaQuery.of(context).orientation ==
                                  Orientation.landscape
                              ? Spacing.of(context).insets.horizontal.extraBig *
                                  5
                              : Spacing.of(context).insets.onlyTop.big,
                          child: buildDictionary(),
                        ),
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
        if (_blurBox != null) {
          _applyBlur();
        }
        _restoreSubtitles(url);
      },
    );
  }

  /// The subtitle line over the page's video, as the player draws its own;
  /// a tap looks a word up, and a long press moves it up or down the
  /// [area], in full screen and out of it each.
  Widget _subtitleLine(double area) {
    bool moving = _dragFrom != null;
    return AnimatedBuilder(
      animation: Listenable.merge([_line, _highlight]),
      builder: (context, _) {
        String line = _line.value;
        if (line.isEmpty || _lineHidden) {
          return const SizedBox.shrink();
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _lookUp,
          onLongPressStart: (_) {
            HapticFeedback.selectionClick();
            setState(() =>
                _dragFrom = _fullscreen ? _lineHeight : _lineHeightInPage);
          },
          onLongPressMoveUpdate: (details) {
            double? from = _dragFrom;
            if (from == null || area <= 0) {
              return;
            }
            double height =
                (from - details.offsetFromOrigin.dy / area).clamp(0.0, 0.85);
            setState(() {
              if (_fullscreen) {
                _lineHeight = height;
              } else {
                _lineHeightInPage = height;
              }
            });
          },
          onLongPressEnd: (_) {
            setState(() => _dragFrom = null);
            if (_fullscreen) {
              appModel.setPageSubtitleHeight(_lineHeight);
            } else {
              appModel.setPageSubtitleHeightInPage(_lineHeightInPage);
            }
          },
          child: AnimatedScale(
            scale: moving ? 1.05 : 1,
            duration: const Duration(milliseconds: 120),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: moving
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
              child: SubtitleBox(
                options: _style,
                child: SubtitleText(
                  text: line,
                  options: _style,
                  scale: _fullscreen ? 1 : 0.85,
                  textKey: _lineKey,
                  highlight: _highlight.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Buttons at hand while watching: lines before, again and after, the
  /// line hidden, the blur box, the transcript and the rest.
  Widget _quickBar() {
    Color accent = theme.colorScheme.primary;
    Widget button(IconData icon, String tooltip, VoidCallback onPressed,
            {bool active = false}) =>
        IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 20, color: active ? accent : Colors.white),
          onPressed: onPressed,
        );
    Widget gap() => Container(
          width: 1,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          color: Colors.white24,
        );
    return Material(
      key: const ValueKey('quick'),
      color: Colors.black.withOpacity(0.65),
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(Ui.angleLeft, t.page_subtitles_previous,
                () => _seek((lines, at) => lines.previousFrom(at))),
            button(Ui.replay, t.page_subtitles_replay,
                () => _seek((lines, at) => lines.replayFrom(at))),
            button(Ui.angleRight, t.page_subtitles_next,
                () => _seek((lines, at) => lines.nextFrom(at))),
            gap(),
            button(
              _lineHidden ? Ui.eyeCrossed : Ui.eye,
              _lineHidden ? t.page_subtitles_show : t.page_subtitles_hide,
              _toggleLine,
            ),
            button(Ui.blur_on_outlined, t.page_subtitles_blur, _editBlur,
                active: _blurBox != null),
            button(Ui.playlist_play, t.page_subtitles_transcript, _transcript),
            button(Ui.menuDots, t.page_subtitles_more, () {
              _quickTimer?.cancel();
              setState(() => _quick = false);
              _subtitleMenu();
            }),
          ],
        ),
      ),
    );
  }

  /// The blur box being moved, by dragging it, and sized, by its corner.
  Widget _blurEditor(BoxConstraints size) {
    Rect box = _blurBox!;
    double width = size.maxWidth;
    double height = size.maxHeight;
    Rect rect = Rect.fromLTWH(box.left * width, box.top * height,
        box.width * width, box.height * height);
    Color accent = theme.colorScheme.primary;

    void move(Offset delta) {
      double left = (box.left + delta.dx / width).clamp(0.0, 1 - box.width);
      double top = (box.top + delta.dy / height).clamp(0.0, 1 - box.height);
      setState(
          () => _blurBox = Rect.fromLTWH(left, top, box.width, box.height));
    }

    void resize(Offset delta) {
      double right = (box.right + delta.dx / width).clamp(box.left + 0.08, 1.0);
      double bottom =
          (box.bottom + delta.dy / height).clamp(box.top + 0.05, 1.0);
      setState(
          () => _blurBox = Rect.fromLTRB(box.left, box.top, right, bottom));
    }

    Widget action(String label, VoidCallback onPressed, {bool main = false}) =>
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Material(
            color: main ? accent : Colors.black.withOpacity(0.7),
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onPressed,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Text(
                  label,
                  style: textTheme.labelLarge!.copyWith(
                    color: main ? theme.colorScheme.onPrimary : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );

    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: GestureDetector(
            onPanUpdate: (details) => move(details.delta),
            onPanEnd: (_) => _applyBlur(),
            child: Container(
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                border: Border.all(color: accent, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                t.page_subtitles_blur_hint,
                textAlign: TextAlign.center,
                style: textTheme.labelMedium!.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
        Positioned(
          left: rect.right - 20,
          top: rect.bottom - 20,
          child: GestureDetector(
            onPanUpdate: (details) => resize(details.delta),
            onPanEnd: (_) => _applyBlur(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child:
                  Icon(Ui.expand, size: 18, color: theme.colorScheme.onPrimary),
            ),
          ),
        ),
        Positioned(
          left: rect.left,
          top: rect.top > 52 ? rect.top - 44 : rect.bottom + 8,
          child: Row(
            children: [
              action(t.page_subtitles_blur_done, _doneBlur, main: true),
              action(t.page_subtitles_blur_remove, _removeBlur),
            ],
          ),
        ),
      ],
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
      onPressed: _tapSubtitleButton,
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

/// Every subtitle line with its time, the one showing marked and in view;
/// closes with where the line tapped starts.
class _TranscriptSheet extends StatelessWidget {
  const _TranscriptSheet({required this.subtitles, required this.current});

  final PageSubtitles subtitles;

  /// The line showing, or -1.
  final int current;

  static const double _row = 60;

  String _time(Duration time) {
    int seconds = time.inSeconds;
    String two(int value) => value.toString().padLeft(2, '0');
    return seconds >= 3600
        ? '${seconds ~/ 3600}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}'
        : '${seconds ~/ 60}:${two(seconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    MediaQueryData media = MediaQuery.of(context);
    ScrollController controller = ScrollController(
      initialScrollOffset: max(0, current * _row - _row * 2),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TtuSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              t.page_subtitles_transcript,
              style: theme.textTheme.titleLarge!
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Flexible(
            child: ListView.builder(
              controller: controller,
              itemExtent: _row,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
              itemCount: subtitles.cues.length,
              itemBuilder: (context, index) {
                bool showing = index == current;
                return Material(
                  color: showing
                      ? theme.colorScheme.primary.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () =>
                        Navigator.pop(context, subtitles.startOf(index)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              _time(subtitles.startOf(index)),
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: showing
                                    ? theme.colorScheme.primary
                                    : theme.unselectedWidgetColor,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              subtitles.cues[index].data
                                  .replaceAll('\n', ' ')
                                  .trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium!.copyWith(
                                fontWeight: showing ? FontWeight.w600 : null,
                                color:
                                    showing ? theme.colorScheme.primary : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
