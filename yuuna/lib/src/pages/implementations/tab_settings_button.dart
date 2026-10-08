import 'package:flutter/material.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// The gear at the top of the home page, for the tab on screen: the
/// Dictionary tab's menu, or the settings of the source a tab shows.
/// Hidden for a source without settings.
class TabSettingsButton extends BasePage {
  /// Create the gear for [mediaType]'s tab.
  const TabSettingsButton({required this.mediaType, super.key});

  /// The tab on screen.
  final MediaType mediaType;

  @override
  BasePageState<TabSettingsButton> createState() => _TabSettingsButtonState();
}

class _TabSettingsButtonState extends BasePageState<TabSettingsButton> {
  @override
  Widget build(BuildContext context) {
    /// Changing a tab's source changes what its gear does.
    return AnimatedBuilder(
      animation: widget.mediaType.tabRefreshNotifier,
      builder: (context, _) {
        if (widget.mediaType is DictionaryMediaType) {
          return buildDictionaryMenu();
        }
        MediaSource source = appModel.getCurrentSourceForMediaType(
          mediaType: widget.mediaType,
        );
        VoidCallback? open = source.settingsAction(
          context: context,
          ref: ref,
          appModel: appModelNoUpdate,
        );
        if (open == null) {
          return const SizedBox.shrink();
        }
        return JidoujishoIconButton(
          tooltip: t.settings,
          icon: Ui.settings_outlined,
          onTap: open,
        );
      },
    );
  }

  Widget buildDictionaryMenu() {
    return PopupMenuButton<VoidCallback>(
      splashRadius: 20,
      padding: EdgeInsets.zero,
      tooltip: t.settings,
      icon: Icon(
        Ui.settings_outlined,
        color: theme.iconTheme.color,
        size: 24,
      ),
      color: theme.popupMenuTheme.color,
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        buildItem(
          label: t.my_words,
          icon: Ui.myWords,
          action: () => showTtuSheet<void>(
            context: context,
            builder: (_) => const MyWordsSheet(),
          ),
        ),
        buildItem(
          label: t.dictionary_settings,
          icon: Ui.settings,
          action: openDictionarySettings,
        ),
        const PopupMenuDivider(),
        buildItem(
          label: t.clear_search_title,
          icon: Ui.manage_search,
          action: () => confirm(
            title: t.clear_search_title,
            description: t.clear_search_description,
            clear: () async {
              DictionaryMediaType dictionary = DictionaryMediaType.instance;
              appModel.clearSearchHistory(
                  historyKey: dictionary.uniqueKey);
              dictionary.floatingSearchBarController.clear();
              dictionary.refreshTab();
            },
          ),
        ),
        buildItem(
          label: t.clear_dictionary_title,
          icon: Ui.delete_sweep,
          action: () => confirm(
            title: t.clear_dictionary_title,
            description: t.clear_dictionary_description,
            clear: () async {
              await appModel.clearDictionaryHistory();
              DictionaryMediaType.instance.refreshTab();
            },
          ),
        ),
      ],
    );
  }

  /// A row of the menu, laid out as the home page's own menu.
  PopupMenuItem<VoidCallback> buildItem({
    required String label,
    required IconData icon,
    required VoidCallback action,
  }) {
    return PopupMenuItem<VoidCallback>(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: textTheme.bodyMedium?.fontSize),
          const Space.normal(),
          Text(label),
        ],
      ),
    );
  }

  Future<void> openDictionarySettings() async {
    double oldFontSize = appModel.dictionaryFontSize;
    await showDialog(
      context: context,
      builder: (context) => const DictionarySettingsDialogPage(),
    );
    if (appModel.dictionaryFontSize != oldFontSize) {
      appModel.refresh();
    }
  }

  Future<void> confirm({
    required String title,
    required String description,
    required Future<void> Function() clear,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            child: Text(
              t.dialog_clear,
              style: TextStyle(color: theme.colorScheme.primary),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await clear();
            },
          ),
          TextButton(
            child: Text(t.dialog_cancel),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
