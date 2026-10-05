import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/language.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';

void main() {
  TtuBook book() => TtuBook(
        language: JapaneseLanguage.instance,
        port: 52159,
        id: 7,
        title: '吾輩は猫である & co',
        characters: 1000,
        lastBookOpen: 0,
        lastBookModified: 0,
        exploredCharCount: 250,
        progress: 0.25,
        coverPath: null,
      );

  test('page settings script writes the values ッツ reads', () {
    String script = TtuPagePreset(
      theme: 'dark',
      fontSize: 26,
      vertical: false,
      paginated: false,
      furigana: false,
    ).toScript(autoBookmark: true);

    expect(script, contains("s.setItem('theme', 'dark-theme');"));
    expect(script, contains("s.setItem('fontSize', '26');"));
    expect(script, contains("s.setItem('writingMode', 'horizontal-tb');"));
    expect(script, contains("s.setItem('viewMode', 'continuous');"));
    expect(script, contains("s.setItem('hideFurigana', '1');"));
    expect(script, contains("s.setItem('autoBookmark', '1');"));
  });

  test('without a theme the script leaves ッツ’s theme alone', () {
    String script = TtuPagePreset(
      theme: null,
      fontSize: 24,
      vertical: true,
      paginated: true,
      furigana: true,
    ).toScript(autoBookmark: false);

    expect(script, isNot(contains("'theme'")));
    expect(script, contains("s.setItem('writingMode', 'vertical-rl');"));
    expect(script, contains("s.setItem('viewMode', 'paginated');"));
    expect(script, contains("s.setItem('autoBookmark', '0');"));
  });

  test('jump address carries the book, position and an encoded title', () {
    Uri uri = Uri.parse(
      TtuLaunch.jumpUrl(
        book: book(),
        position: const TtuPosition(characters: 600, progress: 0.6),
      ),
    );

    expect(uri.port, 52159);
    expect(uri.path, '/jidoujisho/jump.html');
    expect(uri.queryParameters['id'], '7');
    expect(uri.queryParameters['c'], '600');
    expect(uri.queryParameters['p'], '0.60000');
    expect(uri.queryParameters['title'], '吾輩は猫である & co');
  });

  test('a launch without a target opens the book where ッツ saved it', () {
    TtuLaunch launch = TtuLaunch(book: book());
    expect(launch.initialUrl, book().readerUrl);
  });

  test('book keys and totals', () {
    expect(book().key, '52159/7');
    TtuBook old = TtuBook(
      language: EnglishLanguage.instance,
      port: 52160,
      id: 1,
      title: 'Old',
      characters: 0,
      lastBookOpen: 0,
      lastBookModified: 0,
      exploredCharCount: 300,
      progress: 0.5,
      coverPath: null,
    );
    expect(old.totalCharacters, 600);
  });

  test('percent labels', () {
    expect(ttuPercent(0.0021), '0.2%');
    expect(ttuPercent(0.523), '52%');
    expect(ttuPercent(0.87), '87%');
    expect(ttuPercent(1), '100%');
  });
}
