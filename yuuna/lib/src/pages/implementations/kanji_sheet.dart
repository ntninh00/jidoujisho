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

/// The tints behind on and kun readings.
const Color _onHue = Color(0xFF26A69A);
const Color _kunHue = Color(0xFF5C8DD6);

/// The colour of text. The dark theme keeps the light scheme's onSurface,
/// which is black, so this goes by the text theme.
Color _ink(ThemeData theme) =>
    theme.textTheme.bodyLarge?.color ??
    (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

/// Meanings, the first one bold as the kanji's keyword.
TextSpan _meaningSpan(List<String> meanings) => TextSpan(children: [
      for (int i = 0; i < meanings.length; i++)
        i == 0
            ? TextSpan(
                text: meanings[i],
                style: const TextStyle(fontWeight: FontWeight.bold))
            : TextSpan(text: ', ${meanings[i]}'),
    ]);

/// A kanji in the sheet, with what the pack has on its parts, and which
/// reading each of its words uses.
class _Shown {
  _Shown(this.info, this.related)
      : readings = {
          for (KanjiWord word in info.words) word: info.readingIn(word)
        };

  final KanjiInfo info;

  /// Its parts and radical, by character, where the pack has them.
  final Map<String, KanjiInfo> related;

  final Map<KanjiWord, KanjiWordReading?> readings;
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
  final GlobalKey _wordsKey = GlobalKey();
  KanjiPack? _pack;
  Future<_Shown?>? _shown;
  double? _progress;
  CancelToken? _cancel;
  bool _failed = false;
  bool _allWords = false;

  /// The reading the words are narrowed to.
  String? _reading;

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
    _reading = null;
    KanjiPack pack = _pack!;
    if (!pack.isInstalled) {
      _shown = null;
      return;
    }
    // The header's credits come with the pack's first read.
    _shown = pack.lookup(_trail.last).then((info) async {
      if (info == null) {
        return null;
      }
      return _Shown(
        info,
        await pack.lookupAll([
          for (KanjiPart part in info.parts) part.character,
          if (info.radical != null) info.radical!,
        ]),
      );
    }).whenComplete(() {
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

  /// Shows only the words read with [reading], scrolled to; again, all.
  void _narrow(String reading) {
    setState(() {
      _reading = _reading == reading ? null : reading;
      _allWords = false;
    });
    if (_reading == null) {
      return;
    }
    bool still = MediaQuery.of(context).disableAnimations;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BuildContext? words = _wordsKey.currentContext;
      if (words != null) {
        Scrollable.ensureVisible(
          words,
          duration: still ? Duration.zero : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Lists the kanji [part] is used in; one picked there opens here.
  Future<void> _list(KanjiInfo part) async {
    String? picked = await showDialog<String>(
      context: context,
      builder: (_) => _KanjiList(pack: _pack!, part: part),
    );
    if (picked != null && mounted) {
      _open(picked);
    }
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
            FutureBuilder<_Shown?>(
              future: _shown,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 160);
                }
                _Shown? shown = snapshot.data;
                return shown == null ? _nothing() : _details(shown);
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

  Widget _details(_Shown shown) {
    KanjiInfo info = shown.info;
    Map<String, int> counts = {};
    for (KanjiWordReading? reading in shown.readings.values) {
      if (reading != null) {
        counts.update(reading.reading, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    List<KanjiWord> matching = _reading == null
        ? info.words
        : info.words
            .where((word) => shown.readings[word]?.reading == _reading)
            .toList();
    List<KanjiWord> words = _allWords ? matching : matching.take(8).toList();
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
                  _readings('音', t.kanji_on, info.onReadings, counts,
                      kun: false),
                if (info.kunReadings.isNotEmpty)
                  _readings('訓', t.kanji_kun, info.kunReadings, counts,
                      kun: true),
              ],
            ),
          ),
        if (info.parts.isNotEmpty)
          _section(
            t.kanji_parts,
            Wrap(
              spacing: 4,
              runSpacing: 8,
              children: [
                for (KanjiPart part in info.parts)
                  _part(part.character, shown.related[part.character],
                      accent: part.character == info.radical),
              ],
            ),
          ),
        if (info.radical != null &&
            info.radical != info.character &&
            !partCharacters.contains(info.radical))
          _section(
              t.kanji_radical,
              Wrap(children: [
                _part(info.radical!, shown.related[info.radical!],
                    accent: true),
              ])),
        if (info.variants.isNotEmpty)
          _section(
            t.kanji_variants,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (String v in info.variants) _tile(v)],
            ),
          ),
        if (info.usedIn.isNotEmpty) _section(t.kanji_used_in, _usedIn(info)),
        if (info.words.isNotEmpty)
          _section(
            t.kanji_words,
            key: _wordsKey,
            trailing: _reading == null
                ? null
                : _ReadingPill(
                    reading: _reading!,
                    kun: info.kunReadings.contains(_reading),
                    selected: true,
                    clear: true,
                    onTap: () => _narrow(_reading!),
                  ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (KanjiWord word in words)
                  _word(word, info.character, shown.readings[word]),
                if (!_allWords && matching.length > words.length)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _more(matching.length,
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
                    child: Text.rich(_meaningSpan(info.meanings),
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

  Widget _section(String? label, Widget child, {Key? key, Widget? trailing}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    label.toUpperCase(),
                    style: textTheme.labelMedium!.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  if (trailing != null) trailing,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }

  /// One kind of reading, marked 音 or 訓 as dictionaries do. Each pill
  /// counts the words read with it, and narrows the words to them.
  Widget _readings(
    String mark,
    String name,
    List<String> readings,
    Map<String, int> counts, {
    required bool kun,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: name,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: muted.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(mark,
                  style: textTheme.bodyMedium!.copyWith(color: muted)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (String reading in readings)
                  _ReadingPill(
                    reading: reading,
                    kun: kun,
                    count: counts[reading] ?? 0,
                    selected: reading == _reading,
                    onTap: counts.containsKey(reading)
                        ? () => _narrow(reading)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A part, with its Sino-Vietnamese reading or first meaning under it. A
  /// tap lists the kanji it is used in, or opens it when it is in none.
  Widget _part(String character, KanjiInfo? info, {bool accent = false}) {
    String caption = info == null
        ? ''
        : info.hanViet.isNotEmpty
            ? info.hanViet.first
            : info.meanings.isNotEmpty
                ? info.meanings.first
                : '';
    return SizedBox(
      width: 60,
      child: Column(
        children: [
          _tile(
            character,
            accent: accent,
            onTap: info != null && info.usedIn.isNotEmpty
                ? () => _list(info)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall!.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  /// The kanji [info] is used in, as many as fit on a line. When more are
  /// left, the last tile lists them all.
  Widget _usedIn(KanjiInfo info) {
    List<String> all = info.usedIn.characters.toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        int fit = ((constraints.maxWidth + 6) / 46).floor();
        int shown = all.length > fit ? fit - 1 : all.length;
        return Row(
          children: [
            for (String c in all.take(shown))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _tile(c, small: true),
              ),
            if (shown < all.length)
              Tooltip(
                message: t.kanji_show_all(n: all.length),
                child: Material(
                  color: muted.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _list(info),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Text(
                          '+${all.length - shown}',
                          style: textTheme.labelMedium!.copyWith(
                              color: muted, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _tile(
    String character, {
    bool accent = false,
    bool small = false,
    VoidCallback? onTap,
  }) {
    double side = small ? 40 : 48;
    Color edge = accent ? theme.colorScheme.primary : muted.withOpacity(0.35);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () => _open(character),
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
  }

  /// A word with its reading above it, the kanji and its part of the
  /// reading in the accent, and its meaning beside it.
  Widget _word(KanjiWord word, String character, KanjiWordReading? reading) {
    Color accent = theme.colorScheme.primary;
    String kana = word.reading;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _search(word.word),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 84),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    reading == null
                        ? TextSpan(text: kana)
                        : TextSpan(children: [
                            TextSpan(text: kana.substring(0, reading.start)),
                            TextSpan(
                              text: kana.substring(reading.start, reading.end),
                              style: TextStyle(color: accent),
                            ),
                            TextSpan(text: kana.substring(reading.end)),
                          ]),
                    style: textTheme.labelSmall!
                        .copyWith(color: muted, height: 1.2),
                  ),
                  Text.rich(
                    TextSpan(children: [
                      for (String c in word.word.characters)
                        TextSpan(
                          text: c,
                          style:
                              c == character ? TextStyle(color: accent) : null,
                        ),
                    ]),
                    style: textTheme.titleLarge!.copyWith(height: 1.25),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                word.gloss,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium!.copyWith(height: 1.35),
              ),
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

/// A reading on a tint of its kind, its okurigana lighter, with how many
/// words read the kanji so.
class _ReadingPill extends StatelessWidget {
  const _ReadingPill({
    required this.reading,
    required this.kun,
    this.count = 0,
    this.selected = false,
    this.dense = false,
    this.clear = false,
    this.onTap,
  });

  final String reading;
  final bool kun;
  final int count;
  final bool selected;
  final bool dense;

  /// Whether it ends in a cross, as the pill that undoes a narrowing.
  final bool clear;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color ink = _ink(theme);
    Color hue = kun ? _kunHue : _onHue;
    List<String> halves = reading.split('.');
    BorderRadius radius = BorderRadius.circular(dense ? 8 : 10);
    return Material(
      color: hue.withOpacity(selected ? 0.42 : 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: selected ? BorderSide(color: hue, width: 1.2) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: dense ? 24 : 32),
          padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: halves.first),
                  if (halves.length > 1)
                    TextSpan(
                      text: halves.skip(1).join(),
                      style: TextStyle(color: ink.withOpacity(0.5)),
                    ),
                ]),
                style: (dense
                        ? theme.textTheme.bodyMedium!
                        : theme.textTheme.bodyLarge!)
                    .copyWith(color: ink, height: 1.2),
              ),
              if (count > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelSmall!
                        .copyWith(color: ink.withOpacity(0.55)),
                  ),
                ),
              if (clear)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Ui.cross, size: 11, color: ink.withOpacity(0.7)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The kanji [part] is used in, with their readings and meanings, as kanji
/// dictionaries list them under a radical. Pops with the kanji tapped, or
/// with the part itself when its own tile is tapped.
class _KanjiList extends StatefulWidget {
  const _KanjiList({required this.pack, required this.part});

  final KanjiPack pack;
  final KanjiInfo part;

  @override
  State<_KanjiList> createState() => _KanjiListState();
}

class _KanjiListState extends State<_KanjiList> {
  late final List<String> _characters = widget.part.usedIn.characters.toList();
  late final Future<Map<String, KanjiInfo>> _infos =
      widget.pack.lookupAll(_characters);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    TextTheme textTheme = theme.textTheme;
    Color muted = theme.unselectedWidgetColor;
    KanjiInfo part = widget.part;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 10),
            child: Row(
              children: [
                Material(
                  color: muted.withOpacity(0.16),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, part.character),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Center(
                        child: Text(part.character,
                            style: const TextStyle(fontSize: 28, height: 1)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (part.hanViet.isNotEmpty)
                        Text(
                          part.hanViet.join(', ').toUpperCase(),
                          style: textTheme.titleSmall!.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      Text(
                        t.kanji_count(n: _characters.length),
                        style: textTheme.bodySmall!.copyWith(color: muted),
                      ),
                    ],
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
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.4)),
          Flexible(
            child: FutureBuilder<Map<String, KanjiInfo>>(
              future: _infos,
              builder: (context, snapshot) {
                Map<String, KanjiInfo>? infos = snapshot.data;
                if (infos == null) {
                  return const SizedBox(height: 120);
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _characters.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 76,
                    color: theme.dividerColor.withOpacity(0.3),
                  ),
                  itemBuilder: (context, i) =>
                      _row(_characters[i], infos[_characters[i]]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String character, KanjiInfo? info) {
    ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.pop(context, character),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Text(character,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 34, height: 1.2)),
            ),
            const SizedBox(width: 12),
            if (info != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (String reading in info.onReadings.take(3))
                          _ReadingPill(
                              reading: reading, kun: false, dense: true),
                        for (String reading in info.kunReadings.take(3))
                          _ReadingPill(
                              reading: reading, kun: true, dense: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(children: [
                        if (info.hanViet.isNotEmpty)
                          TextSpan(
                            text: '${info.hanViet.first.toUpperCase()}  ',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        _meaningSpan(info.meanings),
                      ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
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
                ink: _ink(theme),
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
