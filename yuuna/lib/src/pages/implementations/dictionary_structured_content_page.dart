import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/utils.dart';

/// Each dictionary's own stylesheet, read once from the files kept when it
/// was imported. Empty for dictionaries without one.
final dictionaryCssProvider =
    Provider.family<List<DictionaryCssRule>, int>((ref, dictionaryId) {
  final directory =
      ref.watch(dictionaryResourceDirectoryProvider(dictionaryId));
  final file = File(path.join(directory.path, 'styles.css'));
  try {
    if (file.existsSync()) {
      return parseDictionaryCss(file.readAsStringSync());
    }
  } catch (error) {
    debugPrint('Could not read styles of dictionary $dictionaryId: $error');
  }
  return const [];
});

/// The HTML of a [DictionaryEntry], styled by its dictionary's stylesheet in
/// the given theme. Kept while the entry is shown.
final dictionaryEntryHtmlProvider = Provider.autoDispose
    .family<String, (DictionaryEntry, DictionaryCssTheme)>((ref, key) {
  final (entry, theme) = key;
  final dictionaryId = entry.dictionary.value?.id;
  final css = dictionaryId == null
      ? const <DictionaryCssRule>[]
      : ref.watch(dictionaryCssProvider(dictionaryId));
  return entry.definitions
      .map((definition) => definitionHtml(definition, css: css, theme: theme))
      .join();
});

/// Get the [Directory] used as a resource directory for a certain [Dictionary].
final dictionaryResourceDirectoryProvider =
    Provider.family<Directory, int>((ref, dictionaryId) {
  final appModel = ref.watch(appProvider);

  return Directory(
      path.join(appModel.dictionaryResourceDirectory.path, '$dictionaryId'));
});

/// Where pictures come from for entries that aren't imported, such as a
/// dictionary previewed from a server. Null for imported dictionaries,
/// whose pictures are files in their resource directory.
final dictionaryPreviewImageProvider =
    Provider<ImageProvider Function(String src)?>((ref) => null);

/// HTML renderer for dictionary definitions. Structured content is drawn
/// as Yomitan draws it, with the dictionary's own stylesheet; its colours
/// that would not read on the popup are left out.
class DictionaryHtmlWidget extends ConsumerWidget {
  /// Create an instance of this page.
  const DictionaryHtmlWidget({
    required this.entry,
    required this.onSearch,
    super.key,
  });

  /// Dictionary entry to be rendered.
  final DictionaryEntry entry;

  /// Action to be done upon selecting the search option.
  final Function(String) onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textColor =
        theme.brightness == Brightness.dark ? Colors.white : Colors.black;
    final linkColor = theme.colorScheme.primary;
    final dictionaryFontSize = ref.read(appProvider).dictionaryFontSize;
    final cssTheme = DictionaryCssTheme(
      text: textColor,
      background: theme.cardColor,
      fontSize: dictionaryFontSize,
    );
    final body = ref.watch(dictionaryEntryHtmlProvider((entry, cssTheme)));

    /// The app's defaults go first, so a dictionary's styles win over them.
    final defaults = '<style>'
        'ul, ol { padding-left: 1.2em; margin: 0; } '
        'li { padding: 0; } '
        'td, th { border: 0.3px solid ${hexOf(textColor)}; '
        'padding: 0.15em 0.3em; } '
        'a { color: ${hexOf(linkColor)}; text-decoration: none; } '
        '</style>';

    return Html(
      data: '$defaults$body',
      shrinkWrap: true,
      onAnchorTap: (url, attributes, element) {
        onSearch.call(attributes['query'] ?? element?.text ?? 'f');
      },
      style: {
        'html': Style(
          fontSize: FontSize(dictionaryFontSize),
          color: textColor,
          fontFamilyFallback: const [AppModel.ipaFontFamily],
        ),
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
      },
      extensions: [
        const TableHtmlExtension(),
        _PillExtension(baseFontSize: dictionaryFontSize),
        _BoxExtension(baseFontSize: dictionaryFontSize),
        _ImageExtension(entry: entry, baseFontSize: dictionaryFontSize),
      ],
    );
  }
}

double _lengthInPixels(String value, double fontSize) {
  final match = RegExp(r'^(-?[\d.]+)(px|em|rem|%)?$').firstMatch(value.trim());
  if (match == null) {
    return 0;
  }
  final number = double.parse(match.group(1)!);
  switch (match.group(2)) {
    case 'em' || 'rem':
      return number * fontSize;
    case '%':
      return number / 100 * fontSize;
    default:
      return number;
  }
}

/// Inline boxes with a background, such as Jitendex's tags, as rounded
/// pills. Tapping one with a title shows it.
class _PillExtension extends HtmlExtension {
  const _PillExtension({required this.baseFontSize});

  final double baseFontSize;

