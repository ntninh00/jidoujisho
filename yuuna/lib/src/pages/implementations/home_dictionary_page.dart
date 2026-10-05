import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// The body content for the Dictionary tab in the main menu.
class HomeDictionaryPage extends BaseTabPage {
  /// Create an instance of this page.
  const HomeDictionaryPage({super.key});

  @override
  BaseTabPageState<BaseTabPage> createState() => _HomeDictionaryPageState();
}

class _HomeDictionaryPageState<T extends BaseTabPage> extends BaseTabPageState {
  @override
  MediaType get mediaType => DictionaryMediaType.instance;

  DictionarySearchResult? _result;

  bool _isSearching = false;
  bool _lastOpenedState = false;

  @override
  void initState() {
    super.initState();
    appModelNoUpdate.dictionarySearchAgainNotifier.addListener(searchAgain);
    appModelNoUpdate.dictionaryEntriesNotifier.addListener(() {
      if (mediaType.floatingSearchBarController.isClosed) {
        if (!appModel.isMediaOpen &&
            DictionaryMediaType.instance ==
                appModel.mediaTypes.values
                    .toList()[appModel.currentHomeTabIndex]) {
          if (mounted) {
            setState(() {});
          }
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool get shouldPlaceholderBeShown => appModel.dictionaryHistory.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      if (shouldPlaceholderBeShown)
        buildPlaceholder()
      else
        buildDictionaryHistory(),
      buildFloatingSearchBar(),
    ]);
  }

  /// This is shown as the body when [shouldPlaceholderBeShown] is true.
  Widget buildPlaceholder() {
    return Center(
      child: JidoujishoPlaceholderMessage(
        icon: mediaType.outlinedIcon,
        message: t.info_empty_home_tab,
      ),
    );
  }

  Widget buildDictionaryHistory() {
    return RawScrollbar(
      thumbVisibility: true,
      thickness: 3,
      controller: DictionaryMediaType.instance.scrollController,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Spacing.of(context).spaces.normal,
        ),
        child: DictionaryHistoryPage(
          onSearch: onSearch,
          onStash: onStash,
          onShare: onShare,
        ),
      ),
    );
  }

  /// The search bar to show at the topmost of the tab body. When selected,
  /// [buildSearchBarBody] will take the place of the remainder tab body, or
  /// the elements below the search bar when unselected.
  @override
  Widget buildFloatingSearchBar() {
    return FloatingSearchBar(
      isScrollControlled: true,
      hint: t.search_ellipsis,
      controller: mediaType.floatingSearchBarController,
      builder: buildFloatingSearchBody,
      borderRadius: BorderRadius.circular(24),
      elevation: 0,
      backgroundColor: appModel.isDarkMode
          ? const Color.fromARGB(255, 30, 30, 30)
          : const Color.fromARGB(255, 229, 229, 229),
      backdropColor: appModel.isDarkMode ? Colors.black : Colors.white,
      accentColor: theme.colorScheme.primary,
      scrollPadding: const EdgeInsets.only(top: 6, bottom: 56),
      transitionDuration: Duration.zero,
      margins: const EdgeInsets.symmetric(horizontal: 6),
      width: double.maxFinite,
      transition: SlideFadeFloatingSearchBarTransition(),
      automaticallyImplyBackButton: false,
      progress: _isSearching,
      onFocusChanged: (focused) => onFocusChanged(focused: focused),
      onQueryChanged: onQueryChanged,
      onSubmitted: search,
      debounceDelay: Duration(milliseconds: appModel.searchDebounceDelay),
      leadingActions: [
        buildDictionaryButton(),
        buildBackButton(),
      ],
      actions: [
        buildDictionarySettingsButton(),
        buildMoreButton(),
        buildSearchButton(),
      ],
    );
  }

  @override
  void onFocusChanged({required bool focused}) async {
    if (mediaType.floatingSearchBarController.isOpen != _lastOpenedState) {
      _lastOpenedState = mediaType.floatingSearchBarController.isOpen;
      if (!_lastOpenedState) {
        setState(() {});
      }
    }
  }

  void searchAgain() {
    _result = null;
    lastQuery = '';
    search(mediaType.floatingSearchBarController.query);
  }

  Duration get historyDelay => const Duration(milliseconds: 500);

  void onQueryChanged(String query) async {
    if (!appModel.autoSearchEnabled) {
      return;
    }

    if (mounted) {
      search(query);
    }
  }

