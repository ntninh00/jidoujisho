import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/language.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';

/// Writes a small EPUB with [opfMetadata] in its package file and
/// [paragraph] repeated through one chapter.
String writeEpub(String opfMetadata, String paragraph) {
  Archive archive = Archive();
  void add(String name, String text) {
    List<int> bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('mimetype', 'application/epub+zip');
  add('META-INF/container.xml',
      '<container><rootfiles><rootfile full-path="OEBPS/content.opf"/></rootfiles></container>');
  add('OEBPS/content.opf',
      '<package><metadata xmlns:dc="http://purl.org/dc/elements/1.1/">$opfMetadata</metadata></package>');
  add('OEBPS/ch1.xhtml',
      '<html><body>${List.filled(40, '<p>$paragraph</p>').join()}</body></html>');
  String path =
      '${Directory.systemTemp.createTempSync('jdj_epub_').path}/book.epub';
  File(path).writeAsBytesSync(ZipEncoder().encode(archive)!);
  return path;
}

void main() {
  const String english =
      'Data is at the center of many challenges in system design today.';
  const String japanese = '吾輩は猫である。名前はまだ無い。どこで生れたかとんと見当がつかぬ。';

  test('three-letter language codes such as eng are understood', () async {
    String path =
        writeEpub('<dc:language id="pub-language">eng</dc:language>', english);
    expect(await TtuLibrary.detectLanguageCode(path), 'en');
  });

  test('a book without a language tag is told by its text', () async {
    expect(await TtuLibrary.detectLanguageCode(writeEpub('', english)), 'en');
    expect(await TtuLibrary.detectLanguageCode(writeEpub('', japanese)), 'ja');
  });

  test('Japanese text wins over a wrong tag', () async {
    String path = writeEpub('<dc:language>en</dc:language>', japanese);
    expect(await TtuLibrary.detectLanguageCode(path), 'ja');
  });

  test('a declared language other than Japanese is kept for Latin text',
      () async {
    String path = writeEpub('<opf:language>fr-FR</opf:language>', english);
    expect(await TtuLibrary.detectLanguageCode(path), 'fr');
  });

  test('the book from the user, if present, reads as English', () async {
    File file = File(Platform.environment['JDJ_SAMPLE_EPUB'] ?? '');
    if (!file.existsSync()) {
      return;
    }
    expect(await TtuLibrary.detectLanguageCode(file.path), 'en');
  });
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
