import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:yuuna/language.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// One place in a book where a search matched.
class TtuSearchHit {
  /// Describe a match.
  const TtuSearchHit({
    required this.characters,
    required this.progress,
    required this.before,
    required this.match,
    required this.after,
    required this.flash,
  });

  /// Read from the reader bridge's `search()` result.
  factory TtuSearchHit.fromMap(Map<dynamic, dynamic> map) {
    return TtuSearchHit(
      characters: (map['characters'] as num?)?.toInt() ?? 0,
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      before: (map['before'] as String?) ?? '',
      match: (map['match'] as String?) ?? '',
      after: (map['after'] as String?) ?? '',
      flash: (map['flash'] as String?) ?? '',
    );
  }

  /// ッツ's character position of the match.
  final int characters;

  /// Position as a fraction from 0 to 1.
  final double progress;

  /// Text of the paragraph just before the match.
  final String before;

  /// The matched text as it is in the book.
  final String match;

  /// Text of the paragraph just after the match.
  final String after;

  /// The text to highlight once the page shows the match.
  final String flash;

  /// Where to open the book for this match.
  TtuPosition get position =>
      TtuPosition(characters: characters, progress: progress);
}

/// What a search of a book found: the first matches, and how many there
/// are in all.
class TtuSearchResults {
  /// Describe a search.
  const TtuSearchResults({
    required this.query,
    required this.hits,
    required this.total,
  });

  /// Read from the reader bridge's `search()` result.
  factory TtuSearchResults.fromMap(String query, Map<dynamic, dynamic> map) {
    return TtuSearchResults(
      query: query,
      hits: ((map['results'] as List?) ?? const [])
          .whereType<Map>()
          .map(TtuSearchHit.fromMap)
          .toList(),
      total: (map['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// What was searched for.
  final String query;

  /// The matches listed, in book order.
  final List<TtuSearchHit> hits;

  /// How many matches there are, listed or not.
  final int total;
}

/// Searches the open book and lists where the text appears, under the
/// chapters it is in. Picking a result reads there; the reader's saved place
/// stays where it was.
class TtuSearchSheet extends StatefulWidget {
  /// Create the sheet.
  const TtuSearchSheet({
    required this.chapters,
    required this.language,
    required this.onSearch,
    required this.onSelect,
    this.results,
    this.current,
    super.key,
  });

  /// The book's chapters, to group results under.
  final List<TtuChapter> chapters;

  /// The book's language, for its quotation marks and font.
  final Language language;

  /// Runs a search. Null when the book could not be read.
  final Future<TtuSearchResults?> Function(String query) onSearch;

  /// A result was picked: the results it belongs to and its index.
  final void Function(TtuSearchResults results, int index) onSelect;

  /// The last search, shown again when the sheet reopens.
  final TtuSearchResults? results;

  /// The result being read, marked in the list.
  final int? current;

  @override
  State<TtuSearchSheet> createState() => _TtuSearchSheetState();
}

class _TtuSearchSheetState extends State<TtuSearchSheet> {
  late final TextEditingController _query =
      TextEditingController(text: widget.results?.query ?? '');
  late TtuSearchResults? _results = widget.results;
  bool _searching = false;
  Timer? _debounce;
  int _serial = 0;
  final ScrollController _scroll = ScrollController();
  final GlobalKey _currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        BuildContext? current = _currentKey.currentContext;
        if (current != null) {
          Scrollable.ensureVisible(current, alignment: 0.3);
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(text));
  }

  Future<void> _run(String text) async {
    _debounce?.cancel();
    String query = text.trim();
    int serial = ++_serial;
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    TtuSearchResults? results = await widget.onSearch(query);
    if (!mounted || serial != _serial) {
      return;
    }
    setState(() {
      _results = results;
      _searching = false;
    });
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    MediaQueryData media = MediaQuery.of(context);
    double height = media.size.height * 0.88 - media.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: height.clamp(240, media.size.height).toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TtuSheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
              child: Row(
                children: [
                  Expanded(child: _field(theme)),
                  JidoujishoInfoButton(message: t.ttu_search_info),
                ],
              ),
            ),
            _status(theme),
            Expanded(child: _list(theme)),
          ],
        ),
      ),
    );
  }

  Widget _field(ThemeData theme) {
    return TextField(
      controller: _query,
      autofocus: widget.results == null,
      textInputAction: TextInputAction.search,
      onChanged: _onChanged,
      onSubmitted: _run,
      style: TextStyle(fontFamily: widget.language.defaultFontFamily),
      decoration: InputDecoration(
        hintText: t.ttu_search_hint,
        isDense: true,
        filled: true,
        fillColor: theme.dividerColor.withOpacity(0.08),
        prefixIcon: const Icon(Ui.search, size: 18),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _query,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Ui.cross, size: 18),
                  onPressed: () {
                    _query.clear();
                    _run('');
                  },
                ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _status(ThemeData theme) {
    Color muted = theme.unselectedWidgetColor;
    TtuSearchResults? results = _results;
    Widget child;
    if (_searching) {
      child = Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            t.ttu_search_reading,
            style: theme.textTheme.bodySmall!.copyWith(color: muted),
          ),
        ],
      );
    } else if (results == null) {
      child = const SizedBox.shrink();
    } else if (results.total == 0) {
      child = Text(
        t.ttu_search_none,
        style: theme.textTheme.bodySmall!.copyWith(color: muted),
      );
    } else {
      child = Text(
        t.ttu_search_found(count: results.total),
        style: theme.textTheme.bodySmall!.copyWith(
          color: muted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 16, 6),
      child: SizedBox(height: 18, child: child),
    );
  }

  Widget _list(ThemeData theme) {
    TtuSearchResults? results = _results;
    if (results == null || results.hits.isEmpty) {
      return const SizedBox.shrink();
    }

    /// Chapter headings go before the first result in each chapter.
    List<Widget> rows = [];
    TtuChapter? shownChapter;
    bool first = true;
    for (int i = 0; i < results.hits.length; i++) {
      TtuSearchHit hit = results.hits[i];
      TtuChapter? chapter = ttuChapterAt(widget.chapters, hit.characters);
      if (first || chapter != shownChapter) {
        first = false;
        shownChapter = chapter;
        if (chapter != null && chapter.label.isNotEmpty) {
          rows.add(_chapterHeading(theme, chapter.label));
        }
      }
      rows.add(_ResultRow(
        key: i == widget.current ? _currentKey : null,
        hit: hit,
        language: widget.language,
        current: i == widget.current,
        onTap: () => widget.onSelect(results, i),
      ));
    }
    if (results.total > results.hits.length) {
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
        child: Text(
          t.ttu_search_first(shown: results.hits.length),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall!
              .copyWith(color: theme.unselectedWidgetColor),
        ),
      ));
    }

    return ListView(
      controller: _scroll,
      padding: EdgeInsets.only(
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      children: rows,
    );
  }

  Widget _chapterHeading(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 16, 4),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium!.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.hit,
    required this.language,
    required this.current,
    required this.onTap,
    super.key,
  });

  final TtuSearchHit hit;
  final Language language;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color accent = theme.colorScheme.primary;
    Color muted = theme.unselectedWidgetColor;
    TextStyle base = theme.textTheme.bodyMedium!.copyWith(
      fontFamily: language.defaultFontFamily,
      height: 1.5,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: current ? accent.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: base,
                      children: [
                        TextSpan(text: hit.before),
                        TextSpan(
                          text: hit.match,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            backgroundColor: accent.withOpacity(0.22),
                          ),
                        ),
                        TextSpan(text: hit.after),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    ttuPercent(hit.progress),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
}

