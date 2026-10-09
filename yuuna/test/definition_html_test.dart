import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/dictionary.dart';

const DictionaryCssTheme _theme = DictionaryCssTheme(
  text: Colors.black,
  background: Colors.white,
  fontSize: 15,
);

String _html(Object content) =>
    definitionHtml(jsonEncode(content), css: const [], theme: _theme);

void main() {
  test('line breaks in structured content are kept', () {
    expect(
      _html(['ねこ【猫】\n〘名〙\n❶ 愛玩用']),
      contains('ねこ【猫】<br>〘名〙<br>❶ 愛玩用'),
    );
  });

  test('a meaning before a block gets a block of its own', () {
    String html = _html([
      'having beauty',
      {
        'tag': 'ul',
        'content': [
          {'tag': 'li', 'content': 'a beautiful woman'},
        ],
      },
    ]);
    expect(html, contains('<div>having beauty</div><ul'));
  });

  test('tags and glossaries beside a block stay in their line', () {
    String html = _html([
      {
        'tag': 'span',
        'data': {'content': 'tag'},
        'content': 'abbr.',
      },
      {
        'tag': 'ul',
        'data': {'content': 'glossary'},
        'content': [
          {'tag': 'li', 'content': 'wheelbarrow'},
        ],
      },
      {'tag': 'div', 'content': 'See also'},
    ]);
    expect(html, isNot(contains('<div><span')));
  });

  test('inflected forms link to their words', () {
    List<String> definitions = YomichanFormat.processDefinitions([
      [
        'strap',
        ['present participle'],
      ],
    ]);
    String html =
        definitionHtml(definitions.single, css: const [], theme: _theme);
    expect(html, contains('query="strap"'));
    expect(html, contains('strap</a> (present participle)'));
  });

  test('a redirect with a link of its own keeps only that', () {
    List<String> definitions = YomichanFormat.processDefinitions([
      {
        'type': 'structured-content',
        'content': ['⟶ 労働相'],
      },
      [
        '労働相',
        ['redirected from 勞働相'],
      ],
    ]);
    expect(definitions, [
      jsonEncode(['⟶ 労働相'])
    ]);
  });
}
