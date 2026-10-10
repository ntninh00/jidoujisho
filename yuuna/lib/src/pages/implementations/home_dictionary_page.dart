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

  /// Whether a search has run long enough to show the bar's progress line.
  /// Most take a few milliseconds, and a line flashing on every key is
  /// noise.
  bool _slowSearch = false;

  /// What was last put in the history, and when, so the start of a word
  /// recorded during a pause gives way to the whole word.
  ({String term, DateTime at, int? resultId})? _recorded;

  @override
  void initState() {
    super.initState();
    appModelNoUpdate.dictionarySearchAgainNotifier.addListener(searchAgain);
    appModelNoUpdate.myWordsVersion.addListener(_onMyWordsChanged);
    appModelNoUpdate.dictionaryEntriesNotifier.addListener(_onEntriesChanged);
  }

  /// Every listener goes with the tab, which is built again on some
  /// changes: one left behind would search for a tab that is gone.
  @override
  void dispose() {
    appModelNoUpdate.dictionarySearchAgainNotifier.removeListener(searchAgain);
    appModelNoUpdate.myWordsVersion.removeListener(_onMyWordsChanged);
    appModelNoUpdate.dictionaryEntriesNotifier
        .removeListener(_onEntriesChanged);
    super.dispose();
  }

  void _onEntriesChanged() {
    if (!mounted || !mediaType.floatingSearchBarController.isClosed) {
      return;
    }
    if (!appModel.isMediaOpen &&
        DictionaryMediaType.instance ==
            appModel.mediaTypes.values.toList()[appModel.currentHomeTabIndex]) {
      setState(() {});
    }
  }

  /// Shows a word just added to My words in the open results.
  void _onMyWordsChanged() {
    if (mediaType.floatingSearchBarController.query.isNotEmpty) {
      searchAgain();
    }
  }

  bool get shouldPlaceholderBeShown => appModel.dictionaryHistory.isEmpty;

  /// The tab opens blank, with only the search bar; earlier results show
  /// once something has been looked up.
  bool _searchedYet = false;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      if (!_searchedYet)
        const SizedBox.expand()
      else if (shouldPlaceholderBeShown)
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
  /// The languages picked in the dictionaries sheet, as `Japanese,
  /// Vietnamese`, in its order.
  String _modeNames() {
    Set<String> picked = appModel.dictionaryModeLanguages;
    return appModel.dictionaryLanguages
        .where(picked.contains)
        .map(catalogLanguageName)
        .join(', ');
  }

  @override
  Widget buildFloatingSearchBar() {
    return FloatingSearchBar(
      isScrollControlled: true,
      hint: appModel.searchByMeaning
          ? t.search_by_meaning_hint
          : appModel.dictionaryModeLanguages.isNotEmpty
              ? t.search_language_hint(language: _modeNames())
              : t.search_ellipsis,
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
      progress: _slowSearch,
      onFocusChanged: (focused) => onFocusChanged(focused: focused),
      onQueryChanged: onQueryChanged,
      onSubmitted: (query) => search(query, fresh: true),
      debounceDelay: Duration(milliseconds: appModel.searchDebounceDelay),
      leadingActions: [
        buildDictionaryButton(),
        buildBackButton(),
      ],
      actions: [
        buildMeaningToggle(),
        buildSearchButton(),
      ],
    );
  }

  @override
  void onFocusChanged({required bool focused}) async {
    if (focused) {
      appModel.warmUpDictionarySearch();
    }
    if (mediaType.floatingSearchBarController.isOpen != _lastOpenedState) {
      _lastOpenedState = mediaType.floatingSearchBarController.isOpen;
      if (!_lastOpenedState) {
        setState(() {});
      }
    }
  }

  void searchAgain() {
    _result = null;
    search(mediaType.floatingSearchBarController.query, fresh: true);
  }

  Duration get historyDelay => const Duration(milliseconds: 500);

  void onQueryChanged(String query) async {
    if (!appModel.autoSearchEnabled) {
      /// The search still runs, unseen, so pressing search shows it at once.
      appModel.prefetchDictionarySearch(query,
          byMeaning: appModel.searchByMeaning);
      return;
    }

    if (mounted) {
      search(query);
    }
  }

  bool _showMore = false;
  String lastQuery = '';

  /// The dictionaries' revision when [lastQuery] was searched.
  int _lastRevision = -1;

  /// Counts searches so a slow, older search never replaces a newer one.
  int _searchSerial = 0;

  /// Searches for [query], unless it was just searched and the
  /// dictionaries are as they were then. [fresh] searches anyway, as
  /// pressing search does.
  void search(
    String query, {
    int? overrideMaximumTerms,
    bool fresh = false,
  }) async {
    if (!fresh &&
        lastQuery == query &&
        _lastRevision == appModel.dictionariesRevision &&
        overrideMaximumTerms == null) {
      return;
    } else {
      lastQuery = query;
      _lastRevision = appModel.dictionariesRevision;
    }

    int maximumTerms = overrideMaximumTerms ?? appModel.maximumTerms;
    int serial = ++_searchSerial;
    if (query.trim().isNotEmpty) {
      _searchedYet = true;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && serial == _searchSerial && _isSearching) {
        setState(() => _slowSearch = true);
      }
    });

    DictionarySearchResult? result;
    try {
      /// Searches while typing are not stored; the one that makes it into
      /// the history is, when it does.
      result = await appModel.searchDictionary(
        searchTerm: query,
        searchWithWildcards: true,
        overrideMaximumTerms: maximumTerms,
        channel: 'dictionary_tab',
        byMeaning: appModel.searchByMeaning,
        persist: false,
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
      _slowSearch = false;
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
        await _record(query, found);
      }
    });
  }

  /// Puts [query] in the history. The start of a word recorded during a
  /// pause in typing gives way to the word, and a step back while
  /// deleting is not recorded at all.
  Future<void> _record(String query, DictionarySearchResult found) async {
    var last = _recorded;
    bool recent = last != null &&
        DateTime.now().difference(last.at) < const Duration(seconds: 30);
    if (recent && last.term.startsWith(query)) {
      return;
    }
    if (recent && query.startsWith(last.term)) {
      appModel.removeFromSearchHistory(
        historyKey: mediaType.uniqueKey,
        searchTerm: last.term,
      );
      if (last.resultId != null) {
        await appModel.removeFromDictionaryHistory(last.resultId!);
      }
    }
    appModel.addToSearchHistory(
      historyKey: mediaType.uniqueKey,
      searchTerm: query,
    );
    if (found.headingIds.isNotEmpty) {
      await appModel.addToDictionaryHistory(result: found);
    }
    _recorded = (term: query, at: DateTime.now(), resultId: found.id);
  }

  Widget buildDictionaryButton() {
    return FloatingSearchBarAction(
      child: JidoujishoIconButton(
        size: textTheme.titleLarge?.fontSize,
        tooltip: t.dictionaries,
        icon: Ui.auto_stories,
        onTap: appModel.showDictionaryMenu,
      ),
    );
  }

  /// Switches between finding words by how they are written and by what
  /// they mean.
  Widget buildMeaningToggle() {
    return FloatingSearchBarAction(
      showIfOpened: true,
      child: MeaningSearchToggle(
        on: appModel.searchByMeaning,
        onPressed: () async {
          await appModel.toggleSearchByMeaning();
          if (mounted) {
            setState(() {});
            searchAgain();
          }
        },
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

  Widget buildFloatingSearchBody(
    BuildContext context,
    Animation<double> transition,
  ) {
    Widget body = buildSearchBody();
    if (!appModel.searchByMeaning) {
      return body;
    }

    /// Words are found by meaning only once their entries have their words.
    return Stack(
      fit: StackFit.expand,
      children: [
        body,
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: ValueListenableBuilder<double?>(
            valueListenable: appModel.meaningIndexProgress,
            builder: (context, progress, _) {
              if (progress == null) {
                return const SizedBox.shrink();
              }

              /// Its own colours: the dark theme's surfaces are light.
              bool dark = appModel.isDarkMode;
              return Center(
                child: Material(
                  color: dark
                      ? const Color.fromARGB(255, 52, 52, 56)
                      : const Color.fromARGB(255, 232, 232, 236),
                  shape: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      t.meaning_index_progress(
                        percent: (progress * 100).floor(),
                      ),
                      style: textTheme.bodySmall!.copyWith(
                        color: dark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildSearchBody() {
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

    /// While a search runs, what the last one found stays: results, or that
    /// there were none, instead of blinking blank on every key.
    if (_isSearching && _result == null) {
      return const SizedBox.shrink();
    }

    if (_result == null ||
        _result!.headingIds.isEmpty ||
        !appModel.showsAnything(_result!)) {
      return buildNoSearchResultsPlaceholderMessage();
    }

    return buildSearchResult();
  }

  Widget buildSearchResult() {
    Widget page = DictionaryResultPage(
      onSearch: onSearch,
      onStash: onStash,
      onShare: onShare,
      result: _result!,
      footerWidget: footerWidget,
    );
    if (!appModel.searchByMeaning) {
      return page;
    }
    return MeaningHighlight(
      words: meaningWordsOfText(_result!.searchTerm),
      color: meaningHighlightColor(
        theme.colorScheme.primary,
        dark: appModel.isDarkMode,
      ),
      child: page,
    );
  }

  Widget? get footerWidget {
    if (_showMore) {
      return null;
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: Spacing.of(context).insets.all.small,
        child: Material(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
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
            child: SizedBox(
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
        icon: Ui.search,
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
        icon: Ui.search_off,
        message: t.no_search_results,
      ),
    );
  }
}
