import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';

class _Server extends DictionaryServer {
  _Server() : super(url: 'https://example.com', token: 'x');

  @override
  Future<List<SubtitleShow>> searchSubtitles(String query) async => [];

  @override
  Future<List<SubtitleFile>> subtitleFiles(SubtitleShow show) async => [
        for (int episode in [1, 2, 3])
          SubtitleFile.fromJson({
            'name': 'Show - 0$episode.srt',
            'size': 20000,
            'episode': episode,
          }),
      ];
}

class _AppModel extends AppModel {
  @override
  DictionaryServer? get dictionaryServer => _Server();
}

void main() {
  testWidgets(
      'on a phone on its side, the search keeps the keyboard as it opens',
      (tester) async {
    tester.view.physicalSize = const Size(2340, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [appProvider.overrideWith((ref) => _AppModel())],
      child: MaterialApp(
        builder: (context, child) => Spacing(
          dataBuilder: (context) => SpacingData.generate(10),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showTtuSheet<SubtitlePick>(
                  context: context,
                  builder: (_) =>
                      const SubtitleSearchSheet(name: 'Show 05.mkv'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    bool focused() => tester
        .state<EditableTextState>(find.byType(EditableText))
        .widget
        .focusNode
        .hasFocus;
    expect(focused(), isTrue);

    /// The keyboard takes the bottom of the screen.
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pumpAndSettle();
    expect(focused(), isTrue);
  });

  testWidgets('opened on a show, it lists its files at the episode given',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [appProvider.overrideWith((ref) => _AppModel())],
      child: MaterialApp(
        builder: (context, child) => Spacing(
          dataBuilder: (context) => SpacingData.generate(10),
          child: child!,
        ),
        home: Scaffold(
          body: SubtitleSearchSheet(
            name: '',
            fillQuery: false,
            show: SubtitleShow.fromJson(
                {'id': 7, 'name': 'Show', 'japaneseName': 'ショー'}),
            episode: 2,
          ),
        ),
      ),
    ));

    /// Straight to the show's files: no search, so no keyboard, first.
    expect(find.byType(TextField), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('ショー'), findsOneWidget);
    expect(find.text('Show - 02.srt'), findsOneWidget);
    expect(find.text('Show - 01.srt'), findsNothing);
  });
}
