import 'dart:ui' show PathMetric;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Opens the kanji sheet for [character]. [onSearch] looks a word up where
/// the sheet was opened from, after the sheet closes.
Future<void> showKanjiSheet({
  required BuildContext context,
  required String character,
  required void Function(String) onSearch,
}) {
  return showTtuSheet<void>(
    context: context,
    builder: (_) => KanjiSheet(character: character, onSearch: onSearch),
  );
}

/// Strokes, readings, parts and words of a kanji, from the kanji pack. The
/// first time, it offers the pack's download instead.
class KanjiSheet extends StatefulWidget {
  /// Show [character].
  const KanjiSheet({
    required this.character,
    required this.onSearch,
    super.key,
  });

  /// The kanji tapped.
  final String character;

  /// Looks a word up where the sheet was opened from.
  final void Function(String) onSearch;

  @override
  State<KanjiSheet> createState() => _KanjiSheetState();
}

class _KanjiSheetState extends State<KanjiSheet> {
  /// The characters opened in the sheet, the one shown last.
  final List<String> _trail = [];
  KanjiPack? _pack;
  Future<KanjiInfo?>? _info;
  double? _progress;
  CancelToken? _cancel;
  bool _failed = false;
  bool _allWords = false;
  bool _allUses = false;

  ThemeData get theme => Theme.of(context);
  TextTheme get textTheme => theme.textTheme;
  Color get muted => theme.unselectedWidgetColor;

  @override
  void initState() {
    super.initState();
    _trail.add(widget.character);
    KanjiPack.instance.then((pack) {
      if (mounted) {
        setState(() {
          _pack = pack;
          _load();
        });
      }
    });
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  void _load() {
    _allWords = false;
    _allUses = false;
    if (!_pack!.isInstalled) {
      _info = null;
      return;
    }
    // The header's credits come with the pack's first read.
    _info = _pack!.lookup(_trail.last).whenComplete(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _open(String character) {
    if (character == _trail.last) {
      return;
    }
    setState(() {
      _trail.add(character);
      _load();
    });
  }

  void _back() {
    setState(() {
      _trail.removeLast();
      _load();
    });
  }

  void _search(String text) {
    Navigator.pop(context);
    widget.onSearch(text);
  }

  Future<void> _download() async {
    CancelToken cancel = _cancel = CancelToken();
    setState(() {
      _progress = 0;
      _failed = false;
    });
    try {
      await _pack!.install(
        cancelToken: cancel,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _progress = progress);
          }
        },
      );
    } catch (error) {
      debugPrint('Kanji pack download stopped: $error');
      _failed = !cancel.isCancelled;
    }
    if (mounted) {
      setState(() {
        _progress = null;
        _load();
      });
    }
  }

