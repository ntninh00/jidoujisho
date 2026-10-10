import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:yuuna/creator.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/utils.dart';

/// An enhancement used effectively as a shortcut for previewing audio.
class PlayAudioAction extends QuickAction {
  /// Initialise this enhancement with the hardset parameters.
  PlayAudioAction()
      : super(
          uniqueKey: key,
          label: 'Play Audio',
          description:
              'Attempts to play audio based on the Audio enhancements. The auto'
              ' is the top priority. Words without a recording, and words in'
              ' other languages, are read aloud by the phone instead.',
          icon: Ui.volume_up,
        );

  final AudioPlayer _audioPlayer = AudioPlayer();

  /// Used to identify this enhancement and to allow a constant value for the
  /// default mappings value of [AnkiMapping].
  static const String key = 'play_audio';

  @override
  Future<void> executeAction({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
    required CreatorModel creatorModel,
    required DictionaryHeading heading,
    required String? dictionaryName,
  }) async {
    _audioPlayer.stop();

    /// Recordings come from sources for the language being learnt; a word
    /// in another language goes straight to the phone's voice.
    String language = WordSpeech.languageOf(appModel, heading);
    if (language == appModel.targetLanguage.languageCode &&
        await _playRecording(
          context: context,
          appModel: appModel,
          heading: heading,
        )) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    /// Kana is read as written, where the phone might misread kanji.
    await WordSpeech.speak(
      context: context,
      appModel: appModel,
      text: language == 'ja' && heading.reading.isNotEmpty
          ? heading.reading
          : heading.term,
      language: language,
      play: _playFile,
    );
  }

  /// Plays the first recording of [heading] the profile's audio sources
  /// find. Returns whether one played.
  Future<bool> _playRecording({
    required BuildContext context,
    required AppModel appModel,
    required DictionaryHeading heading,
  }) async {
    List<Enhancement> audioEnhancements = [];

    Enhancement? autoEnhancement =
        appModel.lastSelectedMapping.getAutoFieldEnhancement(
      appModel: appModel,
      field: AudioField.instance,
    );
    if (autoEnhancement != null) {
      audioEnhancements.add(autoEnhancement);
    }
    audioEnhancements.addAll(
      appModel.lastSelectedMapping.getManualFieldEnhancement(
        appModel: appModel,
        field: AudioField.instance,
      ),
    );

    for (Enhancement? enhancement in audioEnhancements) {
      if (enhancement == null) {
        continue;
      }

      if (enhancement is AudioEnhancement) {
        File? file = await enhancement.fetchAudio(
          appModel: appModel,
          context: context,
          term: heading.term,
          reading: heading.reading,
        );

        if (file != null) {
          await _playFile(file);
          return true;
        }
      }
    }
    return false;
  }

  /// Plays [file] as a short sound, quieting other audio for it.
  Future<void> _playFile(File file) async {
    await _audioPlayer.setFilePath(file.path);
    final AudioSession session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: true,
      ),
    );
    session.becomingNoisyEventStream.listen((event) async {
      await _audioPlayer.stop();
      session.setActive(false);
    });
    session.setActive(true);
    await _audioPlayer.play();
    session.setActive(false);
  }
}
