import 'package:flutter/material.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// A book's tag as a rounded pill, coloured by its text so a tag always has
/// the same colour, and cut short with an ellipsis past [maxWidth].
class TtuTagPill extends StatelessWidget {
  /// Draw [tag].
  const TtuTagPill({
    required this.tag,
    this.maxWidth = 160,
    this.dense = false,
    this.onTap,
    this.onRemove,
    super.key,
  });

  /// The tag's text.
  final String tag;

  /// Wider tags are cut short.
  final double maxWidth;

  /// Small, as on a cover.
  final bool dense;

  /// Tapping the pill, as for a suggestion.
  final VoidCallback? onTap;

  /// Shows a cross that removes the tag.
  final VoidCallback? onRemove;

  /// The hue of [tag], from its text: the same for the same tag, whatever
  /// its case.
  static double hueOf(String tag) =>
      ((fastHash(tag.toLowerCase()) % 360 + 360) % 360).toDouble();

  /// The pill's fill and text colours for [tag]. On a cover the pill is
  /// always light, so it reads over any picture.
  static (Color, Color) colorsOf(String tag, {required bool dark}) {
    double hue = hueOf(tag);
    return (
      HSLColor.fromAHSL(1, hue, 0.55, dark ? 0.30 : 0.86).toColor(),
      HSLColor.fromAHSL(1, hue, 0.65, dark ? 0.86 : 0.27).toColor(),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool dark = !dense && Theme.of(context).brightness == Brightness.dark;
    (Color, Color) colors = colorsOf(tag, dark: dark);
    Widget pill = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: dense
          ? const EdgeInsets.fromLTRB(6, 1, 6, 2)
          : EdgeInsets.fromLTRB(11, 5, onRemove == null ? 11 : 4, 5),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
        boxShadow: dense
            ? const [BoxShadow(color: Colors.black38, blurRadius: 2)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              tag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: colors.$2,
                fontSize: dense ? 9.5 : 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: Icon(Ui.cross, size: 14, color: colors.$2),
              ),
            ),
        ],
      ),
    );
    if (onTap != null) {
      pill = GestureDetector(onTap: onTap, child: pill);
    }
    return dense ? pill : Tooltip(message: tag, child: pill);
  }
}

/// A book's tags on its cover: the first two, then how many more. Each is
/// cut short to fit the room it is given.
class TtuCoverTags extends StatelessWidget {
  /// Show [tags].
  const TtuCoverTags({required this.tags, super.key});

  /// The book's tags.
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    List<String> shown = tags.take(2).toList();
    int more = tags.length - shown.length;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (String tag in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: TtuTagPill(
                tag: tag,
                dense: true,
                maxWidth: constraints.maxWidth,
              ),
            ),
          if (more > 0)
            Container(
              padding: const EdgeInsets.fromLTRB(6, 1, 6, 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '+$more',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Adds and removes a book's tags. The tags already used on other books
/// are offered, the most used first, and narrow down while typing.
class TtuTagsSheet extends StatefulWidget {
  /// Create the sheet for [book].
  const TtuTagsSheet({required this.book, super.key});

  /// The book to tag.
  final TtuBook book;

  @override
  State<TtuTagsSheet> createState() => _TtuTagsSheetState();
}

class _TtuTagsSheetState extends State<TtuTagsSheet> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  ReaderTtuSource get _source => ReaderTtuSource.instance;
  late List<String> _tags = _source.tagsOf(widget.book);
  late final List<String> _known = _source.allTags;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> tags) async {
    setState(() => _tags = tags);
    await _source.setTagsOf(widget.book, tags);
    if (mounted) {
      setState(() => _tags = _source.tagsOf(widget.book));
    }
  }

  /// Adds [text], in the spelling it already has on other books.
  void _add(String text) {
    String tag = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (tag.isEmpty) {
      return;
    }
    tag = _known.firstWhere(
      (known) => known.toLowerCase() == tag.toLowerCase(),
      orElse: () => tag,
    );
    _text.clear();
    if (_tags.any((mine) => mine.toLowerCase() == tag.toLowerCase())) {
      setState(() {});
      return;
    }
    _save([..._tags, tag]);
  }

  void _remove(String tag) => _save([..._tags]..remove(tag));

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color muted = theme.unselectedWidgetColor;
    String typed = _text.text.trim().toLowerCase();
    List<String> suggestions = _known
        .where((tag) =>
            !_tags.any((mine) => mine.toLowerCase() == tag.toLowerCase()) &&
            (typed.isEmpty || tag.toLowerCase().contains(typed)))
        .take(24)
        .toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TtuSheetHandle(),
                Row(
                  children: [
                    Text(
                      t.ttu_tags,
                      style: theme.textTheme.titleLarge!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    JidoujishoInfoButton(message: t.ttu_tags_info),
                  ],
                ),
                Text(
                  widget.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall!.copyWith(color: muted),
                ),
                const SizedBox(height: 12),
                if (_tags.isEmpty)
                  Text(
                    t.ttu_tags_none,
                    style: theme.textTheme.bodyMedium!.copyWith(color: muted),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (String tag in _tags)
                        TtuTagPill(
                          tag: tag,
                          maxWidth: 220,
                          onRemove: () => _remove(tag),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: _text,
                  focusNode: _focus,
                  maxLength: 40,
                  buildCounter: (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (text) {
                    _add(text);
                    _focus.requestFocus();
                  },
                  decoration: InputDecoration(
                    hintText: t.ttu_add_tag,
                    isDense: true,
                    filled: true,
                    fillColor: theme.dividerColor.withOpacity(0.08),
                    prefixIcon: const Icon(Ui.plus, size: 18),
                    suffixIcon: typed.isEmpty
                        ? null
                        : IconButton(
                            tooltip: t.ttu_add_tag,
                            icon: Icon(
                              Ui.check,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: () => _add(_text.text),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    t.ttu_tags_used_before.toUpperCase(),
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: muted,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (String tag in suggestions)
                        TtuTagPill(
                          tag: tag,
                          maxWidth: 220,
                          onTap: () => _add(tag),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