  Future<void> _remove() async {
    await _pack!.remove();
    if (mounted) {
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const TtuSheetHandle(),
          _header(),
          if (_pack == null)
            const SizedBox(height: 160)
          else if (!_pack!.isInstalled)
            _prompt()
          else
            FutureBuilder<KanjiInfo?>(
              future: _info,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 160);
                }
                KanjiInfo? info = snapshot.data;
                return info == null ? _nothing() : _details(info);
              },
            ),
        ],
      ),
    );
  }

  Widget _header() {
    bool installed = _pack?.isInstalled ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Row(
        children: [
          if (_trail.length > 1)
            TextButton.icon(
              onPressed: _back,
              icon: const Icon(Ui.angleLeft, size: 16),
              label:
                  Text(_trail[_trail.length - 2], style: textTheme.titleMedium),
            ),
          const Spacer(),
          IconButton(
            tooltip: t.kanji_search,
            icon: const Icon(Ui.search),
            onPressed: () => _search(_trail.last),
          ),
          if (installed && _pack!.meta.isNotEmpty)
            JidoujishoInfoButton(message: _sources(), size: 20),
          if (installed)
            PopupMenuButton<void>(
              tooltip: t.show_options,
              icon: const Icon(Ui.menuDots),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  onTap: _remove,
                  child: Row(
                    children: [
                      Icon(Ui.trash, size: 18, color: theme.colorScheme.error),
                      const SizedBox(width: 12),
                      Text(t.kanji_remove,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: t.dialog_close,
            icon: const Icon(Ui.cross),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String _sources() {
    List<dynamic> sources = _pack!.meta['sources'] as List? ?? const [];
    return t.kanji_sources(
        sources: sources
            .cast<Map<String, dynamic>>()
            .map((source) =>
                '${source['name']} (${source['by']}, ${source['licence']})')
            .join('; '));
  }

  Widget _prompt() {
    String size =
        '${(KanjiPack.downloadSize / (1 << 20)).toStringAsFixed(1)} MB';
    double? progress = _progress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        children: [
          Text(_trail.last, style: const TextStyle(fontSize: 88, height: 1.2)),
          const SizedBox(height: 12),
          Text(
            t.kanji_download_prompt(size: size),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium!.copyWith(color: muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (progress != null)
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null, minHeight: 6),
                  ),
                ),
                const SizedBox(width: 12),
                Text(ttuPercent(progress), style: textTheme.labelMedium),
                IconButton(
                  tooltip: t.dialog_cancel,
                  icon: const Icon(Ui.cross, size: 18),
                  onPressed: () => _cancel?.cancel(),
                ),
              ],
            )
          else
            FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Ui.download, size: 18),
              label: Text('${t.kanji_download} · $size'),
            ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                t.kanji_download_failed,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall!
                    .copyWith(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _nothing() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Text(_trail.last, style: const TextStyle(fontSize: 88, height: 1.2)),
          const SizedBox(height: 12),
          Text(t.kanji_no_details,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium!.copyWith(color: muted)),
        ],
      ),
    );
  }

  Widget _details(KanjiInfo info) {
    List<KanjiWord> words =
        _allWords ? info.words : info.words.take(8).toList();
    String uses =
        _allUses ? info.usedIn : info.usedIn.characters.take(24).string;
    Set<String> partCharacters = info.parts.map((p) => p.character).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(info),
        if (info.onReadings.isNotEmpty || info.kunReadings.isNotEmpty)
          _section(
            null,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (info.onReadings.isNotEmpty)
                  _reading(t.kanji_on, Text(info.onReadings.join('、'))),
                if (info.kunReadings.isNotEmpty)
                  _reading(t.kanji_kun, _kun(info.kunReadings)),
              ],
            ),
          ),
        if (info.parts.isNotEmpty)
          _section(
            t.kanji_parts,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (KanjiPart part in info.parts)
                  _tile(part.character,
                      accent: part.character == info.radical,
                      inside: part.parts.map((p) => p.character).join()),
              ],
            ),
          ),
        if (info.radical != null &&
            info.radical != info.character &&
            !partCharacters.contains(info.radical))
          _section(t.kanji_radical,
              Wrap(children: [_tile(info.radical!, accent: true)])),
        if (info.variants.isNotEmpty)
          _section(
            t.kanji_variants,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (String v in info.variants) _tile(v)],
            ),
          ),
        if (info.usedIn.isNotEmpty)
          _section(
            t.kanji_used_in,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (String c in uses.characters) _tile(c, small: true)
                  ],
                ),
                if (!_allUses && info.usedIn.characters.length > 24)
                  _more(info.usedIn.characters.length,
                      () => setState(() => _allUses = true)),
              ],
            ),
          ),
        if (info.words.isNotEmpty)
          _section(
            t.kanji_words,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (KanjiWord word in words) _word(word, info.character),
                if (!_allWords && info.words.length > words.length)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _more(info.words.length,
                        () => setState(() => _allWords = true)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _hero(KanjiInfo info) {
    List<String> facts = [
      if (info.jlpt != null) 'N${info.jlpt}',
      if (info.grade != null && info.grade! <= 6) t.kanji_grade(n: info.grade!),
      if (info.grade == 8) t.kanji_joyo,
      if (info.grade == 9 || info.grade == 10) t.kanji_jinmeiyo,
      if (info.strokes != null) t.kanji_strokes(n: info.strokes!),
      if (info.bookRank != null) t.kanji_book_rank(n: info.bookRank!),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.strokePaths.isNotEmpty)
            KanjiStrokes(
              key: ValueKey(info.character),
              paths: info.strokePaths,
              size: 128,
            )
          else
            SizedBox(
              width: 128,
              height: 128,
              child: Center(
                child: Text(info.character,
                    style: const TextStyle(fontSize: 88, height: 1)),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.hanViet.isNotEmpty)
                  Text(
                    info.hanViet.join(', ').toUpperCase(),
                    style: textTheme.titleMedium!.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                if (info.meanings.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(info.meanings.join(', '),
                        style: textTheme.bodyLarge),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (String fact in facts) _fact(fact)],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fact(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: textTheme.labelMedium),
    );
  }

  Widget _section(String? label, Widget child) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                label.toUpperCase(),
                style: textTheme.labelMedium!.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }

  Widget _reading(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(label,
                  style: textTheme.labelMedium!.copyWith(color: muted)),
            ),
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: textTheme.bodyLarge,
              child: value,
            ),
          ),
        ],
      ),
    );
  }

  /// Kun readings, their okurigana (after the dot) drawn lighter.
  Widget _kun(List<String> readings) {
    List<InlineSpan> spans = [];
    for (int i = 0; i < readings.length; i++) {
      if (i > 0) {
        spans.add(const TextSpan(text: '、'));
      }
      List<String> halves = readings[i].split('.');
      spans.add(TextSpan(text: halves.first));
      if (halves.length > 1) {
        spans.add(TextSpan(
            text: halves.skip(1).join(), style: TextStyle(color: muted)));
      }
    }
    return Text.rich(TextSpan(children: spans));
  }

  Widget _tile(
    String character, {
    bool accent = false,
    bool small = false,
    String inside = '',
  }) {
    double side = small ? 40 : 48;
    Color edge = accent ? theme.colorScheme.primary : muted.withOpacity(0.35);
    Widget tile = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(character),
        child: Container(
          width: side,
          height: side,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: edge, width: accent ? 1.6 : 1),
          ),
          child: Text(character,
              style: TextStyle(fontSize: small ? 20 : 24, height: 1)),
        ),
      ),
    );
    return inside.isEmpty ? tile : Tooltip(message: inside, child: tile);
  }

  Widget _word(KanjiWord word, String character) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _search(word.word),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  for (String c in word.word.characters)
                    TextSpan(
                      text: c,
                      style: c == character
                          ? TextStyle(color: theme.colorScheme.primary)
                          : null,
                    ),
                  TextSpan(
                    text: '  ${word.reading}',
                    style: textTheme.bodyMedium!.copyWith(color: muted),
                  ),
                ],
              ),
              style: textTheme.titleMedium,
            ),
            if (word.gloss.isNotEmpty)
              Text(
                word.gloss,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall!.copyWith(color: muted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _more(int count, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      child: Text(t.kanji_show_all(n: count)),
    );
  }
}

