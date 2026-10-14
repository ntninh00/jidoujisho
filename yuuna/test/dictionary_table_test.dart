import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';

class _AppModel extends AppModel {
  @override
  double get dictionaryFontSize => 15;
}

Map<String, Object> _table(List<List<String>> rows) => {
      'type': 'structured-content',
      'content': {
        'tag': 'table',
        'content': [
          for (List<String> row in rows)
            {
              'tag': 'tr',
              'content': [
                for (String cell in row) {'tag': 'td', 'content': cell},
              ],
            },
        ],
      },
    };

/// How far the table in the shown entry scrolls sideways.
Future<double> _sideways(WidgetTester tester, Map<String, Object> table) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  DictionaryEntry entry = DictionaryEntry(
    definitions: [jsonEncode(table)],
    popularity: 0,
  );
  entry.dictionary.value =
      Dictionary(id: -1, name: 'test', formatKey: 'yomichan', order: 0);
  await tester.pumpWidget(ProviderScope(
    overrides: [appProvider.overrideWith((ref) => _AppModel())],
    child: MaterialApp(
      home: Scaffold(
        body: ProviderScope(
          overrides: [
            dictionaryPreviewCssProvider.overrideWithValue(const []),
          ],
          child: SingleChildScrollView(
            child: DictionaryHtmlWidget(entry: entry, onSearch: (_) {}),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();

  ScrollableState sideways = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .firstWhere((state) => state.widget.axis == Axis.horizontal);
  return sideways.position.maxScrollExtent;
}

void main() {
  testWidgets('a table wider than the screen scrolls sideways', (tester) async {
    double extent = await _sideways(
      tester,
      _table([
        ['', '肯定', '否定', '丁寧', '丁寧否定', '過去'],
        ['使役受身', '食べさせられる', '食べさせられない', '食べさせられます', '食べさせられません', '食べさせられた'],
      ]),
    );
    expect(extent, greaterThan(0));
  });

  testWidgets('a table that fits the screen stays put', (tester) async {
    double extent = await _sideways(
      tester,
      _table([
        ['音読み', 'ショク'],
        ['訓読み', 'た.べる'],
      ]),
    );
    expect(extent, 0);
  });
}
