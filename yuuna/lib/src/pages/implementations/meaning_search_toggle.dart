import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/utils.dart';

/// A definition card with a magnifying glass: searching by meaning.
const String _meaningSearchIcon = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
  stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M11 21H6a2.5 2.5 0 0 1-2.5-2.5v-13A2.5 2.5 0 0 1 6 3h10a2.5 2.5 0 0 1 2.5 2.5V10"/>
  <path d="M7.5 7.5h7M7.5 11.5h4M7.5 15.5h2"/>
  <circle cx="16.5" cy="16.5" r="3.5"/>
  <path d="m19 19 2.5 2.5"/>
</svg>''';

/// The same, solid, for while it is on: the card filled, with its lines cut
/// out of it and room left around the magnifying glass.
const String _meaningSearchIconSolid = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#000" fill-rule="evenodd" d="M6 3h10a2.5 2.5 0 0 1 2.5 2.5v5.77A5.6 5.6 0 0 0 13.17 21H6a2.5 2.5 0 0 1-2.5-2.5v-13A2.5 2.5 0 0 1 6 3Z
    M7.5 6.5h7a1 1 0 0 1 0 2h-7a1 1 0 0 1 0-2Z
    M7.5 10.5h4a1 1 0 0 1 0 2h-4a1 1 0 0 1 0-2Z
    M7.5 14.5h2a1 1 0 0 1 0 2h-2a1 1 0 0 1 0-2Z"/>
  <circle cx="16.5" cy="16.5" r="3.4" fill="none" stroke="#000" stroke-width="2.4"/>
  <path d="m19 19 2.5 2.5" stroke="#000" stroke-width="2.4" stroke-linecap="round"/>
</svg>''';

/// The colour behind the words a search by meaning found: the accent, made
/// light enough in dark mode to show on a dark page whatever the accent.
Color meaningHighlightColor(Color accent, {required bool dark}) {
  if (!dark) {
    return accent.withOpacity(0.28);
  }
  HSLColor hsl = HSLColor.fromColor(accent);
  return hsl
      .withLightness(max(hsl.lightness, 0.62))
      .toColor()
      .withOpacity(0.7);
}

/// The button on the Dictionary tab's search bar that switches between
/// finding words by how they are written and by what they mean. Solid and
/// in the accent colour, on a tinted circle, while it is on.
class MeaningSearchToggle extends StatelessWidget {
  /// Create the toggle.
  const MeaningSearchToggle({
    required this.on,
    required this.onPressed,
    super.key,
  });

  /// Whether words are found by meaning.
  final bool on;

  /// Switches it.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color accent = theme.colorScheme.primary;
    bool dark = theme.brightness == Brightness.dark;
    double size = theme.textTheme.titleLarge!.fontSize! + 2;
    return Semantics(
      toggled: on,
      child: IconButton(
        constraints: BoxConstraints(
          maxWidth: Spacing.of(context).spaces.extraBig,
          maxHeight: Spacing.of(context).spaces.extraBig,
        ),
        tooltip: t.search_by_meaning,
        icon: DecoratedBox(
          decoration: ShapeDecoration(
            shape: const CircleBorder(),
            color:
                on ? accent.withOpacity(dark ? 0.3 : 0.16) : Colors.transparent,
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: SvgPicture.string(
              on ? _meaningSearchIconSolid : _meaningSearchIcon,
              width: size,
              height: size,
              colorFilter: ColorFilter.mode(
                on ? accent : theme.iconTheme.color!,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
