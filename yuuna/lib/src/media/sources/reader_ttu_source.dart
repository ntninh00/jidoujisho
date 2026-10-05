import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:local_assets_server/local_assets_server.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/language.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// A global [Provider] for serving a local ッツ Ebook Reader.
final ttuServerProvider =
    FutureProvider.family<LocalAssetsServer, Language>((ref, language) {
  return ReaderTtuSource.instance.serveLocalAssets(language);
});

/// Every book in ッツ Ebook Reader across languages, most recently opened
/// first. Books are read from each language's copy of ッツ.
final ttuShelfProvider = FutureProvider<List<TtuBook>>((ref) async {
  AppModel appModel = ref.read(appProvider);
  ReaderTtuSource source = ReaderTtuSource.instance;
  source.shelfErrors.clear();

  List<List<TtuBook>> perLanguage = await Future.wait(
    source.shelfLanguages.map((language) async {
      try {
        await ref.watch(ttuServerProvider(language).future);
        return await TtuLibrary.listBooks(
          language: language,
          port: source.getPortForLanguage(language),
          coverDirectory: appModel.thumbnailsDirectory,
        );
      } catch (error, stack) {
        debugPrint('ッツ shelf for ${language.languageCode}: $error\n$stack');
        source.shelfErrors[language] = error;
        return <TtuBook>[];
      }
    }),
  );

  List<TtuBook> books = perLanguage.expand((books) => books).toList()
    ..sort((a, b) => b.lastBookOpen.compareTo(a.lastBookOpen));
  return books;
});

/// A media source that allows the user to read from ッツ Ebook Reader.
class ReaderTtuSource extends ReaderMediaSource {
  /// Define this media source.
  ReaderTtuSource._privateConstructor()
      : super(
          uniqueKey: 'reader_ttu',
          sourceName: 'ッツ Ebook Reader',
          description: 'Read EPUBs and mine sentences via an embedded web'
              ' reader.',
          icon: Ui.chrome_reader_mode_outlined,
          implementsSearch: false,
          implementsHistory: false,
        );

  /// Get the singleton instance of this media type.
  static ReaderTtuSource get instance => _instance;

  static final ReaderTtuSource _instance =
      ReaderTtuSource._privateConstructor();

  /// Default scrolling speed when in continuous page turning mode.
  static int get defaultScrollingSpeed => 100;

  /// Builds installed beside the main app use other ports, so both can run
  /// without fighting over the local server.
  int _portOffset = 0;

  @override
  Future<void> prepareResources() async {
    PackageInfo info = await PackageInfo.fromPlatform();
    if (info.packageName.endsWith('.dev')) {
      _portOffset = 100;
    }
  }

  /// Languages that have their own copy of ッツ, and so their own books.
  List<Language> get shelfLanguages => [
        JapaneseLanguage.instance,
        EnglishLanguage.instance,
      ];

  /// The language whose copy of ッツ serves [url], if any.
  Language? languageForUrl(String url) {
    int? port = Uri.tryParse(url)?.port;
    return shelfLanguages
        .firstWhereOrNull((language) => getPortForLanguage(language) == port);
  }

  /// Errors from the last read of the shelf, per language.
  final Map<Language, Object> shelfErrors = {};

  /// Positions to offer as a way back after jumping to a memo, per book.
  final Map<String, TtuPosition> returnPositions = {};

  /// Books being added, by name, while ッツ imports them.
  final ValueNotifier<List<String>> importing = ValueNotifier(const []);

  /// Books deleted this session. Hidden from the shelf straight away.
  final ValueNotifier<Set<String>> removedBooks = ValueNotifier(const {});

  final Map<String, Timer> _pendingDeletes = {};

  TtuLaunch? _pendingLaunch;

  /// Takes what the reader should do when it opens, if anything.
  TtuLaunch? takePendingLaunch() {
    TtuLaunch? launch = _pendingLaunch;
    _pendingLaunch = null;
    return launch;
  }

  @override
  Future<void> onSourceExit({
    required AppModel appModel,
    required WidgetRef ref,
  }) async {
    ref.invalidate(ttuShelfProvider);
  }

  /// Get the port for a language. Each language has its own copy of ッツ,
  /// with its own books and settings.
  int getPortForLanguage(Language language) {
    /// Language Customizable
    if (language is JapaneseLanguage) {
      return 52059 + _portOffset;
    } else if (language is EnglishLanguage) {
      return 52060 + _portOffset;
    }

    throw UnimplementedError();
  }

