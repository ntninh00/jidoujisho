import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/utils.dart';

/// Reads words aloud with the phone's text-to-speech, for words that have
/// no recording: those in other languages than the one being learnt, and
/// those the recording sources do not have.
class WordSpeech {
  WordSpeech._();

  static const MethodChannel _channel =
      MethodChannel('app.arianneorpilla.yuuna/speech');

  /// Problems already explained in a dialog since the app started. After
  /// that, a short notice is enough.
  static final Set<String> _explained = {};

  /// The language [heading] is in, as a language code: that of the first
  /// dictionary it comes from that says, in the order the user keeps them,
  /// or else told from its script.
  static String languageOf(AppModel appModel, DictionaryHeading heading) {
    Map<String, Map<String, dynamic>> sources = appModel.dictionarySources;
    List<Dictionary> dictionaries = [
      for (DictionaryEntry entry in heading.entries)
        if (entry.dictionary.value != null) entry.dictionary.value!,
    ]..sort((a, b) => a.order.compareTo(b.order));
    for (Dictionary dictionary in dictionaries) {
      Object? language = sources[dictionary.name]?['language'];
      if (language is String && language.isNotEmpty) {
        return language;
      }
    }
    return languageOfText(heading.term) ?? appModel.targetLanguage.languageCode;
  }

  /// The language [text] is most likely in, told from its script.
  static String? languageOfText(String text) {
    if (RegExp('[぀-ヿㇰ-ㇿｦ-ﾟ]').hasMatch(text)) {
      return 'ja';
    }
    if (RegExp('[가-힯ᄀ-ᇿ]').hasMatch(text)) {
      return 'ko';
    }
    if (RegExp('[㐀-䶿一-鿿]').hasMatch(text)) {
      return 'ja';
    }
    if (RegExp('[Ѐ-ӿ]').hasMatch(text)) {
      return 'ru';
    }
    if (RegExp('[ăđơưĂĐƠƯẠ-ỹ]').hasMatch(text)) {
      return 'vi';
    }
    if (RegExp('[A-Za-z]').hasMatch(text)) {
      return 'en';
    }
    return null;
  }

  /// Reads [text] in [language] with the phone's voice, or, when the phone
  /// has none for it, has the dictionary server's voice read it through
  /// [play]. When neither can, says why and how to fix the phone, in a
  /// dialog the first time and in a notice after that.
  static Future<void> speak({
    required BuildContext context,
    required AppModel appModel,
    required String text,
    required String language,
    required Future<void> Function(File file) play,
  }) async {
    Map<String, dynamic>? answer;
    try {
      answer = await _channel.invokeMapMethod<String, dynamic>('speak', {
        'text': text,
        'language': language,
        'display': appModel.appLocale.languageCode,
      });
    } on PlatformException catch (error) {
      debugPrint('Could not read aloud: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Could not read aloud: $error');
    }

    String status = answer?['status'] as String? ?? 'error';
    if (status == 'ok') {
      return;
    }

    DictionaryServer? server = appModel.dictionaryServer;
    if (server != null) {
      try {
        await play(await server.speech(text: text, language: language));
        return;
      } catch (error) {
        debugPrint('The dictionary server could not read aloud: $error');
      }
    }

    String problem = status == 'no_voice' ? '$status/$language' : status;
    if (status == 'error' || !_explained.add(problem)) {
      Fluttertoast.showToast(
        msg: t.audio_unavailable,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    if (!context.mounted) {
      return;
    }
    String name = answer?['name'] as String? ?? language;
    late String title;
    late String content;
    late String action;
    late String fix;
    switch (status) {
      case 'disabled':
        title = t.speech_no_engine_title;
        content = t.speech_disabled;
        action = t.speech_enable;
        fix = 'enable';
        break;
      case 'no_voice':
        title = t.speech_no_voice_title(language: name);
        content = t.speech_no_voice(language: name);
        action = t.speech_download;
        fix = 'voice';
        break;
      default:
        title = t.speech_no_engine_title;
        content = t.speech_no_engine;
        action = t.speech_install;
        fix = 'install';
    }

    bool? fixing = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.dialog_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (fixing == true) {
      /// Once fixed, the next try reads aloud, so the problem may come back
      /// to a dialog if it is still there.
      _explained.remove(problem);
      await _channel.invokeMethod<bool>('open', {'what': fix});
    }
  }
}
