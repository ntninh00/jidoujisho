import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Every book's memos in one place: under their books, by the day they were
/// written, or as a wall of notes. Colours narrow them, and a search finds
/// them by their words, passages or books.
class TtuMemosPage extends BasePage {
  /// Create the page.
  const TtuMemosPage({super.key});

  @override
  BasePageState<TtuMemosPage> createState() => _TtuMemosPageState();
}

class _TtuMemosPageState extends BasePageState<TtuMemosPage> {
  ReaderTtuSource get source => ReaderTtuSource.instance;

  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// The colours shown; none picked shows them all.
  final Set<TtuMemoColor> _colors = {};

  /// Books whose memos are folded away, by key.
  final Set<String> _folded = {};

  /// Memos swiped away, hidden before the database says they are gone.
  final Set<int> _gone = {};

  /// 0 by book, 1 by date, 2 as a wall.
  late int _view = source.memosView.clamp(0, 2);

  Color get muted => theme.unselectedWidgetColor;

  /// The fill of the page's fields and chips, as on the shelf's bar.
  Color get surface => theme.brightness == Brightness.dark
      ? const Color.fromARGB(255, 30, 30, 30)
      : const Color.fromARGB(255, 229, 229, 229);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(TtuBook book, ReaderMemo memo) {
    source.openBook(
      appModel: appModelNoUpdate,
      ref: ref,
      book: book,
      memo: memo,
    );
  }

  Future<void> _edit(TtuBook book, ReaderMemo memo) async {
    TtuMemoDraft? draft = await showTtuMemoEditor(
      context: context,
      book: book,
      excerpt: memo.excerpt,
      progress: memo.progress,
      characters: memo.exploredCharCount,
      initialMemo: memo.memo,
      initialColor: TtuMemoColor.ofMemo(memo),
      isNew: false,
      onDelete: () => _delete(memo),
    );
    if (draft == null) {
      return;
    }
    memo
      ..memo = draft.text
      ..color = draft.color.name;
    await appModelNoUpdate.putReaderMemo(memo);
  }

