import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/language.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/src/pages/implementations/media_item_edit_dialog_page.dart';
import 'package:yuuna/utils.dart';

/// The Reader tab's shelf when ッツ Ebook Reader is the source: every book in
/// every language, most recently opened first.
class ReaderTtuSourceHistoryPage extends HistoryReaderPage {
  /// Create an instance of this tab page.
  const ReaderTtuSourceHistoryPage({
    super.key,
  });

  @override
  BaseHistoryPageState<BaseHistoryPage> createState() =>
      _ReaderTtuSourceHistoryPageState();
}

class _ReaderTtuSourceHistoryPageState<T extends HistoryReaderPage>
    extends HistoryReaderPageState with SingleTickerProviderStateMixin {
  @override
  MediaType get mediaType => mediaSource.mediaType;

  @override
  ReaderTtuSource get mediaSource => ReaderTtuSource.instance;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  /// Where a press on a group's heading started, to tell a drag from a
  /// long press.
  Offset? _pressedAt;

  /// While a group is dragged to a new place, the shelf shows only its
  /// headings, so every group is in reach.
  bool _reordering = false;

  /// Whether the heading held now has moved, which makes it a drag rather
  /// than a long press for the group's menu.
  bool _dragMoved = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _open(
    TtuBook book, {
    ReaderMemo? memo,
    MyWord? term,
    TtuPosition? returnTo,
  }) {
    mediaSource.openBook(
      appModel: appModelNoUpdate,
      ref: ref,
      book: book,
      memo: memo,
      term: term,
      returnTo: returnTo,
    );
  }

  void _showTerms(TtuBook book) {
    showTtuSheet<void>(
      context: context,
      builder: (_) => TtuBookTermsSheet(
        book: book,
        onOpen: (term) => _open(book, term: term),
      ),
    );
  }

  void _showMemos(TtuBook book) {
    showTtuSheet<void>(
      context: context,
      builder: (_) => TtuMemoSheet(
        book: book,
        onOpen: ({memo, returnTo}) =>
            _open(book, memo: memo, returnTo: returnTo),
      ),
    );
  }

  void _showDetails(TtuBook book, int memoCount) {
    HapticFeedback.selectionClick();
    showTtuSheet<void>(
      context: context,
      builder: (sheetContext) => TtuBookDetailsSheet(
        book: book,
        memoCount: memoCount,
        onRead: () {
          Navigator.pop(sheetContext);
          _open(book);
        },
        onMemos: () {
          Navigator.pop(sheetContext);
          _showMemos(book);
        },
        termCount: appModelNoUpdate.myTermsFromBook(book.key).length,
        onTerms: () {
          Navigator.pop(sheetContext);
          _showTerms(book);
        },
        onEdit: () async {
          Navigator.pop(sheetContext);
          await showDialog(
            context: context,
            builder: (_) => MediaItemEditDialogPage(item: book.toMediaItem()),
          );
          if (mounted) {
            setState(() {});
          }
        },
        onDelete: () {
          Navigator.pop(sheetContext);
          _delete(book);
        },
        onLanguage: (language) async {
          await mediaSource.setBookLanguage(book, language);
          Fluttertoast.showToast(
            msg: t.ttu_language_changed(language: language.languageName),
          );
          if (mounted) {
            ref.invalidate(ttuShelfProvider);
          }
        },
      ),
    );
  }

  void _delete(TtuBook book) {
    ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    mediaSource.scheduleDelete(
      appModel: appModelNoUpdate,
      book: book,
      onDeleted: () {
        if (mounted) {
          ref.invalidate(ttuShelfProvider);
        }
      },
    );
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(t.ttu_book_deleted(name: book.title)),
        action: SnackBarAction(
          label: t.ttu_undo,
          onPressed: () => mediaSource.undoDelete(book),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AsyncValue<List<TtuBook>> shelf = ref.watch(ttuShelfProvider);
    List<ReaderMemo> memos =
        ref.watch(ttuMemosProvider).valueOrNull ?? const <ReaderMemo>[];
    // Once the shelf is listed again it shows the books just read as they
    // are, so what was noted about them can go, after a frame of both.
    ref.listen<AsyncValue<List<TtuBook>>>(ttuShelfProvider, (_, next) {
      if (next is AsyncData && !next.isLoading) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => mediaSource.justRead.value = const {});
      }
    });

    return ValueListenableBuilder<Set<String>>(
      valueListenable: mediaSource.removedBooks,
      builder: (context, removed, _) => ValueListenableBuilder<List<String>>(
        valueListenable: mediaSource.importing,
        builder: (context, importing, _) => ValueListenableBuilder(
          valueListenable: mediaSource.justRead,
          builder: (context, _, __) {
            List<TtuBook>? listed = shelf.valueOrNull
                ?.where((book) => !removed.contains(book.key))
                .toList();
            List<TtuBook>? books =
                listed == null ? null : mediaSource.withJustRead(listed);

            if (books == null) {
              if (shelf.hasError) {
                return buildShelfError(shelf.error);
              }
              return buildSkeleton();
            }

            if (_pulse.isAnimating) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _pulse.stop();
                }
              });
            }

            if (books.isEmpty &&
                importing.isEmpty &&
                mediaSource.shelfErrors.length ==
                    mediaSource.shelfLanguages.length) {
              return buildShelfError(mediaSource.shelfErrors.values.first);
            }

            return ValueListenableBuilder<int>(
              valueListenable: mediaSource.shelfChanges,
              builder: (context, _, __) => buildShelf(books, memos, importing),
            );
          },
        ),
      ),
    );
  }

  /// The grid of books, with the import card above it when books are being
  /// added.
  Widget buildShelf(
    List<TtuBook> books,
    List<ReaderMemo> memos,
    List<String> importing,
  ) {
    Map<String, List<ReaderMemo>> memosByBook = {};
    for (ReaderMemo memo in memos) {
      memosByBook.putIfAbsent(memo.bookKey, () => []).add(memo);
    }

    Set<String> folded = mediaSource.foldedSections;
    Set<String> favourites = mediaSource.favouriteBooks;

    return RefreshIndicator(
      edgeOffset: 52,
      color: theme.colorScheme.primary,
      onRefresh: () => ref.refresh(ttuShelfProvider.future),
      child: CustomScrollView(
        controller: mediaType.scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          const SliverPadding(padding: EdgeInsets.only(top: 52)),
          if (importing.isNotEmpty)
            SliverToBoxAdapter(child: buildImportCard(importing)),
          if (books.isEmpty && importing.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: buildEmptyShelf(),
            )
          else
            for (_ShelfSection section in _sections(books)) ...[
              // Keyed, so a heading being dragged stays the same widget
              // while the shelf folds down to headings around it.
              if (section.title != null)
                SliverToBoxAdapter(
                  key: ValueKey('heading:${section.id}'),
                  child: section.group == null
                      ? _buildSectionHeader(
                          section,
                          folded: folded.contains(section.id),
                        )
                      : _buildGroupHeader(
                          section,
                          folded: folded.contains(section.id),
                        ),
                ),
              if (!_reordering &&
                  (!folded.contains(section.id) || section.title == null))
                SliverPadding(
                  key: ValueKey('books:${section.id}'),
                  padding: const EdgeInsets.fromLTRB(3, 0, 3, 8),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150,
                      childAspectRatio: mediaSource.aspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        TtuBook book = section.books[index];
                        return _BookTile(
                          key: ValueKey(book.key),
                          book: book,
                          favourite: favourites.contains(book.key),
                          tags: mediaSource.tagsOf(book),
                          memos: memosByBook[book.key] ?? const [],
                          onOpen: () => _open(book),
                          onDetails: () => _showDetails(
                            book,
                            memosByBook[book.key]?.length ?? 0,
                          ),
                        );
                      },
                      childCount: section.books.length,
                    ),
                  ),
                ),
            ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
        ],
      ),
    );
  }

  /// The shelf in sections: favourites first, then the books grouped as
  /// chosen in the shelf settings. Grouped by the user's own groups, a
  /// favourite stays in its group instead, at the top. A section without a
  /// title is the whole shelf, ungrouped.
  List<_ShelfSection> _sections(List<TtuBook> books) {
    Set<String> favouriteKeys = mediaSource.favouriteBooks;
    bool inGroups = mediaSource.shelfGrouping == TtuShelfGrouping.groups;
    List<TtuBook> favourites = inGroups
        ? const []
        : books.where((book) => favouriteKeys.contains(book.key)).toList();
    List<TtuBook> rest = inGroups
        ? books
        : books.where((book) => !favouriteKeys.contains(book.key)).toList();
    List<TtuBook> favouritesFirst(List<TtuBook> books) => [
          ...books.where((book) => favouriteKeys.contains(book.key)),
          ...books.where((book) => !favouriteKeys.contains(book.key)),
        ];
    List<_ShelfSection> sections = [
      if (favourites.isNotEmpty)
        _ShelfSection(
          id: 'favourites',
          title: t.ttu_favourites,
          icon: Ui.starSolid,
          books: favourites,
        ),
    ];
    if (rest.isEmpty) {
      return sections;
    }

    switch (mediaSource.shelfGrouping) {
      case TtuShelfGrouping.none:
        sections.add(_ShelfSection(
          id: 'all',
          title: favourites.isEmpty ? null : t.ttu_other_books,
          books: rest,
        ));
      case TtuShelfGrouping.groups:
        List<String> groups = mediaSource.shelfGroups;
        Map<String, List<TtuBook>> byGroup = {};
        List<TtuBook> ungrouped = [];
        for (TtuBook book in rest) {
          String? group = mediaSource.groupOf(book);
          if (group == null) {
            ungrouped.add(book);
          } else {
            byGroup.putIfAbsent(group, () => []).add(book);
          }
        }
        for (String group in groups) {
          List<TtuBook>? inGroup = byGroup[group];
          if (inGroup != null) {
            sections.add(_ShelfSection(
              id: 'group:$group',
              title: group,
              icon: Ui.folder,
              group: group,
              books: favouritesFirst(inGroup),
            ));
          }
        }
        if (ungrouped.isNotEmpty) {
          sections.add(_ShelfSection(
            id: 'ungrouped',
            title: sections.isEmpty ? null : t.ttu_ungrouped,
            books: favouritesFirst(ungrouped),
          ));
        }
      case TtuShelfGrouping.language:
        Map<Language, List<TtuBook>> byLanguage = {};
        for (TtuBook book in rest) {
          byLanguage.putIfAbsent(book.language, () => []).add(book);
        }
        for (MapEntry<Language, List<TtuBook>> entry in byLanguage.entries) {
          sections.add(_ShelfSection(
            id: 'language:${entry.key.languageCode}',
            title: entry.key.languageName,
            icon: Ui.translate,
            books: entry.value,
          ));
        }
      case TtuShelfGrouping.progress:
        List<TtuBook> reading = [];
        List<TtuBook> unread = [];
        List<TtuBook> finished = [];
        for (TtuBook book in rest) {
          if (book.progress >= 0.97) {
            finished.add(book);
          } else if (book.progress <= 0 && book.exploredCharCount <= 0) {
            unread.add(book);
          } else {
            reading.add(book);
          }
        }
        for ((String, String, IconData, List<TtuBook>) part in [
          ('reading', t.ttu_progress_reading, Ui.play_arrow_rounded, reading),
          ('unread', t.ttu_progress_unread, Ui.books, unread),
          ('finished', t.ttu_progress_finished, Ui.checkCircle, finished),
        ]) {
          if (part.$4.isNotEmpty) {
            sections.add(_ShelfSection(
              id: 'progress:${part.$1}',
              title: part.$2,
              icon: part.$3,
              books: part.$4,
            ));
          }
        }
    }
    return sections;
  }

  Widget _buildSectionHeader(_ShelfSection section, {required bool folded}) {
    Color muted = theme.unselectedWidgetColor;
    bool reduceMotion = MediaQuery.of(context).disableAnimations;
    IconData? icon = section.group == null
        ? section.icon
        : (folded || _reordering)
            ? Ui.folderClosed
            : Ui.folder;
    return InkWell(
      onTap: _reordering ? null : () => mediaSource.toggleSection(section.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: section.title ?? '',
                      style: textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '  ${section.books.length}',
                      style: textTheme.labelMedium!.copyWith(color: muted),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AnimatedRotation(
              turns: folded ? -0.25 : 0,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              child: Icon(Ui.angleDown, size: 18, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  /// A group's heading. Held and moved, it drags the group to another
  /// group's place; held and let go, it opens the group's menu.
  Widget _buildGroupHeader(_ShelfSection section, {required bool folded}) {
    String group = section.group!;
    Widget header = _buildSectionHeader(section, folded: folded);
    return DragTarget<String>(
      onWillAccept: (dragged) => dragged != null && dragged != group,
      onAccept: (dragged) {
        setState(() => _reordering = false);
        mediaSource.moveGroup(dragged, group);
      },
      builder: (context, candidates, _) => Listener(
        onPointerDown: (event) => _pressedAt = event.position,
        child: LongPressDraggable<String>(
          data: group,
          axis: Axis.vertical,
          feedback: _buildGroupDragFeedback(section),
          childWhenDragging: Opacity(opacity: 0.35, child: header),
          onDragStarted: () => _dragMoved = false,
          onDragUpdate: (details) {
            Offset? start = _pressedAt;
            if (!_dragMoved &&
                start != null &&
                (details.globalPosition - start).distance > 12) {
              _dragMoved = true;
              setState(() => _reordering = true);
            }
          },
          onDragEnd: (_) {
            bool moved = _dragMoved;
            _dragMoved = false;
            setState(() => _reordering = false);
            if (!moved) {
              _showGroupMenu(group);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: candidates.isEmpty
                  ? Colors.transparent
                  : theme.colorScheme.primary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: header,
          ),
        ),
      ),
    );
  }

  /// The heading under the finger while a group is dragged.
  Widget _buildGroupDragFeedback(_ShelfSection section) {
    return Material(
      elevation: 6,
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: MediaQuery.of(context).size.width - 24,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(Ui.folderClosed, size: 15, color: theme.colorScheme.primary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                section.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    textTheme.titleSmall!.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Icon(Ui.grip, size: 18, color: theme.unselectedWidgetColor),
          ],
        ),
      ),
    );
  }

  /// Rename or delete a group, from a long press on its heading.
  void _showGroupMenu(String group) {
    HapticFeedback.selectionClick();
    showTtuSheet<void>(
      context: context,
      builder: (sheetContext) => TtuGroupMenuSheet(group: group),
    );
  }

  /// Shown while ッツ adds books.
  Widget buildImportCard(List<String> names) {
    String label = names.length == 1
        ? t.ttu_adding_book(name: names.first)
        : t.ttu_adding_books(n: names.length);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ttuCardRadius),
      ),
      child: Row(
        children: [
          Icon(Ui.menu_book_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor:
                        theme.unselectedWidgetColor.withOpacity(0.2),
                    valueColor:
                        AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shown when there are no books yet.
  Widget buildEmptyShelf() {
    Color red = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(mediaSource.icon, size: 40, color: red),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  t.ttu_empty_title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              JidoujishoInfoButton(message: t.ttu_empty_body),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: red,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.fromLTRB(16, 12, 22, 12),
            ),
            icon: const Icon(Ui.add),
            label: Text(t.ttu_add_book),
            onPressed: () => mediaSource.pickAndImport(
              context: context,
              appModel: appModelNoUpdate,
              ref: ref,
            ),
          ),
          TextButton(
            onPressed: () => mediaSource.openTtuPage(
              appModel: appModelNoUpdate,
              ref: ref,
              language: mediaSource.shelfLanguages
                      .contains(appModel.savedTargetLanguage)
                  ? appModel.savedTargetLanguage
                  : mediaSource.shelfLanguages.first,
              page: 'manage.html',
            ),
            child: Text(
              t.ttu_restore_backup,
              style: TextStyle(color: theme.unselectedWidgetColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Cover-shaped placeholders while the shelf loads for the first time.
  Widget buildSkeleton() {
    if (!_pulse.isAnimating && !MediaQuery.of(context).disableAnimations) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_pulse.isAnimating) {
          _pulse.repeat(reverse: true);
        }
      });
    }
    Color block = theme.dividerColor.withOpacity(0.12);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1).animate(_pulse),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(3, 52, 3, 16),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          childAspectRatio: mediaSource.aspectRatio,
        ),
        itemCount: 9,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.all(5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: block,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }

  /// Shown when no copy of ッツ could be read, usually because the local
  /// server's port is taken.
  Widget buildShelfError(Object? error) {
    String message =
        error is SocketException ? t.server_port_in_use : t.ttu_shelf_error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            JidoujishoPlaceholderMessage(
              icon: Ui.lan_outlined,
              message: message,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                for (Language language in mediaSource.shelfLanguages) {
                  ref.invalidate(ttuServerProvider(language));
                }
                ref.invalidate(ttuShelfProvider);
              },
              child: Text(t.ttu_try_again),
            ),
          ],
        ),
      ),
    );
  }
}

