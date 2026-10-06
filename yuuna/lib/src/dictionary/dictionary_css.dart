import 'dart:math';

import 'package:flutter/material.dart' show Color;
import 'package:html/dom.dart' as dom;

/// One rule of a dictionary's stylesheet, flattened: a single selector and
/// its declarations.
class DictionaryCssRule {
  /// Describe a rule.
  DictionaryCssRule({
    required this.selector,
    required this.declarations,
    required this.order,
  }) : specificity = _specificityOf(selector);

  /// The selector, with nesting resolved.
  final String selector;

  /// Property names to values, as written.
  final Map<String, String> declarations;

  /// Position in the stylesheet; later rules win ties.
  final int order;

  /// Rough CSS specificity: ids, then classes, attributes and pseudo-classes,
  /// then element names.
  final int specificity;

  static int _specificityOf(String selector) {
    String s = selector.replaceAll(RegExp(r'\[[^\]]*\]'), '[]');
    int ids = '#'.allMatches(s).length;
    int classes = RegExp(r'\.|\[\]|:(?!:)').allMatches(s).length;
    int elements = RegExp(r'(^|[\s>+~])[a-zA-Z][\w-]*').allMatches(s).length;
    return ids * 10000 + classes * 100 + elements;
  }
}

/// The colours a stylesheet's theme variables stand for, as in Yomitan.
class DictionaryCssTheme {
  /// Describe the theme a popup is drawn in.
  const DictionaryCssTheme({
    required this.text,
    required this.background,
    required this.fontSize,
  });

  /// Text colour.
  final Color text;

  /// Background colour.
  final Color background;

  /// Base font size in logical pixels.
  final double fontSize;

  /// Yomitan's variables, which dictionary stylesheets use for colours that
  /// follow the theme.
  Map<String, String> get variables => {
        '--text-color': hexOf(text),
        '--fg': hexOf(text),
        '--background-color': hexOf(background),
        '--canvas': hexOf(background),
        '--font-size-no-units': _number(fontSize),
      };
}

/// The properties the app's HTML renderer understands, which may be written
/// to an element's style.
const Set<String> _supported = {
  'background-color',
  'color',
  'display',
  'font-family',
  'font-size',
  'font-style',
  'font-weight',
  'height',
  'line-height',
  'list-style-type',
  'list-style-position',
  'margin-top',
  'margin-right',
  'margin-bottom',
  'margin-left',
  'padding-top',
  'padding-right',
  'padding-bottom',
  'padding-left',
  'text-align',
  'text-decoration-line',
  'text-decoration-style',
  'text-decoration-color',
  'text-shadow',
  'text-transform',
  'vertical-align',
  'width',
};

const List<String> _sides = ['top', 'right', 'bottom', 'left'];

/// Reads a dictionary's stylesheet into flat rules. Nested rules are
/// joined to their parents; at-rules and rules for pseudo-elements, which
/// cannot apply to a static page, are left out.
List<DictionaryCssRule> parseDictionaryCss(String css) {
  String text = css.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  List<DictionaryCssRule> rules = [];
  int order = 0;

  void parseBlock(String body, List<String> parents) {
    Map<String, String> declarations = {};
    int i = 0;
    StringBuffer buffer = StringBuffer();
    while (i < body.length) {
      String ch = body[i];
      if (ch == '{') {
        int end = _matchingBrace(body, i);
        String head = buffer.toString().trim();
        buffer.clear();
        String inner = body.substring(i + 1, end);
        i = end + 1;
        if (head.startsWith('@')) {
          continue;
        }
        List<String> selectors = _splitSelectors(head)
            .expand((child) => parents.isEmpty
                ? [child]
                : parents.map((parent) => child.contains('&')
                    ? child.replaceAll('&', parent)
                    : '$parent $child'))
            .toList();
        parseBlock(inner, selectors);
        continue;
      }
      if (ch == ';') {
        _addDeclaration(declarations, buffer.toString());
        buffer.clear();
        i++;
        continue;
      }
      buffer.write(ch);
      i++;
    }
    _addDeclaration(declarations, buffer.toString());
    if (declarations.isEmpty || parents.isEmpty) {
      return;
    }
    for (String selector in parents) {
      if (selector.contains('::') ||
          RegExp(r':(hover|focus|active|visited|before|after)\b')
              .hasMatch(selector)) {
        continue;
      }
      rules.add(DictionaryCssRule(
        selector: selector,
        declarations: Map.of(declarations),
        order: order++,
      ));
    }
  }

  parseBlock(text, const []);
  return rules;
}

