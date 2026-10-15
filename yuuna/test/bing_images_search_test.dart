import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/creator.dart';

void main() {
  test('Bing searches for the word alone, encoded', () {
    Uri uri = BingImagesSearchEnhancement.searchUri('猫 & 犬');

    expect(uri.host, 'www.bing.com');
    expect(uri.path, '/images/search');
    expect(uri.queryParameters['q'], '猫 & 犬');
  });

  test('image addresses are read from results, broken ones skipped', () {
    String result(String turl) => [
          '<a class="iusc" m="{&quot;murl&quot;:',
          '&quot;https://example.com/full.jpg&quot;,&quot;turl&quot;:',
          '&quot;$turl&quot;}" href="#"></a>',
        ].join();

    String html = [
      '<html><body>',
      result('https://ts1.mm.bing.net/th?id=OIP.a&amp;pid=15.1'),
      '<a class="iusc" href="#"></a>',
      '<a class="iusc" m="not json" href="#"></a>',
      '<a class="iusc" m="[1, 2]" href="#"></a>',
      result('https://ts3.mm.bing.net/th?id=OIP.b'),
      '</body></html>',
    ].join();

    expect(BingImagesSearchEnhancement.parseImageUrls(html), [
      'https://ts1.mm.bing.net/th?id=OIP.a&pid=15.1',
      'https://ts3.mm.bing.net/th?id=OIP.b',
    ]);
  });

  test('a page with no results gives no images', () {
    expect(BingImagesSearchEnhancement.parseImageUrls(null), isEmpty);
    expect(
      BingImagesSearchEnhancement.parseImageUrls('<p>No results</p>'),
      isEmpty,
    );
  });
}
