import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show FontFeature;

import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:yuuna/language.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Corner radius shared by the reader's sheets and cards.
const double ttuCardRadius = 16;

/// Opens one of the reader's bottom sheets with rounded top corners.
Future<T?> showTtuSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).cardColor,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: builder,
  );
}

/// Position as a short percentage, with one decimal under ten percent.
String ttuPercent(double progress) {
  if (progress >= 1) {
    return '100%';
  }
  if (progress < 0.1) {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }
  return '${(progress * 100 + 1e-9).floor()}%';
}

/// A count with thousands separators.
String ttuCount(int value) => intl.NumberFormat.decimalPattern().format(value);

/// The unit for character counts in [language].
String ttuCharacterUnit(Language language) =>
    language is JapaneseLanguage ? '字' : ' chars';

/// How long ago [time] was, in plain words.
String ttuAgo(DateTime time) {
  Duration since = DateTime.now().difference(time);
  if (since.inMinutes < 1) {
    return t.ttu_just_now;
  }
  if (since.inHours < 1) {
    return t.ttu_minutes_ago(n: since.inMinutes);
  }
  if (since.inDays < 1) {
    return t.ttu_today;
  }
  if (since.inDays == 1) {
    return t.ttu_yesterday;
  }
  if (since.inDays < 7) {
    return t.ttu_days_ago(n: since.inDays);
  }
  if (since.inDays < 30) {
    int weeks = (since.inDays / 7).round();
    return weeks == 1 ? t.ttu_week_ago : t.ttu_weeks_ago(n: weeks);
  }
  int months = (since.inDays / 30).round();
  return months == 1 ? t.ttu_month_ago : t.ttu_months_ago(n: months);
}

/// Quotation marks that suit [language].
String ttuQuote(Language language, String text) =>
    language is JapaneseLanguage ? '「$text」' : '“$text”';

/// The small bar at the top of a sheet that shows it can be dragged.
class TtuSheetHandle extends StatelessWidget {
  /// Create the handle.
  const TtuSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 4,
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).unselectedWidgetColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// A book's cover, or a plain tile with its title when it has none.
class TtuCover extends StatelessWidget {
  /// Show the cover of [book].
  const TtuCover({
    required this.book,
    this.width,
    this.radius = 4,
    this.overrideImage,
    super.key,
  });

  /// The book to show.
  final TtuBook book;

  /// Width of the cover. Height follows the book cover aspect ratio.
  final double? width;

  /// Corner radius.
  final double radius;

  /// A cover chosen by the user, shown instead of the book's own.
  final ImageProvider? overrideImage;

  @override
  Widget build(BuildContext context) {
    String? coverPath = book.coverPath;
    ImageProvider? chosen = overrideImage;
    Widget image = chosen != null
        ? Image(image: chosen, fit: BoxFit.cover, gaplessPlayback: true)
        : coverPath == null
            ? ColoredBox(
                color: Colors.grey.shade800,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      book.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 9),
                    ),
                  ),
                ),
              )
            : Image(
                image: FileImage(File(coverPath)),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: Colors.grey.shade800),
              );

    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: ReaderTtuSource.instance.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: image,
        ),
      ),
    );
  }
}

/// What the memo editor saves: the memo's text and colour.
typedef TtuMemoDraft = ({String text, TtuMemoColor color});

/// Opens the memo editor. Resolves to the memo, or null when cancelled. A
/// new memo starts in the colour picked last. With [onDelete], the editor
/// also offers Delete.
Future<TtuMemoDraft?> showTtuMemoEditor({
  required BuildContext context,
  required TtuBook book,
  required String excerpt,
  required double progress,
  required int characters,
  String initialMemo = '',
  TtuMemoColor? initialColor,
  bool isNew = true,
  VoidCallback? onDelete,
}) {
  return showTtuSheet<TtuMemoDraft>(
    context: context,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: TtuMemoEditor(
        book: book,
        excerpt: excerpt,
        progress: progress,
        characters: characters,
        initialMemo: initialMemo,
        initialColor: initialColor ?? ReaderTtuSource.instance.lastMemoColor,
        isNew: isNew,
        onDelete: onDelete,
      ),
    ),
  );
}

/// The sheet for writing or changing a memo.
class TtuMemoEditor extends StatefulWidget {
  /// Create the editor.
  const TtuMemoEditor({
    required this.book,
    required this.excerpt,
    required this.progress,
    required this.characters,
    required this.initialMemo,
    required this.initialColor,
    required this.isNew,
    this.onDelete,
    super.key,
  });

  /// The book the memo belongs to.
  final TtuBook book;

  /// The memo's colour when the editor opens.
  final TtuMemoColor initialColor;

  /// The quoted line.
  final String excerpt;

  /// Position as a fraction from 0 to 1.
  final double progress;

  /// Position in characters.
  final int characters;

  /// Text already written.
  final String initialMemo;

  /// Whether this is a new memo.
  final bool isNew;

  /// Deletes the memo. Only offered when editing.
  final VoidCallback? onDelete;

  @override
  State<TtuMemoEditor> createState() => _TtuMemoEditorState();
}

