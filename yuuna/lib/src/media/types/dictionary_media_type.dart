import 'package:flutter/material.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Media type that encapsulates dictionary search results.
class DictionaryMediaType extends MediaType {
  /// Initialise this media type.
  DictionaryMediaType._privateConstructor()
      : super(
          uniqueKey: 'dictionary_media_type',
          icon: Ui.dictionarySolid,
          outlinedIcon: Ui.auto_stories_outlined,
        );

  /// Get the singleton instance of this media type.
  static DictionaryMediaType get instance => _instance;

  static final DictionaryMediaType _instance =
      DictionaryMediaType._privateConstructor();

  @override
  Widget get home => const HomeDictionaryPage();
}