int _matchingBrace(String text, int open) {
  int depth = 0;
  for (int i = open; i < text.length; i++) {
    if (text[i] == '{') {
      depth++;
    } else if (text[i] == '}') {
      depth--;
      if (depth == 0) {
        return i;
      }
    }
  }
  return text.length - 1;
}

List<String> _splitSelectors(String head) {
  List<String> parts = [];
  int depth = 0;
  StringBuffer buffer = StringBuffer();
  for (int i = 0; i < head.length; i++) {
    String ch = head[i];
    if (ch == '(' || ch == '[') {
      depth++;
    } else if (ch == ')' || ch == ']') {
      depth--;
    }
    if (ch == ',' && depth == 0) {
      parts.add(buffer.toString().trim());
      buffer.clear();
    } else {
      buffer.write(ch);
    }
  }
  parts.add(buffer.toString().trim());
  return parts.where((part) => part.isNotEmpty).toList();
}

void _addDeclaration(Map<String, String> declarations, String text) {
  int colon = text.indexOf(':');
  if (colon <= 0) {
    return;
  }
  String property = text.substring(0, colon).trim().toLowerCase();
  String value = text
      .substring(colon + 1)
      .replaceAll(RegExp('!important', caseSensitive: false), '')
      .trim();
  if (property.isNotEmpty && value.isNotEmpty) {
    declarations[property] = value;
  }
}

/// Reads an element's `style` attribute into properties and values.
Map<String, String> parseInlineStyle(String? style) {
  Map<String, String> declarations = {};
  for (String part in (style ?? '').split(';')) {
    _addDeclaration(declarations, part);
  }
  return declarations;
}

/// Applies [rules] to every element under [root] as CSS would, with each
/// element's own style winning, then rewrites each element's style into
/// what the app's renderer understands. Inline boxes with a background,
/// such as tags, are marked to be drawn as rounded pills.
void applyDictionaryCss(
  dom.Element root,
  List<DictionaryCssRule> rules,
  DictionaryCssTheme theme,
) {
  Map<dom.Element, List<DictionaryCssRule>> matched = {};
  for (DictionaryCssRule rule in rules) {
    List<dom.Element> elements;
    try {
      elements = root.querySelectorAll(rule.selector);
    } catch (_) {
      continue;
    }
    for (dom.Element element in elements) {
      matched.putIfAbsent(element, () => []).add(rule);
    }
  }

  List<dom.Element> all = [root, ...root.querySelectorAll('*')];
  for (dom.Element element in all) {
    List<DictionaryCssRule> own = matched[element] ?? const [];
    Map<String, String> declarations = {};
    if (own.isNotEmpty) {
      List<DictionaryCssRule> sorted = List.of(own)
        ..sort((a, b) => a.specificity != b.specificity
            ? a.specificity.compareTo(b.specificity)
            : a.order.compareTo(b.order));
      for (DictionaryCssRule rule in sorted) {
        declarations.addAll(rule.declarations);
      }
    }
    declarations.addAll(parseInlineStyle(element.attributes['style']));
    if (declarations.isEmpty) {
      continue;
    }
    _writeStyle(element, declarations, theme);
  }

  _yomitanLayout(root, all, theme);
}

