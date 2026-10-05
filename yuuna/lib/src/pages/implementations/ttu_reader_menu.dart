import 'dart:math';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
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
              button(Ui.chapters, t.ttu_chapters, onChapters),
              button(Ui.textSize, t.ttu_reader_settings, onSettings),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lists a book's chapters, with the one being read marked. Picking one
/// opens the book at its start.
class TtuChaptersSheet extends StatefulWidget {
  /// Create the list.
  const TtuChaptersSheet({
    required this.chapters,
    required this.totalCharacters,
    required this.position,
    required this.onSelect,
    super.key,
  });

  /// The chapters in reading order.
  final List<TtuChapter> chapters;

  /// Characters in the whole book.
  final int totalCharacters;

  /// ッツ's position now, in characters.
  final int position;

  /// Opens the book at a chapter.
  final ValueChanged<TtuChapter> onSelect;

  @override
  State<TtuChaptersSheet> createState() => _TtuChaptersSheetState();
}

class _TtuChaptersSheetState extends State<TtuChaptersSheet> {
  static const double _rowHeight = 48;
  bool _scrolled = false;

  /// Brings the chapter being read into view the first time the list shows.
  void _scrollToCurrent(ScrollController controller, int index) {
    if (_scrolled) {
      return;
    }
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.jumpTo(min(controller.position.maxScrollExtent,
            max(0, index * _rowHeight - _rowHeight * 2)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<TtuChapter> chapters = widget.chapters;
    int totalCharacters = widget.totalCharacters;
    ThemeData theme = Theme.of(context);
    Color accent = theme.colorScheme.primary;
    Color muted = theme.unselectedWidgetColor;
    TtuChapter? current = ttuChapterAt(chapters, widget.position);
    int currentIndex = current == null ? 0 : chapters.indexOf(current);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.94,
      builder: (context, controller) {
        _scrollToCurrent(controller, currentIndex);
        return Column(
          children: [
            const TtuSheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.ttu_chapters,
                      style: theme.textTheme.titleLarge!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: t.dialog_close,
                    icon: const Icon(Ui.cross),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: chapters.isEmpty
                  ? Center(
                      child: Text(
                        t.ttu_no_chapters,
                        style:
                            theme.textTheme.bodyMedium!.copyWith(color: muted),
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        TtuChapter chapter = chapters[index];
                        bool here = chapter == current;
                        double share = totalCharacters <= 0
                            ? 0
                            : chapter.start / totalCharacters;
                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            widget.onSelect(chapter);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: EdgeInsets.fromLTRB(
                                chapter.nested ? 32 : 14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: here
                                  ? accent.withOpacity(0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    chapter.label.isEmpty
                                        ? '${index + 1}'
                                        : chapter.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium!.copyWith(
                                      color: here ? accent : null,
                                      fontWeight: here
                                          ? FontWeight.bold
                                          : (chapter.nested
                                              ? FontWeight.normal
                                              : FontWeight.w600),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  ttuPercent(share),
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: muted,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
