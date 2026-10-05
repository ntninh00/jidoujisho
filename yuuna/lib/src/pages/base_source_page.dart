import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// A page template which assumes use of [BaseSourcePageState] by which all
/// pages in the app that are used for when using a certain source will
/// conveniently share base functionality.f
abstract class BaseSourcePage extends BasePage {
  /// Create an instance of this tab page.
  const BaseSourcePage({
    required this.item,
    super.key,
  });

  /// The media item pertaining to this usage instance of the source.
  final MediaItem? item;

  @override
  BaseSourcePageState<BaseSourcePage> createState();
}

/// A base class for providing all pages used for media in the app with a
/// collection of shared functions and variables. In large part, this was
/// implemented to define shortcuts for common lengthy methods across UI code.
class BaseSourcePageState<T extends BaseSourcePage> extends BasePageState<T> {
  @override
  void initState() {
    super.initState();
    appModelNoUpdate.myWordsVersion.addListener(_onMyWordsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _creatorActiveStreamSubscription = appModel.creatorActiveStream.listen(
        (creatorActive) {
          if (creatorActive) {
            onCreatorOpen();
          } else {
            onCreatorClose();
          }
        },
      );
    });
  }

  @override
  void dispose() {
    appModelNoUpdate.myWordsVersion.removeListener(_onMyWordsChanged);
    _creatorActiveStreamSubscription?.cancel();
    super.dispose();
  }

  /// Shows a word just added to My words in the open popup.
  void _onMyWordsChanged() {
    String? term = _lastSearchTerm;
    JidoujishoPopupPosition? position = _popupPositionNotifier.value;
    if (term != null && position != null && isDictionaryShown) {
      searchDictionaryResult(
        searchTerm: term,
        position: position,
        overrideMaximumTerms: appModel.maximumTerms,
      );
    }
  }

  /// Used for listening to when the Card Creator is opened and closed.
  StreamSubscription<bool>? _creatorActiveStreamSubscription;

  /// Allows customisation of dictionary background.
  double get dictionaryBackgroundOpacity => 0.98;

  /// Allows customisation of opacity of dictionary entries.
  double get dictionaryEntryOpacity => 1;

  /// The result from the last dictionary search performed with
  /// [searchDictionaryResult].
  final ValueNotifier<DictionarySearchResult?> _dictionaryResultNotifier =
      ValueNotifier<DictionarySearchResult?>(null);

  String? _lastSearchTerm;

  /// Counts lookups. A search whose number is no longer current was replaced
  /// by a newer lookup or a close, and its result is dropped.
  int _searchSerial = 0;

  /// Notifies the progress bar whether or not to refresh.
  final ValueNotifier<bool> _isSearchingNotifier = ValueNotifier<bool>(false);

  /// Whether or not there is a present dictionary result.
  bool get isDictionaryShown => _dictionaryResultNotifier.value != null;

  /// The popup position for the [buildDictionary] widget.
  final _popupPositionNotifier =
      ValueNotifier<JidoujishoPopupPosition?>(JidoujishoPopupPosition.topHalf);

  /// Standard warning dialog for leaving a source page. All sources should
  /// use this and wrap their [build] function with a [WillPopScope].
  Future<bool> onWillPop() async {
    Widget alertDialog = AlertDialog(
      title: Text(t.exit_media_title),
      content: Text(t.exit_media_description),
      actions: <Widget>[
        TextButton(
            child: Text(
              t.dialog_exit,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onPressed: () async {
              await onSourcePagePop();

              if (mounted) {
                Navigator.pop(context, true);
              }
              await appModel.closeMedia(
                ref: ref,
                mediaSource: appModel.currentMediaSource!,
                item: widget.item,
              );
            }),
        TextButton(
          child: Text(
            t.dialog_cancel,
          ),
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
    );

    return await showDialog(
          context: context,
          builder: (context) => alertDialog,
        ) ??
        false;
  }

  bool _showMore = false;

  /// Action to perform within the source page upon closing the media.
  Future<void> onSourcePagePop() async {}

  /// Perform a search with a given query and update the dictionary search
  /// result. The [position] parameter determines where the pop-up will
  /// be shown on the screen.
  Future<void> searchDictionaryResult({
    required String searchTerm,
    required JidoujishoPopupPosition position,
    int? overrideMaximumTerms,
  }) async {
    if (_lastSearchTerm == searchTerm && overrideMaximumTerms == null) {
      return;
    } else {
      _lastSearchTerm = searchTerm;
    }

    bool notShowMore = overrideMaximumTerms == null;

    overrideMaximumTerms ??= appModel.maximumTerms;

    int serial = ++_searchSerial;
    _popupPositionNotifier.value = position;

    try {
      _isSearchingNotifier.value = true;

      DictionarySearchResult dictionaryResult = await appModel.searchDictionary(
        searchTerm: searchTerm,
        searchWithWildcards: false,
        overrideMaximumTerms: overrideMaximumTerms,
        channel: 'popup',
      );

      /// A newer lookup, or a close, happened while this one ran.
      if (serial != _searchSerial) {
        return;
      }

      if (notShowMore && resultScrollController.hasClients) {
        resultScrollController
            .jumpTo(resultScrollController.initialScrollOffset);
      }

      _lastSearchTerm = searchTerm;

      appModel.addToDictionaryHistory(result: dictionaryResult);
      _showMore = dictionaryResult.headingIds.length < overrideMaximumTerms;
      _dictionaryResultNotifier.value = dictionaryResult;
    } finally {
      if (serial == _searchSerial) {
        _isSearchingNotifier.value = false;
      }
    }
  }

  /// Hide the dictionary and dispose of the current result.
  void clearDictionaryResult() async {
    _searchSerial++;
    _isSearchingNotifier.value = false;
    _dictionaryResultNotifier.value = null;
    _popupPositionNotifier.value = null;
    _lastSearchTerm = null;
    _showMore = false;
    appModel.currentMediaSource?.clearCurrentSentence();
    appModel.currentMediaSource?.clearExtraData();
  }

  /// Build a dictionary showing the result with positioning.
  /// If the result is null, show nothing.
  Widget buildDictionary() {
    return Theme(
      data: appModel.overrideDictionaryTheme ?? theme,
      child: MultiValueListenableBuilder(
        valueListenables: [
          _popupPositionNotifier,
        ],
        builder: (context, result, _) {
          if (!_isSearchingNotifier.value &&
              _dictionaryResultNotifier.value == null) {
            return const SizedBox.shrink();
          }

          switch (_popupPositionNotifier.value) {
            case null:
              return const SizedBox.shrink();
            case JidoujishoPopupPosition.topHalf:
              return buildTopHalfDictionary();

            case JidoujishoPopupPosition.bottomHalf:
              return buildBottomHalfDictionary();

            case JidoujishoPopupPosition.leftHalf:
              return buildLeftHalfDictionary();

            case JidoujishoPopupPosition.rightHalf:
              return buildRightHalfDictionary();

            case JidoujishoPopupPosition.topThreeFourths:
              return buildTopThreeFourths();
          }
        },
      ),
    );
  }

  /// The dictionary in the case of [JidoujishoPopupPosition.topHalf].
  Widget buildTopHalfDictionary() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: buildDictionaryResult(),
        ),
        const Space.semiBig(),
        const Flexible(
          child: SizedBox.shrink(),
        ),
      ],
    );
  }

  /// The dictionary in the case of [JidoujishoPopupPosition.bottomHalf].
  Widget buildBottomHalfDictionary() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Flexible(
          child: SizedBox.shrink(),
        ),
        const Space.semiBig(),
        Flexible(
          child: buildDictionaryResult(),
        ),
      ],
    );
  }

  /// The dictionary in the case of [JidoujishoPopupPosition.leftHalf].
  Widget buildLeftHalfDictionary() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: buildDictionaryResult(),
        ),
        const Space.semiBig(),
        const Flexible(
          child: SizedBox.shrink(),
        ),
      ],
    );
  }

  /// The dictionary in the case of [JidoujishoPopupPosition.rightHalf].
  Widget buildRightHalfDictionary() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Flexible(
          child: SizedBox.shrink(),
        ),
        const Space.semiBig(),
        Flexible(
          child: buildDictionaryResult(),
        ),
      ],
    );
  }

  /// The dictionary in the case of [JidoujishoPopupPosition.topThreeFourths].
  Widget buildTopThreeFourths() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          flex: 3,
          child: buildDictionaryResult(),
        ),
        const Space.semiBig(),
        const Flexible(
          child: SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Used to check if the pop-up is open.
  bool get dictionaryPopupShown => _popupPositionNotifier.value != null;

  /// The dictionary result unpositioned. See [buildDictionary] for the
  /// positioned version.
  Widget buildDictionaryResult() {
    Color color = appModel.overrideDictionaryColor ?? theme.cardColor;

    if ((appModel.overrideDictionaryTheme ?? theme).brightness ==
        Brightness.dark) {
      color = JidoujishoColor.lighten(color, 0.05);
    } else {
      color = JidoujishoColor.darken(color, 0.05);
    }

    bool reduceMotion = MediaQuery.of(context).disableAnimations;

    return Dismissible(
      key: ValueKey(_dictionaryResultNotifier.value),
      onDismissed: (dismissDirection) {},
      onUpdate: (details) {
        if (details.reached) {
          onDictionaryDismiss();
        }
      },
      dismissThresholds: const {DismissDirection.horizontal: 0.25},
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        ),
        child: Container(
          margin: Spacing.of(context).insets.all.normal,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: color.withOpacity(dictionaryBackgroundOpacity),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: Spacing.of(context).insets.all.semiSmall,
            child: Stack(
              children: [
                buildSearchResult(),
                Positioned.fill(child: buildDictionaryLoading()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Executed on dictionary dismiss.
  void onDictionaryDismiss() {
    clearDictionaryResult();
  }

  /// In progress indicator for dictionary searching.
  Widget buildDictionaryLoading() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isSearchingNotifier,
      builder: (context, value, child) {
        return Visibility(
          visible: value,
          child: const Align(
            alignment: Alignment.topCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                minHeight: 2.75,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Scroll controller for the search result.
  final ScrollController resultScrollController = ScrollController();

  /// Displays the dictionary entries.
  Widget buildSearchResult() {
    return ValueListenableBuilder(
      valueListenable: _dictionaryResultNotifier,
      builder: (_, __, ___) {
        if (_dictionaryResultNotifier.value == null) {
          /// First lookup still running: a short card instead of half the
          /// screen, so the popup does not jump in size.
          return const SizedBox(height: 120, width: double.infinity);
        }

        if (_dictionaryResultNotifier.value!.headingIds.isEmpty) {
          return SizedBox(
            height: 140,
            child: buildNoSearchResultsPlaceholderMessage(),
          );
        }

        return DictionaryResultPage(
          scrollController: resultScrollController,
          cardColor: appModel.overrideDictionaryColor,
          opacity: dictionaryEntryOpacity,
          onSearch: onSearch,
          onStash: onStash,
          onShare: onShare,
          result: _dictionaryResultNotifier.value!,
          spaceBeforeFirstResult: false,
          footerWidget: footerWidget,
          shrinkWrap: true,
          flat: true,
        );
      },
    );
  }

  /// Show more widget.
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
            onTap: _isSearchingNotifier.value
                ? null
                : () async {
                    searchDictionaryResult(
                      searchTerm: _lastSearchTerm!,
                      position: _popupPositionNotifier.value!,
                      overrideMaximumTerms:
                          _dictionaryResultNotifier.value!.headingIds.length +
                              appModel.maximumTerms,
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

  /// Placeholder when there are no search results.
  Widget buildNoSearchResultsPlaceholderMessage() {
    return Center(
      child: JidoujishoPlaceholderMessage(
        icon: Ui.search_off,
        message: t.no_search_results,
      ),
    );
  }

  /// Get the result returned from the last search.
  DictionarySearchResult? get currentResult => _dictionaryResultNotifier.value;

  /// Action upon selecting the Search option.
  @override
  void onSearch(String searchTerm, {String? sentence = ''}) async {
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
  }

  /// Action upon selecting the Stash option.
  @override
  void onStash(String searchTerm) {
    appModel.addToStash(terms: [searchTerm]);
  }

  /// Performs an action before opening the Card Creator.
  void onCreatorOpen() {}

  /// Performs an action after closing the Card Creator.
  void onCreatorClose() {}
}
