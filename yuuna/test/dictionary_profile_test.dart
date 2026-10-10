import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/dictionary.dart';

void main() {
  test("the catalog's record gives a dictionary's languages and kind", () {
    DictionaryProfile? grammar = DictionaryProfile.fromSource({
      'kind': 'server',
      'language': 'ja',
      'target': 'vi',
      'section': 'grammar',
    });
    expect(grammar?.source, 'ja');
    expect(grammar?.target, 'vi');
    expect(grammar?.kind, DictionaryProfile.grammar);
    expect(
      DictionaryProfile.fromSource({'language': 'en', 'section': 'bilingual'})
          ?.kind,
      DictionaryProfile.words,
    );
    // Recorded before the app kept sections: told from its rows instead.
    expect(DictionaryProfile.fromSource({'language': 'ja'}), isNull);
    expect(DictionaryProfile.fromSource(null), isNull);
  });

  test("an entry's meanings are told apart by their script", () {
    expect(DictionaryProfile.languageOfDefinitions(['bảo tàng']), 'vi');
    expect(DictionaryProfile.languageOfDefinitions(['美術品などを集めた施設']), 'ja');
    expect(DictionaryProfile.languageOfDefinitions(['museum; gallery']), 'en');
    // Structured content's keys and tags are not counted as English.
    expect(
      DictionaryProfile.languageOfDefinitions([
        '{"type":"structured-content","content":[{"tag":"span","content":"博物館。展示する施設"}]}'
      ]),
      'ja',
    );
    expect(
      DictionaryProfile.languageOfMost(['ja', 'en', 'ja', null]),
      'ja',
    );
    expect(DictionaryProfile.languageOfMost([null]), isNull);
  });
}