  /// Used to delay the serve if the server failed to launch last time. Makes
  /// retry look better for port conflicts.
  bool _lastServeFailed = false;

  /// For serving the reader assets locally.
  Future<LocalAssetsServer> serveLocalAssets(Language language) async {
    int port = getPortForLanguage(language);

    if (_lastServeFailed) {
      await Future.delayed(const Duration(seconds: 1));
    }

    try {
      _lastServeFailed = false;
      final server = LocalAssetsServer(
        address: InternetAddress.loopbackIPv4,
        port: port,
        assetsBasePath: 'assets/ttu-ebook-reader',
        logger: const DebugLogger(),
      );

      await server.serve();

      return server;
    } catch (e) {
      _lastServeFailed = true;
      rethrow;
    }
  }

  @override
  BaseSourcePage buildLaunchPage({
    MediaItem? item,
  }) {
    return ReaderTtuSourcePage(item: item);
  }

  @override
  Widget? buildBar() {
    return const TtuReaderBar();
  }

  @override
  BasePage buildHistoryPage({MediaItem? item}) {
    return const ReaderTtuSourceHistoryPage();
  }

  /// Opens [book]: at [memo] if given, or at [returnTo] to go back after a
  /// jump, or else where ッツ last saved.
  Future<void> openBook({
    required AppModel appModel,
    required WidgetRef ref,
    required TtuBook book,
    ReaderMemo? memo,
    TtuPosition? returnTo,
  }) async {
    TtuPosition? target;
    TtuPosition? back;

    if (memo != null) {
      target = TtuPosition(
        characters: memo.exploredCharCount,
        progress: memo.progress,
      );
      if ((book.exploredCharCount - memo.exploredCharCount).abs() > 200) {
        back = TtuPosition(
          characters: book.exploredCharCount,
          progress: book.progress,
        );
        returnPositions[book.key] = back;
      }
    } else if (returnTo != null) {
      target = returnTo;
      returnPositions.remove(book.key);
    }

    _pendingLaunch = TtuLaunch(
      book: book,
      target: target,
      excerpt: memo?.excerpt,
      memo: memo?.memo,
      returnTo: back,
    );

    await appModel.openMedia(
      ref: ref,
      mediaSource: this,
      item: book.toMediaItem(),
    );
  }

  /// Opens one of ッツ's own pages, such as `manage.html` for backup and sync.
  Future<void> openTtuPage({
    required AppModel appModel,
    required WidgetRef ref,
    required Language language,
    required String page,
  }) async {
    _pendingLaunch = null;
    int port = getPortForLanguage(language);
    await appModel.openMedia(
      ref: ref,
      mediaSource: this,
      item: MediaItem(
        mediaIdentifier: 'http://localhost:$port/$page',
        title: '',
        mediaTypeIdentifier: mediaType.uniqueKey,
        mediaSourceIdentifier: uniqueKey,
        position: 0,
        duration: 1,
        canDelete: false,
        canEdit: true,
      ),
    );
  }

  /// Shows the reader settings sheet.
  Future<void> showSettings({
    required BuildContext context,
    required AppModel appModel,
    required WidgetRef ref,
  }) {
    List<TtuBook> books = ref.read(ttuShelfProvider).valueOrNull ?? const [];
    List<Language> languages = shelfLanguages
        .where((language) => books.any((book) => book.language == language))
        .toList();
    if (languages.isEmpty) {
      languages = [
        if (shelfLanguages.contains(appModel.targetLanguage))
          appModel.targetLanguage
        else
          JapaneseLanguage.instance,
      ];
    }

    return showTtuSheet<void>(
      context: context,
      builder: (_) => TtuReaderSettingsSheet(
        languages: languages,
        onOpenTtuPage: (language, page) => openTtuPage(
          appModel: appModel,
          ref: ref,
          language: language,
          page: page,
        ),
      ),
    );
  }