  bool _showMore = false;
  String lastQuery = '';

  /// Counts searches so a slow, older search never replaces a newer one.
  int _searchSerial = 0;

  void search(
    String query, {
    int? overrideMaximumTerms,
  }) async {
    if (lastQuery == query && overrideMaximumTerms == null) {
      return;
    } else {
      lastQuery = query;
    }

    int maximumTerms = overrideMaximumTerms ?? appModel.maximumTerms;
    int serial = ++_searchSerial;

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    DictionarySearchResult? result;
    try {
      result = await appModel.searchDictionary(
        searchTerm: query,
        searchWithWildcards: true,
        overrideMaximumTerms: maximumTerms,
        channel: 'dictionary_tab',
      );
    } catch (error) {
      debugPrint('Dictionary search failed: $error');
    }

    /// The query changed while this search ran.
    if (serial != _searchSerial || !mounted) {
      return;
    }

    setState(() {
      _isSearching = false;
      if (result != null) {
        _result = result;
        _showMore = result.headingIds.length < maximumTerms;
      }
    });

    DictionarySearchResult? found = result;
    if (found == null) {
      return;
    }
    Future.delayed(historyDelay, () async {
      if (serial == _searchSerial &&
          query == mediaType.floatingSearchBarController.query) {
        appModel.addToSearchHistory(
          historyKey: mediaType.uniqueKey,
          searchTerm: mediaType.floatingSearchBarController.query,
        );
        if (found.headingIds.isNotEmpty) {
          appModel.addToDictionaryHistory(result: found);
        }
      }
    });
  }

  Widget buildDictionaryButton() {
    return FloatingSearchBarAction(
      child: JidoujishoIconButton(
        size: textTheme.titleLarge?.fontSize,
        tooltip: t.dictionaries,
        icon: Icons.auto_stories,
        onTap: appModel.showDictionaryMenu,
      ),
    );
  }