  @override
  Set<String> get supportedTags => const {'span', 'a'};

  @override
  bool matches(ExtensionContext context) {
    return supportedTags.contains(context.elementName) &&
        context.attributes.containsKey('data-jdj-pill');
  }

  @override
  InlineSpan build(ExtensionContext context) {
    final attributes = context.attributes;
    final style = context.style;
    final fontSize = style?.fontSize?.value ?? baseFontSize;
    final background = _colorFromHex(attributes['data-jdj-pill-bg']);
    final padding = (attributes['data-jdj-pill-padding'] ?? '0 0').split(' ');
    final vertical = _lengthInPixels(padding.first, fontSize);
    final horizontal = _lengthInPixels(padding.last, fontSize);
    final radius =
        _lengthInPixels(attributes['data-jdj-pill-radius'] ?? '0', fontSize);
    final left = _lengthInPixels(
        attributes['data-jdj-pill-margin-left'] ?? '0', fontSize);
    final right = _lengthInPixels(
        attributes['data-jdj-pill-margin-right'] ?? '0', fontSize);
    final title = attributes['title'];

    Widget pill = Container(
      margin: EdgeInsets.only(left: left, right: right),
      padding: EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: vertical,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        context.element?.text ?? '',
        style: TextStyle(
          color: style?.color,
          fontSize: fontSize,
          fontWeight: style?.fontWeight,
          fontStyle: style?.fontStyle,
          height: 1.15,
        ),
      ),
    );
    if (title != null && title.isNotEmpty) {
      pill = Tooltip(
        message: title,
        triggerMode: TooltipTriggerMode.tap,
        child: pill,
      );
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: pill,
    );
  }
}

/// Blocks with a background or borders, such as Jitendex's example and
/// note boxes, drawn by the app: the renderer would paint a background twice
/// and cannot round corners.
class _BoxExtension extends HtmlExtension {
  const _BoxExtension({required this.baseFontSize});

  final double baseFontSize;

  @override
  Set<String> get supportedTags => const {'div', 'details'};

  @override
  bool matches(ExtensionContext context) {
    return supportedTags.contains(context.elementName) &&
        context.attributes.containsKey('data-jdj-box');
  }

  @override
  InlineSpan build(ExtensionContext context) {
    final styled = context.styledElement!;
    final fontSize = styled.style.fontSize?.value ?? baseFontSize;
    final attributes = context.attributes;

    List<double> four(String? value) {
      final parts = (value ?? '').split(' ');
      return List.generate(
        4,
        (i) => i < parts.length
            ? max(0, _lengthInPixels(parts[i], fontSize)).toDouble()
            : 0,
      );
    }

    final padding = four(attributes['data-jdj-box-padding']);
    final margin = four(attributes['data-jdj-box-margin']);
    final radius =
        _lengthInPixels(attributes['data-jdj-box-radius'] ?? '0', fontSize);
    final edges =
        (attributes['data-jdj-box-border'] ?? '').split(',').map((side) {
      final parts = side.trim().split(' ');
      return (
        width: max(0, _lengthInPixels(parts.first, fontSize)).toDouble(),
        color: _colorFromHex(parts.length > 1 ? parts[1] : null),
      );
    }).toList();
    while (edges.length < 4) {
      edges.add((width: 0, color: null));
    }
    double edge(int side) => edges[side].color == null ? 0 : edges[side].width;

    final inner = styled.style.copyWith(
      backgroundColor: Colors.transparent,
      padding: HtmlPaddings.zero,
      margin: Margins.zero,
      border: const Border(),
    );
    final children = context.builtChildrenMap!.entries
        .expandIndexed((i, child) => [
              child.value,
              if (context.parser.shrinkWrap &&
                  i != styled.children.length - 1 &&
                  (child.key.style.display == Display.block ||
                      child.key.style.display == Display.listItem))
                const TextSpan(text: '\n', style: TextStyle(fontSize: 0)),
            ])
        .toList();

    Widget box = CssBoxWidget.withInlineSpanChildren(
      style: inner,
      shrinkWrap: context.parser.shrinkWrap,
      children: children,
    );
    box = Padding(
      padding: EdgeInsets.fromLTRB(
        padding[3] + edge(3),
        padding[0] + edge(0),
        padding[1] + edge(1),
        padding[2] + edge(2),
      ),
      child: box,
    );
    box = CustomPaint(
      foregroundPainter: _EdgePainter([
        for (int i = 0; i < 4; i++) (width: edge(i), color: edges[i].color),
      ]),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _colorFromHex(attributes['data-jdj-box-bg']),
        ),
        child: box,
      ),
    );
    if (radius > 0) {
      box = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: box,
      );
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(margin[3], margin[0], margin[1], margin[2]),
        child: box,
      ),
    );
  }
}