/// One book on the shelf: its cover and title, progress with memo marks, and
/// a coloured tab peeking out from the cover for its memos.
/// Books under one heading on the shelf.
class _ShelfSection {
  const _ShelfSection({
    required this.id,
    required this.title,
    required this.books,
    this.icon,
    this.group,
  });

  /// Remembers whether the section is folded away.
  final String id;

  /// The heading, or null for the whole shelf without one.
  final String? title;

  final List<TtuBook> books;
  final IconData? icon;

  /// The user's group the section shows, if it is one.
  final String? group;
}

class _BookTile extends BasePage {
  const _BookTile({
    required this.book,
    required this.memos,
    required this.onOpen,
    required this.onDetails,
    this.favourite = false,
    this.tags = const [],
    super.key,
  });

  final TtuBook book;

  /// Marked with a star.
  final bool favourite;

  /// The user's tags, shown as pills on the cover.
  final List<String> tags;
  final List<ReaderMemo> memos;
  final VoidCallback onOpen;
  final VoidCallback onDetails;

  @override
  BasePageState<_BookTile> createState() => _BookTileState();
}

class _BookTileState extends BasePageState<_BookTile> {
  @override
  Widget build(BuildContext context) {
    TtuBook book = widget.book;
    ReaderTtuSource source = ReaderTtuSource.instance;
    MediaItem item = book.toMediaItem();
    String title = source.getDisplayTitleFromMediaItem(item);
    ImageProvider? overrideImage = source.getOverrideThumbnailFromMediaItem(
      appModel: appModel,
      item: item,
    );
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (widget.memos.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: TtuMemoTabsPainter(
                    tabs: [
                      for (ReaderMemo memo in widget.memos)
                        (
                          at: memo.progress,
                          color: TtuMemoColor.ofMemo(memo).color,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                TtuCover(book: book, radius: 0, overrideImage: overrideImage),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: 0.25,
                    widthFactor: 1,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.fromLTRB(3, 2, 3, 5),
                      color: Colors.black.withOpacity(0.6),
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall!.copyWith(
                          color: Colors.white,
                          fontSize: textTheme.bodySmall!.fontSize! * 0.9,
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 8,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _ProgressTicksPainter(
                        progress: book.progress,
                        color: Theme.of(context).colorScheme.primary,
                        marks:
                            widget.memos.map((memo) => memo.progress).toList(),
                      ),
                    ),
                  ),
                ),
                if (widget.tags.isNotEmpty)
                  Positioned(
                    top: 5,
                    left: 5,
                    right: 26,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: TtuCoverTags(tags: widget.tags),
                    ),
                  ),
                if (widget.favourite)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Ui.starSolid,
                        size: 12,
                        color: Color(0xFFFFC107),
                      ),
                    ),
                  ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: widget.onOpen,
                    onLongPress: widget.onDetails,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The thin progress line on a cover, with a tick for each memo.
class _ProgressTicksPainter extends CustomPainter {
  _ProgressTicksPainter({
    required this.progress,
    required this.color,
    required this.marks,
  });

  final double progress;
  final Color color;
  final List<double> marks;

  @override
  void paint(Canvas canvas, Size size) {
    double top = size.height - 2;
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, 2),
      Paint()..color = Colors.white.withOpacity(0.6),
    );
    double shown = progress > 0.97 ? 1 : progress.clamp(0, 1).toDouble();
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width * shown, 2),
      Paint()..color = color,
    );

    Paint outline = Paint()..color = Colors.black.withOpacity(0.55);
    Paint tick = Paint()..color = Colors.white;
    for (double mark in marks) {
      double x = (size.width * mark.clamp(0, 1)).clamp(1, size.width - 1);
      canvas.drawRect(Rect.fromLTWH(x - 2, 0, 4, size.height), outline);
      canvas.drawRect(Rect.fromLTWH(x - 1, 1, 2, size.height - 1), tick);
    }
  }

  @override
  bool shouldRepaint(_ProgressTicksPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.marks.length != marks.length ||
        !oldDelegate.marks.every(marks.contains);
  }
}
