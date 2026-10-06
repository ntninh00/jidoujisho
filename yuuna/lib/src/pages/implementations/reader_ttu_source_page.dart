import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FontFeature;

import 'package:collection/collection.dart';
import 'package:document_file_save_plus/document_file_save_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:local_assets_server/local_assets_server.dart';
import 'package:spaces/spaces.dart';
import 'package:wakelock/wakelock.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/language.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// The media page used for the [ReaderTtuSource].
class ReaderTtuSourcePage extends BaseSourcePage {
  /// Create an instance of this page.
  const ReaderTtuSourcePage({
    super.item,
    super.key,
  });

  @override
  BaseSourcePageState createState() => _ReaderTtuSourcePageState();
}

/// What the loading screen says while ッツ opens a book.
enum _MaskKind { opening, jumping, returning, applying }

class _ReaderTtuSourcePageState extends BaseSourcePageState<ReaderTtuSourcePage>
    with WidgetsBindingObserver {
  /// The media source pertaining to this page.
  ReaderTtuSource get mediaSource => ReaderTtuSource.instance;
  InAppWebViewController? _controller;

  Orientation? lastOrientation;

  final FocusNode _focusNode = FocusNode();
  bool _isRecursiveSearching = false;

  /// The launch request, if the page was opened for a book.
  TtuLaunch? _launch;

  /// The language of the copy of ッツ this page shows.
  late final Language _language;

  /// Scripts are ready and the book's language is set up for lookups.
  bool _ready = false;
  String? _readerScript;
  String? _settingsScript;
  String? _fitScript;

  /// Loading screen shown over the WebView until the book is on screen.
  final ValueNotifier<bool> _maskVisible = ValueNotifier(false);
  bool _maskBuilt = false;
  _MaskKind _maskKind = _MaskKind.opening;
  double? _maskProgress;

  /// Offers the position before a jump for a few seconds.
  final ValueNotifier<TtuPosition?> _backChip = ValueNotifier(null);
  Timer? _backChipTimer;

  bool _flashPending = false;
  bool _chipPending = false;
  bool _leaving = false;
  int _lookupSerial = 0;

  /// The visit ended: the reader went back to their own place, or chose a
  /// chapter to read from.
  bool _wentBack = false;

  /// This visit is to a memo or term: ッツ's saved place stays as it was.
  bool get _keepPlace => (_launch?.keepPlace ?? false) && !_wentBack;

  /// The menu over the book, opened from its top or bottom edge.
  final ValueNotifier<bool> _menuVisible = ValueNotifier(false);

  /// Where the reader is, shown in the menu.
  String _menuDetail = '';

  /// The book's chapters and length, read once from ッツ.
  List<TtuChapter>? _chapters;
  int _bookCharacters = 0;

  /// A position known to be on the page that is loading, which tells the
  /// page which chapter it shows.
  int _expectedPosition = -1;

  /// Sends the book's memos to the page again whenever they change.
  StreamSubscription<void>? _memoWatch;

  /// The place when the settings opened; the book reopens there.
  TtuPosition? _settingsAnchor;
  bool _settingsChanged = false;
  Timer? _layoutReload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _launch = mediaSource.takePendingLaunch();
    String url = widget.item?.mediaIdentifier ?? '';
    _language = mediaSource.languageForUrl(url) ??
        (_launch?.book.language ?? JapaneseLanguage.instance);

    TtuLaunch? launch = _launch;
    _expectedPosition =
        launch?.target?.characters ?? launch?.book.exploredCharCount ?? -1;
    _memoWatch =
        appModelNoUpdate.watchReaderMemos().listen((_) => _sendMemos());
    if (launch != null) {
      _maskVisible.value = true;
      _maskBuilt = true;
      _maskKind = launch.target == null ? _MaskKind.opening : _MaskKind.jumping;
      _maskProgress = launch.target?.progress ?? launch.book.progress;
      _flashPending = launch.excerpt != null && launch.target != null;
      _chipPending = launch.returnTo != null;
    }

    _prepare();
  }

  Future<void> _prepare() async {
    _readerScript = await TtuLibrary.readerScript;
    _fitScript = await TtuLibrary.fitScript;
    _settingsScript = mediaSource.settingsScriptFor(
      _language,
      darkMode: appModelNoUpdate.isDarkMode,
      keepPlace: _launch?.keepPlace ?? false,
    );
    mediaSource.termOrigin = _termOrigin;
    await appModelNoUpdate.setSessionLanguage(_language);
    if (!mediaSource.keepScreenOn) {
      await Wakelock.disable();
    }
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    if (mediaSource.termOrigin == _termOrigin) {
      mediaSource.termOrigin = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _backChipTimer?.cancel();
    _layoutReload?.cancel();
    _memoWatch?.cancel();
    _menuVisible.dispose();
    _maskVisible.dispose();
    _backChip.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      FocusScope.of(context).unfocus();
      _focusNode.requestFocus();
    }
  }

  @override
  void onSearch(String searchTerm, {String? sentence = ''}) async {
    _isRecursiveSearching = true;
    if (appModel.isMediaOpen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await Future.delayed(const Duration(milliseconds: 5), () {});
    }
    await appModel.openRecursiveDictionarySearch(
      searchTerm: searchTerm,
      killOnPop: false,
    );
    if (appModel.isMediaOpen) {
      await Future.delayed(const Duration(milliseconds: 5), () {});
      await appModel.applyMediaSystemUi();
    }
    _isRecursiveSearching = false;

    _focusNode.requestFocus();
  }

  /// Hide the dictionary and dispose of the current result.
  @override
  void clearDictionaryResult() async {
    _lookupSerial++;
    super.clearDictionaryResult();
    unselectWebViewTextSelection();
  }

  @override
  void onCreatorClose() {
    _focusNode.unfocus();
    _focusNode.requestFocus();
  }

  /// Leaving a book saves the reading position and goes straight back to the
  /// shelf, without asking.
  @override
  Future<bool> onWillPop() async {
    if (_menuVisible.value) {
      _menuVisible.value = false;
      return false;
    }

    /// A formula opened at full size closes first.
    Object? viewerClosed = await _controller?.evaluateJavascript(
      source: 'window.__jdjFit ? window.__jdjFit.close() : false',
    );
    if (viewerClosed == true) {
      return false;
    }
    if (isDictionaryShown) {
      clearDictionaryResult();
      mediaSource.clearCurrentSentence();
      return false;
    }
    if (_leaving) {
      return false;
    }
    _leaving = true;

    TtuPosition? saved;
    bool keptPlace = _keepPlace;
    if (keptPlace) {
      await _restorePlace()
          .timeout(const Duration(milliseconds: 1500), onTimeout: () {});
    } else if (mediaSource.autoSavePosition) {
      saved = await _savePosition()
          .timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
    }

    await onSourcePagePop();
    if (!mounted) {
      return false;
    }
    mediaSource.holdShelfUntilClosed(ModalRoute.of(context)?.animation);
    await appModel.closeMedia(
      ref: ref,
      mediaSource: mediaSource,
      item: widget.item,
    );

    TtuLaunch? launch = _launch;
    if (keptPlace && launch != null) {
      Fluttertoast.showToast(
        msg: t.ttu_place_kept(position: ttuPercent(launch.book.progress)),
      );
    } else if (saved != null) {
      Fluttertoast.showToast(
        msg: t.ttu_saved_place(position: ttuPercent(saved.progress)),
      );
    }
    return true;
  }

  /// Puts ッツ's saved place back to where the reader was before this visit
  /// to a memo or term.
  Future<void> _restorePlace() async {
    TtuLaunch? launch = _launch;
    if (launch == null) {
      return;
    }
    try {
      await _controller?.callAsyncJavaScript(
        functionBody: 'return window.__jdj ? await window.__jdj.writePosition('
            '${launch.book.exploredCharCount}, ${launch.book.progress}) : null;',
      );
    } catch (error) {
      debugPrint('Could not keep place: $error');
    }
  }

  /// The position on screen. On a visit to a memo or term, ッツ's saved
  /// place is put back afterwards.
  Future<TtuPosition?> _capturePosition() async {
    TtuPosition? position = await _savePosition();
    if (_keepPlace) {
      await _restorePlace();
    }
    return position;
  }

  /// Where a term saved now comes from: this book, this place, and
  /// [excerpt], the text it was taken from.
  Future<TermOrigin?> _termOrigin(String excerpt) async {
    TtuBook? book = await _currentBook();
    if (book == null) {
      return null;
    }
    TtuPosition? position = await _capturePosition();
    String sentence = mediaSource.currentSentence.text.trim();
    return TermOrigin(
      bookKey: book.key,
      bookTitle: book.title,
      characters: position?.characters ?? 0,
      progress: position?.progress ?? 0,
      excerpt: excerpt.isNotEmpty ? excerpt : sentence,
    );
  }

  /// Presses ッツ's own bookmark key and reads back the saved position.
  Future<TtuPosition?> _savePosition() async {
    InAppWebViewController? controller = _controller;
    if (controller == null || !_isBookPage(await controller.getUrl())) {
      return null;
    }
    try {
      CallAsyncJavaScriptResult? result = await controller.callAsyncJavaScript(
        functionBody:
            'return window.__jdj ? await window.__jdj.savePosition() : null;',
      );
      Object? value = result?.value;
      if (value is! Map) {
        return null;
      }
      return TtuPosition(
        characters: ((value['exploredCharCount'] as num?) ?? 0).toInt(),
        progress: ((value['progress'] as num?) ?? 0).toDouble(),
      );
    } catch (error) {
      debugPrint('Could not save position: $error');
      return null;
    }
  }

  bool _isBookPage(Uri? uri) {
    String path = uri?.path ?? '';
    return path.endsWith('/b.html') || path.endsWith('/b');
  }

  /// A text field on top of the reader has the keyboard, such as the My words
  /// editor opened from the popup. The reader must not take focus back.
  bool get _someoneIsTyping {
    BuildContext? focused = FocusManager.instance.primaryFocus?.context;
    return focused != null &&
        (focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  bool get _openedForBook =>
      widget.item?.mediaIdentifier.contains('/b.html') ?? false;

  @override
  Widget build(BuildContext context) {
    Orientation orientation = MediaQuery.of(context).orientation;
    if (orientation != lastOrientation) {
      if (_controller != null) {
        clearDictionaryResult();
      }
      lastOrientation = orientation;
    }

    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onFocusChange: (value) {
        if (mediaSource.volumePageTurningEnabled &&
            !(ModalRoute.of(context)?.isCurrent ?? false) &&
            !appModel.isCreatorOpen &&
            !_isRecursiveSearching &&
            !_someoneIsTyping) {
          _focusNode.requestFocus();
        }
      },
      canRequestFocus: true,
      onKey: (data, event) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          if (mediaSource.volumePageTurningEnabled) {
            InAppWebViewController? controller = _controller;
            if (controller == null) {
              return KeyEventResult.ignored;
            }

            if (isDictionaryShown) {
              clearDictionaryResult();
              mediaSource.clearCurrentSentence();

              return KeyEventResult.handled;
            }

            if (event.isKeyPressed(LogicalKeyboardKey.audioVolumeUp)) {
              unselectWebViewTextSelection();
              controller.evaluateJavascript(source: leftArrowSimulateJs);

              return KeyEventResult.handled;
            }
            if (event.isKeyPressed(LogicalKeyboardKey.audioVolumeDown)) {
              unselectWebViewTextSelection();
              controller.evaluateJavascript(source: rightArrowSimulateJs);

              return KeyEventResult.handled;
            }
          }

          return KeyEventResult.ignored;
        } else {
          return KeyEventResult.ignored;
        }
      },
      child: WillPopScope(
        onWillPop: onWillPop,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: _systemBarStyle,
          child: Scaffold(
            backgroundColor:
                mediaSource.fullScreen ? Colors.black : _pageColors[0],
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              top: !mediaSource.fullScreen ||
                  !mediaSource.extendPageBeyondNavigationBar,
              bottom: !mediaSource.fullScreen,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: <Widget>[
                  buildBody(),
                  buildMenu(),
                  buildDictionary(),
                  if (_maskBuilt) buildMask(),
                  buildBackChip(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildBody() {
    if (!_ready) {
      return const SizedBox.expand();
    }

    AsyncValue<LocalAssetsServer> server =
        ref.watch(ttuServerProvider(_language));

    return server.when(
      data: buildReaderArea,
      loading: buildLoading,
      error: (error, stack) => buildError(
        error: error,
        stack: stack,
        refresh: () {
          ref.invalidate(ttuServerProvider(_language));
        },
      ),
    );
  }

  /// The colours of the page ッツ is about to show, so the loading screen
  /// matches it.
  List<Color> get _pageColors {
    String theme = mediaSource.effectiveThemeFor(
      _language,
      darkMode: appModel.isDarkMode,
    );
    List<int> colors =
        TtuPagePreset.themeColors[theme] ?? TtuPagePreset.themeColors['dark']!;
    return [Color(colors[0]), Color(colors[1])];
  }

  /// Status and navigation bars in the page's colours, so they read as part
  /// of the page when they are shown.
  SystemUiOverlayStyle get _systemBarStyle {
    Color page = _pageColors[0];
    bool dark = page.computeLuminance() < 0.4;
    Brightness icons = dark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: icons,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: page,
      systemNavigationBarDividerColor: page,
      systemNavigationBarIconBrightness: icons,
    );
  }

  /// Covers the WebView while ッツ loads, saying where the book will open.
  Widget buildMask() {
    List<Color> colors = _pageColors;
    Color foreground = colors[1];
    Color muted = foreground.withOpacity(0.5);
    TtuLaunch? launch = _launch;
    String? memo = _maskKind == _MaskKind.jumping ? launch?.memo : null;
    String? excerpt = _maskKind == _MaskKind.jumping ? launch?.excerpt : null;
    String kicker = switch (_maskKind) {
      _MaskKind.opening => t.ttu_opening,
      _MaskKind.jumping => t.ttu_jumping_to,
      _MaskKind.returning => t.ttu_returning_to,
      _MaskKind.applying => t.ttu_applying,
    };
    double? progress = _maskProgress;

    return ValueListenableBuilder<bool>(
      valueListenable: _maskVisible,
      builder: (context, visible, child) => IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 180),
          onEnd: () {
            if (!_maskVisible.value && mounted) {
              setState(() => _maskBuilt = false);
            }
          },
          child: child,
        ),
      ),
      child: ColoredBox(
        color: colors[0],
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kicker.toUpperCase(),
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    letterSpacing: 1.4,
                  ),
                ),
                if (progress != null)
                  Text(
                    ttuPercent(progress),
                    style: TextStyle(
                      color: foreground,
                      fontSize: 44,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                if (launch != null)
                  Text(
                    launch.book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                if (memo != null && memo.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    memo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (excerpt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    ttuQuote(_language, excerpt),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 14, height: 1.6),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: muted.withOpacity(0.25),
                      valueColor:
                          AlwaysStoppedAnimation(theme.colorScheme.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A chip offering the position from before a jump, for six seconds.
  Widget buildBackChip() {
    return ValueListenableBuilder<TtuPosition?>(
      valueListenable: _backChip,
      builder: (context, back, _) {
        bool reduceMotion = MediaQuery.of(context).disableAnimations;
        return AnimatedSwitcher(
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          child: back == null
              ? const SizedBox.shrink()
              : Align(
                  key: const ValueKey('back-chip'),
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 56),
                    child: Material(
                      color: const Color(0xFF303030),
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      elevation: 4,
                      child: InkWell(
                        onTap: () => _goBack(back),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Ui.undo_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    t.ttu_back_to(
                                        position: ttuPercent(back.progress)),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 1, end: 0),
                                duration: const Duration(seconds: 6),
                                builder: (context, value, _) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: value,
                                    child: Container(
                                      height: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  void _showBackChip(TtuPosition back) {
    _backChip.value = back;
    _backChipTimer?.cancel();
    _backChipTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        _backChip.value = null;
      }
    });
  }

  /// Goes back to where the reader was before jumping to a memo.
  void _goBack(TtuPosition back) {
    TtuLaunch? launch = _launch;
    if (launch == null) {
      return;
    }
    _backChipTimer?.cancel();
    _backChip.value = null;
    _wentBack = true;
    mediaSource.returnPositions.remove(launch.book.key);
    _reloadAt(launch.book, back, _MaskKind.returning);
  }

  /// Opens [book] again at [position], behind the loading screen.
  Future<void> _reloadAt(
    TtuBook book,
    TtuPosition position,
    _MaskKind kind,
  ) async {
    InAppWebViewController? controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    setState(() {
      _maskKind = kind;
      _maskProgress = position.progress;
      _maskBuilt = true;
    });
    _maskVisible.value = true;
    _flashPending = false;
    _chipPending = false;
    _expectedPosition = position.characters;
    await controller.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(TtuLaunch.jumpUrl(book: book, position: position)),
      ),
    );
  }

  /* ---------- menu, chapters and settings over the book ---------- */

  /// A tap on the book's top or bottom edge: closes the popup if one is
  /// open, otherwise shows or hides the menu.
  void _onMenuTap() {
    if (isDictionaryShown) {
      clearDictionaryResult();
      mediaSource.clearCurrentSentence();
      return;
    }
    if (_menuVisible.value) {
      _menuVisible.value = false;
      return;
    }
    _menuVisible.value = true;
    _refreshMenuDetail();
  }

  Future<void> _refreshMenuDetail() async {
    TtuPosition? position = await _capturePosition();
    await _loadChapters();
    if (!mounted) {
      return;
    }
    TtuChapter? chapter = position == null
        ? null
        : ttuChapterAt(_chapters ?? const [], position.characters);
    setState(() {
      _menuDetail = [
        if (chapter != null && chapter.label.isNotEmpty) chapter.label,
        if (position != null) ttuPercent(position.progress),
      ].join(' · ');
    });
  }

  Future<void> _loadChapters() async {
    if (_chapters != null) {
      return;
    }
    try {
      CallAsyncJavaScriptResult? result =
          await _controller?.callAsyncJavaScript(
        functionBody:
            'return window.__jdj ? await window.__jdj.chapters() : null;',
      );
      Object? value = result?.value;
      if (value is Map) {
        _bookCharacters = (value['characters'] as num?)?.toInt() ?? 0;
        _chapters = ((value['sections'] as List?) ?? const [])
            .whereType<Map>()
            .map(TtuChapter.fromMap)
            .toList();
      }
    } catch (error) {
      debugPrint('Could not read chapters: $error');
    }
  }

  Widget buildMenu() {
    List<Color> colors = _pageColors;
    bool reduceMotion = MediaQuery.of(context).disableAnimations;
    Duration duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 160);
    return ValueListenableBuilder<bool>(
      valueListenable: _menuVisible,
      builder: (context, visible, _) => IgnorePointer(
        ignoring: !visible,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _menuVisible.value = false,
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: AnimatedSlide(
                offset: visible ? Offset.zero : const Offset(0, -0.4),
                duration: duration,
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: duration,
                  child: TtuReaderMenu(
                    title: _launch?.book.title ?? widget.item?.title ?? '',
                    detail: _menuDetail,
                    background: colors[0],
                    foreground: colors[1],
                    onBack: _leaveFromMenu,
                    onChapters: _showChapters,
                    onSettings: _showLiveSettings,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _leaveFromMenu() async {
    _menuVisible.value = false;
    bool leave = await onWillPop();
    if (leave && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _showChapters() async {
    _menuVisible.value = false;
    await _loadChapters();
    TtuPosition? position = await _capturePosition();
    if (!mounted) {
      return;
    }
    _isRecursiveSearching = true;
    await showTtuSheet<void>(
      context: context,
      builder: (_) => TtuChaptersSheet(
        chapters: _chapters ?? const [],
        totalCharacters: _bookCharacters,
        position: position?.characters ?? 0,
        onSelect: _goToChapter,
      ),
    );
    _isRecursiveSearching = false;
    _focusNode.requestFocus();
  }

  /// Reads on from [chapter]. Choosing a chapter ends a visit to a memo or
  /// term, so the saved place follows the reader again.
  void _goToChapter(TtuChapter chapter) async {
    TtuBook? book = await _currentBook();
    if (book == null) {
      return;
    }
    _wentBack = true;
    double progress = _bookCharacters > 0 ? chapter.start / _bookCharacters : 0;
    await _reloadAt(
      book,
      TtuPosition(characters: chapter.start, progress: progress),
      _MaskKind.jumping,
    );
  }

  /// Fonts the user added in ッツ's own settings.
  Future<List<String>> _userFonts() async {
    try {
      Object? value = await _controller?.evaluateJavascript(
        source: 'window.__jdj ? window.__jdj.userFonts() : []',
      );
      if (value is List) {
        return value.whereType<String>().toList();
      }
    } catch (_) {}
    return const [];
  }

  /// The page settings over the book. Most changes show on the page at
  /// once; changes to the layout reopen the book at the same place, and so
  /// does closing the sheet, so ッツ applies everything properly.
  Future<void> _showLiveSettings() async {
    _menuVisible.value = false;
    _settingsAnchor = await _capturePosition();
    _settingsChanged = false;
    List<String> fonts = await _userFonts();
    mediaSource.rememberUserFonts(_language, fonts);
    if (!mounted) {
      return;
    }
    _isRecursiveSearching = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.transparent,
      backgroundColor: Theme.of(context).cardColor,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TtuReaderSettingsSheet(
        languages: [_language],
        extraFonts: fonts,
        onPresetChanged: _onPresetChanged,
        onOptionsChanged: _onOptionsChanged,
      ),
    );
    _isRecursiveSearching = false;
    _layoutReload?.cancel();
    if (_settingsChanged) {
      await _applySettings();
    }
    _focusNode.requestFocus();
  }

  void _onPresetChanged(TtuPagePreset preset, {required bool structural}) {
    _settingsChanged = true;
    if (structural) {
      _layoutReload?.cancel();
      _layoutReload = Timer(const Duration(milliseconds: 350), _applySettings);
      return;
    }
    _previewPreset(preset);
  }

  static String _cssColor(int argb) =>
      'rgba(${(argb >> 16) & 0xff}, ${(argb >> 8) & 0xff}, ${argb & 0xff}, '
      '${(((argb >> 24) & 0xff) / 255).toStringAsFixed(3)})';

  /// Shows [preset] on the page straight away.
  void _previewPreset(TtuPagePreset preset) {
    String theme = preset.theme ?? (appModel.isDarkMode ? 'dark' : 'light');
    List<int> colors =
        TtuPagePreset.themeColors[theme] ?? TtuPagePreset.themeColors['dark']!;
    Map<String, Object> payload = {
      'fontSize': preset.fontSize,
      'lineHeight': preset.lineHeight,
      'fontFamily': preset.fontFamily,
      'margin': preset.margin,
      'background': _cssColor(colors[0]),
      'foreground': _cssColor(colors[1]),
      'blurImages': preset.blurImages,
      'avoidPageBreak': preset.avoidPageBreak,
      if (_language is JapaneseLanguage) 'furigana': preset.furigana,
      'furiganaStyle': preset.furiganaStyle,
    };
    _controller?.evaluateJavascript(
      source: 'window.__jdj && window.__jdj.preview(${jsonEncode(payload)});',
    );
    setState(() {});
  }

  /// Reopens the book at the place the settings opened at, with ッツ given
  /// the new settings.
  Future<void> _applySettings() async {
    _settingsChanged = false;
    InAppWebViewController? controller = _controller;
    TtuBook? book = await _currentBook();
    if (controller == null || book == null || !mounted) {
      return;
    }
    _settingsScript = mediaSource.settingsScriptFor(
      _language,
      darkMode: appModel.isDarkMode,
      keepPlace: _keepPlace,
    );
    await controller.removeAllUserScripts();
    await controller.addUserScripts(userScripts: [
      UserScript(
        source: _settingsScript ?? '',
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: _fitScript ?? '',
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
    ]);
    TtuPosition position = _settingsAnchor ??
        TtuPosition(
          characters: book.exploredCharCount,
          progress: book.progress,
        );
    await _reloadAt(book, position, _MaskKind.applying);
  }

  /// Shows the book's memos as notes on the page, or none if that is off.
  Future<void> _sendMemos() async {
    InAppWebViewController? controller = _controller;
    if (controller == null || !_isBookPage(await controller.getUrl())) {
      return;
    }
    TtuBook? book = await _currentBook();
    if (book == null) {
      return;
    }
    List<Map<String, Object>> memos = !mediaSource.showMemosOnPage
        ? const []
        : appModel.readerMemos
            .where((memo) => memo.bookKey == book.key)
            .map((memo) => <String, Object>{
                  'id': memo.id,
                  'text': memo.memo,
                  'excerpt': memo.excerpt,
                  'characters': memo.exploredCharCount,
                  'progress': memo.progress,
                })
            .toList();
    await controller.evaluateJavascript(
      source: 'window.__jdj && window.__jdj.showMemos('
          '${jsonEncode(memos)}, $_expectedPosition);',
    );
  }

  /// Opens a memo in full from its note on the page.
  void _openMemo(int? id) async {
    ReaderMemo? memo =
        appModel.readerMemos.firstWhereOrNull((memo) => memo.id == id);
    TtuBook? book = await _currentBook();
    if (memo == null || book == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (isDictionaryShown) {
      clearDictionaryResult();
    }
    _isRecursiveSearching = true;
    await showTtuSheet<void>(
      context: context,
      builder: (_) => TtuMemoViewSheet(
        memo: memo,
        book: book,
        onEdit: () => _editMemo(memo, book),
      ),
    );
    _isRecursiveSearching = false;
    _focusNode.requestFocus();
  }

  void _editMemo(ReaderMemo memo, TtuBook book) async {
    _isRecursiveSearching = true;
    String? text = await showTtuMemoEditor(
      context: context,
      book: book,
      excerpt: memo.excerpt,
      progress: memo.progress,
      characters: memo.exploredCharCount,
      initialMemo: memo.memo,
      isNew: false,
      onDelete: () => appModel.deleteReaderMemo(memo),
    );
    _isRecursiveSearching = false;
    await appModel.applyMediaSystemUi();
    if (text != null) {
      memo.memo = text;
      await appModel.putReaderMemo(memo);
    }
    _focusNode.requestFocus();
  }

  /// A reading option changed from the settings over the book.
  void _onOptionsChanged() async {
    _sendMemos();
    await appModel.applyMediaSystemUi();
    if (mediaSource.keepScreenOn) {
      await Wakelock.enable();
    } else {
      await Wakelock.disable();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void setDictionaryColors() async {
    InAppWebViewController? controller = _controller;
    if (controller == null) {
      return;
    }
    String currentTheme = (await controller.evaluateJavascript(
            source: 'window.localStorage.getItem("theme")'))
        .toString();
    switch (currentTheme) {
      case 'light-theme':
        appModel.setOverrideDictionaryTheme(appModel.theme);
        appModel.setOverrideDictionaryColor(
          Color.fromRGBO(249, 249, 249, dictionaryEntryOpacity),
        );
        break;
      case 'ecru-theme':
        appModel.setOverrideDictionaryTheme(appModel.theme);
        appModel.setOverrideDictionaryColor(
          Color.fromRGBO(247, 246, 235, dictionaryEntryOpacity),
        );
        break;
      case 'water-theme':
        appModel.setOverrideDictionaryTheme(appModel.theme);
        appModel.setOverrideDictionaryColor(
          Color.fromRGBO(223, 236, 244, dictionaryEntryOpacity),
        );
        break;
      case 'gray-theme':
        appModel.setOverrideDictionaryTheme(appModel.darkTheme);
        appModel.setOverrideDictionaryColor(
          Color.fromRGBO(35, 39, 42, dictionaryEntryOpacity),
        );
        break;
      case 'dark-theme':
        appModel.setOverrideDictionaryTheme(appModel.darkTheme);
        appModel.setOverrideDictionaryColor(
          Color.fromRGBO(18, 18, 18, dictionaryEntryOpacity),
        );
        break;
      case 'black-theme':
        appModel.setOverrideDictionaryTheme(appModel.darkTheme);
        appModel.setOverrideDictionaryColor(
          Color.fromRGBO(16, 16, 16, dictionaryEntryOpacity),
        );
        break;
    }

    if (mounted) {
      clearDictionaryResult();
      setState(() {});
    }
  }

  CacheMode get cacheMode {
    if (mediaSource.currentTtuInternalVersion ==
        ReaderTtuSource.ttuInternalVersion) {
      return CacheMode.LOAD_CACHE_ELSE_NETWORK;
    } else {
      mediaSource.setTtuInternalVersion();
      return CacheMode.LOAD_NO_CACHE;
    }
  }

  createFileFromBase64(String base64Content) async {
    var bytes = base64Decode(base64Content.replaceAll('\n', ''));
    DocumentFileSavePlus().saveFile(
      bytes.buffer.asUint8List(),
      _suggestedFilename,
      _mimeType,
    );
    Fluttertoast.showToast(msg: t.file_downloaded(name: _suggestedFilename));
  }

  Widget buildReaderArea(LocalAssetsServer server) {
    String initialUrl = _launch?.initialUrl ??
        widget.item?.mediaIdentifier ??
        'http://localhost:${server.boundPort}/manage.html';

    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: _settingsScript ?? '',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
        UserScript(
          source: _fitScript ?? '',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      onPermissionRequest: (controller, origin) async {
        return PermissionResponse(
          action: PermissionResponseAction.GRANT,
        );
      },
      initialSettings: InAppWebViewSettings(
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        mediaPlaybackRequiresUserGesture: false,
        verticalScrollBarEnabled: false,
        horizontalScrollBarEnabled: false,
        javaScriptCanOpenWindowsAutomatically: true,
        useOnDownloadStart: true,
        verticalScrollbarThumbColor: Colors.transparent,
        verticalScrollbarTrackColor: Colors.transparent,
        horizontalScrollbarThumbColor: Colors.transparent,
        horizontalScrollbarTrackColor: Colors.transparent,
        scrollbarFadingEnabled: false,
        appCachePath: appModel.browserDirectory.path,
        cacheMode: cacheMode,
        supportMultipleWindows: true,
      ),
      contextMenu: contextMenu,
      onWebViewCreated: (controller) {
        _controller = controller;

        controller.addJavaScriptHandler(
          handlerName: 'blobToBase64Handler',
          callback: (data) async {
            if (data.isNotEmpty) {
              final String base64Content = data[0];
              createFileFromBase64(base64Content);
            }
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'jidoujisho',
          callback: (arguments) {
            Object? message = arguments.isEmpty ? null : arguments.first;
            if (message is Map && message['type'] == 'lookup') {
              onLookup(Map<String, dynamic>.from(message));
            } else if (message is Map && message['type'] == 'menu') {
              _onMenuTap();
            } else if (message is Map && message['type'] == 'memo') {
              _openMemo((message['id'] as num?)?.toInt());
            }
            return null;
          },
        );
      },
      onCreateWindow: (controller, createWindowRequest) async {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              insetPadding: Spacing.of(context).insets.all.big,
              contentPadding: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              content: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * (3 / 4),
                child: InAppWebView(
                  initialSettings: InAppWebViewSettings(
                    supportZoom: false,
                    disableContextMenu: true,
                    allowFileAccessFromFileURLs: true,
                    allowUniversalAccessFromFileURLs: true,
                    mediaPlaybackRequiresUserGesture: false,
                    verticalScrollBarEnabled: false,
                    horizontalScrollBarEnabled: false,
                    javaScriptCanOpenWindowsAutomatically: true,
                    userAgent: 'random',
                    useOnDownloadStart: true,
                    verticalScrollbarThumbColor: Colors.transparent,
                    verticalScrollbarTrackColor: Colors.transparent,
                    horizontalScrollbarThumbColor: Colors.transparent,
                    horizontalScrollbarTrackColor: Colors.transparent,
                    scrollbarFadingEnabled: false,
                    appCachePath: appModel.browserDirectory.path,
                    cacheMode: cacheMode,
                    supportMultipleWindows: true,
                  ),
                  windowId: createWindowRequest.windowId,
                  onDownloadStartRequest: onDownloadStartRequest,
                  onCloseWindow: (controller) {
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            );
          },
        );
        return true;
      },
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        return ServerTrustAuthResponse(
          action: ServerTrustAuthResponseAction.PROCEED,
        );
      },
      onLoadStop: (controller, uri) async {
        await _injectReaderScript(controller);
        if (mediaSource.adaptTtuTheme) {
          setDictionaryColors();
        }
        await _onPageLoaded(controller, uri);
        mediaSource.rememberUserFonts(_language, await _userFonts());
        Future.delayed(const Duration(seconds: 1), _focusNode.requestFocus);
      },
      onTitleChanged: (controller, title) async {
        await _injectReaderScript(controller);
        if (mediaSource.adaptTtuTheme) {
          setDictionaryColors();
        }
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        _onNavigated(url);
      },
      onDownloadStartRequest: onDownloadStartRequest,
    );
  }

  /// The bridge script guards itself, so running it on every load and title
  /// change adds no second listener.
  Future<void> _injectReaderScript(InAppWebViewController controller) async {
    String? script = _readerScript;
    if (script != null) {
      await controller.evaluateJavascript(source: script);
    }
  }

  /// Once a book is on screen: hide the loading screen, flash the memo's
  /// quoted line, and offer the way back.
  Future<void> _onPageLoaded(
      InAppWebViewController controller, Uri? uri) async {
    if (!_isBookPage(uri)) {
      if (!(uri?.path.endsWith('jump.html') ?? false)) {
        _maskVisible.value = false;
      }
      return;
    }

    for (int i = 0; i < 30; i++) {
      Object? ready = await controller.evaluateJavascript(
        source: "(function(){var c=document.querySelector('.book-content'); "
            'return !!(c && c.textContent && c.textContent.length > 0);})()',
      );
      if (ready == true || !mounted) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) {
      return;
    }
    await Future.delayed(const Duration(milliseconds: 250));
    _maskVisible.value = false;

    TtuLaunch? launch = _launch;
    if (_keepPlace) {
      await _restorePlace();
    }
    await _sendMemos();
    String? excerpt = launch?.excerpt;
    if (_flashPending && excerpt != null) {
      _flashPending = false;
      controller.evaluateJavascript(
        source: 'window.__jdj && window.__jdj.flash(${jsonEncode(excerpt)});',
      );
    }
    TtuPosition? back = launch?.returnTo;
    if (_chipPending && back != null) {
      _chipPending = false;
      _showBackChip(back);
    }
  }

  /// ッツ's own exit arrow opens its library page inside the book's WebView.
  /// When the page was opened for a book, go back to the app's shelf instead.
  void _onNavigated(WebUri? url) {
    String path = url?.path ?? '';
    bool toLibrary = path.endsWith('/manage') || path.endsWith('/manage.html');
    if (toLibrary && _openedForBook && !_leaving && mounted) {
      onWillPop().then((leave) {
        if (leave && mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  String _suggestedFilename = '';
  String _mimeType = '';

  void onDownloadStartRequest(
      InAppWebViewController controller, DownloadStartRequest request) async {
    _mimeType = request.mimeType ?? _mimeType;

    _suggestedFilename = request.suggestedFilename ?? _suggestedFilename;

    await controller.evaluateJavascript(
        source: downloadFileJs.replaceAll(
            'blobUrlPlaceholder', request.url.toString()));
  }

  /// Highlights [length] characters from [start] of the tapped paragraph.
  /// The highlight is drawn by the page, not a text selection, so Android's
  /// selection toolbar never appears for it.
  Future<void> _highlight({
    required int start,
    required int length,
    required bool wordMode,
  }) async {
    await _controller?.evaluateJavascript(
      source:
          'window.__jdj && window.__jdj.highlight($start, $length, $wordMode);',
    );
  }

  /// Handles a tap in the book. An index of -1 means the tap was not on a
  /// character, which closes the popup.
  void onLookup(Map<String, dynamic> message) async {
    if (!_ready || !mounted) {
      return;
    }
    _menuVisible.value = false;

    FocusScope.of(context).unfocus();
    _focusNode.requestFocus();

    int index = (message['index'] as num?)?.toInt() ?? -1;
    String text = (message['text'] as String?) ?? '';
    int x = (message['x'] as num?)?.toInt() ?? 0;
    int y = (message['y'] as num?)?.toInt() ?? 0;

    if (text.isEmpty || index < 0) {
      clearDictionaryResult();
      mediaSource.clearCurrentSentence();
      return;
    }

    int serial = ++_lookupSerial;

    late JidoujishoPopupPosition position;
    Size size = MediaQuery.of(context).size;
    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      position = y < size.height / 2
          ? JidoujishoPopupPosition.bottomHalf
          : JidoujishoPopupPosition.topHalf;
    } else {
      position = x < size.width / 2
          ? JidoujishoPopupPosition.rightHalf
          : JidoujishoPopupPosition.leftHalf;
    }

    text = text.replaceAll('\\n', '\n');

    try {
      /// If we cut off at a lone surrogate, offset the index back by 1. The
      /// selection meant to select the index before
      RegExp loneSurrogate = RegExp(
        '[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?:[^\uD800-\uDBFF]|^)[\uDC00-\uDFFF]',
      );
      if (index != 0 && text.substring(index).startsWith(loneSurrogate)) {
        index = index - 1;
      }

      bool isSpaceDelimited = appModel.targetLanguage.isSpaceDelimited;

      String searchTerm = appModel.targetLanguage.getSearchTermFromIndex(
        text: text,
        index: index,
      );
      int whitespaceOffset = searchTerm.length - searchTerm.trimLeft().length;

      int offsetIndex =
          appModel.targetLanguage.getStartingIndex(text: text, index: index) +
              whitespaceOffset;

      int length = appModel.targetLanguage.getGuessHighlightLength(
        searchTerm: searchTerm,
      );

      /// Start the search first; the highlight follows alongside it.
      Future<void> search = searchDictionaryResult(
        searchTerm: searchTerm,
        position: position,
      );
      if (mediaSource.highlightOnTap) {
        unawaited(_highlight(
          start: offsetIndex,
          length: length,
          wordMode: isSpaceDelimited,
        ));
      }
      await search;

      /// Another tap, or a close, happened while searching.
      if (serial != _lookupSerial || !mounted) {
        return;
      }

      length = appModel.targetLanguage.getFinalHighlightLength(
        result: currentResult,
        searchTerm: searchTerm,
      );

      if (mediaSource.highlightOnTap) {
        if (dictionaryPopupShown) {
          await _highlight(
            start: offsetIndex,
            length: length,
            wordMode: isSpaceDelimited,
          );
        } else {
          unselectWebViewTextSelection();
        }
      }

      JidoujishoTextSelection selection =
          appModel.targetLanguage.getSentenceFromParagraph(
        paragraph: text,
        index: index,
        startOffset: offsetIndex,
        endOffset: offsetIndex + length,
      );

      mediaSource.setCurrentSentence(
        selection: selection,
      );
    } catch (e) {
      clearDictionaryResult();
    }
  }

  Future<void> unselectWebViewTextSelection() async {
    await _controller?.evaluateJavascript(
      source: 'window.__jdj ? window.__jdj.clearSelection() : '
          'window.getSelection().removeAllRanges();',
    );
  }

  /// Get the default context menu for sources that make use of embedded web
  /// views.
  ContextMenu get contextMenu => ContextMenu(
        settings: ContextMenuSettings(
          hideDefaultSystemContextMenuItems: true,
        ),
        menuItems: [
          copyMenuItem(),
          searchMenuItem(),
          memoMenuItem(),
          addWordMenuItem(),
        ],
      );

  ContextMenuItem searchMenuItem() {
    return ContextMenuItem(
      id: 1,
      title: t.search,
      action: searchMenuAction,
    );
  }

  /// Looks the selected text up as one phrase, which a tap cannot do. The
  /// popup opens on the other half of the screen from the selection.
  void searchMenuAction() async {
    String phrase = await getSelectedText();
    if (phrase.isEmpty || !mounted) {
      return;
    }
    Object? middle = await _controller?.evaluateJavascript(
      source: '(function () { var s = getSelection();'
          ' if (!s.rangeCount) { return null; }'
          ' var r = s.getRangeAt(0).getBoundingClientRect();'
          ' return [r.left + r.width / 2, r.top + r.height / 2,'
          ' innerWidth, innerHeight]; })()',
    );
    if (!mounted) {
      return;
    }
    JidoujishoPopupPosition position = JidoujishoPopupPosition.bottomHalf;
    if (middle is List && middle.length == 4) {
      List<double> values =
          middle.map((value) => (value as num).toDouble()).toList();
      bool portrait =
          MediaQuery.of(context).orientation == Orientation.portrait;
      position = portrait
          ? (values[1] < values[3] / 2
              ? JidoujishoPopupPosition.bottomHalf
              : JidoujishoPopupPosition.topHalf)
          : (values[0] < values[2] / 2
              ? JidoujishoPopupPosition.rightHalf
              : JidoujishoPopupPosition.leftHalf);
    }
    _lookupSerial++;
    await searchDictionaryResult(searchTerm: phrase, position: position);
  }

  ContextMenuItem copyMenuItem() {
    return ContextMenuItem(
      id: 3,
      title: t.copy,
      action: copyMenuAction,
    );
  }

  ContextMenuItem memoMenuItem() {
    return ContextMenuItem(
      id: 6,
      title: t.ttu_memo,
      action: memoMenuAction,
    );
  }

  ContextMenuItem addWordMenuItem() {
    return ContextMenuItem(
      id: 7,
      title: t.add_word,
      action: addWordMenuAction,
    );
  }

  /// Adds the selected text to My terms. Text written like "software as a
  /// service (SaaS)" is saved at once, as SaaS with that meaning; anything
  /// else opens the editor with the term filled in.
  void addWordMenuAction() async {
    String selected = (await getSelectedText()).replaceAll(RegExp(r'\s+'), ' ');
    if (selected.isEmpty) {
      return;
    }
    TermOrigin? origin = await _termOrigin(selected);
    await unselectWebViewTextSelection();
    if (!mounted) {
      return;
    }

    ({String term, String meaning})? split = MyWords.split(selected);
    if (split != null) {
      int entryId = appModel.saveMyWord(
        term: split.term,
        meaning: split.meaning,
        origin: origin,
      );
      _showSavedTerm(split.term, entryId);
      return;
    }

    _isRecursiveSearching = true;
    await showMyWordEditor(
      context: context,
      appModel: appModel,
      term: selected,
      origin: origin,
    );
    _isRecursiveSearching = false;
    await appModel.applyMediaSystemUi();
    _focusNode.requestFocus();
  }

  /// Confirms a term saved in one tap, with a way to edit it.
  void _showSavedTerm(String term, int entryId) {
    ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(t.my_terms_saved_term(term: term)),
        action: SnackBarAction(
          label: t.my_terms_edit,
          onPressed: () async {
            MyWord? saved = appModel.myWords
                .firstWhereOrNull((word) => word.entryId == entryId);
            if (saved == null || !mounted) {
              return;
            }
            _isRecursiveSearching = true;
            await showMyWordEditor(
              context: context,
              appModel: appModel,
              existing: saved,
            );
            _isRecursiveSearching = false;
            await appModel.applyMediaSystemUi();
            _focusNode.requestFocus();
          },
        ),
      ),
    );
  }

  /// The book on screen, as far as the page knows it.
  Future<TtuBook?> _currentBook() async {
    TtuLaunch? launch = _launch;
    if (launch != null) {
      return launch.book;
    }
    Uri? uri = await _controller?.getUrl();
    int? id = int.tryParse(uri?.queryParameters['id'] ?? '');
    if (id == null) {
      return null;
    }
    return TtuBook(
      language: _language,
      port: mediaSource.getPortForLanguage(_language),
      id: id,
      title: widget.item?.title ?? '',
      characters: 0,
      lastBookOpen: 0,
      lastBookModified: 0,
      exploredCharCount: 0,
      progress: 0,
      coverPath: null,
    );
  }

  /// Saves a memo at the selected text, with ッツ's position of the page.
  void memoMenuAction() async {
    String excerpt = await getSelectedText();
    TtuBook? book = await _currentBook();
    if (excerpt.isEmpty || book == null) {
      return;
    }

    TtuPosition? position = await _capturePosition();
    await unselectWebViewTextSelection();
    if (!mounted) {
      return;
    }
    if (position == null) {
      return;
    }

    _isRecursiveSearching = true;
    String? text = await showTtuMemoEditor(
      context: context,
      book: book,
      excerpt: excerpt,
      progress: position.progress,
      characters: position.characters,
    );
    _isRecursiveSearching = false;
    await appModel.applyMediaSystemUi();
    _focusNode.requestFocus();

    if (text == null) {
      return;
    }

    await appModel.putReaderMemo(
      ReaderMemo(
        bookKey: book.key,
        bookTitle: book.title,
        exploredCharCount: position.characters,
        progress: position.progress,
        memo: text,
        excerpt: excerpt,
        createdAt: DateTime.now(),
      ),
    );
    Fluttertoast.showToast(
      msg: t.ttu_memo_saved(position: ttuPercent(position.progress)),
    );
  }

  void copyMenuAction() async {
    String searchTerm = await getSelectedText();
    Clipboard.setData(ClipboardData(text: searchTerm));
    await unselectWebViewTextSelection();
  }

  Future<String> getSelectedText() async {
    return (await _controller?.getSelectedText() ?? '')
        .replaceAll('\\n', '\n')
        .trim();
  }

  String downloadFileJs = '''
var xhr = new XMLHttpRequest();
var blobUrl = "blobUrlPlaceholder";
console.log(blobUrl);
xhr.open('GET', blobUrl, true);
xhr.responseType = 'blob';
xhr.onload = function(e) {
  if (this.status == 200) {
    var blob = this.response;
    var reader = new FileReader();
    reader.readAsDataURL(blob);
    reader.onloadend = function() {
      var base64data = reader.result;
      var base64ContentArray = base64data.split(",")     ;
      var mimeType = base64ContentArray[0].match(/[^:\\s*]\\w+\\/[\\w-+\\d.]+(?=[;| ])/)[0];
      var decodedFile = base64ContentArray[1];
      console.log(mimeType);
      window.flutter_inappwebview.callHandler('blobToBase64Handler', decodedFile, mimeType);
    };
  };
};
xhr.send();
''';

  String get leftArrowSimulateJs => '''
    var evt = document.createEvent('MouseEvents');
    evt.initEvent('wheel', true, true);
    evt.deltaY = +0.001 * ${mediaSource.volumePageTurningSpeed * (mediaSource.volumePageTurningInverted ? -1 : 1)};
    document.body.dispatchEvent(evt);
    ''';

  String get rightArrowSimulateJs => '''
    var evt = document.createEvent('MouseEvents');
    evt.initEvent('wheel', true, true);
    evt.deltaY = -0.001 * ${mediaSource.volumePageTurningSpeed * (mediaSource.volumePageTurningInverted ? -1 : 1)};
    document.body.dispatchEvent(evt);
    ''';
}