  /// Lets the user pick EPUB or HTMLZ files and adds them.
  Future<void> pickAndImport({
    required BuildContext context,
    required AppModel appModel,
    required WidgetRef ref,
  }) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );
    if (result == null) {
      return;
    }

    List<File> files = [];
    for (PlatformFile picked in result.files) {
      String? filePath = picked.path;
      if (filePath == null) {
        continue;
      }
      String extension = path.extension(filePath).toLowerCase();
      if (extension == '.epub' || extension == '.htmlz') {
        files.add(File(filePath));
      } else {
        Fluttertoast.showToast(msg: t.ttu_unsupported_file(name: picked.name));
      }
    }

    if (files.isNotEmpty) {
      await importFiles(appModel: appModel, ref: ref, files: files);
    }
  }

  /// Adds books through ッツ's own importer, each into the copy of ッツ for its
  /// language.
  Future<void> importFiles({
    required AppModel appModel,
    required WidgetRef ref,
    required List<File> files,
  }) async {
    importing.value = [
      ...importing.value,
      ...files.map((file) => path.basenameWithoutExtension(file.path)),
    ];

    Language fallback = shelfLanguages.contains(appModel.targetLanguage)
        ? appModel.targetLanguage
        : JapaneseLanguage.instance;

    Map<Language, List<File>> byLanguage = {};
    for (File file in files) {
      String? code = await TtuLibrary.detectLanguageCode(file.path);
      Language language = shelfLanguages
              .firstWhereOrNull((language) => language.languageCode == code) ??
          fallback;
      byLanguage.putIfAbsent(language, () => []).add(file);
    }

    int added = 0;
    List<String> failures = [];
    for (MapEntry<Language, List<File>> entry in byLanguage.entries) {
      try {
        await ref.read(ttuServerProvider(entry.key).future);
        List<int> ids = await TtuLibrary.importFiles(
          port: getPortForLanguage(entry.key),
          files: entry.value,
        );
        added += ids.length;
      } catch (error) {
        failures.add('$error');
      }
    }

    importing.value = const [];
    ref.invalidate(ttuShelfProvider);

    if (failures.isNotEmpty) {
      Fluttertoast.showToast(
        msg: t.ttu_import_failed(reason: failures.first),
        toastLength: Toast.LENGTH_LONG,
      );
    } else if (added == 1 && files.length == 1) {
      Fluttertoast.showToast(
        msg: t.ttu_added_book(
          name: path.basenameWithoutExtension(files.first.path),
        ),
      );
    } else if (added > 0) {
      Fluttertoast.showToast(msg: t.ttu_added_books(n: added));
    }
  }

  /// Hides [book] now and deletes it after a few seconds unless
  /// [undoDelete] is called first. [onDeleted] runs once it is gone.
  void scheduleDelete({
    required AppModel appModel,
    required TtuBook book,
    required VoidCallback onDeleted,
  }) {
    removedBooks.value = {...removedBooks.value, book.key};
    _pendingDeletes[book.key]?.cancel();
    _pendingDeletes[book.key] = Timer(const Duration(seconds: 5), () async {
      _pendingDeletes.remove(book.key);
      try {
        await TtuLibrary.deleteBooks(port: book.port, ids: [book.id]);
        await appModel.deleteReaderMemosOfBook(book.key);
        await clearOverrideValues(appModel: appModel, item: book.toMediaItem());
        String? coverPath = book.coverPath;
        if (coverPath != null && File(coverPath).existsSync()) {
          File(coverPath).deleteSync();
        }
        returnPositions.remove(book.key);
      } catch (error) {
        debugPrint('Could not delete ${book.title}: $error');
        removedBooks.value = {...removedBooks.value}..remove(book.key);
      }
      onDeleted();
    });
  }

  /// Keeps a book that [scheduleDelete] was about to delete.
  void undoDelete(TtuBook book) {
    _pendingDeletes.remove(book.key)?.cancel();
    removedBooks.value = {...removedBooks.value}..remove(book.key);
  }

  /// Page settings for books in [language].
  TtuPagePreset presetFor(Language language) {
    String code = language.languageCode;
    bool vertical = language.preferVerticalReading;
    return TtuPagePreset(
      theme:
          getPreference<String?>(key: 'page_${code}_theme', defaultValue: null),
      fontSize: getPreference<int>(
        key: 'page_${code}_font_size',
        defaultValue: vertical ? 24 : 18,
      ),
      vertical: getPreference<bool>(
        key: 'page_${code}_vertical',
        defaultValue: vertical,
      ),
      paginated: getPreference<bool>(
        key: 'page_${code}_paginated',
        defaultValue: true,
      ),
      furigana: getPreference<bool>(
        key: 'page_${code}_furigana',
        defaultValue: true,
      ),
    );
  }

  /// Saves page settings for books in [language].
  Future<void> savePreset(Language language, TtuPagePreset preset) async {
    String code = language.languageCode;
    await setPreference<String?>(
        key: 'page_${code}_theme', value: preset.theme);
    await setPreference<int>(
        key: 'page_${code}_font_size', value: preset.fontSize);
    await setPreference<bool>(
        key: 'page_${code}_vertical', value: preset.vertical);
    await setPreference<bool>(
        key: 'page_${code}_paginated', value: preset.paginated);
    await setPreference<bool>(
        key: 'page_${code}_furigana', value: preset.furigana);
  }

  /// Script that applies the page settings for [language] before ッツ loads.
  /// Without a chosen theme, the page follows the app: dark or light.
  String settingsScriptFor(Language language, {required bool darkMode}) {
    TtuPagePreset preset = presetFor(language);
    preset.theme ??= darkMode ? 'dark' : 'light';
    return preset.toScript(autoBookmark: autoSavePosition);
  }

  /// The ッツ theme books in [language] open with.
  String effectiveThemeFor(Language language, {required bool darkMode}) {
    return presetFor(language).theme ?? (darkMode ? 'dark' : 'light');
  }

  /// Whether ッツ saves the reading position by itself while reading, and the
  /// app saves it on leaving a book.
  bool get autoSavePosition {
    return getPreference<bool>(key: 'auto_save_position', defaultValue: true);
  }

  /// Toggles saving the reading position automatically.
  void toggleAutoSavePosition() async {
    await setPreference<bool>(
      key: 'auto_save_position',
      value: !autoSavePosition,
    );
  }

  /// Whether or not using the volume buttons in the Reader should turn the
  /// page.
  bool get volumePageTurningEnabled {
    return getPreference<bool>(
        key: 'volume_page_turning_enabled', defaultValue: true);
  }

  /// Toggles the volume page turning option.
  void toggleVolumePageTurningEnabled() async {
    await setPreference<bool>(
      key: 'volume_page_turning_enabled',
      value: !volumePageTurningEnabled,
    );
  }

  /// Controls which direction is up or down for volume button page turning.
  bool get volumePageTurningInverted {
    return getPreference<bool>(
        key: 'volume_page_turning_inverted', defaultValue: false);
  }

  /// Inverts the current volume button page turning direction preference.
  void toggleVolumePageTurningInverted() async {
    await setPreference<bool>(
      key: 'volume_page_turning_inverted',
      value: !volumePageTurningInverted,
    );
  }

  /// Whether or not to add to extend the webpage beyond the navigation bar.
  /// This may be helpful for devices that don't have difficulty accessing the
  /// top bar (i.e. don't have a teardrop notch).
  bool get extendPageBeyondNavigationBar {
    return getPreference<bool>(
        key: 'extend_page_beyond_navbar', defaultValue: false);
  }

  /// Toggles the extend navbar option.
  void toggleExtendPageBeyondNavigationBar() async {
    await setPreference<bool>(
      key: 'extend_page_beyond_navbar',
      value: !extendPageBeyondNavigationBar,
    );
  }

  /// Whether or not the dictionary popup should adapt to the reader's theme.
  bool get adaptTtuTheme {
    return getPreference<bool>(key: 'adapt_ttu_theme', defaultValue: true);
  }

  /// Toggles whether dictionary popup should adapt to the reader's theme.
  void toggleAdaptTtuTheme() async {
    await setPreference<bool>(
      key: 'adapt_ttu_theme',
      value: !adaptTtuTheme,
    );
  }

  /// Controls the speed for volume button page turning.
  int get volumePageTurningSpeed {
    return getPreference<int>(
        key: 'volume_page_turning_speed', defaultValue: defaultScrollingSpeed);
  }

  /// Sets the speed for volume button page turning.
  void setVolumePageTurningSpeed(int speed) async {
    await setPreference<int>(
      key: 'volume_page_turning_speed',
      value: speed,
    );
  }

  /// Whether the reader will highlight words on tap.
  bool get highlightOnTap {
    return getPreference<bool>(
      key: 'highlight_on_tap',
      defaultValue: true,
    );
  }

  /// Toggles whether the reader will highlight words on tap.
  void toggleHighlightOnTap() async {
    await setPreference<bool>(
      key: 'highlight_on_tap',
      value: !highlightOnTap,
    );
  }

  /// This ensures that the internal version included with the app always uses
  /// the cache and is consistent. If this version changes and the current stored
  /// last version mismatches, a load from network is forced. The app will then
  /// update its new last version, and all new loads will be from the cache
  /// unless there is a new app version loaded with a different internal version.
  static const ttuInternalVersion = 3;

  /// Used to check for the current version.
  int? get currentTtuInternalVersion {
    return getPreference<int?>(key: 'ttu_internal_version', defaultValue: null);
  }

  /// Sets the new version.
  void setTtuInternalVersion() async {
    await setPreference<int?>(
      key: 'ttu_internal_version',
      value: ttuInternalVersion,
    );
  }
}
