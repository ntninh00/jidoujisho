import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:yuuna/dictionary.dart';

/// Words a search by meaning found, to mark wherever a definition has
/// them, with or without accents.
@immutable
class MeaningMarks {
  /// Mark [words], as [meaningWordsOfText] gives them, in [color].
  const MeaningMarks({required this.words, required this.color});

  /// The words, folded.
  final List<String> words;

  /// The colour behind them.
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is MeaningMarks &&
      listEquals(words, other.words) &&
      color == other.color;

  @override
  int get hashCode => Object.hash(Object.hashAll(words), color);
}

/// Tags Yomitan allows in structured content. Anything else becomes a span.
const Set<String> _tags = {
  'br',
  'ruby',
  'rt',
  'rp',
  'table',
  'thead',
  'tbody',
  'tfoot',
  'tr',
  'td',
  'th',
  'span',
  'div',
  'ol',
  'ul',
  'li',
  'details',
  'summary',
  'img',
  'a',
};

/// Yomitan's style properties that take a plain number as a length in em.
const Set<String> _emNumbers = {
  'margin',
  'marginTop',
  'marginLeft',
  'marginRight',
  'marginBottom',
  'padding',
  'paddingTop',
  'paddingLeft',
  'paddingRight',
  'paddingBottom',
  'fontSize',
  'borderWidth',
  'borderRadius',
};

/// Builds HTML for one stored definition: structured content as Yomitan
/// shows it, with each part marked the way dictionary stylesheets expect
/// (`data-sc-*` attributes and `gloss-sc-*` classes), or plain text with
/// its line breaks. [css] and [theme] style the result for the app's
/// renderer. [marks], if any, are marked last, over the dictionary's styles.
String definitionHtml(
  String definition, {
  required List<DictionaryCssRule> css,
  required DictionaryCssTheme theme,
  MeaningMarks? marks,
}) {
  Object? content;
  String trimmed = definition.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      content = jsonDecode(definition);
    } on FormatException {
      content = null;
    }
  }
  dom.Element root = dom.Element.tag('div')
    ..attributes['class'] = 'yomitan-glossary';
  if (content == null) {
    List<String> lines = definition.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (i > 0) {
        root.append(dom.Element.tag('br'));
      }
      root.append(dom.Text(lines[i]));
    }
    _mark(root, marks);
    return root.outerHtml;
  }
  for (dom.Node node in _nodes(content)) {
    root.append(node);
  }
  applyDictionaryCss(root, css, theme);
  _mark(root, marks);
  return root.outerHtml;
}

/// Wraps each of [marks]' words in the text under [root] in a marked span:
/// whole words, found without accents and marked as written.
void _mark(dom.Element root, MeaningMarks? marks) {
  if (marks == null || marks.words.isEmpty) {
    return;
  }
  RegExp word = RegExp(
    '(?<![\\p{L}\\p{M}\\p{N}])'
    '(?:${marks.words.map(RegExp.escape).join('|')})'
    '(?![\\p{L}\\p{M}\\p{N}])',
    unicode: true,
  );
  String style = 'background-color:${cssColor(marks.color)};';

  List<dom.Text> texts = [];
  void collect(dom.Node node) {
    for (dom.Node child in node.nodes) {
      if (child is dom.Text) {
        texts.add(child);
      } else if (child is dom.Element && child.localName != 'rt') {
        collect(child);
      }
    }
  }

  collect(root);
  for (dom.Text text in texts) {
    String data = text.data;
    List<int> origins = [];
    String folded = foldMeaningText(data, origins);
    List<RegExpMatch> found = word.allMatches(folded).toList();
    if (found.isEmpty) {
      continue;
    }
    dom.Node parent = text.parentNode!;
    int at = 0;
    for (RegExpMatch match in found) {
      int start = origins[match.start];
      int end = match.end < origins.length ? origins[match.end] : data.length;
      if (start > at) {
        parent.insertBefore(dom.Text(data.substring(at, start)), text);
      }
      parent.insertBefore(
        dom.Element.tag('span')
          ..attributes['style'] = style
          ..append(dom.Text(data.substring(start, end))),
        text,
      );
      at = end;
    }
    if (at < data.length) {
      parent.insertBefore(dom.Text(data.substring(at)), text);
    }
    text.remove();
  }
}

