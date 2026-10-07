import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/i18n/strings.g.dart';

/// How the app shows wording from the dictionary server's strings page: as
/// overrides on the strings it was built with, or in English's place for a
/// language it wasn't built with. With JDJ_DICT_SERVER and JDJ_DICT_READER
/// set, the server's languages are fetched too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    LocaleSettings.overrideTranslationsFromMap(
        locale: AppLocale.en, isFlatMap: true, map: {});
    LocaleSettings.overrideTranslationsFromMap(
        locale: AppLocale.vi, isFlatMap: true, map: {});
    LocaleSettings.setLocale(AppLocale.en);
  });

  test('a fix on the server replaces one string', () {
    LocaleSettings.overrideTranslationsFromMap(
      locale: AppLocale.vi,
      isFlatMap: true,
      map: {'back': 'Trở lại', 'import_name': 'Nhập 『\$name』'},
    );
    LocaleSettings.setLocale(AppLocale.vi);
    expect(t.back, 'Trở lại');
    expect(t.import_name(name: 'JMdict'), 'Nhập 『JMdict』');
    expect(t.search, 'Tìm kiếm');
  });

  test('a language the app lacks takes English\'s place', () {
    LocaleSettings.overrideTranslationsFromMap(
      locale: AppLocale.en,
      isFlatMap: true,
      map: {
        'back': '返回',
        'retrying_in.seconds.other': '\$n 秒后重试',
        'addons.field.term.label': '词条',
      },
    );
    LocaleSettings.setLocale(AppLocale.en);
    expect(t.back, '返回');
    expect(t.retrying_in.seconds(n: 3), '3 秒后重试');
    expect(t['addons.field.term.label'], '词条');
    // Strings it doesn't have stay English.
    expect(t.search, 'Search');
  });

  String? url = Platform.environment['JDJ_DICT_SERVER'];
  String reader = Platform.environment['JDJ_DICT_READER'] ?? '';
  test('the server lists its languages and their strings', () async {
    // The test binding answers every request with 400; this one is real.
    HttpOverrides.global = _RealHttp();
    DictionaryServer server = DictionaryServer(url: url!, token: reader);
    List<AppLanguage> languages = await server.appLanguages();
    expect(languages.map((language) => language.code), containsAll(['en', 'vi']));
    for (AppLanguage language in languages) {
      Map<String, String> strings = await server.appStrings(language.code);
      if (!language.builtIn) {
        expect(strings, isNotEmpty);
      }
      // Every value is one the app knows how to show.
      LocaleSettings.overrideTranslationsFromMap(
          locale: AppLocale.en, isFlatMap: true, map: strings);
      expect(t.back, isNotEmpty);
    }
  }, skip: url == null);
}

class _RealHttp extends HttpOverrides {}
