import 'package:change_notifier_builder/change_notifier_builder.dart';
import 'package:flutter/material.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/models.dart';
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

  /// The tabs, with their names in the app's current language.
  List<BottomNavigationBarItem> get navBarItems => [
        for (MediaType mediaType in appModel.mediaTypes.values)
          BottomNavigationBarItem(
            activeIcon: Icon(mediaType.icon),
            icon: Icon(mediaType.outlinedIcon),
            label: t[mediaType.uniqueKey],
          ),
      ];

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      appModel.populateDefaultMapping(appModel.targetLanguage);
      appModel.moveStashButtonToMyWords();
      appModel.populateBookmarks();
      if (appModel.isFirstTimeSetup) {
        await appModel.showLanguageMenu();
        appModel.setLastSelectedDictionaryFormat(
            appModel.targetLanguage.standardFormat);

        appModel.setFirstTimeSetupFlag();
      }
      AutoBackup.scheduleIfDue(appModelNoUpdate, ref);
      appModelNoUpdate.refreshAppStrings();
      appModelNoUpdate.updates.check();

      /// The first lookup, in a book or the Dictionary tab, need not wait
      /// for the search worker to start and open the database.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          appModelNoUpdate.warmUpDictionarySearch();
        }
      });
    });
  }

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
    if (AppLifecycleState.resumed == state) {
      AutoBackup.scheduleIfDue(appModelNoUpdate, ref);

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
      buildAutoBackupIndicator(),
      buildCreatorButton(),
      TabSettingsButton(
        mediaType: appModel.mediaTypes.values.toList()[currentHomeTabIndex],
      ),
      buildShowMenuButton(),
    ];
  }

  /// A small spinner while the backup file is being updated, which opens
  /// the backup page.
  Widget buildAutoBackupIndicator() {
    return ValueListenableBuilder<bool>(
      valueListenable: AutoBackup.running,
      builder: (context, running, _) => running
          ? IconButton(
              tooltip: t.auto_backup_running,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupPage()),
              ),
              icon: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
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
      icon: ValueListenableBuilder<List<AppRelease>>(
        valueListenable: appModel.updates.newer,
        builder: (context, newer, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Ui.more_vert,
              color: theme.iconTheme.color,
              size: 24,
            ),
            if (newer.isNotEmpty)
              Positioned(top: 0, right: 1, child: buildUpdateDot()),
          ],
        ),
      ),
      color: Theme.of(context).popupMenuTheme.color,
      onSelected: (value) => value(),
      itemBuilder: (context) => getMenuItems(),
    );
  }

  /// Marks the menu and its Update item while a newer build is out.
  Widget buildUpdateDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        shape: BoxShape.circle,
      ),
    );
  }

  PopupMenuItem<VoidCallback> buildPopupItem({
    required String label,
    required Function() action,
    IconData? icon,
    Color? color,
    bool dot = false,
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
          if (dot) ...[
            const SizedBox(width: 8),
            buildUpdateDot(),
          ],
        ],
      ),
    );
  }

  /// The Update item, with a dot while a newer build is out. It leads the
  /// menu then, and sits above Attribution otherwise.
  PopupMenuItem<VoidCallback> buildUpdateItem() {
    return buildPopupItem(
      label: t.update_menu,
      icon: Ui.update,
      dot: appModel.updates.newer.value.isNotEmpty,
      action: () => showTtuSheet<void>(
        context: context,
        builder: (_) => const AppUpdateSheet(),
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

  /// The menu, most used first. User enhancements live in the card creator,
  /// and the original project's repository is no link of this app's.
  List<PopupMenuItem<VoidCallback>> getMenuItems() {
    bool updates = appModel.updates.enabled;
    bool updateOut = appModel.updates.newer.value.isNotEmpty;
    return [
      if (updates && updateOut) buildUpdateItem(),
      buildPopupItem(
        label: t.options_dictionaries,
        icon: Ui.auto_stories_rounded,
        action: appModel.showDictionaryMenu,
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
        label: t.theme_menu,
        icon: Ui.palette,
        action: () => showModalBottomSheet(
          context: context,
          builder: (_) => const AppThemeSheet(),
        ),
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
      if (updates && !updateOut) buildUpdateItem(),
      buildPopupItem(
        label: t.options_attribution,
        icon: Ui.info,
        action: navigateToLicensePage,
      ),
    ];
  }
}
