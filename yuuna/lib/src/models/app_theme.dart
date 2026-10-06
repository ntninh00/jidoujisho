import 'package:flutter/material.dart';
import 'package:yuuna/utils.dart';

/// The accent colours the app can be themed with. Each reads well behind
/// white text and against both the light and the dark background.
enum AppAccent {
  /// The app's original accent.
  red(Color(0xFFF44336)),

  /// Pink.
  rose(Color(0xFFE91E63)),

  /// Orange.
  orange(Color(0xFFF4511E)),

  /// Green.
  green(Color(0xFF43A047)),

  /// Blue green.
  teal(Color(0xFF00897B)),

  /// Blue.
  blue(Color(0xFF1E88E5)),

  /// Purple.
  violet(Color(0xFF7E57C2)),

  /// Grey blue, for an almost colourless app.
  slate(Color(0xFF607D8B));

  const AppAccent(this.color);

  /// The colour itself.
  final Color color;

  /// The accent saved as [name], or red.
  static AppAccent of(String? name) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => red,
    );
  }

  /// The colour as CSS, for pages shown in a WebView.
  String css(double alpha) =>
      'rgba(${color.red}, ${color.green}, ${color.blue}, $alpha)';

  /// The accent's name for screen readers.
  String get label => switch (this) {
        red => t.theme_accent_red,
        rose => t.theme_accent_rose,
        orange => t.theme_accent_orange,
        green => t.theme_accent_green,
        teal => t.theme_accent_teal,
        blue => t.theme_accent_blue,
        violet => t.theme_accent_violet,
        slate => t.theme_accent_slate,
      };
}
