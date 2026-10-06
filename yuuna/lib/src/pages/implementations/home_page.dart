import 'package:change_notifier_builder/change_notifier_builder.dart';
import 'package:flutter/material.dart';
import 'package:spaces/spaces.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Appears at startup as the portal from which a user may select media and
/// broadly select their activity of choice. The page characteristically has
/// an [AppBar] and a [BottomNavigationBar].
class HomePage extends BasePage {
  /// Construct an instance of the [HomePage].
  const HomePage({
    super.key,
  });

  @override
  BasePageState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends BasePageState<HomePage>
    with WidgetsBindingObserver {
  late final List<Widget> mediaTypeBodies;
  late final List<BottomNavigationBarItem> navBarItems;

  String get appName => appModel.packageInfo.appName;
  String get appVersion => appModel.packageInfo.version;

  int get currentHomeTabIndex => appModel.currentHomeTabIndex;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    appModelNoUpdate.databaseCloseNotifier.addListener(refresh);

    /// Populate and define the tabs and their respective content bodies based
    /// on the media types specified and ordered by [AppModel]. As [ref.watch]
    /// cannot be used here, [ref.read] is used instead, via [appModelNoUpdate].
    mediaTypeBodies = List.unmodifiable(
        appModelNoUpdate.mediaTypes.values.map((mediaType) => mediaType.home));
    navBarItems = List.unmodifiable(
      appModelNoUpdate.mediaTypes.values.map(
        (mediaType) => BottomNavigationBarItem(
          activeIcon: Icon(mediaType.icon),
          icon: Icon(mediaType.outlinedIcon),
          label: t[mediaType.uniqueKey],
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      appModel.populateDefaultMapping(appModel.targetLanguage);
      appModel.moveStashButtonToMyWords();
      appModel.populateBookmarks();
      if (appModel.isFirstTimeSetup) {
        await appModel.showLanguageMenu();
        appModel.setLastSelectedDictionaryFormat(
            appModel.targetLanguage.standardFormat);

        appModel.setFirstTimeSetupFlag();
      } else {
        _openQuickSearch();
      }
    });
  }

  /// When the app was left on the Dictionary tab, it opens ready to type,
  /// like a quick dictionary.
  void _openQuickSearch() {
    MediaType current =
        appModel.mediaTypes.values.toList()[currentHomeTabIndex];
    bool onTop = ModalRoute.of(context)?.isCurrent ?? false;
    if (current is DictionaryMediaType &&
        onTop &&
        !appModel.isMediaOpen &&
        current.floatingSearchBarController.isClosed) {
      current.floatingSearchBarController.open();
    }
  }

  /// When the app went to the background.
  DateTime? _pausedAt;

  void refresh() {
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appModelNoUpdate.databaseCloseNotifier.removeListener(refresh);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (AppLifecycleState.paused == state) {
      _pausedAt = DateTime.now();
    }
    if (AppLifecycleState.resumed == state) {
      DateTime? pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt) > const Duration(seconds: 30)) {
        _openQuickSearch();
      }

      /// Keep the search database ready.
      debugPrint('Lifecycle Resumed');
      appModel.searchDictionary(
        searchTerm: appModel.targetLanguage.helloWorld,
        searchWithWildcards: false,
        useCache: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!appModel.isDatabaseOpen) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: buildAppBar(),
        body: SafeArea(
          child: buildBody(),
        ),
        bottomNavigationBar: buildBottomNavigationBar(),
      ),
    );
  }

  /// Only the actions: the app's name and icon are not shown.
  PreferredSizeWidget? buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 48,
      actions: buildActions(),
    );
  }

  Widget buildBody() {
    return IndexedStack(
      index: currentHomeTabIndex,
      children: mediaTypeBodies,
    );
  }

  Widget? buildBottomNavigationBar() {
    return BottomNavigationBar(
      onTap: switchTab,
      currentIndex: currentHomeTabIndex,
      items: navBarItems,
      selectedFontSize: textTheme.labelSmall!.fontSize!,
      unselectedFontSize: textTheme.labelSmall!.fontSize!,
    );
  }

  void switchTab(int index) async {
    MediaType mediaType = appModelNoUpdate.mediaTypes.values.toList()[index];
    if (index == currentHomeTabIndex) {
      mediaType.floatingSearchBarController.close();

      if (mediaType.scrollController.hasClients) {
        if (mediaType.scrollController.offset > 5000) {
          mediaType.scrollController.jumpTo(0);
        } else {
          mediaType.scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      }
    } else {
      await appModel.setCurrentHomeTabIndex(index);
      setState(() {});

      if (mediaType is DictionaryMediaType && appModel.shouldRefreshTabs) {
        appModel.shouldRefreshTabs = false;
        mediaType.refreshTab();
      }
    }
  }

  Widget? buildLeading() {
    return ChangeNotifierBuilder(
      notifier: appModel.incognitoNotifier,
      builder: (context, notifier, _) {
        return Padding(
          padding: Spacing.of(context).insets.onlyLeft.normal,
          child: Image.asset('assets/meta/icon.png'),
        );
      },
    );
  }

  Widget buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appName,
          style: textTheme.titleLarge,
        ),
        const Space.extraSmall(),
        Text(
          appVersion,
          style: textTheme.labelSmall!.copyWith(
            letterSpacing: 0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  List<Widget> buildActions() {
    return [
      buildCreatorButton(),
      buildShowMenuButton(),
    ];
  }

  Widget buildResumeButton() {
    return JidoujishoIconButton(
      tooltip: t.resume_last_media,
      icon: Ui.update,
      enabled: false,
      onTap: resumeAction,
    );
  }

  Widget buildCreatorButton() {
    return JidoujishoIconButton(
      tooltip: t.card_creator,
      icon: Ui.note_add_outlined,
      onTap: () => appModel.openCreator(
        ref: ref,
        killOnPop: false,
      ),
    );
  }

  Widget buildShowMenuButton() {
    return PopupMenuButton<VoidCallback>(
      splashRadius: 20,
      padding: EdgeInsets.zero,
      tooltip: t.show_menu,
      icon: Icon(
        Ui.more_vert,
        color: theme.iconTheme.color,
        size: 24,
      ),
      color: Theme.of(context).popupMenuTheme.color,
      onSelected: (value) => value(),
      itemBuilder: (context) => getMenuItems(),
    );
  }

  PopupMenuItem<VoidCallback> buildPopupItem({
    required String label,
    required Function() action,
    IconData? icon,
    Color? color,
  }) {
    return PopupMenuItem<VoidCallback>(
      value: action,
      child: Row(
        children: [
          if (icon != null)
            Icon(
              icon,
              size: textTheme.bodyMedium?.fontSize,
              color: color,
            ),
          if (icon != null) const Space.normal(),
          Text(
            label,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }

  void resumeAction() {}

  void openMenu(TapDownDetails details) async {
    RelativeRect position = RelativeRect.fromLTRB(
        details.globalPosition.dx, details.globalPosition.dy, 0, 0);
    Function()? selectedAction = await showMenu(
      context: context,
      position: position,
      items: getMenuItems(),
    );

    selectedAction?.call();

    if (selectedAction == null) {
      Future.delayed(const Duration(milliseconds: 50), () {
        FocusScope.of(context).unfocus();
      });
    }
  }

  void browseToGithub() async {
    launchUrl(
      Uri.parse('https://github.com/arianneorpilla/jidoujisho'),
      mode: LaunchMode.externalApplication,
    );
  }

  void navigateToLicensePage() async {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Theme(
          data: theme.copyWith(
            cardColor: theme.colorScheme.background,
          ),
          child: LicensePage(
            applicationName: appModel.packageInfo.appName,
            applicationVersion: appModel.packageInfo.version,
            applicationLegalese: t.legalese,
            applicationIcon: Padding(
              padding: Spacing.of(context).insets.all.normal,
              child: Image.asset(
                'assets/meta/icon.png',
                height: 128,
                width: 128,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<PopupMenuItem<VoidCallback>> getMenuItems() {
    return [
      buildPopupItem(
        label:
            appModel.isDarkMode ? t.options_theme_light : t.options_theme_dark,
        icon: appModel.isDarkMode ? Ui.light_mode : Ui.dark_mode,
        action: appModel.toggleDarkMode,
      ),
      // if ((appModel.androidDeviceInfo.version.sdkInt ?? 0) >= 33)
      //   buildPopupItem(
      //     label: optionsPipMode,
      //     icon: Ui.picture_in_picture,
      //     action: () {
      //       appModel.usePictureInPicture(ref: ref);
      //     },
      //   ),
      buildPopupItem(
        label: t.options_dictionaries,
        icon: Ui.auto_stories_rounded,
        action: appModel.showDictionaryMenu,
      ),
      buildPopupItem(
        label: t.options_enhancements,
        icon: Ui.auto_fix_high,
        action: appModel.openCreatorEnhancementsEditor,
      ),
      buildPopupItem(
        label: t.options_language,
        icon: Ui.translate,
        action: appModel.showLanguageMenu,
      ),
      buildPopupItem(
        label: t.options_profiles,
        icon: Ui.switch_account,
        action: appModel.showProfilesMenu,
      ),
      buildPopupItem(
        label: t.backup_menu,
        icon: Ui.storage,
        action: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BackupPage()),
        ),
      ),
      buildPopupItem(
        label: t.options_github,
        icon: Ui.code,
        action: browseToGithub,
      ),
      buildPopupItem(
        label: t.options_attribution,
        icon: Ui.info,
        action: navigateToLicensePage,
      ),
    ];
  }
}