/// What Yomitan does around dictionary styles, and what the renderer needs
/// to draw them faithfully:
/// - glossaries are compact, one line with ` | ` between meanings, as in
///   Yomitan's default layout;
/// - list items without a marker are plain blocks, since the renderer
///   numbers them otherwise;
/// - text list markers, which the renderer lacks, become text at the start
///   of the item's first line.
void _yomitanLayout(
  dom.Element root,
  List<dom.Element> all,
  DictionaryCssTheme theme,
) {
  String muted = cssColor(theme.text.withOpacity(0.45));
  for (dom.Element list in root.querySelectorAll(
      'ul[data-sc-content="glossary"], ol[data-sc-content="glossary"]')) {
    _appendStyle(list, 'padding-left:0;margin-left:0;list-style-type:none;');
    bool first = true;
    for (dom.Element item in list.children) {
      if (item.localName != 'li') {
        continue;
      }
      item.attributes['data-jdj-marker'] = '1';
      _appendStyle(item, 'display:inline;list-style-type:none;');
      if (!first) {
        dom.Element separator = dom.Element.tag('span')
          ..attributes['style'] = 'color:$muted;'
          ..append(dom.Text(' | '));
        item.nodes.insert(0, separator);
      }
      first = false;
    }
  }

  for (dom.Element element in all) {
    String? own = element.attributes.remove('data-jdj-own-marker');
    if (own != null) {
      _addMarker(element, own);
    }
  }
  for (dom.Element list in all) {
    String? marker = list.attributes.remove('data-jdj-child-marker');
    if (marker == null) {
      continue;
    }
    for (dom.Element item in list.children) {
      if (item.localName == 'li' &&
          item.attributes['data-jdj-marker'] == null) {
        _addMarker(item, marker);
      }
    }
  }

  for (dom.Element element in all) {
    if (element.localName != 'li' ||
        (element.attributes['style'] ?? '').contains('display:')) {
      continue;
    }
    String own = element.attributes['style'] ?? '';
    String parent = element.parent?.attributes['style'] ?? '';
    bool none = own.contains('list-style-type:none') ||
        (!own.contains('list-style-type') &&
            parent.contains('list-style-type:none'));
    if (none) {
      _appendStyle(element, 'display:block;');
    }
  }
}

void _appendStyle(dom.Element element, String declarations) {
  element.attributes['style'] =
      '${element.attributes['style'] ?? ''}$declarations';
}

