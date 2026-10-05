import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// A tag that can be clicked on for more information. Used in dictionary
/// entries to indicate information about a definition or term.
class JidoujishoTag extends StatelessWidget {
  /// Create a tag that can be clicked on for more information.
  const JidoujishoTag({
    required this.text,
    required this.backgroundColor,
    this.message,
    this.trailingText,
    this.icon,
    this.foregroundColor = Colors.white,
    this.iconSize,
    this.style,
    super.key,
  });

  /// A soft tint of the accent, for dictionary names. Quieter than a solid
  /// tag so the definitions stay the focus.
  factory JidoujishoTag.dictionary({
    required BuildContext context,
    required String text,
    String? trailingText,
    Key? key,
  }) {
    ThemeData theme = Theme.of(context);
    Color accent = theme.colorScheme.primary;
    bool dark = theme.brightness == Brightness.dark;
    return JidoujishoTag(
      key: key,
      text: text,
      trailingText: trailingText,
      backgroundColor: accent.withOpacity(dark ? 0.2 : 0.12),
      foregroundColor: dark
          ? Color.lerp(accent, Colors.white, 0.45)!
          : Color.lerp(accent, Colors.black, 0.3)!,
    );
  }

  /// The icon to display on the tag.
  final IconData? icon;

  /// The text to display on the tag.
  final String text;

  /// The message to show when the tag has been clicked on.
  final String? message;

  /// An extra bit to put on a rectangle on the right of the message.
  final String? trailingText;

  /// The color of the tag background.
  final Color backgroundColor;

  /// The color of the icon and text.
  final Color foregroundColor;

  /// The display size for the [icon].
  final double? iconSize;

  /// Text style to use for the [text] of the tag.
  final TextStyle? style;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(6));

  @override
  Widget build(BuildContext context) {
    TextStyle? labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        );

    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 4),
      child: Material(
        color: backgroundColor,
        borderRadius: _radius,
        child: InkWell(
          borderRadius: _radius,
          onTap: message != null
              ? () {
                  Fluttertoast.showToast(
                    backgroundColor: backgroundColor,
                    textColor: foregroundColor,
                    msg: message!,
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Icon(
                    icon,
                    color: foregroundColor,
                    size: Theme.of(context).textTheme.labelSmall?.fontSize,
                  ),
                if (icon != null) const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    text,
                    style: labelStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailingText != null) const SizedBox(width: 6),
                if (trailingText != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: foregroundColor.withOpacity(0.16),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        trailingText!,
                        style: labelStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
