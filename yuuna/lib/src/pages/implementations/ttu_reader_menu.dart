import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:yuuna/language.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// A chapter of a book, as ッツ stored it.
class TtuChapter {
  /// Describe a chapter.
  const TtuChapter({
    required this.label,
    required this.start,
    required this.characters,
    required this.nested,
  });

  /// Read from the reader bridge's `chapters()` result.
  factory TtuChapter.fromMap(Map<dynamic, dynamic> map) {
    return TtuChapter(
      label: (map['label'] as String?)?.trim() ?? '',
      start: (map['start'] as num?)?.toInt() ?? 0,
      characters: (map['characters'] as num?)?.toInt() ?? 0,
      nested: map['parent'] != null,
    );
  }

  /// The chapter's title from the book's table of contents.
  final String label;

  /// ッツ's character position where the chapter starts.
  final int start;

  /// Characters in the chapter.
  final int characters;

  /// Whether the chapter sits under another one.
  final bool nested;
}

/// The chapter holding [characters], or null before the first one.
TtuChapter? ttuChapterAt(List<TtuChapter> chapters, int characters) {
  TtuChapter? current;
  for (TtuChapter chapter in chapters) {
    if (chapter.start <= characters) {
      current = chapter;
    } else {
      break;
    }
  }
  return current;
}

/// The menu shown over a book when its top or bottom edge is tapped: the way
/// out, where the reader is, the chapters and the page settings.
class TtuReaderMenu extends StatelessWidget {
  /// Create the menu.
  const TtuReaderMenu({
    required this.title,
    required this.detail,
    required this.background,
    required this.foreground,
    required this.onBack,
    required this.onChapters,
    required this.onSearch,
    required this.onSettings,
    super.key,
  });

  /// The book's title.
  final String title;

  /// Where the reader is, such as "Chapter 3 · 42%".
  final String detail;

  /// The page's background colour, which the menu follows.
  final Color background;

  /// The page's text colour.
  final Color foreground;

  /// Leaves the book.
  final VoidCallback onBack;

  /// Opens the chapter list.
  final VoidCallback onChapters;

  /// Opens search in the book.
  final VoidCallback onSearch;

  /// Opens the page settings over the book.
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    bool dark = background.computeLuminance() < 0.4;
    Color surface = Color.lerp(
        background, dark ? Colors.white : Colors.black, dark ? 0.08 : 0.04)!;
    Color muted = foreground.withOpacity(0.6);