/// The text of a quoted CSS string, or null if [value] is not one.
String? _quoted(String value) {
  String text = value.trim();
  if (text.length >= 2 &&
      (text.startsWith('"') || text.startsWith("'")) &&
      text.endsWith(text[0])) {
    return text.substring(1, text.length - 1).replaceAll(r'\', '');
  }
  return null;
}

void _addMarker(dom.Element item, String marker) {
  if (item.attributes['data-jdj-marker'] != null) {
    return;
  }
  item.attributes['data-jdj-marker'] = '1';
  String text = marker.endsWith(' ') ? marker : '$marker\u2009';
  dom.Element host = item;
  for (int depth = 0; depth < 8; depth++) {
    dom.Node? first;
    for (dom.Node node in host.nodes) {
      if (node is dom.Text && node.text.trim().isEmpty) {
        continue;
      }
      first = node;
      break;
    }
    if (first is dom.Element &&
        const {'div', 'ul', 'ol', 'li', 'details'}.contains(first.localName) &&
        first.attributes['data-jdj-box'] == null &&
        first.attributes['data-jdj-pill'] == null) {
      host = first;
    } else {
      break;
    }
  }
  host.nodes.insert(0, dom.Text(text));
  String style = item.attributes['style'] ?? '';
  if (!style.contains('list-style-type')) {
    item.attributes['style'] = '${style}list-style-type:none;';
  }
  if (!(item.attributes['style'] ?? '').contains('display:')) {
    _appendStyle(item, 'display:block;');
  }
}

void _writeStyle(
  dom.Element element,
  Map<String, String> declarations,
  DictionaryCssTheme theme,
) {
  Map<String, String> resolved = {};
  declarations.forEach((property, value) {
    String? clean = resolveCssValue(value, theme);
    if (clean != null && clean.isNotEmpty) {
      resolved[property] = clean;
    }
  });

  Map<String, String> out = {};
  _expandBoxes(resolved);
  Map<String, String>? border = _borders(resolved, theme);
  if (border != null) {
    out.addAll(border);
  }
  resolved.forEach((property, value) {
    if (property == 'background' && _colorOf(value) != null) {
      out['background-color'] = value;
    } else if (property == 'list-style-type') {
      String? marker = _quoted(value);
      if (marker == null) {
        out[property] = value;
      } else {
        /// The renderer has no text markers: the marker becomes text.
        out[property] = 'none';
        element.attributes[element.localName == 'li'
            ? 'data-jdj-own-marker'
            : 'data-jdj-child-marker'] = marker;
      }
    } else if (property == 'width' || property == 'height') {
      if (RegExp(r'^-?[\d.]+(px|em|rem|%)$').hasMatch(value)) {
        out[property] = value;
      }
    } else if (property == 'vertical-align') {
      out[property] = value == 'text-bottom'
          ? 'bottom'
          : value == 'text-top'
              ? 'top'
              : value;
    } else if (_supported.contains(property)) {
      out[property] = value;
    }
  });

  bool inline = const {'span', 'a', 'b', 'i', 'em', 'strong', 'small'}
          .contains(element.localName) &&
      !const {'block', 'list-item'}.contains(out['display']);
  String? background = out['background-color'];
  Color? backgroundColor = background == null ? null : _colorOf(background);
  if (inline && backgroundColor != null && backgroundColor.alpha > 0) {
    String radius = resolved['border-radius'] ?? '0';
    element.attributes['data-jdj-pill'] = '1';
    element.attributes['data-jdj-pill-bg'] = hexOf(backgroundColor);
    element.attributes['data-jdj-pill-radius'] = radius.split(' ').first;
    element.attributes['data-jdj-pill-padding'] =
        '${out['padding-top'] ?? '0'} ${out['padding-left'] ?? '0'}';
    if (out['margin-left'] != null) {
      element.attributes['data-jdj-pill-margin-left'] = out['margin-left']!;
    }
    if (out['margin-right'] != null) {
      element.attributes['data-jdj-pill-margin-right'] = out['margin-right']!;
    }
    for (String property in [
      'background-color',
      'padding-top',
      'padding-right',
      'padding-bottom',
      'padding-left',
      'margin-left',
      'margin-right',
      'vertical-align',
    ]) {
      out.remove(property);
    }
  }

  bool boxable = const {'div', 'details'}.contains(element.localName) &&
      out['display'] != 'inline' &&
      element.attributes['data-jdj-pill'] == null;
  bool bordered = _sides.any((side) => out['border-$side'] != null);
  if (boxable &&
      ((backgroundColor != null && backgroundColor.alpha > 0) || bordered)) {
    element.attributes['data-jdj-box'] = '1';
    if (backgroundColor != null && backgroundColor.alpha > 0) {
      element.attributes['data-jdj-box-bg'] = hexOf(backgroundColor);
    }
    element.attributes['data-jdj-box-radius'] =
        (resolved['border-radius'] ?? '0').split(' ').first;
    element.attributes['data-jdj-box-padding'] =
        _sides.map((side) => out['padding-$side'] ?? '0').join(' ');
    element.attributes['data-jdj-box-margin'] =
        _sides.map((side) => out['margin-$side'] ?? '0').join(' ');
    element.attributes['data-jdj-box-border'] = _sides.map((side) {
      List<String> parts = _parts(out['border-$side'] ?? '');
      if (parts.length < 3) {
        return '0 transparent';
      }
      Color? color = _colorOf(parts[2]);
      return '${parts[0]} ${color == null ? 'transparent' : hexOf(color)}';
    }).join(',');
    out.remove('background-color');
    for (String side in _sides) {
      out.remove('border-$side');
      out.remove('padding-$side');
      out.remove('margin-$side');
    }
  }

  /// A dictionary's own text colour that would not read on the popup, as a
  /// dark grey on a dark theme, gives way to the theme's.
  if (element.attributes['data-jdj-pill'] == null) {
    String? colorText = out['color'];
    Color? color = colorText == null ? null : _colorOf(colorText);
    if (color != null && lowContrast(color, theme.background)) {
      out.remove('color');
    }
  }

  if (out.isEmpty) {
    element.attributes.remove('style');
  } else {
    element.attributes['style'] =
        out.entries.map((e) => '${e.key}:${e.value};').join();
  }
}

/// Splits `margin` and `padding` into their four sides.
void _expandBoxes(Map<String, String> declarations) {
  for (String box in ['margin', 'padding']) {
    String? value = declarations.remove(box);
    if (value == null) {
      continue;
    }
    List<String> parts = _parts(value);
    List<String> four = _fourSides(parts);
    for (int i = 0; i < 4; i++) {
      declarations.putIfAbsent('$box-${_sides[i]}', () => four[i]);
    }
  }
}

/// Border longhands and shorthands as the renderer's one shorthand per
/// side, which it understands where it does not understand the longhands.
Map<String, String>? _borders(
  Map<String, String> declarations,
  DictionaryCssTheme theme,
) {
  List<String?> style = List.filled(4, null);
  List<String?> width = List.filled(4, null);
  List<String?> color = List.filled(4, null);
  bool any = false;

  void shorthand(String value, Iterable<int> sides) {
    for (String part in _parts(value)) {
      if (const {
        'none',
        'hidden',
        'solid',
        'dashed',
        'dotted',
        'double',
        'groove',
        'ridge',
        'inset',
        'outset'
      }.contains(part)) {
        for (int i in sides) {
          style[i] = part;
        }
      } else if (_colorOf(part) != null) {
        for (int i in sides) {
          color[i] = part;
        }
      } else {
        for (int i in sides) {
          width[i] = part;
        }
      }
    }
  }

  String? all = declarations.remove('border');
  if (all != null) {
    any = true;
    shorthand(all, [0, 1, 2, 3]);
  }
  for (int i = 0; i < 4; i++) {
    String? side = declarations.remove('border-${_sides[i]}');
    if (side != null) {
      any = true;
      shorthand(side, [i]);
    }
  }
  for (String part in ['style', 'width', 'color']) {
    String? value = declarations.remove('border-$part');
    if (value != null) {
      any = true;
      List<String> four = _fourSides(_parts(value));
      for (int i = 0; i < 4; i++) {
        (part == 'style' ? style : (part == 'width' ? width : color))[i] =
            four[i];
      }
    }
    for (int i = 0; i < 4; i++) {
      String? value = declarations.remove('border-${_sides[i]}-$part');
      if (value != null) {
        any = true;
        (part == 'style' ? style : (part == 'width' ? width : color))[i] =
            value;
      }
    }
  }
  declarations.remove('border-radius');
  if (!any) {
    return null;
  }
  Map<String, String> out = {};
  for (int i = 0; i < 4; i++) {
    String? s = style[i];
    if (s == null || s == 'none' || s == 'hidden') {
      continue;
    }
    out['border-${_sides[i]}'] =
        '${width[i] ?? '1px'} $s ${color[i] ?? hexOf(theme.text)}';
  }
  return out;
}

List<String> _fourSides(List<String> parts) {
  if (parts.isEmpty) {
    return List.filled(4, '0');
  }
  String top = parts[0];
  String right = parts.length > 1 ? parts[1] : top;
  String bottom = parts.length > 2 ? parts[2] : top;
  String left = parts.length > 3 ? parts[3] : right;
  return [top, right, bottom, left];
}

/// Splits a value on spaces outside brackets.
List<String> _parts(String value) {
  List<String> parts = [];
  int depth = 0;
  StringBuffer buffer = StringBuffer();
  for (int i = 0; i < value.length; i++) {
    String ch = value[i];
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
    }
    if (ch.trim().isEmpty && depth == 0) {
      if (buffer.isNotEmpty) {
        parts.add(buffer.toString());
        buffer.clear();
      }
    } else {
      buffer.write(ch);
    }
  }
  if (buffer.isNotEmpty) {
    parts.add(buffer.toString());
  }
  return parts;
}

