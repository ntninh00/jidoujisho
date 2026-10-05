import 'package:flutter/material.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Media type that encapsulates videos or music.
class PlayerMediaType extends MediaType {
  /// Initialise this media type.
  PlayerMediaType._privateConstructor()
      : super(
          uniqueKey: 'player_media_type',
          icon: Ui.video_library,
          outlinedIcon: Ui.video_library_outlined,
        );

  /// Get the singleton instance of this media type.
  static PlayerMediaType get instance => _instance;

  static final PlayerMediaType _instance =
      PlayerMediaType._privateConstructor();

  @override
  Widget get home => const HomePlayerPage();
}
