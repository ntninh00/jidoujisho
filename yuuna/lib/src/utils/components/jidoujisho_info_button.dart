import 'package:flutter/material.dart';
import 'package:yuuna/src/utils/misc/ui_icons.dart';

/// A small info mark that shows [message] when tapped. Used instead of
/// subtitles under settings, so screens stay light on text.
class JidoujishoInfoButton extends StatelessWidget {
  /// Create an info mark for [message].
  const JidoujishoInfoButton({
    required this.message,
    this.size = 16,
    super.key,
  });

  /// What tapping the mark explains.
  final String message;

  /// Size of the mark.
  final double size;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    bool dark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 5),
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFFEDEDED) : const Color(0xFF2B2B2B),
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: theme.textTheme.bodySmall!.copyWith(
        color: dark ? Colors.black87 : Colors.white,
        height: 1.4,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Ui.info,
          size: size,
          color: theme.unselectedWidgetColor,
        ),
      ),
    );
  }
}