/// A value with theme variables, `calc()` and `color-mix()` worked out, or
/// null when it cannot be.
String? resolveCssValue(String value, DictionaryCssTheme theme) {
  String text = value.trim();
  Map<String, String> variables = theme.variables;

  /// Innermost var() first, so fallbacks that use var() resolve too.
  RegExp varCall = RegExp(r'var\(\s*(--[\w-]+)\s*(?:,\s*([^()]*))?\)');
  for (int guard = 0; guard < 20 && text.contains('var('); guard++) {
    Match? match = varCall.firstMatch(text);
    if (match == null) {
      return null;
    }
    String? replacement = variables[match.group(1)] ?? match.group(2)?.trim();
    if (replacement == null) {
      return null;
    }
    text = text.replaceRange(match.start, match.end, replacement);
  }

  RegExp calcCall = RegExp(r'calc\(([^()]*)\)');
  for (int guard = 0; guard < 10 && text.contains('calc('); guard++) {
    Match? match = calcCall.firstMatch(text);
    if (match == null) {
      return null;
    }
    String? result = _calc(match.group(1)!);
    if (result == null) {
      return null;
    }
    text = text.replaceRange(match.start, match.end, result);
  }

  RegExp mixCall = RegExp(r'color-mix\(([^()]*(?:\([^()]*\))?[^()]*)\)');
  for (int guard = 0; guard < 10 && text.contains('color-mix('); guard++) {
    Match? match = mixCall.firstMatch(text);
    if (match == null) {
      return null;
    }
    String? result = _colorMix(match.group(1)!);
    if (result == null) {
      return null;
    }
    text = text.replaceRange(match.start, match.end, result);
  }
  return text;
}