/// Structured content as DOM nodes. Content may be text, a list, an
/// element, or a definition object wrapping content.
List<dom.Node> _nodes(Object? content) {
  if (content == null) {
    return const [];
  }
  if (content is String) {
    return [dom.Text(content)];
  }
  if (content is num || content is bool) {
    return [dom.Text('$content')];
  }
  if (content is List) {
    return content.expand(_nodes).toList();
  }
  if (content is Map) {
    if (content['type'] == 'structured-content') {
      return _nodes(content['content']);
    }
    if (content['type'] == 'text') {
      return [dom.Text('${content['text'] ?? ''}')];
    }
    if (content['type'] == 'image' || content['tag'] == 'img') {
      return [_image(content)];
    }
    return [_element(content)];
  }
  return const [];
}

dom.Element _element(Map content) {
  String tag = '${content['tag'] ?? 'span'}';
  if (!_tags.contains(tag)) {
    tag = 'span';
  }
  dom.Element element = dom.Element.tag(tag);
  element.attributes['class'] = 'gloss-sc-$tag';

  Object? data = content['data'];
  if (data is Map) {
    data.forEach((key, value) {
      element.attributes['data-sc-${'$key'.toLowerCase()}'] = '$value';
    });
  }
  for (String attribute in ['lang', 'title']) {
    Object? value = content[attribute];
    if (value is String && value.isNotEmpty) {
      element.attributes[attribute] = value;
    }
  }
  for (String span in ['colSpan', 'rowSpan']) {
    Object? value = content[span];
    if (value is num) {
      element.attributes[span.toLowerCase()] = '${value.toInt()}';
    }
  }
  if (tag == 'a') {
    String href = '${content['href'] ?? ''}';
    element.attributes['href'] = href;

    /// Links within the dictionary look the term up.
    if (href.startsWith('?')) {
      String? query = Uri.tryParse('http://x/$href')?.queryParameters['query'];
      if (query != null && query.isNotEmpty) {
        element.attributes['query'] = query;
      }
    }
  }
  Object? style = content['style'];
  if (style is Map) {
    String inline = _inlineStyle(style);
    if (inline.isNotEmpty) {
      element.attributes['style'] = inline;
    }
  }
  if (tag != 'br') {
    for (dom.Node node in _nodes(content['content'])) {
      element.append(node);
    }
  }
  return element;
}

/// An image, sized as the dictionary asked: em sizes stay relative to the
/// text, so small pictures such as tags sit in the line.
dom.Element _image(Map content) {
  dom.Element image = dom.Element.tag('img');
  image.attributes['src'] = 'jidoujisho://${content['path'] ?? ''}';
  String units = '${content['sizeUnits'] ?? 'px'}';
  for (String size in ['width', 'height']) {
    Object? value = content[size];
    if (value is num) {
      image.attributes['data-jdj-$size'] = '$value$units';
    }
  }
  for (String attribute in [
    'title',
    'description',
    'appearance',
    'verticalAlign',
    'imageRendering',
  ]) {
    Object? value = content[attribute];
    if (value is String && value.isNotEmpty) {
      image.attributes[attribute == 'description'
          ? 'alt'
          : 'data-jdj-${attribute.toLowerCase()}'] = value;
    }
  }
  if (content['pixelated'] == true) {
    image.attributes['data-jdj-imagerendering'] = 'pixelated';
  }
  return image;
}

/// A Yomitan style object as CSS declarations.
String _inlineStyle(Map style) {
  List<String> declarations = [];
  style.forEach((key, value) {
    String property = '$key'.replaceAllMapped(
        RegExp('[A-Z]'), (match) => '-${match.group(0)!.toLowerCase()}');
    String text;
    if (value is num) {
      text = _emNumbers.contains('$key') ? '${value}em' : '$value';
    } else if (value is List) {
      text = value.join(' ');
    } else {
      text = '$value';
    }
    if (text.isNotEmpty) {
      declarations.add('$property:$text');
    }
  });
  return declarations.join(';');
}