/// The borders of a drawn box, one side at a time, inside its clip.
class _EdgePainter extends CustomPainter {
  _EdgePainter(this.edges);

  /// Top, right, bottom and left.
  final List<({double width, Color? color})> edges;

  @override
  void paint(Canvas canvas, Size size) {
    final rects = [
      Rect.fromLTWH(0, 0, size.width, edges[0].width),
      Rect.fromLTWH(
          size.width - edges[1].width, 0, edges[1].width, size.height),
      Rect.fromLTWH(
          0, size.height - edges[2].width, size.width, edges[2].width),
      Rect.fromLTWH(0, 0, edges[3].width, size.height),
    ];
    for (int i = 0; i < 4; i++) {
      final color = edges[i].color;
      if (color != null && edges[i].width > 0) {
        canvas.drawRect(rects[i], Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) => false;
}

Color? _colorFromHex(String? hex) {
  if (hex == null || !hex.startsWith('#')) {
    return null;
  }
  final digits = hex.substring(1);
  if (digits.length == 6) {
    return Color(int.parse('ff$digits', radix: 16));
  }
  if (digits.length == 8) {
    return Color(
        int.parse(digits.substring(6) + digits.substring(0, 6), radix: 16));
  }
  return null;
}

/// Pictures in definitions, from the dictionary's files or, for a preview,
/// from the server.
class _ImageExtension extends HtmlExtension {
  const _ImageExtension({required this.entry, required this.baseFontSize});

  final DictionaryEntry entry;
  final double baseFontSize;

  @override
  Set<String> get supportedTags => const {'img'};

  @override
  InlineSpan build(ExtensionContext context) {
    final fontSize = context.style?.fontSize?.value ?? baseFontSize;
    final attributes = context.attributes;
    final inline = (attributes['data-jdj-width'] ?? '').endsWith('em') ||
        (attributes['data-jdj-height'] ?? '').endsWith('em');
    return WidgetSpan(
      alignment:
          inline ? PlaceholderAlignment.middle : PlaceholderAlignment.bottom,
      child: JidoujishoDictionaryImage(
        entry: entry,
        attributes: Map.of(attributes),
        fontSize: fontSize,
        textColor: context.style?.color,
      ),
    );
  }
}

/// Handles image rendering of images in a dictionary definition.
class JidoujishoDictionaryImage extends ConsumerWidget {
  /// Initialise this widget.
  const JidoujishoDictionaryImage({
    required this.entry,
    required this.attributes,
    required this.fontSize,
    this.textColor,
    super.key,
  });

  /// Dictionary entry to be rendered.
  final DictionaryEntry entry;

  /// The image element's attributes.
  final Map<String, String> attributes;

  /// The font size around the image, for sizes given in em.
  final double fontSize;

  /// The text colour around the image, for monochrome pictures.
  final Color? textColor;

  double? _size(String name) {
    final value = attributes['data-jdj-$name'];
    if (value == null) {
      return null;
    }
    final match = RegExp(r'^([\d.]+)([a-z%]*)$').firstMatch(value);
    if (match == null) {
      return null;
    }
    final number = double.parse(match.group(1)!);
    return match.group(2) == 'em' ? number * fontSize : number;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final src = (attributes['src'] ?? '').replaceFirst('jidoujisho://', '');
    final width = _size('width');
    final height = _size('height');
    final monochrome = attributes['data-jdj-appearance'] == 'monochrome';
    final tint = monochrome
        ? ColorFilter.mode(
            textColor ?? Theme.of(context).colorScheme.onSurface,
            BlendMode.srcIn,
          )
        : null;
    final svg = src.toLowerCase().endsWith('.svg');
    final inline = (attributes['data-jdj-width'] ?? '').endsWith('em') ||
        (attributes['data-jdj-height'] ?? '').endsWith('em');
    final title = attributes['title'];

    Widget image;
    final preview = ref.watch(dictionaryPreviewImageProvider);
    if (preview != null) {
      final provider = preview(src);
      if (svg && provider is NetworkImage) {
        image = SvgPicture.network(
          provider.url,
          headers: provider.headers,
          width: width,
          height: height,
          colorFilter: tint,
        );
      } else {
        image = Image(
          image: provider,
          height: height,
          width: width,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
    } else {
      final dictionaryId = entry.dictionary.value?.id;
      if (dictionaryId == null) {
        return const SizedBox.shrink();
      }
      final directory =
          ref.read(dictionaryResourceDirectoryProvider(dictionaryId));
      final file = File(path.join(directory.path, src));
      image = svg
          ? SvgPicture.file(
              file,
              width: width,
              height: height,
              colorFilter: tint,
            )
          : Image.file(
              file,
              height: height,
              width: width,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            );
    }
    if (tint != null && !svg) {
      image = ColorFiltered(colorFilter: tint, child: image);
    }
    if (title != null && title.isNotEmpty) {
      image = Tooltip(
        message: title,
        triggerMode: TooltipTriggerMode.tap,
        child: image,
      );
    }
    if (inline) {
      return Padding(
        padding: EdgeInsets.only(right: fontSize * 0.25),
        child: image,
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [image],
    );
  }
}

/// Special delegate for text selection from a dictionary search result.
class DictionarySelectionDelegate
    extends MultiSelectableSelectionContainerDelegate {
  /// Initialise this widget.
  DictionarySelectionDelegate({
    required this.onTextSelectionGuessLength,
  });

  /// Callback with a [JidoujishoTextSelection] which contains the text of all
  /// selectables as well as a [TextRange] representing the substring to use
  /// for dictionary search. Returns the guess length of the text selection.
  final JidoujishoTextSelection Function(JidoujishoTextSelection)
      onTextSelectionGuessLength;

  // This method is called when newly added selectable is in the current
  // selected range.
  @override
  void ensureChildUpdated(Selectable selectable) {}

  /// Handles a [JidoujishoTextSelection].
  SelectionResult handleTextSelection(
      SelectWordSelectionEvent event, JidoujishoTextSelection selection) {
    handleClearSelection(const ClearSelectionEvent());

    super.handleSelectWord(event);
    while ((getSelectedContent()?.plainText ?? '').length > 1) {
      super.handleGranularlyExtendSelection(
        const GranularlyExtendSelectionEvent(
            forward: false,
            isEnd: true,
            granularity: TextGranularity.character),
      );
    }

    final highlightLength = selection.textInside.length;

    SelectionResult? result;
    for (int i = 0; i < highlightLength - 1; i++) {
      result = super.handleGranularlyExtendSelection(
        const GranularlyExtendSelectionEvent(
          forward: true,
          isEnd: true,
          granularity: TextGranularity.character,
        ),
      );
    }

    return result ?? super.handleSelectWord(event);
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    // _expectSearchSelection = event is SelectWordSelectionEvent;
    return super.dispatchSelectionEvent(event);
  }

  //  bool _expectSearchSelection = false;
  SelectionEvent? _lastEvent;
  JidoujishoTextSelection? _guessSelection;
  JidoujishoTextSelection? _searchSelection;

  @override
  SelectionResult handleSelectWord(SelectWordSelectionEvent event) {
    if (_searchSelection != null && _lastEvent == event) {
      final selection = _searchSelection;
      _searchSelection = null;

      final startDiff = selection!.range.start - _guessSelection!.range.start;
      final endDiff = selection.range.end - _guessSelection!.range.end;

      SelectionResult? result;
      for (int i = 0; i < startDiff.abs(); i++) {
        result = super.handleGranularlyExtendSelection(
          GranularlyExtendSelectionEvent(
            forward: !startDiff.isNegative,
            isEnd: true,
            granularity: TextGranularity.character,
          ),
        );
      }

      for (int i = 0; i < endDiff.abs(); i++) {
        result = super.handleGranularlyExtendSelection(
          GranularlyExtendSelectionEvent(
            forward: !endDiff.isNegative,
            isEnd: true,
            granularity: TextGranularity.character,
          ),
        );
      }

      return result!;
    }

    super.handleSelectWord(event);
    _lastEvent = event;
    // _expectSearchSelection = true;

    if (!(currentSelectionEndIndex < selectables.length &&
        currentSelectionEndIndex >= 0)) {
      return handleClearSelection(const ClearSelectionEvent());
    }

    handleGranularlyExtendSelection(
      const GranularlyExtendSelectionEvent(
        forward: false,
        isEnd: true,
        granularity: TextGranularity.document,
      ),
    );

    handleClearSelection(const ClearSelectionEvent());

    final textBefore = getSelectedContent()?.plainText ?? '';

    super.handleSelectWord(event);
    handleGranularlyExtendSelection(
      const GranularlyExtendSelectionEvent(
        forward: true,
        isEnd: true,
        granularity: TextGranularity.document,
      ),
    );

    final textAfter = getSelectedContent()?.plainText ?? '';

    final text = '$textBefore$textAfter';

    final eventSelection = JidoujishoTextSelection(
      text: text,
      range: TextRange(
        start: textBefore.length,
        end: text.length,
      ),
    );

    late SelectionResult result;
    final guessSelection = onTextSelectionGuessLength(eventSelection);
    result = handleTextSelection(event, guessSelection);

    // onTextSelectionSearchLength(eventSelection, (searchSelection) {
    //   _guessSelection = guessSelection;
    //   _searchSelection = searchSelection;
    //   if (getSelectedContent()?.plainText == guessSelection.textInside &&
    //       searchSelection.textInside != guessSelection.textInside) {
    //     dispatchSelectionEvent(event);
    //   }
    // });

    return result;
  }
}