/// Works out simple `calc()` sums: numbers with one unit, multiplied or
/// divided by plain numbers, added or subtracted with the same unit.
String? _calc(String expression) {
  RegExp term = RegExp(r'^\s*(-?[\d.]+)([a-z%]*)\s*');
  String rest = expression;
  Match? first = term.firstMatch(rest);
  if (first == null) {
    return null;
  }
  double value = double.parse(first.group(1)!);
  String unit = first.group(2)!;
  rest = rest.substring(first.end);
  while (rest.trim().isNotEmpty) {
    String op = rest.trim()[0];
    rest = rest.trim().substring(1);
    Match? next = term.firstMatch(rest);
    if (next == null) {
      return null;
    }
    double operand = double.parse(next.group(1)!);
    String operandUnit = next.group(2)!;
    rest = rest.substring(next.end);
    switch (op) {
      case '*':
        value *= operand;
        if (unit.isEmpty) {
          unit = operandUnit;
        }
      case '/':
        if (operand == 0 || operandUnit.isNotEmpty) {
          return null;
        }
        value /= operand;
      case '+' || '-':
        if (operandUnit != unit) {
          return null;
        }
        value = op == '+' ? value + operand : value - operand;
      default:
        return null;
    }
  }
  return '${_number(value)}$unit';
}

