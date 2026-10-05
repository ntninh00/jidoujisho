import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuuna/creator.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/utils.dart';

/// Text before highlighted text in a sentence
class ClozeBeforeField extends Field {
  /// Initialise this field with the predetermined and hardset values.
  ClozeBeforeField._privateConstructor()
      : super(
          uniqueKey: key,
          label: 'Cloze Before',
          description: 'Text before highlighted text in a sentence. '
              'Empty if nothing is highlighted.',
          icon: Ui.keyboard_double_arrow_left,
        );

  /// Get the singleton instance of this field.
  static ClozeBeforeField get instance => _instance;

  static final ClozeBeforeField _instance =
      ClozeBeforeField._privateConstructor();

  /// The unique key for this field.
  static const String key = 'cloze_before';

  @override
  String? onCreatorOpenAction({
    required WidgetRef ref,
    required AppModel appModel,
    required CreatorModel creatorModel,
    required DictionaryHeading heading,
    required bool creatorJustLaunched,
    required String? dictionaryName,
  }) {
    if (creatorJustLaunched) {
      return appModel.getCurrentSentence().textBefore.trimLeft();
    } else {
      return null;
    }
  }
}