/// A kanji written out stroke by stroke, again on a tap.
class KanjiStrokes extends StatefulWidget {
  /// Draw [paths], KanjiVG strokes in a 109 by 109 box, at [size].
  const KanjiStrokes({required this.paths, required this.size, super.key});

  /// The strokes, in writing order.
  final List<String> paths;

  /// The width and height drawn at.
  final double size;

  @override
  State<KanjiStrokes> createState() => _KanjiStrokesState();
}

class _KanjiStrokesState extends State<KanjiStrokes>
    with SingleTickerProviderStateMixin {
  late final List<Path> _paths = widget.paths.map(_parse).toList();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_paths.length * 420).clamp(1200, 9000)),
  )..forward();

  static Path _parse(String data) {
    _PathWriter writer = _PathWriter();
    writeSvgPathDataToPath(data, writer);
    return writer.path;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Tooltip(
      message: t.replay,
      triggerMode: TooltipTriggerMode.longPress,
      child: GestureDetector(
        onTap: () => _controller.forward(from: 0),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: theme.unselectedWidgetColor.withOpacity(0.3)),
          ),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _StrokePainter(
                paths: _paths,
                progress: _controller,
                ink: theme.colorScheme.onSurface,
                pen: theme.colorScheme.primary,
                guide: theme.unselectedWidgetColor.withOpacity(0.22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PathWriter extends PathProxy {
  final Path path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
          double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}

class _StrokePainter extends CustomPainter {
  _StrokePainter({
    required this.paths,
    required this.progress,
    required this.ink,
    required this.pen,
    required this.guide,
  }) : super(repaint: progress);

  final List<Path> paths;
  final Animation<double> progress;
  final Color ink;
  final Color pen;
  final Color guide;

  @override
  void paint(Canvas canvas, Size size) {
    Paint grid = Paint()
      ..color = guide
      ..strokeWidth = 1;
    double middle = size.width / 2;
    for (double at = 6; at < size.width - 6; at += 8) {
      canvas.drawLine(Offset(at, middle), Offset(at + 3, middle), grid);
      canvas.drawLine(Offset(middle, at), Offset(middle, at + 3), grid);
    }

    canvas.save();
    canvas.scale(size.width / 109);
    Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    double done = progress.value * paths.length;
    for (int i = 0; i < paths.length; i++) {
      if (i < done.floor() || progress.value >= 1) {
        canvas.drawPath(paths[i], stroke..color = ink);
        continue;
      }
      canvas.drawPath(paths[i], stroke..color = guide);
      if (i == done.floor()) {
        double share = done - i;
        for (PathMetric metric in paths[i].computeMetrics()) {
          canvas.drawPath(metric.extractPath(0, metric.length * share),
              stroke..color = pen);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrokePainter old) =>
      old.paths != paths || old.ink != ink || old.pen != pen;
}
