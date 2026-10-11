import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
/// those its requests don't show, as files in a page's own `<video>`.
const String videoPageScan = '''
(() => {
  const found = [];
  for (const media of document.querySelectorAll('video, audio')) {
    const sources = [media.currentSrc, media.src,
      ...[...media.querySelectorAll('source')].map((source) => source.src)];
    for (const source of sources) {
      if (source && !source.startsWith('blob:')) {
        found.push({ source, track: false });
      }
    }
    for (const track of media.querySelectorAll('track')) {
      if (track.src) {
        found.push({ source: track.src, track: true, label: track.label,
          language: track.srclang });
      }
    }
  }
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

  @override
  void initState() {
    super.initState();
    _scan = Timer.periodic(const Duration(seconds: 3), (_) => _scanPage());
  }

  @override
  void dispose() {
    _scan?.cancel();
    _address.dispose();
    _finder.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _bar(),
            if (_progress < 1)
              LinearProgressIndicator(value: _progress, minHeight: 2)
            else
              const SizedBox(height: 2),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialSettings: videoPageSettings(),
                    initialUrlRequest:
                        URLRequest(url: WebUri(_address.text.trim())),
                    onWebViewCreated: (controller) => _controller = controller,
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
                        appModel.rememberVideoPage(
                            url: url.toString(), title: _title);
                      }
                      _scanPage();
                    },
                  ),
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
                ],
              ),
            ),
          ],
        ),
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
          JidoujishoInfoButton(message: t.video_finder_info),
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
