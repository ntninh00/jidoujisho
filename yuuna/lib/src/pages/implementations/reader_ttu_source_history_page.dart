import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _open(TtuBook book, {ReaderMemo? memo, TtuPosition? returnTo}) {
    mediaSource.openBook(
      appModel: appModelNoUpdate,
      ref: ref,
      book: book,
      memo: memo,
      returnTo: returnTo,
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

    return ValueListenableBuilder<Set<String>>(
      valueListenable: mediaSource.removedBooks,
      builder: (context, removed, _) => ValueListenableBuilder<List<String>>(
        valueListenable: mediaSource.importing,
        builder: (context, importing, _) {
          List<TtuBook>? books = shelf.valueOrNull
              ?.where((book) => !removed.contains(book.key))
              .toList();

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

          return buildShelf(books, memos, importing);
        },
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(3, 0, 3, 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 150,
                  childAspectRatio: mediaSource.aspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _BookTile(
                    key: ValueKey(books[index].key),
                    book: books[index],
                    memos: memosByBook[books[index].key] ?? const [],
                    showLanguage:
                        books[index].language != appModel.savedTargetLanguage,
                    onOpen: () => _open(books[index]),
                    onDetails: () => _showDetails(
                      books[index],
                      memosByBook[books[index].key]?.length ?? 0,
                    ),
                    onMemos: () => _showMemos(books[index]),
                  ),
                  childCount: books.length,
                ),
              ),
            ),
        ],
      ),
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
                Text(
                  t.ttu_reading_file,
                  style: textTheme.bodySmall!
                      .copyWith(color: theme.unselectedWidgetColor),
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
          Text(
            t.ttu_empty_title,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            t.ttu_empty_body,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium!
                .copyWith(color: theme.unselectedWidgetColor, height: 1.5),
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

/// One book on the shelf: its cover and title, progress with memo marks, a
/// memo count that opens the book's memos, and a language tag for books not
/// in the app's language.
class _BookTile extends BasePage {
  const _BookTile({
    required this.book,
    required this.memos,
    required this.showLanguage,
    required this.onOpen,
    required this.onDetails,
    required this.onMemos,
    super.key,
  });

  final TtuBook book;
  final List<ReaderMemo> memos;
  final bool showLanguage;
  final VoidCallback onOpen;
  final VoidCallback onDetails;
  final VoidCallback onMemos;

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
    int count = widget.memos.length;

    return Padding(
      padding: const EdgeInsets.all(5),
      child: ClipRRect(
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
                    marks: widget.memos.map((memo) => memo.progress).toList(),
                  ),
                ),
              ),
            ),
            if (widget.showLanguage)
              Positioned(
                top: 6,
                left: 6,
                child: _Pill(
                  child: Text(
                    book.language.languageCode.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
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
            if (count > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Semantics(
                  button: true,
                  label: '${t.ttu_memos} · $count',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onMemos,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 5, 5, 14),
                      child: _Pill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Ui.edit_note,
                              size: 14,
                              color: Color(0xFFFF8A80),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

/// The thin progress line on a cover, with a tick for each memo.
class _ProgressTicksPainter extends CustomPainter {
  _ProgressTicksPainter({
    required this.progress,
    required this.marks,
  });

  final double progress;
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
      Paint()..color = Colors.red,
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
        oldDelegate.marks.length != marks.length ||
        !oldDelegate.marks.every(marks.contains);
  }
}
