import 'package:flutter/material.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Picks light or dark and the accent. Changes apply at once, so the app
/// behind the sheet shows what they look like.
class AppThemeSheet extends BasePage {
  /// Create the sheet.
  const AppThemeSheet({super.key});

  @override
  BasePageState<AppThemeSheet> createState() => _AppThemeSheetState();
}

class _AppThemeSheetState extends BasePageState<AppThemeSheet> {
  Widget _group(String title, {String? info}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: textTheme.labelMedium!.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          if (info != null) JidoujishoInfoButton(message: info, size: 14),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeMode mode = appModel.themeMode;
    AppAccent accent = appModel.accent;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TtuSheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                t.theme_menu,
                style:
                    textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            _group(t.theme_mode, info: t.theme_mode_hint),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (ThemeMode value in const [
                    ThemeMode.system,
                    ThemeMode.light,
                    ThemeMode.dark,
                  ]) ...[
                    if (value != ThemeMode.system) const SizedBox(width: 10),
                    Expanded(
                      child: _ModeTile(
                        mode: value,
                        selected: value == mode,
                        accent: accent.color,
                        onTap: () => appModel.setThemeMode(value),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _group(t.theme_accent),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _AccentPicker(
                selected: accent,
                onChanged: appModel.setAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of System, Light and Dark, drawn as a small picture of the app.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  String get _label => switch (mode) {
        ThemeMode.system => t.theme_mode_system,
        ThemeMode.light => t.theme_mode_light,
        ThemeMode.dark => t.theme_mode_dark,
      };

  IconData get _icon => switch (mode) {
        ThemeMode.system => Ui.themeAuto,
        ThemeMode.light => Ui.sun,
        ThemeMode.dark => Ui.moon,
      };

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color muted = theme.unselectedWidgetColor;
    return Semantics(
      button: true,
      selected: selected,
      label: _label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 96,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.dividerColor.withOpacity(0.25),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: switch (mode) {
                  ThemeMode.system => Row(
                      children: [
                        Expanded(child: _MiniApp(dark: false, accent: accent)),
                        Expanded(child: _MiniApp(dark: true, accent: accent)),
                      ],
                    ),
                  ThemeMode.light => _MiniApp(dark: false, accent: accent),
                  ThemeMode.dark => _MiniApp(dark: true, accent: accent),
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _icon,
                  size: 14,
                  color: selected ? theme.colorScheme.primary : muted,
                ),
                const SizedBox(width: 6),
                Text(
                  _label,
                  style: theme.textTheme.labelLarge!.copyWith(
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? null : muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A few lines of text and a button in the app's colours.
class _MiniApp extends StatelessWidget {
  const _MiniApp({required this.dark, required this.accent});

  final bool dark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    Color background = dark ? Colors.black : Colors.white;
    Color card = dark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0);
    Color line = dark ? Colors.white24 : Colors.black12;
    Widget bar(double widthFactor, {double height = 5, Color? color}) =>
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: color ?? line,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        );
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(9, 10, 9, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(0.55, height: 6, color: dark ? Colors.white54 : Colors.black45),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(0.9),
                  const SizedBox(height: 4),
                  bar(0.6),
                  const Spacer(),
                  Container(
                    width: 26,
                    height: 9,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The accents as a row of swatches.
class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.selected, required this.onChanged});

  final AppAccent selected;
  final ValueChanged<AppAccent> onChanged;

  @override
  Widget build(BuildContext context) {
    // The dark theme keeps the light scheme's onSurface, so pick by brightness.
    Color ring = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 4,
      children: [
        for (AppAccent value in AppAccent.values)
          Semantics(
            button: true,
            selected: value == selected,
            label: value.label,
            child: InkResponse(
              onTap: () => onChanged(value),
              radius: 22,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    width: value == selected ? 34 : 28,
                    height: value == selected ? 34 : 28,
                    decoration: BoxDecoration(
                      color: value.color,
                      shape: BoxShape.circle,
                      border: value == selected
                          ? Border.all(color: ring, width: 2)
                          : null,
                    ),
                    child: value == selected
                        ? const Icon(Ui.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
