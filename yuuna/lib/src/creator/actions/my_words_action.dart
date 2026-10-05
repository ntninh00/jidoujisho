import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuuna/creator.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Adds the headword to My words with a meaning of the user's own, or edits
/// the meaning already there.
class MyWordsAction extends QuickAction {
  /// Initialise this action with the hardset parameters.
  MyWordsAction()
      : super(
          uniqueKey: key,
          label: 'My Words',
          description: 'Write your own meaning for a word. It shows first'
              ' whenever you look the word up.',
          icon: Ui.bookmark,
        );

  /// Used to identify this action and to allow a constant value for the
  /// default mappings value of [AnkiMapping].
  static const String key = 'my_words';

  @override
  Future<Color?> getIconColor({
    required AppModel appModel,
    required DictionaryHeading heading,
  }) async {
    return appModel.myWordFor(heading) != null ? Colors.red : null;
  }

  @override
  Future<void> executeAction({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
    required CreatorModel creatorModel,
    required DictionaryHeading heading,
    required String? dictionaryName,
  }) async {
    await showMyWordEditor(
      context: context,
      appModel: appModel,
      term: heading.term,
      reading: heading.reading,
      existing: appModel.myWordFor(heading),
    );
  }
}