/// Shown over the book while reading search results: which result this is,
/// the previous and next ones, the way back to where the reader was, and
/// staying here.
class TtuSearchBar extends StatelessWidget {
  /// Create the bar.
  const TtuSearchBar({
    required this.index,
    required this.count,
    required this.more,
    required this.home,
    required this.onPrevious,
    required this.onNext,
    required this.onList,
    required this.onBack,
    required this.onStay,
    super.key,
  });

  /// The result open, from 0.
  final int index;

  /// Results listed.
  final int count;

  /// There are more results than are listed.
  final bool more;

  /// Where the reader was before the search.
  final TtuPosition home;

  /// Opens the previous result, or null at the first.
  final VoidCallback? onPrevious;

  /// Opens the next result, or null at the last.
  final VoidCallback? onNext;

  /// Shows the results again.
  final VoidCallback onList;

  /// Goes back to where the reader was.
  final VoidCallback onBack;

  /// Stays here, ending the search.
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    const Color foreground = Colors.white;
    const Color faded = Colors.white38;
    Widget icon(IconData icon, String tooltip, VoidCallback? onTap) {
      return IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 18, color: onTap == null ? faded : foreground),
        onPressed: onTap,
      );
    }

    return Material(
      color: const Color(0xFF303030),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon(Ui.angleLeft, t.ttu_search_previous, onPrevious),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onList,
              child: Tooltip(
                message: t.ttu_search_list,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    '${index + 1} / $count${more ? '+' : ''}',
                    style: const TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            icon(Ui.angleRight, t.ttu_search_next, onNext),
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: Colors.white24,
            ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onBack,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Ui.undo_rounded, size: 16, color: foreground),
                    const SizedBox(width: 5),
                    Text(
                      ttuPercent(home.progress),
                      style: const TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            icon(Ui.cross, t.ttu_search_stay, onStay),
          ],
        ),
      ),
    );
  }
}
