import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/dictionary.dart';

/// A card's text for a definition as a Yomitan dictionary writes it.
String cardText(Object content) {
  String definition = YomichanFormat.processDefinitions([
    {'type': 'structured-content', 'content': content},
  ]).single;
  return YomichanFormat.instance.getCustomDefinitionText(definition);
}

Map<String, Object> glossary(List<Object> glosses) => {
      'tag': 'ul',
      'data': {'content': 'glossary'},
      'content': [
        for (Object gloss in glosses) {'tag': 'li', 'content': gloss},
      ],
    };

void main() {
  test('a Jitendex entry gives its senses, without the extras', () {
    String text = cardText([
      {
        'tag': 'ul',
        'data': {'content': 'sense-groups'},
        'content': [
          {
            'tag': 'li',
            'data': {'content': 'sense-group'},
            'content': [
              {
                'tag': 'span',
                'data': {'content': 'part-of-speech-info'},
                'content': '5-dan',
              },
              {
                'tag': 'ol',
                'content': [
                  {
                    'tag': 'li',
                    'data': {'content': 'sense'},
                    'content': [
                      glossary(['to represent', 'to signify']),
                      {
                        'tag': 'div',
                        'data': {'content': 'extra-info'},
                        'content': '＆のマークはａｎｄの文字を表す。',
                      },
                    ],
                  },
                  {
                    'tag': 'li',
                    'data': {'content': 'sense'},
                    'content': [
                      glossary(['to reveal']),
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
      {
        'tag': 'div',
        'data': {'content': 'forms'},
        'content': {
          'tag': 'table',
          'content': {'tag': 'tr', 'content': '表す'},
        },
      },
      {
        'tag': 'div',
        'data': {'content': 'attribution'},
        'content': 'JMdict | Tatoeba',
      },
    ]);

    expect(text, '1. to represent; to signify\n2. to reveal');
  });

  test('a single sense is its glosses, readings left out', () {
    String text = cardText([
      {
        'tag': 'div',
        'data': {'content': 'sense'},
        'content': [
          glossary([
            'baseball',
            [
              {
                'tag': 'ruby',
                'content': [
                  '野球',
                  {'tag': 'rt', 'content': 'やきゅう'},
                ],
              },
              ' game',
            ],
          ]),
        ],
      },
    ]);

    expect(text, 'baseball; 野球 game');
  });

  test('a definition that is only a table keeps it', () {
    String text = cardText({
      'tag': 'table',
      'content': [
        {
          'tag': 'tr',
          'content': [
            {'tag': 'td', 'content': '書く'},
            {'tag': 'td', 'content': '書かない'},
          ],
        },
      ],
    });

    expect(text, '書く 書かない');
  });

  test('a plain definition stays as it is', () {
    expect(
      YomichanFormat.instance.shouldUseCustomDefinitionWidget('baseball'),
      isFalse,
    );
    expect(jsonEncode(YomichanFormat.processDefinitions(['baseball'])),
        '["baseball"]');
  });
}
