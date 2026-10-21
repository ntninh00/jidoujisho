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

  /// The space the popup can grow to fill on the screen.
  Rect popupRoom(WidgetTester tester) {
    Expanded popup = tester
        .widgetList<Expanded>(find.byType(Expanded))
        .firstWhere((expanded) => expanded.child is Align);
    RenderBox box = tester.renderObject(find.byWidget(popup.child));
    return box.localToGlobal(Offset.zero) & box.size;
  }

  testWidgets('the popup leaves the looked-up word in view', (tester) async {
    _PageState page = await open(tester);
    Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;

    /// A word across the middle, with a little more room above it.
    Rect word = Rect.fromLTWH(380, screen.height * 0.46, 40, 60);
    await page.searchDictionaryResult(
      searchTerm: '輪廻転生',
      position: JidoujishoPopupPosition.bottomHalf,
    );
    page.keepWordVisible(parts: [word], area: screen);
    await tester.pumpAndSettle();
    Rect room = popupRoom(tester);
    expect(room.top, 0);
    expect(room.bottom, lessThanOrEqualTo(word.top));
    expect(room.height, greaterThan(screen.height / 4));

    /// A word in the top half gets the usual bottom half.
    await page.searchDictionaryResult(
      searchTerm: '野球',
      position: JidoujishoPopupPosition.topHalf,
    );
    word = Rect.fromLTWH(380, screen.height * 0.2, 40, 60);
    page.keepWordVisible(parts: [word], area: screen);
    await tester.pumpAndSettle();
    room = popupRoom(tester);
    expect(room.bottom, screen.height);
    expect(room.top, greaterThanOrEqualTo(screen.height / 2));
    expect(room.top, greaterThanOrEqualTo(word.bottom));

    /// A word just under the middle pushes the popup below it.
    await page.searchDictionaryResult(
      searchTerm: '桃香',
      position: JidoujishoPopupPosition.bottomHalf,
    );
    word = Rect.fromLTWH(380, screen.height * 0.3, 40, screen.height * 0.25);
    page.keepWordVisible(parts: [word], area: screen);
    await tester.pumpAndSettle();
    room = popupRoom(tester);
    expect(room.top, greaterThanOrEqualTo(word.bottom));
    expect(room.bottom, screen.height);

    /// A word at the foot of one column and the head of the next gets the
    /// room between its parts.
    await page.searchDictionaryResult(
      searchTerm: '一言一句',
      position: JidoujishoPopupPosition.topHalf,
    );
    Rect foot = Rect.fromLTWH(420, screen.height * 0.9, 40, 40);
    Rect head = Rect.fromLTWH(380, screen.height * 0.05, 40, 120);
    page.keepWordVisible(parts: [foot, head], area: screen);
    await tester.pumpAndSettle();
    room = popupRoom(tester);
    expect(room.top, greaterThanOrEqualTo(head.bottom));
    expect(room.bottom, lessThanOrEqualTo(foot.top));
    expect(room.height, greaterThanOrEqualTo(screen.height / 4));

    /// Parts on lines next to each other leave no room between them, so the
    /// popup goes to the side with more room.
    await page.searchDictionaryResult(
      searchTerm: '桜並木',
      position: JidoujishoPopupPosition.topHalf,
    );
    Rect end = Rect.fromLTWH(300, screen.height * 0.3, 100, 24);
    Rect next = Rect.fromLTWH(0, screen.height * 0.3 + 30, 60, 24);
    page.keepWordVisible(parts: [end, next], area: screen);
    await tester.pumpAndSettle();
    room = popupRoom(tester);
    expect(room.top, greaterThanOrEqualTo(next.bottom));
    expect(room.bottom, screen.height);
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