    Widget button(IconData icon, String tooltip, VoidCallback onTap) {
      return IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 20, color: foreground),
        onPressed: onTap,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Material(
        color: surface,
        elevation: 6,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
            children: [
              button(Ui.arrow_back, t.dialog_close, onBack),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
              button(Ui.search, t.ttu_search, onSearch),
              button(Ui.chapters, t.ttu_chapters, onChapters),
              button(Ui.textSize, t.ttu_reader_settings, onSettings),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lists a book's chapters, with the one being read marked and each
/// chapter's memos under it in their colours. Picking a chapter opens the
/// book at its start; picking a memo opens it at the memo.
class TtuChaptersSheet extends StatefulWidget {
  /// Create the list.
  const TtuChaptersSheet({
    required this.chapters,
    required this.totalCharacters,
    required this.position,
    required this.memos,
    required this.language,
    required this.onSelect,
    required this.onSelectMemo,
    super.key,
  });

  /// The chapters in reading order.
  final List<TtuChapter> chapters;

  /// Characters in the whole book.
  final int totalCharacters;

  /// ッツ's position now, in characters.
  final int position;

  /// The book's memos.
  final List<ReaderMemo> memos;

  /// The book's language, for quoting.
  final Language language;

  /// Opens the book at a chapter.
  final ValueChanged<TtuChapter> onSelect;

  /// Opens the book at a memo.
  final ValueChanged<ReaderMemo> onSelectMemo;

  @override
  State<TtuChaptersSheet> createState() => _TtuChaptersSheetState();
}

class _TtuChaptersSheetState extends State<TtuChaptersSheet> {
  final GlobalKey _currentKey = GlobalKey();
  bool _scrolled = false;

  /// Brings the chapter being read into view the first time the list shows.
  void _scrollToCurrent() {
    if (_scrolled) {
      return;
    }
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BuildContext? row = _currentKey.currentContext;
      if (row != null) {
        Scrollable.ensureVisible(row, alignment: 0.2);
      }
    });
  }

  /// The book's memos in reading order, under the chapter each falls in.
  /// Memos before the first chapter go with it.
  List<List<ReaderMemo>> _memosByChapter() {
    List<TtuChapter> chapters = widget.chapters;
    List<List<ReaderMemo>> groups = [for (TtuChapter _ in chapters) []];
    List<ReaderMemo> memos = [...widget.memos]..sort((a, b) {
        int order = a.exploredCharCount.compareTo(b.exploredCharCount);
        return order != 0 ? order : a.createdAt.compareTo(b.createdAt);
      });
    for (ReaderMemo memo in memos) {
      int index = 0;
      for (int i = 0; i < chapters.length; i++) {
        if (chapters[i].start <= memo.exploredCharCount) {
          index = i;
        } else {
          break;
        }
      }
      if (groups.isNotEmpty) {
        groups[index].add(memo);
      }
    }
    return groups;
  }

  Widget _buildChapter(TtuChapter chapter, int index, bool here) {
    ThemeData theme = Theme.of(context);
    Color accent = theme.colorScheme.primary;
    int total = widget.totalCharacters;
    double share = total <= 0 ? 0 : chapter.start / total;
    return InkWell(
      key: here ? _currentKey : null,
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.pop(context);
        widget.onSelect(chapter);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: EdgeInsets.fromLTRB(chapter.nested ? 32 : 14, 12, 14, 12),
        decoration: BoxDecoration(
          color: here ? accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                chapter.label.isEmpty ? '${index + 1}' : chapter.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: here ? accent : null,
                  fontWeight: here
                      ? FontWeight.bold
                      : (chapter.nested ? FontWeight.normal : FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              ttuPercent(share),
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.unselectedWidgetColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemo(ReaderMemo memo, {required bool nested}) {
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    Color muted = theme.unselectedWidgetColor;
    Color color = TtuMemoColor.ofMemo(memo).color;
    String quote = ttuQuote(widget.language, memo.excerpt);
    bool written = memo.memo.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context);
          widget.onSelectMemo(memo);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(nested ? 34 : 16, 6, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: TtuMemoFlag(color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (written)
                      Text(
                        memo.memo.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium!.copyWith(height: 1.35),
                      ),
                    Container(
                      margin: EdgeInsets.only(top: written ? 4 : 0),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        quote,
                        maxLines: written ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall!.copyWith(
                          height: 1.45,
                          color: textTheme.bodySmall!.color!.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  ttuPercent(memo.progress),
                  style: textTheme.bodySmall!.copyWith(
                    color: muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<TtuChapter> chapters = widget.chapters;
    ThemeData theme = Theme.of(context);
    Color muted = theme.unselectedWidgetColor;
    TtuChapter? current = ttuChapterAt(chapters, widget.position);
    List<List<ReaderMemo>> memosByChapter = _memosByChapter();

    List<Widget> rows = [];
    if (chapters.isEmpty) {
      List<ReaderMemo> memos = [...widget.memos]
        ..sort((a, b) => a.exploredCharCount.compareTo(b.exploredCharCount));
      for (ReaderMemo memo in memos) {
        rows.add(_buildMemo(memo, nested: false));
      }
    } else {
      for (int i = 0; i < chapters.length; i++) {
        TtuChapter chapter = chapters[i];
        rows.add(_buildChapter(chapter, i, chapter == current));
        for (ReaderMemo memo in memosByChapter[i]) {
          rows.add(_buildMemo(memo, nested: chapter.nested));
        }
      }
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.94,
      builder: (context, controller) {
        _scrollToCurrent();
        return Column(
          children: [
            const TtuSheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 4, 4),
              child: Row(
                children: [
                  Text(
                    t.ttu_chapters,
                    style: theme.textTheme.titleLarge!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (widget.memos.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    for (TtuMemoColor color in _colorsUsed())
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: TtuMemoFlag(color: color.color, size: 12),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.memos.length}',
                      style: theme.textTheme.bodySmall!.copyWith(color: muted),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: t.dialog_close,
                    icon: const Icon(Ui.cross),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        t.ttu_no_chapters,
                        style:
                            theme.textTheme.bodyMedium!.copyWith(color: muted),
                      ),
                    )
                  : ListView(
                      controller: controller,
                      padding: const EdgeInsets.only(bottom: 16),
                      children: rows,
                    ),
            ),
          ],
        );
      },
    );
  }

  /// The colours the book's memos use, in palette order.
  List<TtuMemoColor> _colorsUsed() {
    Set<TtuMemoColor> used = widget.memos.map(TtuMemoColor.ofMemo).toSet();
    return TtuMemoColor.values.where(used.contains).toList();
  }
}