/// `color-mix(in srgb, A p%, B)` as one colour.
String? _colorMix(String arguments) {
  List<String> parts = arguments.split(',').map((e) => e.trim()).toList();
  if (parts.length != 3 || !parts[0].startsWith('in ')) {
    return null;
  }
  (Color, double?)? colorAndShare(String part) {
    Match? match = RegExp(r'^(.*?)\s+([\d.]+)%$').firstMatch(part);
    String colorText = match?.group(1) ?? part;
    double? share = match == null ? null : double.parse(match.group(2)!) / 100;
    Color? color = _colorOf(colorText);
    return color == null ? null : (color, share);
  }

  (Color, double?)? a = colorAndShare(parts[1]);
  (Color, double?)? b = colorAndShare(parts[2]);
  if (a == null || b == null) {
    return null;
  }
  double shareA = a.$2 ?? (b.$2 == null ? 0.5 : 1 - b.$2!);
  double shareB = 1 - shareA;
  double alpha = a.$1.opacity * shareA + b.$1.opacity * shareB;
  if (alpha <= 0) {
    return 'transparent';
  }

  /// Premultiplied, as CSS mixes colours.
  int channel(int Function(Color) of) =>
      ((of(a.$1) * a.$1.opacity * shareA + of(b.$1) * b.$1.opacity * shareB) /
              alpha)
          .round()
          .clamp(0, 255);
  Color mixed = Color.fromARGB(
    (alpha * 255).round(),
    channel((c) => c.red),
    channel((c) => c.green),
    channel((c) => c.blue),
  );
  return cssColor(mixed);
}