  /// Deletes at once, with an Undo on the snack bar.
  Future<void> _delete(ReaderMemo memo) async {
    ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _gone.add(memo.id));
    await appModelNoUpdate.deleteReaderMemo(memo);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(t.ttu_memo_deleted),
        action: SnackBarAction(
          label: t.ttu_undo,
          onPressed: () async {
            await appModelNoUpdate.putReaderMemo(memo);
            if (mounted) {
              setState(() => _gone.remove(memo.id));
            }
          },
        ),
      ),
    );
  }

  Future<void> _name(TtuMemoColor color) async {
    HapticFeedback.selectionClick();
    String? name = await showDialog<String>(
      context: context,
      builder: (_) => _ColorNameDialog(color: color),
    );
    if (name != null) {
      await source.setMemoColorName(color, name);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _setView(int view) {
    setState(() => _view = view);
    source.setMemosView(view);
  }

  @override
  Widget build(BuildContext context) {
    List<ReaderMemo> all =
        ref.watch(ttuMemosProvider).valueOrNull ?? const <ReaderMemo>[];
    List<TtuBook>? shelf = ref.watch(ttuShelfProvider).valueOrNull;
    Set<String> removed = source.removedBooks.value;
    Map<String, TtuBook> books = {
      for (TtuBook book in shelf ?? const <TtuBook>[])
        if (!removed.contains(book.key)) book.key: book,
    };

    // Only memos of books on the shelf, which can be opened.
    List<ReaderMemo> kept = all
        .where((memo) =>
            books.containsKey(memo.bookKey) && !_gone.contains(memo.id))
        .toList();
    String query = _query.toLowerCase();
    List<ReaderMemo> found = query.isEmpty
        ? kept
        : kept
            .where((memo) =>
                memo.memo.toLowerCase().contains(query) ||
                memo.excerpt.toLowerCase().contains(query) ||
                books[memo.bookKey]!.title.toLowerCase().contains(query))
            .toList();
    Map<TtuMemoColor, int> counts = {};
    for (ReaderMemo memo in found) {
      counts.update(TtuMemoColor.ofMemo(memo), (n) => n + 1, ifAbsent: () => 1);
    }
    List<ReaderMemo> shown = _colors.isEmpty
        ? found
        : found
            .where((memo) => _colors.contains(TtuMemoColor.ofMemo(memo)))
            .toList();

    Widget body;
    if (shelf == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (kept.isEmpty) {
      body = _empty(t.ttu_no_memos);
    } else if (shown.isEmpty) {
      body = _empty(t.ttu_memos_none_found);
    } else {
      body = switch (_view) {
        1 => _byDate(shown, books),
        2 => _wall(shown, books),
        _ => _byBook(shown, books),
      };
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Ui.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(t.ttu_memos),
        actions: [_viewSwitch(), const SizedBox(width: 12)],
      ),
      body: Column(
        children: [
          _searchField(),
          _colorRow(counts),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _viewSwitch() {
    Color accent = theme.colorScheme.primary;
    List<(IconData, String)> views = [
      (Ui.books, t.ttu_memos_by_book),
      (Ui.calendar, t.ttu_memos_by_date),
      (Ui.grid, t.ttu_memos_wall),
    ];
    return Center(
      child: Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < views.length; i++)
              Tooltip(
                message: views[i].$2,
                child: Semantics(
                  selected: i == _view,
                  child: Material(
                    color: i == _view
                        ? accent.withOpacity(0.22)
                        : Colors.transparent,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _setView(i),
                      child: SizedBox(
                        width: 40,
                        child: Icon(
                          views[i].$1,
                          size: 17,
                          color: i == _view ? accent : muted,
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

  Widget _searchField() {
    OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _search,
          onChanged: (text) => setState(() => _query = text.trim()),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: surface,
            hintText: t.ttu_memos_search,
            prefixIcon: Icon(Ui.search, size: 18, color: muted),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: t.dialog_clear,
                    icon: Icon(Ui.cross, size: 16, color: muted),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
            contentPadding: EdgeInsets.zero,
            border: border,
            enabledBorder: border,
            focusedBorder: border,
          ),
        ),
      ),
    );
  }

  Widget _colorRow(Map<TtuMemoColor, int> counts) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 8),
        children: [
          for (TtuMemoColor color in TtuMemoColor.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _colorChip(color, counts[color] ?? 0),
            ),
          JidoujishoInfoButton(message: t.ttu_memos_colors_info),
        ],
      ),
    );
  }

  /// A colour's chip: a tap shows its memos with the others picked, a long
  /// press names it.
  Widget _colorChip(TtuMemoColor color, int count) {
    bool on = _colors.contains(color);
    String? name = color.customName;
    return Semantics(
      button: true,
      selected: on,
      label: name ?? color.label,
      child: Material(
        color: on ? color.color.withOpacity(0.3) : surface,
        shape: StadiumBorder(
          side:
              on ? BorderSide(color: color.color, width: 1.2) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              setState(() => on ? _colors.remove(color) : _colors.add(color)),
          onLongPress: () => _name(color),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color.color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (name != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(name, style: textTheme.labelLarge),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '$count',
                    style: textTheme.labelMedium!.copyWith(
                        color: count == 0 ? muted.withOpacity(0.5) : muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Ui.memo, size: 40, color: muted.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium!.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }

  /// A memo in a list, swiped away to delete it.
  Widget _row(TtuBook book, ReaderMemo memo, {bool showBook = false}) {
    return Dismissible(
      key: ValueKey(memo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade700,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Ui.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _delete(memo),
      child: TtuMemoRow(
        memo: memo,
        book: book,
        showBook: showBook,
        onTap: () => _open(book, memo),
        onEdit: () => _edit(book, memo),
      ),
    );
  }

  /// Books with memos written in them most lately first, each with its
  /// memos in the order of the book.
  Widget _byBook(List<ReaderMemo> memos, Map<String, TtuBook> books) {
    Map<String, List<ReaderMemo>> byBook = {};
    for (ReaderMemo memo in memos) {
      byBook.putIfAbsent(memo.bookKey, () => []).add(memo);
    }
    DateTime latest(String key) => byBook[key]!
        .map((memo) => memo.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    List<String> keys = byBook.keys.toList()
      ..sort((a, b) => latest(b).compareTo(latest(a)));
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (String key in keys) ...[
          _bookHeading(books[key]!, byBook[key]!.length),
          if (!_folded.contains(key))
            for (ReaderMemo memo in byBook[key]!
              ..sort(
                  (a, b) => a.exploredCharCount.compareTo(b.exploredCharCount)))
              _row(books[key]!, memo),
        ],
      ],
    );
  }

  Widget _bookHeading(TtuBook book, int count) {
    bool folded = _folded.contains(book.key);
    return InkWell(
      onTap: () => setState(
          () => folded ? _folded.remove(book.key) : _folded.add(book.key)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(
          children: [
            TtuCover(book: book, width: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${t.ttu_memos_count(n: count)} · '
                    '${ttuPercent(book.progress)}',
                    style: textTheme.labelSmall!.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: folded ? -0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: Icon(Ui.angleDown, size: 18, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  /// Memos newest first, under the day they were written.
  Widget _byDate(List<ReaderMemo> memos, Map<String, TtuBook> books) {
    List<ReaderMemo> sorted = [...memos]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    List<Widget> children = [];
    String? day;
    for (ReaderMemo memo in sorted) {
      String its = _dayOf(memo.createdAt);
      if (its != day) {
        day = its;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            its,
            style: textTheme.labelMedium!.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ));
      }
      children.add(_row(books[memo.bookKey]!, memo, showBook: true));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }

  /// Today, yesterday, or the date, with the year when it isn't this one.
  String _dayOf(DateTime time) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime day = DateTime(time.year, time.month, time.day);
    int daysAgo = (today.difference(day).inHours / 24).round();
    if (daysAgo <= 0) {
      return t.ttu_today;
    }
    if (daysAgo == 1) {
      return t.ttu_yesterday;
    }
    return (day.year == today.year ? DateFormat.MMMEd() : DateFormat.yMMMEd())
        .format(day);
  }

  /// Memos as notes in their colours, newest first, two to a row.
  Widget _wall(List<ReaderMemo> memos, Map<String, TtuBook> books) {
    List<ReaderMemo> sorted = [...memos]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: sorted.length,
      itemBuilder: (context, i) => _note(books[sorted[i].bookKey]!, sorted[i]),
    );
  }

  /// A memo as a sticky note: a tap opens the book there, a long press
  /// edits it.
  Widget _note(TtuBook book, ReaderMemo memo) {
    bool dark = theme.brightness == Brightness.dark;
    Color color = TtuMemoColor.ofMemo(memo).color;
    Color ink = textTheme.bodyMedium!.color!;
    return Material(
      color: Color.alphaBlend(
        color.withOpacity(dark ? 0.2 : 0.3),
        dark ? surface : Colors.white,
      ),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(book, memo),
        onLongPress: () => _edit(book, memo),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (memo.memo.isNotEmpty) ...[
                Text(
                  memo.memo,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium!
                      .copyWith(fontWeight: FontWeight.bold, height: 1.35),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                ttuQuote(book.language, memo.excerpt),
                maxLines: memo.memo.isEmpty ? 8 : 4,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall!
                    .copyWith(height: 1.5, color: ink.withOpacity(0.8)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall!.copyWith(color: muted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ttuPercent(memo.progress),
                    style: textTheme.labelSmall!.copyWith(color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a memo colour's name, such as Words; pops with the name, empty
/// to take it away.
class _ColorNameDialog extends StatefulWidget {
  const _ColorNameDialog({required this.color});

  final TtuMemoColor color;

  @override
  State<_ColorNameDialog> createState() => _ColorNameDialogState();
}

class _ColorNameDialogState extends State<_ColorNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.color.customName ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: widget.color.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(t.ttu_memos_color_name)),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.color.label),
        onSubmitted: (text) => Navigator.pop(context, text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.dialog_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(t.dialog_save),
        ),
      ],
    );
  }
}