class _TtuMemoEditorState extends State<TtuMemoEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialMemo);
  late TtuMemoColor _color = widget.initialColor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    ReaderTtuSource.instance.setLastMemoColor(_color);
    Navigator.pop(context, (text: _controller.text.trim(), color: _color));
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color muted = theme.unselectedWidgetColor;
    VoidCallback? onDelete = widget.onDelete;
    bool reduceMotion = MediaQuery.of(context).disableAnimations;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TtuSheetHandle(),
          const SizedBox(height: 8),
          Text(
            widget.isNew ? t.ttu_new_memo : t.ttu_edit_memo,
            style: theme.textTheme.titleMedium!
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          // The quoted line, highlighted as it will be on the page.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              constraints: const BoxConstraints(maxHeight: 110),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: _color.color.withOpacity(0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: Text(
                  ttuQuote(widget.book.language, widget.excerpt),
                  style: theme.textTheme.bodyLarge!.copyWith(height: 1.6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.book.title} · ${ttuPercent(widget.progress)} · '
            '${ttuCount(widget.characters)}${ttuCharacterUnit(widget.book.language)}',
            style: theme.textTheme.bodySmall!.copyWith(color: muted),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: t.ttu_memo,
                hintText: t.ttu_memo_placeholder,
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
          ),
          const SizedBox(height: 6),
          TtuMemoColorPicker(
            selected: _color,
            onChanged: (color) => setState(() => _color = color),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (onDelete != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                  child: Text(
                    t.ttu_delete,
                    style: TextStyle(color: muted),
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.dialog_cancel),
              ),
              TextButton(
                onPressed: _save,
                child: Text(
                  t.dialog_save,
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Paints a book's progress with memo marks and the reading position.
class TtuMemoStripPainter extends CustomPainter {
  /// Create the painter. [animation] drops the marks in when the sheet opens.
  TtuMemoStripPainter({
    required this.read,
    required this.current,
    required this.marks,
    required this.trackColor,
    required this.readColor,
    required this.surfaceColor,
    required this.animation,
  }) : super(repaint: animation);

  /// Furthest point read, from 0 to 1.
  final double read;

  /// Current reading position, from 0 to 1.
  final double current;

  /// Memo positions, from 0 to 1, with each memo's colour.
  final List<({double at, Color color})> marks;

  /// Colour of the unread track.
  final Color trackColor;

  /// Colour of the read part and the position dot.
  final Color readColor;

  /// Colour behind the strip, used to ring the position dot.
  final Color surfaceColor;

  /// Drives the drop-in of the marks.
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    double trackY = size.height - 10;
    Paint paint = Paint()..color = trackColor;
    RRect track = RRect.fromLTRBR(
      0,
      trackY - 2,
      size.width,
      trackY + 2,
      const Radius.circular(2),
    );
    canvas.drawRRect(track, paint);
    canvas.save();
    canvas.clipRRect(track);
    canvas.drawRect(
      Rect.fromLTRB(0, trackY - 2, size.width * read.clamp(0, 1), trackY + 2),
      Paint()..color = readColor.withOpacity(0.85),
    );
    canvas.restore();

    List<({double at, Color color})> sorted = [...marks]
      ..sort((a, b) => a.at.compareTo(b.at));
    for (int i = 0; i < sorted.length; i++) {
      double local =
          ((animation.value * 420 - i * 24) / 240).clamp(0, 1).toDouble();
      double eased = Curves.easeOutCubic.transform(local);
      double x = size.width * sorted[i].at.clamp(0, 1);
      double top = trackY - 22 - (1 - eased) * 6;
      Paint mark = Paint()..color = sorted[i].color.withOpacity(eased);
      Path flag = Path()
        ..moveTo(x - 5, top)
        ..lineTo(x + 5, top)
        ..lineTo(x + 5, top + 13)
        ..lineTo(x, top + 9)
        ..lineTo(x - 5, top + 13)
        ..close();
      canvas.drawPath(flag, mark);
    }

    double cx = size.width * current.clamp(0, 1);
    canvas.drawCircle(Offset(cx, trackY), 7, Paint()..color = surfaceColor);
    canvas.drawCircle(Offset(cx, trackY), 5, Paint()..color = readColor);
  }

  @override
  bool shouldRepaint(TtuMemoStripPainter oldDelegate) {
    return oldDelegate.read != read ||
        oldDelegate.current != current ||
        oldDelegate.marks.length != marks.length ||
        !oldDelegate.marks.every(marks.contains) ||
        oldDelegate.trackColor != trackColor;
  }
}

/// The sheet listing a book's memos.
class TtuMemoSheet extends BasePage {
  /// Create the sheet for [book].
  const TtuMemoSheet({
    required this.book,
    required this.onOpen,
    super.key,
  });

  /// The book whose memos are shown.
  final TtuBook book;

  /// Opens the book: at a memo when one is given, back at a position when
  /// one is given, or else where ッツ last saved.
  final void Function({ReaderMemo? memo, TtuPosition? returnTo}) onOpen;

  @override
  BasePageState<TtuMemoSheet> createState() => _TtuMemoSheetState();
}

class _TtuMemoSheetState extends BasePageState<TtuMemoSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  ScrollController? _listController;
  ReaderMemo? _deleted;
  Timer? _undoTimer;
  bool _newestFirst = false;
  int? _flashId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (MediaQuery.of(context).disableAnimations) {
        _drop.value = 1;
      } else {
        Future.delayed(const Duration(milliseconds: 140), () {
          if (mounted) {
            _drop.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _drop.dispose();
    _undoTimer?.cancel();
    super.dispose();
  }

  TtuBook get book => widget.book;

  void _edit(ReaderMemo memo) async {
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

  /// Deletes at once, with an Undo bar inside the sheet for four seconds.
  void _delete(ReaderMemo memo) async {
    await appModelNoUpdate.deleteReaderMemo(memo);
    if (!mounted) {
      return;
    }
    setState(() => _deleted = memo);
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _deleted = null);
      }
    });
  }

  void _undo() {
    ReaderMemo? memo = _deleted;
    _undoTimer?.cancel();
    setState(() => _deleted = null);
    if (memo != null) {
      appModelNoUpdate.putReaderMemo(memo);
    }
  }

  Widget _buildUndoBar() {
    return Container(
      key: const ValueKey('undo'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF323232),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.ttu_memo_deleted,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: _undo,
            child: Text(
              t.ttu_undo.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFFF8A80),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _jumpToRow(List<ReaderMemo> memos, double fraction) {
    if (memos.isEmpty) {
      return;
    }
    ReaderMemo nearest = memos.reduce((a, b) =>
        (a.progress - fraction).abs() <= (b.progress - fraction).abs() ? a : b);
    int index = memos.indexOf(nearest);
    setState(() => _flashId = nearest.id);
    ScrollController? list = _listController;
    if (list != null && list.hasClients) {
      list.animateTo(
        min(list.position.maxScrollExtent, 132.0 + index * 92.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _flashId = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<ReaderMemo> all =
        ref.watch(ttuMemosProvider).valueOrNull ?? const <ReaderMemo>[];
    List<ReaderMemo> memos =
        all.where((memo) => memo.bookKey == book.key).toList();
    memos.sort(_newestFirst
        ? (a, b) => b.createdAt.compareTo(a.createdAt)
        : (a, b) => a.exploredCharCount.compareTo(b.exploredCharCount));

    TtuPosition? back = ReaderTtuSource.instance.returnPositions[book.key];
    Color muted = theme.unselectedWidgetColor;
    Color red = theme.colorScheme.primary;
    String unit = ttuCharacterUnit(book.language);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) {
        _listController = controller;
        return Column(
          children: [
            const TtuSheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: Row(
                children: [
                  TtuCover(book: book, width: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium!
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${t.ttu_read_percent(percent: ttuPercent(book.progress))} · '
                          '${ttuCount(book.totalCharacters)}$unit',
                          style: textTheme.bodySmall!.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: t.dialog_close,
                    icon: const Icon(Ui.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _jumpToRow(
                    memos,
                    details.localPosition.dx / constraints.maxWidth,
                  ),
                  child: RepaintBoundary(
                    child: SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: TtuMemoStripPainter(
                          read: book.progress,
                          current: book.progress,
                          marks: [
                            for (ReaderMemo memo in memos)
                              (
                                at: memo.progress,
                                color: TtuMemoColor.ofMemo(memo).color,
                              ),
                          ],
                          trackColor: muted.withOpacity(0.25),
                          readColor: red,
                          surfaceColor: theme.cardColor,
                          animation: _drop,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  _ActionRow(
                    icon: Ui.play_arrow_rounded,
                    iconColor: red,
                    title: t.ttu_continue_reading,
                    subtitle: ttuPercent(book.progress),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onOpen();
                    },
                  ),
                  if (back != null)
                    _ActionRow(
                      icon: Ui.undo_rounded,
                      iconColor: muted,
                      title: t.ttu_back_to_where,
                      subtitle:
                          '${ttuPercent(back.progress)} · ${t.ttu_before_jump}',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onOpen(returnTo: back);
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 2),
                    child: Row(
                      children: [
                        Text(
                          memos.isEmpty
                              ? t.ttu_no_memos_short
                              : '${t.ttu_memos} · ${memos.length}',
                          style: textTheme.labelMedium!.copyWith(color: muted),
                        ),
                        JidoujishoInfoButton(
                            message: t.ttu_memo_hint, size: 14),
                        const Spacer(),
                        if (memos.length > 1) ...[
                          _SortButton(
                            label: t.ttu_sort_position,
                            selected: !_newestFirst,
                            onTap: () => setState(() => _newestFirst = false),
                          ),
                          _SortButton(
                            label: t.ttu_sort_newest,
                            selected: _newestFirst,
                            onTap: () => setState(() => _newestFirst = true),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (memos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        t.ttu_no_memos,
                        style: textTheme.bodyMedium!.copyWith(color: muted),
                      ),
                    ),
                  for (ReaderMemo memo in memos)
                    Dismissible(
                      key: ValueKey(memo.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red.shade700,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(
                          Ui.delete_outline,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) => _delete(memo),
                      child: _MemoRow(
                        memo: memo,
                        book: book,
                        flash: _flashId == memo.id,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onOpen(memo: memo);
                        },
                        onEdit: () => _edit(memo),
                      ),
                    ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child:
                  _deleted == null ? const SizedBox.shrink() : _buildUndoBar(),
            ),
          ],
        );
      },
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected
              ? theme.colorScheme.primary
              : theme.unselectedWidgetColor,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    TextTheme textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            SizedBox(width: 44, child: Icon(icon, color: iconColor)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium!
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).unselectedWidgetColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoRow extends StatelessWidget {
  const _MemoRow({
    required this.memo,
    required this.book,
    required this.flash,
    required this.onTap,
    required this.onEdit,
  });

  final ReaderMemo memo;
  final TtuBook book;
  final bool flash;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    Color muted = theme.unselectedWidgetColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: flash
            ? theme.colorScheme.primary.withOpacity(0.14)
            : Colors.transparent,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.4)),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: TtuMemoFlag(color: TtuMemoColor.ofMemo(memo).color),
              ),
              SizedBox(
                width: 54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ttuPercent(memo.progress),
                      style: textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '${ttuCount(memo.exploredCharCount)}${ttuCharacterUnit(book.language)}',
                      style: textTheme.labelSmall!.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (memo.memo.isNotEmpty)
                      Text(
                        memo.memo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium!
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    Text(
                      ttuQuote(book.language, memo.excerpt),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall!.copyWith(
                        height: 1.5,
                        color: textTheme.bodySmall!.color!.withOpacity(0.75),
                      ),
                    ),
                    Text(
                      ttuAgo(memo.createdAt),
                      style: textTheme.labelSmall!.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t.ttu_edit_memo,
                icon: Icon(Ui.edit_outlined, size: 19, color: muted),
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sheet shown on long-pressing a book.
class TtuBookDetailsSheet extends BasePage {
  /// Create the sheet for [book].
  const TtuBookDetailsSheet({
    required this.book,
    required this.memoCount,
    required this.onRead,
    required this.onMemos,
    required this.onEdit,
    required this.onDelete,
    this.onLanguage,
    this.termCount = 0,
    this.onTerms,
    super.key,
  });

  /// How many terms were saved from the book.
  final int termCount;

  /// Lists the terms saved from the book.
  final VoidCallback? onTerms;

  /// The book shown.
  final TtuBook book;

  /// Changes the language the book's words are looked up in.
  final ValueChanged<Language>? onLanguage;

  /// How many memos the book has.
  final int memoCount;

  /// Opens the book.
  final VoidCallback onRead;

  /// Opens the book's memos.
  final VoidCallback onMemos;

  /// Edits the title and cover.
  final VoidCallback onEdit;

  /// Deletes the book.
  final VoidCallback onDelete;

  @override
  BasePageState<TtuBookDetailsSheet> createState() =>
      _TtuBookDetailsSheetState();
}

class _TtuBookDetailsSheetState extends BasePageState<TtuBookDetailsSheet> {
  late Language _language = widget.book.language;

  /// Switches to the next shelf language. With two languages, a tap swaps.
  void _nextLanguage() {
    List<Language> languages = ReaderTtuSource.instance.shelfLanguages;
    Language next =
        languages[(languages.indexOf(_language) + 1) % languages.length];
    setState(() => _language = next);
    widget.onLanguage?.call(next);
  }

  Widget _stat({
    required String label,
    required String value,
    required String detail,
    double? meter,
    VoidCallback? onTap,
  }) {
    Color muted = theme.unselectedWidgetColor;
    Widget tile = _statBody(
      label: label,
      value: value,
      detail: detail,
      meter: meter,
      muted: muted,
      trailing: onTap == null
          ? null
          : Icon(Ui.translate, size: 18, color: theme.colorScheme.primary),
    );
    if (onTap == null) {
      return tile;
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ttuCardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(ttuCardRadius),
        onTap: onTap,
        child: tile,
      ),
    );
  }

  Widget _statBody({
    required String label,
    required String value,
    required String detail,
    required Color muted,
    double? meter,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ttuCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: textTheme.labelSmall!.copyWith(color: muted)),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          if (meter == null)
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall!.copyWith(color: muted),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: meter.clamp(0, 1),
                  minHeight: 3,
                  backgroundColor: muted.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? background,
    Color? foreground,
  }) {
    return Material(
      color: background ?? theme.dividerColor.withOpacity(0.08),
      borderRadius: BorderRadius.circular(ttuCardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(ttuCardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: foreground),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.labelMedium!.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
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
    TtuBook book = widget.book;
    String unit = ttuCharacterUnit(book.language);
    int read = (book.progress * book.totalCharacters).round();
    Color red = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TtuSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 14),
            child: Row(
              children: [
                TtuCover(book: book, width: 52, radius: 6),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    book.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2,
            children: [
              _stat(
                label: t.ttu_progress,
                value: ttuPercent(book.progress),
                detail: '',
                meter: book.progress,
              ),
              _stat(
                label: t.ttu_read_label,
                value: ttuCount(read),
                detail: t.ttu_of_total(
                    total: '${ttuCount(book.totalCharacters)}$unit'),
              ),
              _stat(
                label: t.ttu_last_opened,
                value: book.lastBookOpen > 0
                    ? ttuAgo(
                        DateTime.fromMillisecondsSinceEpoch(book.lastBookOpen))
                    : t.ttu_not_opened,
                detail: book.lastBookModified > 0
                    ? t.ttu_added_when(
                        when: ttuAgo(DateTime.fromMillisecondsSinceEpoch(
                                book.lastBookModified))
                            .toLowerCase())
                    : '',
              ),
              _stat(
                label: t.ttu_language,
                value: _language.languageName,
                detail: '',
                onTap: widget.onLanguage == null ? null : _nextLanguage,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: red,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: widget.onRead,
              icon: const Icon(Ui.play_arrow_rounded, size: 20),
              label: Text(
                book.progress > 0 ? t.ttu_continue : t.ttu_read,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _action(
                  icon: Ui.edit_note,
                  label: widget.memoCount > 0
                      ? '${t.ttu_memos} · ${widget.memoCount}'
                      : t.ttu_memos,
                  onTap: widget.onMemos,
                ),
              ),
              if (widget.onTerms != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _action(
                    icon: Ui.myWords,
                    label: widget.termCount > 0
                        ? '${t.ttu_terms} · ${widget.termCount}'
                        : t.ttu_terms,
                    onTap: widget.onTerms!,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _action(
                  icon: Ui.edit_outlined,
                  label: t.ttu_edit,
                  onTap: widget.onEdit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _action(
                  icon: Ui.delete_outline,
                  label: t.ttu_delete,
                  foreground: Colors.red.shade400,
                  onTap: widget.onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The reader's settings in one sheet: page settings per language that ッツ
/// applies, and the app's own reading options.
class TtuReaderSettingsSheet extends BasePage {
  /// Create the sheet. [languages] are the languages that have books.
  const TtuReaderSettingsSheet({
    required this.languages,
    this.onOpenTtuPage,
    this.onPresetChanged,
    this.onOptionsChanged,
    this.extraFonts = const [],
    super.key,
  });

  /// Languages with books on the shelf. A switch appears when there are two.
  final List<Language> languages;

  /// Opens one of ッツ's own pages, such as `manage.html`, for a language.
  /// Without it, as over an open book, those links are left out.
  final void Function(Language language, String page)? onOpenTtuPage;

  /// Set over an open book: shows each page change on the book itself. The
  /// flag is true for changes ッツ must lay the book out again for, such as
  /// the direction or layout.
  final void Function(TtuPagePreset preset, {required bool structural})?
      onPresetChanged;

  /// Set over an open book: a reading option such as full screen changed.
  final VoidCallback? onOptionsChanged;

  /// Fonts the user added in ッツ's settings.
  final List<String> extraFonts;

  /// Whether the sheet is over an open book.
  bool get live => onPresetChanged != null;

  @override
  BasePageState<TtuReaderSettingsSheet> createState() =>
      _TtuReaderSettingsSheetState();
}

class _TtuReaderSettingsSheetState
    extends BasePageState<TtuReaderSettingsSheet> {
  ReaderTtuSource get source => ReaderTtuSource.instance;
  late Language _language =
      widget.languages.contains(appModelNoUpdate.targetLanguage) ||
              widget.languages.isEmpty
          ? appModelNoUpdate.targetLanguage
          : widget.languages.first;
  late TtuPagePreset _preset = source.presetFor(_language);

  void _toggle(void Function() change) async {
    change();
    setState(() {});

    /// The preference is written asynchronously; let it land first.
    await Future<void>.delayed(Duration.zero);
    widget.onOptionsChanged?.call();
  }

  void _update(void Function(TtuPagePreset preset) change) {
    bool vertical = _preset.vertical;
    bool paginated = _preset.paginated;
    int columns = _preset.columns;
    setState(() => change(_preset));
    source.savePreset(_language, _preset);
    bool structural = vertical != _preset.vertical ||
        paginated != _preset.paginated ||
        columns != _preset.columns;
    widget.onPresetChanged?.call(_preset, structural: structural);
  }

  /// Font names and their labels: ッツ's own, then the user's.
  List<MapEntry<String, String>> get _fonts => [
        MapEntry('', t.ttu_font_serif),
        MapEntry('Noto Sans JP', t.ttu_font_sans),
        MapEntry('Shippori Mincho', t.ttu_font_mincho),
        MapEntry('Klee One', t.ttu_font_klee),
        MapEntry('Genei Koburi Mincho v5', t.ttu_font_genei),
        for (String font in widget.extraFonts.isNotEmpty
            ? widget.extraFonts
            : source.userFontsFor(_language))
          MapEntry(font, font),
      ];

  /// The fonts as a row of chips that scrolls when there are many.
  Widget _fontChips() {
    String selected = _preset.fontFamily;
    if (!_fonts.any((font) => font.key == selected)) {
      selected = '';
    }
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (MapEntry<String, String> font in _fonts)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  font.value,
                  style: TextStyle(
                    fontFamily: _previewFamilyOf(font.key),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: font.key == selected,
                showCheckmark: false,
                shape: const StadiumBorder(),
                selectedColor: theme.colorScheme.primary.withOpacity(0.18),
                onSelected: (_) =>
                    _update((preset) => preset.fontFamily = font.key),
              ),
            ),
        ],
      ),
    );
  }

  /// The bundled font that draws a sample of [font] in the preview.
  String? _previewFamilyOf(String font) {
    switch (font) {
      case '':
        return 'PreviewSerif';
      case 'Noto Sans JP':
        return 'NotoSansJP';
      case 'Shippori Mincho':
        return 'PreviewMincho';
      case 'Klee One':
        return 'PreviewKlee';
      case 'Genei Koburi Mincho v5':
        return 'PreviewGenei';
    }
    return null;
  }

  String get _effectiveTheme =>
      _preset.theme ?? (appModelNoUpdate.isDarkMode ? 'dark' : 'light');

  Widget _group(String title, {String? info}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 2),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: textTheme.labelMedium!.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          if (info != null) JidoujishoInfoButton(message: info, size: 14),
        ],
      ),
    );
  }

  /// A setting that is on or off. The whole row toggles it.
  Widget _switch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? info,
    bool indent = false,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.fromLTRB(indent ? 36 : 20, 2, 12, 2),
        child: Row(
          children: [
            Flexible(child: Text(title, style: textTheme.bodyMedium)),
            if (info != null) JidoujishoInfoButton(message: info),
            const Spacer(),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, Widget trailing, {String? info}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 16, 6),
      child: Row(
        children: [
          Flexible(child: Text(title, style: textTheme.bodyMedium)),
          if (info != null) JidoujishoInfoButton(message: info),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }

  /// A number with minus and plus buttons.
  Widget _stepper({
    required String value,
    required VoidCallback? onLess,
    required VoidCallback? onMore,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(icon: Ui.remove, onTap: onLess),
        SizedBox(
          width: 44,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge!.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _RoundButton(icon: Ui.add, onTap: onMore),
      ],
    );
  }

  Widget _segmented<T>({
    required List<T> values,
    required List<String> labels,
    required T selected,
    required ValueChanged<T> onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < values.length; i++)
            GestureDetector(
              onTap: () => onSelect(values[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: values[i] == selected
                      ? theme.cardColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: values[i] == selected
                      ? const [
                          BoxShadow(color: Colors.black26, blurRadius: 3),
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  style: textTheme.labelMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: values[i] == selected
                        ? null
                        : theme.unselectedWidgetColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The bundled font that draws the chosen ッツ font in the preview.
  String? get _previewFontFamily => _previewFamilyOf(_preset.fontFamily);

  Widget _preview() {
    List<int> colors = TtuPagePreset.themeColors[_effectiveTheme]!;
    Color background = Color(colors[0]);
    Color foreground = Color(colors[1]);
    double size = _preset.fontSize * 0.72;
    String sample = _language is JapaneseLanguage
        ? '吾輩は猫である。名前はまだ無い。どこで生れたかとんと見当がつかぬ。何でも薄暗いじめじめした所で泣いていた事だけは記憶している。'
        : 'Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do.';
    TextStyle style = TextStyle(
      color: foreground,
      fontSize: size,
      height: _preset.lineHeight,
      fontFamily: _previewFontFamily,
    );

    Widget content = _preset.vertical
        ? LayoutBuilder(
            builder: (context, constraints) {
              double column = size * _preset.lineHeight;
              int perColumn =
                  max(1, (constraints.maxHeight / (size * 1.05)).floor());
              int columns = max(1, (constraints.maxWidth / column).floor());
              List<String> characters = sample.characters.toList();
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int c = columns - 1; c >= 0; c--)
                    SizedBox(
                      width: column,
                      child: Column(
                        children: [
                          for (int i = c * perColumn;
                              i < min(characters.length, (c + 1) * perColumn);
                              i++)
                            SizedBox(
                              height: size * 1.05,
                              child: Text(
                                characters[i],
                                style: style.copyWith(height: 1),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          )
        : Text(sample, style: style, overflow: TextOverflow.fade);

    double inset = 10 + _preset.margin * 0.3;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 116,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: _preset.vertical
          ? EdgeInsets.fromLTRB(inset + 4, 10, inset + 4, 10)
          : EdgeInsets.fromLTRB(14, inset, 14, inset),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ttuCardRadius),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: ClipRect(child: content),
    );
  }

  /// The furigana choice as one value: shown, or how it is hidden.
  String get _furiganaChoice =>
      _preset.furigana ? 'show' : _preset.furiganaStyle;

  void _setFurigana(String choice) {
    _update((preset) {
      preset.furigana = choice == 'show';
      if (choice != 'show') {
        preset.furiganaStyle = choice;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Language> languages = widget.languages;
    bool hasScroll = !_preset.paginated;
    bool japanese = _language is JapaneseLanguage;

    bool live = widget.live;
    void Function(Language language, String page)? openTtuPage =
        widget.onOpenTtuPage;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: live ? 0.5 : 0.8,
      minChildSize: live ? 0.3 : 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const TtuSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.ttu_reader_settings,
                    style: textTheme.titleLarge!
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
          _group(t.ttu_page, info: live ? null : t.ttu_page_info),
          if (!live && languages.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _segmented<Language>(
                  values: languages,
                  labels: languages
                      .map((language) =>
                          t.ttu_books_in(language: language.languageName))
                      .toList(),
                  selected: _language,
                  onSelect: (language) => setState(() {
                    _language = language;
                    _preset = source.presetFor(language);
                  }),
                ),
              ),
            ),
          if (!live) _preview(),
          SizedBox(
            height: 74,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              children: [
                for (String name in TtuPagePreset.themes)
                  _ThemeSwatch(
                    name: name,
                    selected: _effectiveTheme == name,
                    sample: japanese ? 'あ' : 'Aa',
                    onTap: () => _update((preset) => preset.theme = name),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: Text(t.ttu_font, style: textTheme.bodyMedium),
          ),
          _fontChips(),
          _row(
            t.ttu_text_size,
            _stepper(
              value: '${_preset.fontSize}',
              onLess: _preset.fontSize > 12
                  ? () => _update((preset) => preset.fontSize -= 2)
                  : null,
              onMore: _preset.fontSize < 48
                  ? () => _update((preset) => preset.fontSize += 2)
                  : null,
            ),
          ),
          _row(
            t.ttu_line_spacing,
            _stepper(
              value: _preset.lineHeight.toStringAsFixed(1),
              onLess: _preset.lineHeight > 1.25
                  ? () => _update((preset) => preset.lineHeight =
                      ((preset.lineHeight - 0.1) * 10).round() / 10)
                  : null,
              onMore: _preset.lineHeight < 2.45
                  ? () => _update((preset) => preset.lineHeight =
                      ((preset.lineHeight + 0.1) * 10).round() / 10)
                  : null,
            ),
          ),
          _row(
            t.ttu_margins,
            _stepper(
              value: '${_preset.margin}',
              onLess: _preset.margin > 0
                  ? () => _update((preset) => preset.margin -= 8)
                  : null,
              onMore: _preset.margin < 96
                  ? () => _update((preset) => preset.margin += 8)
                  : null,
            ),
          ),
          _row(
            t.ttu_direction,
            _segmented<bool>(
              values: const [true, false],
              labels: [t.ttu_vertical, t.ttu_horizontal],
              selected: _preset.vertical,
              onSelect: (value) => _update((preset) => preset.vertical = value),
            ),
          ),
          _row(
            t.ttu_layout,
            _segmented<bool>(
              values: const [true, false],
              labels: [t.ttu_pages, t.ttu_scroll],
              selected: _preset.paginated,
              onSelect: (value) =>
                  _update((preset) => preset.paginated = value),
            ),
          ),
          if (_preset.paginated)
            _row(
              t.ttu_columns,
              _segmented<int>(
                values: const [0, 1, 2],
                labels: [t.ttu_columns_auto, '1', '2'],
                selected: _preset.columns,
                onSelect: (value) =>
                    _update((preset) => preset.columns = value),
              ),
            ),
          if (japanese)
            _row(
              t.ttu_furigana_label,
              _segmented<String>(
                values: const ['show', 'partial', 'full', 'toggle'],
                labels: [
                  t.ttu_furigana_show,
                  t.ttu_furigana_faded,
                  t.ttu_furigana_hidden,
                  t.ttu_furigana_tap,
                ],
                selected: _furiganaChoice,
                onSelect: _setFurigana,
              ),
              info: t.ttu_furigana_info,
            ),
          _switch(
            title: t.ttu_avoid_break,
            info: t.ttu_avoid_break_info,
            value: _preset.avoidPageBreak,
            onChanged: (value) =>
                _update((preset) => preset.avoidPageBreak = value),
          ),
          _switch(
            title: t.ttu_blur_images,
            info: t.ttu_blur_images_info,
            value: _preset.blurImages,
            onChanged: (value) =>
                _update((preset) => preset.blurImages = value),
          ),
          _group(t.ttu_while_reading),
          _switch(
            title: t.ttu_full_screen,
            info: t.ttu_full_screen_info,
            value: source.fullScreen,
            onChanged: (_) => _toggle(source.toggleFullScreen),
          ),
          if (source.fullScreen)
            _switch(
              title: t.ttu_camera_area,
              info: t.ttu_camera_area_info,
              value: source.extendPageBeyondNavigationBar,
              indent: true,
              onChanged: (_) =>
                  _toggle(source.toggleExtendPageBeyondNavigationBar),
            ),
          _switch(
            title: t.ttu_memos_on_page,
            info: t.ttu_memos_on_page_info,
            value: source.showMemosOnPage,
            onChanged: (_) => _toggle(source.toggleShowMemosOnPage),
          ),
          _switch(
            title: t.ttu_keep_screen_on,
            value: source.keepScreenOn,
            onChanged: (_) => _toggle(source.toggleKeepScreenOn),
          ),
          _switch(
            title: t.ttu_auto_save,
            info: t.ttu_auto_save_info,
            value: source.autoSavePosition,
            onChanged: (_) => _toggle(source.toggleAutoSavePosition),
          ),
          _switch(
            title: t.ttu_highlight,
            value: source.highlightOnTap,
            onChanged: (_) => _toggle(source.toggleHighlightOnTap),
          ),
          _switch(
            title: t.ttu_match_popup,
            info: t.ttu_match_popup_info,
            value: source.adaptTtuTheme,
            onChanged: (_) => _toggle(source.toggleAdaptTtuTheme),
          ),
          _switch(
            title: t.ttu_volume,
            value: source.volumePageTurningEnabled,
            onChanged: (_) => _toggle(source.toggleVolumePageTurningEnabled),
          ),
          if (source.volumePageTurningEnabled)
            _switch(
              title: t.ttu_volume_swap,
              value: source.volumePageTurningInverted,
              indent: true,
              onChanged: (_) => _toggle(source.toggleVolumePageTurningInverted),
            ),
          if (source.volumePageTurningEnabled && hasScroll)
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 4, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(t.ttu_scroll_step, style: textTheme.bodyMedium),
                      JidoujishoInfoButton(message: t.ttu_scroll_step_info),
                      const Spacer(),
                      Text(
                        '${source.volumePageTurningSpeed}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Slider(
                    value:
                        source.volumePageTurningSpeed.clamp(20, 400).toDouble(),
                    min: 20,
                    max: 400,
                    divisions: 38,
                    onChanged: (value) => _toggle(
                        () => source.setVolumePageTurningSpeed(value.round())),
                  ),
                ],
              ),
            ),
          if (openTtuPage != null) _group(t.ttu_more),
          if (openTtuPage != null)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Ui.cloud_upload_outlined),
              title: Text(t.ttu_backup_sync),
              trailing: const Icon(Ui.chevron_right),
              onTap: () {
                Navigator.pop(context);
                openTtuPage(_language, 'manage.html');
              },
            ),
          if (openTtuPage != null)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Ui.tune),
              title: Text(t.ttu_all_settings),
              trailing: const Icon(Ui.chevron_right),
              onTap: () {
                Navigator.pop(context);
                openTtuPage(_language, 'settings.html');
              },
            ),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.name,
    required this.selected,
    required this.sample,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final String sample;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    List<int> colors = TtuPagePreset.themeColors[name]!;
    String label = '${name[0].toUpperCase()}${name.substring(1)}';
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(colors[0]),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.dividerColor.withOpacity(0.4),
                  width: selected ? 3 : 1,
                ),
              ),
              child: Text(
                sample,
                style: TextStyle(color: Color(colors[1]), fontSize: 13),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall!.copyWith(
                color: selected ? null : theme.unselectedWidgetColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;

  /// Null at the end of the range, which greys the button out.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Material(
      color: theme.dividerColor.withOpacity(0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? theme.disabledColor : null,
          ),
        ),
      ),
    );
  }
}

/// A sheet listing the reader sources, replacing the old source dialog.
class TtuSourcePickerSheet extends BasePage {
  /// Create the sheet.
  const TtuSourcePickerSheet({super.key});

  @override
  BasePageState<TtuSourcePickerSheet> createState() =>
      _TtuSourcePickerSheetState();
}

class _TtuSourcePickerSheetState extends BasePageState<TtuSourcePickerSheet> {
  @override
  Widget build(BuildContext context) {
    MediaType mediaType = ReaderMediaType.instance;
    List<MediaSource> sources =
        appModel.mediaSources[mediaType]!.values.toList();
    MediaSource current =
        appModel.getCurrentSourceForMediaType(mediaType: mediaType);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TtuSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t.ttu_reader_source,
                style:
                    textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (MediaSource source in sources)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    selected: source == current,
                    selectedTileColor:
                        theme.colorScheme.primary.withOpacity(0.08),
                    selectedColor: theme.colorScheme.primary,
                    leading: Icon(source.icon),
                    title: Text(source.getLocalisedSourceName(appModel)),
                    trailing: source == current ? const Icon(Ui.check) : null,
                    onTap: () {
                      Navigator.pop(context);
                      appModel.setCurrentSourceForMediaType(
                        mediaType: mediaType,
                        mediaSource: source,
                      );
                      mediaType.refreshTab();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Reads the memos of every book, as a list that updates itself.
final ttuMemosProvider = StreamProvider<List<ReaderMemo>>((ref) {
  AppModel appModel = ref.read(appProvider);
  return appModel.watchReaderMemos().map((_) => appModel.readerMemos);
});

/// Text with its web addresses as links that open in the browser.
class TtuLinkedText extends StatefulWidget {
  /// Show [text] with links.
  const TtuLinkedText({
    required this.text,
    required this.style,
    super.key,
  });

  /// The text, which may hold web addresses.
  final String text;

  /// Style for the plain text.
  final TextStyle style;

  @override
  State<TtuLinkedText> createState() => _TtuLinkedTextState();
}

class _TtuLinkedTextState extends State<TtuLinkedText> {
  static final RegExp _link = RegExp(r'(https?://[^\s]+|www\.[^\s]+)');
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    TextStyle linkStyle = widget.style.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    List<InlineSpan> spans = [];
    int start = 0;
    for (RegExpMatch match in _link.allMatches(widget.text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: widget.text.substring(start, match.start)));
      }
      String link = match.group(0)!.replaceAll(RegExp(r'[.,;:!?)\]」』]+$'), '');
      TapGestureRecognizer recognizer = TapGestureRecognizer()
        ..onTap = () => launchUrl(
              Uri.parse(link.startsWith('http') ? link : 'https://$link'),
              mode: LaunchMode.externalApplication,
            );
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: link, style: linkStyle, recognizer: recognizer));
      start = match.start + link.length;
    }
    if (start < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(start)));
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

/// One memo in full, opened from its note on the page.
class TtuMemoViewSheet extends StatelessWidget {
  /// Show [memo] from [book].
  const TtuMemoViewSheet({
    required this.memo,
    required this.book,
    required this.onEdit,
    super.key,
  });

  /// The memo shown.
  final ReaderMemo memo;

  /// The book it belongs to.
  final TtuBook book;

  /// Opens the memo editor.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color muted = theme.unselectedWidgetColor;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TtuSheetHandle(),
            Row(
              children: [
                TtuMemoFlag(color: TtuMemoColor.ofMemo(memo).color, size: 18),
                const SizedBox(width: 10),
                Text(
                  '${t.ttu_memo} · ${ttuPercent(memo.progress)}',
                  style: theme.textTheme.titleMedium!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: t.ttu_edit_memo,
                  icon: Icon(Ui.edit, size: 20, color: muted),
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 8, top: 4, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (memo.memo.isNotEmpty)
                      TtuLinkedText(
                        text: memo.memo,
                        style: theme.textTheme.bodyLarge!.copyWith(height: 1.5),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                      decoration: BoxDecoration(
                        color:
                            TtuMemoColor.ofMemo(memo).color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        ttuQuote(book.language, memo.excerpt),
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: muted,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