/// The colour [text] names, if it is one.
Color? _colorOf(String text) {
  String value = text.trim().toLowerCase();
  if (value == 'transparent') {
    return const Color(0x00000000);
  }
  Match? hex = RegExp(r'^#([0-9a-f]{3,8})$').firstMatch(value);
  if (hex != null) {
    String digits = hex.group(1)!;
    if (digits.length == 3 || digits.length == 4) {
      digits = digits.split('').map((d) => '$d$d').join();
    }
    if (digits.length == 6) {
      return Color(int.parse('ff$digits', radix: 16));
    }
    if (digits.length == 8) {
      return Color(
          int.parse(digits.substring(6) + digits.substring(0, 6), radix: 16));
    }
    return null;
  }
  Match? rgb = RegExp(r'^rgba?\(([^)]*)\)$').firstMatch(value);
  if (rgb != null) {
    List<String> parts = rgb
        .group(1)!
        .split(RegExp(r'[\s,/]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 3) {
      return null;
    }
    int channel(String part) => part.endsWith('%')
        ? (double.parse(part.substring(0, part.length - 1)) * 2.55).round()
        : double.parse(part).round();
    double alpha = parts.length > 3
        ? (parts[3].endsWith('%')
            ? double.parse(parts[3].substring(0, parts[3].length - 1)) / 100
            : double.parse(parts[3]))
        : 1;
    return Color.fromARGB((alpha * 255).round(), channel(parts[0]),
        channel(parts[1]), channel(parts[2]));
  }
  int? named = _namedColors[value];
  return named == null ? null : Color(named);
}

/// A colour as CSS the app's renderer reads: `#rrggbb`, or `rgba()` when
/// it is see-through, since the renderer reads eight hex digits as ARGB.
String cssColor(Color color) {
  if (color.alpha == 255) {
    return hexOf(color);
  }
  String alpha = (color.alpha / 255).toStringAsFixed(3);
  return 'rgba(${color.red}, ${color.green}, ${color.blue}, $alpha)';
}

/// A colour as `#rrggbb`, or `#rrggbbaa` when it is see-through.
String hexOf(Color color) {
  String rgb = (color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  if (color.alpha == 255) {
    return '#$rgb';
  }
  return '#$rgb${color.alpha.toRadixString(16).padLeft(2, '0')}';
}

String _number(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return (((value * 10000).round()) / 10000).toString();
}

/// The CSS named colours dictionaries use most.
const Map<String, int> _namedColors = {
  'black': 0xFF000000,
  'white': 0xFFFFFFFF,
  'red': 0xFFFF0000,
  'green': 0xFF008000,
  'blue': 0xFF0000FF,
  'yellow': 0xFFFFFF00,
  'orange': 0xFFFFA500,
  'purple': 0xFF800080,
  'brown': 0xFFA52A2A,
  'gray': 0xFF808080,
  'grey': 0xFF808080,
  'silver': 0xFFC0C0C0,
  'maroon': 0xFF800000,
  'navy': 0xFF000080,
  'teal': 0xFF008080,
  'olive': 0xFF808000,
  'lime': 0xFF00FF00,
  'aqua': 0xFF00FFFF,
  'cyan': 0xFF00FFFF,
  'fuchsia': 0xFFFF00FF,
  'magenta': 0xFFFF00FF,
  'pink': 0xFFFFC0CB,
  'gold': 0xFFFFD700,
  'goldenrod': 0xFFDAA520,
  'darkgoldenrod': 0xFFB8860B,
  'darkred': 0xFF8B0000,
  'darkgreen': 0xFF006400,
  'darkblue': 0xFF00008B,
  'darkgray': 0xFFA9A9A9,
  'darkgrey': 0xFFA9A9A9,
  'dimgray': 0xFF696969,
  'dimgrey': 0xFF696969,
  'lightgray': 0xFFD3D3D3,
  'lightgrey': 0xFFD3D3D3,
  'gainsboro': 0xFFDCDCDC,
  'whitesmoke': 0xFFF5F5F5,
  'crimson': 0xFFDC143C,
  'firebrick': 0xFFB22222,
  'indianred': 0xFFCD5C5C,
  'tomato': 0xFFFF6347,
  'coral': 0xFFFF7F50,
  'salmon': 0xFFFA8072,
  'chocolate': 0xFFD2691E,
  'sienna': 0xFFA0522D,
  'peru': 0xFFCD853F,
  'tan': 0xFFD2B48C,
  'khaki': 0xFFF0E68C,
  'darkorange': 0xFFFF8C00,
  'orangered': 0xFFFF4500,
  'seagreen': 0xFF2E8B57,
  'forestgreen': 0xFF228B22,
  'olivedrab': 0xFF6B8E23,
  'darkolivegreen': 0xFF556B2F,
  'steelblue': 0xFF4682B4,
  'royalblue': 0xFF4169E1,
  'dodgerblue': 0xFF1E90FF,
  'cornflowerblue': 0xFF6495ED,
  'slateblue': 0xFF6A5ACD,
  'slategray': 0xFF708090,
  'slategrey': 0xFF708090,
  'indigo': 0xFF4B0082,
  'darkviolet': 0xFF9400D3,
  'violet': 0xFFEE82EE,
  'orchid': 0xFFDA70D6,
  'plum': 0xFFDDA0DD,
  'darkmagenta': 0xFF8B008B,
  'mediumpurple': 0xFF9370DB,
  'rebeccapurple': 0xFF663399,
  'deeppink': 0xFFFF1493,
  'hotpink': 0xFFFF69B4,
  'lightblue': 0xFFADD8E6,
  'skyblue': 0xFF87CEEB,
  'lightgreen': 0xFF90EE90,
  'darkcyan': 0xFF008B8B,
  'darkslategray': 0xFF2F4F4F,
  'darkslategrey': 0xFF2F4F4F,
  'midnightblue': 0xFF191970,
  'beige': 0xFFF5F5DC,
  'ivory': 0xFFFFFFF0,
  'linen': 0xFFFAF0E6,
  'wheat': 0xFFF5DEB3,
};

/// Whether [color] is too close to [background] to read, by contrast
/// ratio, for keeping dictionary colours readable on dark popups.
bool lowContrast(Color color, Color background) {
  double l1 = color.computeLuminance();
  double l2 = background.computeLuminance();
  double ratio = (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
  return ratio < 2.2;
}
