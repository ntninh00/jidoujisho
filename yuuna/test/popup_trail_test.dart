import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

class _AppModel extends AppModel {
  final List<String> searched = [];

  @override
  int get maximumTerms => 10;

  @override
  Future<DictionarySearchResult> searchDictionary({
    required String searchTerm,
    required bool searchWithWildcards,
    int? overrideMaximumTerms,
    bool useCache = true,
    String? channel,
    bool byMeaning = false,
    bool persist = true,
  }) async {
    searched.add(searchTerm);
    return DictionarySearchResult(searchTerm: searchTerm);
  }

  @override
  Future<void> addToDictionaryHistory(
      {required DictionarySearchResult result}) async {}
}

class _Page extends BaseSourcePage {
  const _Page() : super(item: null);

  @override
  BaseSourcePageState<_Page> createState() => _PageState();
}

class _PageState extends BaseSourcePageState<_Page> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(body: buildDictionary()),
    );
  }
}

void main() {
  late _AppModel appModel;

  Future<_PageState> open(WidgetTester tester) async {
    appModel = _AppModel();
    await tester.pumpWidget(ProviderScope(
      overrides: [appProvider.overrideWith((ref) => appModel)],
      child: MaterialApp(
        builder: (context, child) => Spacing(
          dataBuilder: (context) => SpacingData.generate(10),
          child: child!,
        ),
        home: const _Page(),
      ),
    ));
    _PageState page = tester.state<_PageState>(find.byType(_Page));
    page.clearDictionaryResult();
    return page;
  }

  /// The word the popup offers to go back to, if any.
  String? backTo(WidgetTester tester) {
    Finder chip = find.ancestor(
      of: find.byType(Text),
      matching: find.byType(InkWell),
    );
    if (chip.evaluate().isEmpty) {
      return null;
    }
    return tester
        .widget<Text>(find.descendant(of: chip, matching: find.byType(Text)))
        .data;
  }

  testWidgets('a word looked up in the popup stays in it, and back returns',
      (tester) async {
    _PageState page = await open(tester);

    await page.searchDictionaryResult(
      searchTerm: '猫',
      position: JidoujishoPopupPosition.topHalf,
    );
    await tester.pump();
    expect(backTo(tester), isNull);

    page.lookUpInPopup('犬');
    await tester.pumpAndSettle();
    page.lookUpInPopup('鳥');
    await tester.pumpAndSettle();
    expect(appModel.searched, ['猫', '犬', '鳥']);
    expect(backTo(tester), '犬');

    await tester.tap(find.text('犬'));
    await tester.pumpAndSettle();
    expect(appModel.searched.last, '犬');
    expect(backTo(tester), '猫');

    expect(await page.onWillPop(), isFalse);
    await tester.pumpAndSettle();
    expect(appModel.searched.last, '猫');
    expect(backTo(tester), isNull);
    expect(page.isDictionaryShown, isTrue);
  });

  testWidgets('a new word from the media starts over', (tester) async {
    _PageState page = await open(tester);

    await page.searchDictionaryResult(
      searchTerm: '猫',
      position: JidoujishoPopupPosition.topHalf,
    );
    page.lookUpInPopup('犬');
    await tester.pumpAndSettle();
    expect(backTo(tester), '猫');

    await page.searchDictionaryResult(
      searchTerm: '魚',
      position: JidoujishoPopupPosition.topHalf,
    );
    await tester.pumpAndSettle();
    expect(backTo(tester), isNull);
    expect(page.popupBack(), isFalse);

    page.lookUpInPopup('犬');
    await tester.pumpAndSettle();
    page.clearDictionaryResult();
    await tester.pumpAndSettle();
    expect(page.popupBack(), isFalse);
  });
}
