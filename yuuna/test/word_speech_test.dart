import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/utils.dart';

void main() {
  test('a word is read in the language its script is written in', () {
    expect(WordSpeech.languageOfText('ミュージアム'), 'ja');
    expect(WordSpeech.languageOfText('食べる'), 'ja');
    expect(WordSpeech.languageOfText('博物館'), 'ja');
    expect(WordSpeech.languageOfText('박물관'), 'ko');
    expect(WordSpeech.languageOfText('музей'), 'ru');
    expect(WordSpeech.languageOfText('bảo tàng'), 'vi');
    expect(WordSpeech.languageOfText('museum'), 'en');
    // French and German accents are not Vietnamese.
    expect(WordSpeech.languageOfText('forêt'), 'en');
    expect(WordSpeech.languageOfText('123'), isNull);
  });
}