  /// Clearing history is rare and destructive, so both clear actions live in
  /// one labelled menu instead of two unlabelled icons on the bar.
  Widget buildMoreButton() {
    return FloatingSearchBarAction(
      showIfOpened: true,
      child: PopupMenuButton<VoidCallback>(
        tooltip: t.show_menu,
        icon: Icon(
          Icons.more_vert,
          size: textTheme.titleLarge?.fontSize,
        ),
        onSelected: (action) => action(),
        itemBuilder: (context) => [
          PopupMenuItem<VoidCallback>(
            value: showDeleteSearchHistoryPrompt,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.manage_search),
              title: Text(t.clear_search_title),
            ),
          ),
          PopupMenuItem<VoidCallback>(
            value: showDeleteDictionaryHistoryPrompt,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_sweep),
              title: Text(t.clear_dictionary_title),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSearchButton() {
    return FloatingSearchBarAction(
      showIfOpened: true,
      builder: (context, animation) {
        final bar = FloatingSearchAppBar.of(context)!;

        return ValueListenableBuilder<String>(
          valueListenable: bar.queryNotifer,
          builder: (context, query, _) {
            final isEmpty = query.isEmpty;

            return SearchToClear(
              isEmpty: isEmpty,
              size: textTheme.titleLarge!.fontSize!,
              color: bar.style.iconColor,
              duration: const Duration(milliseconds: 900) * 0.5,
              onTap: () {
                if (!isEmpty) {
                  bar.clear();
                } else {
                  bar.isOpen =
                      !bar.isOpen || (!bar.hasFocus && bar.isAlwaysOpened);
                }

                setState(() {});
              },
              searchButtonSemanticLabel: t.search,
              clearButtonSemanticLabel: t.clear,
            );
          },
        );
      },
    );
  }

  Widget buildSearchClearButton() {
    return FloatingSearchBarAction(
      showIfOpened: true,
      showIfClosed: false,
      child: JidoujishoIconButton(
        size: textTheme.titleLarge?.fontSize,
        tooltip: t.clear_search_title,
        icon: Icons.manage_search,
        onTap: showDeleteSearchHistoryPrompt,
      ),
    );
  }

  /// Dictionary settings bar action.
  Widget buildDictionarySettingsButton() {
    return FloatingSearchBarAction(
      showIfOpened: true,
      child: JidoujishoIconButton(
        size: Theme.of(context).textTheme.titleLarge?.fontSize,
        tooltip: t.dictionary_settings,
        icon: Icons.settings,
        onTap: () async {
          double oldFontSize = appModel.dictionaryFontSize;

          await showDialog(
            context: context,
            builder: (context) => const DictionarySettingsDialogPage(),
          );

          if (appModel.dictionaryFontSize != oldFontSize) {
            appModel.refresh();
          }
        },
      ),
    );
  }

  void showDeleteSearchHistoryPrompt() async {
    Widget alertDialog = AlertDialog(
      title: Text(t.clear_search_title),
      content: Text(
        t.clear_search_description,
      ),
      actions: <Widget>[
        TextButton(
          child: Text(
            t.dialog_clear,
            style: TextStyle(
              color: theme.colorScheme.primary,
            ),
          ),
          onPressed: () async {
            appModel.clearSearchHistory(
                historyKey: DictionaryMediaType.instance.uniqueKey);
            mediaType.floatingSearchBarController.clear();

            setState(() {});
            Navigator.pop(context);
          },
        ),
        TextButton(
          child: Text(t.dialog_cancel),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );

    await showDialog(
      context: context,
      builder: (context) => alertDialog,
    );
  }

  void showDeleteDictionaryHistoryPrompt() async {
    Widget alertDialog = AlertDialog(
      title: Text(t.clear_dictionary_title),
      content: Text(
        t.clear_dictionary_description,
      ),
      actions: <Widget>[
        TextButton(
          child: Text(
            t.dialog_clear,
            style: TextStyle(
              color: theme.colorScheme.primary,
            ),
          ),
          onPressed: () async {
            Navigator.pop(context);
            await appModel.clearDictionaryHistory();

            setState(() {});
          },
        ),
        TextButton(
          child: Text(t.dialog_cancel),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );

    await showDialog(
      context: context,
      builder: (context) => alertDialog,
    );
  }

  Widget buildFloatingSearchBody(
    BuildContext context,
    Animation<double> transition,
  ) {
    if (appModel.dictionaries.isEmpty) {
      return buildImportDictionariesPlaceholderMessage();
    }
    if (mediaType.floatingSearchBarController.query.isEmpty) {
      if (appModel.getSearchHistory(historyKey: mediaType.uniqueKey).isEmpty) {
        return buildEnterSearchTermPlaceholderMessage();
      } else {
        return JidoujishoSearchHistory(
          uniqueKey: mediaType.uniqueKey,
          onSearchTermSelect: (searchTerm) {
            setState(() {
              mediaType.floatingSearchBarController.query = searchTerm;
              search(searchTerm);
              FocusManager.instance.primaryFocus?.unfocus();
            });
          },
          onUpdate: () {
            setState(() {});
          },
        );
      }
    }
    if (_isSearching) {
      if (_result != null && _result!.headingIds.isNotEmpty) {
        return buildSearchResult();
      } else {
        return const SizedBox.shrink();
      }
    }

    if (_result == null || _result!.headingIds.isEmpty) {
      return buildNoSearchResultsPlaceholderMessage();
    }

    return buildSearchResult();
  }

  Widget buildSearchResult() {
    return DictionaryResultPage(
      onSearch: onSearch,
      onStash: onStash,
      onShare: onShare,
      result: _result!,
      footerWidget: footerWidget,
    );
  }

  Widget? get footerWidget {
    if (_showMore) {
      return null;
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: Spacing.of(context).insets.all.small,
        child: Tooltip(
          message: t.show_more,
          child: InkWell(
            onTap: _isSearching
                ? null
                : () async {
                    search(
                      mediaType.floatingSearchBarController.query,
                      overrideMaximumTerms:
                          _result!.headingIds.length + appModel.maximumTerms,
                    );
                  },
            child: Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              width: double.maxFinite,
              child: Padding(
                padding: Spacing.of(context).insets.all.normal,
                child: Text(
                  t.show_more,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: (textTheme.labelMedium?.fontSize)! * 0.9,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildEnterSearchTermPlaceholderMessage() {
    return Center(
      child: JidoujishoPlaceholderMessage(
        icon: Icons.search,
        message: t.enter_search_term,
      ),
    );
  }

  Widget buildImportDictionariesPlaceholderMessage() {
    return Center(
      child: JidoujishoPlaceholderMessage(
        icon: mediaType.outlinedIcon,
        message: t.dictionaries_menu_empty,
      ),
    );
  }

  Widget buildNoSearchResultsPlaceholderMessage() {
    return Center(
      child: JidoujishoPlaceholderMessage(
        icon: Icons.search_off,
        message: t.no_search_results,
      ),
    );
  }
}
