import 'package:flutter/material.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// The bar at the top of the Reader tab when ッツ Ebook Reader is the source:
/// a labelled source switcher and Add, one height. Its settings are under
/// the gear at the top of the home page.
class TtuReaderBar extends BasePage {
  /// Create the bar.
  const TtuReaderBar({super.key});

  @override
  BasePageState<TtuReaderBar> createState() => _TtuReaderBarState();
}

class _TtuReaderBarState extends BasePageState<TtuReaderBar> {
  ReaderTtuSource get source => ReaderTtuSource.instance;

  static const double _height = 40;

  @override
  Widget build(BuildContext context) {
    Color surface = appModel.isDarkMode
        ? const Color.fromARGB(255, 30, 30, 30)
        : const Color.fromARGB(255, 229, 229, 229);
    Color accent = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: SizedBox(
        height: _height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: Material(
                color: surface,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => showTtuSheet<void>(
                    context: context,
                    builder: (_) => const TtuSourcePickerSheet(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(source.icon, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            source.getLocalisedSourceName(appModel),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium!
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Ui.expand_more,
                          size: 18,
                          color: theme.unselectedWidgetColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Material(
              color: accent,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => source.pickAndImport(
                  context: context,
                  appModel: appModelNoUpdate,
                  ref: ref,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Ui.add, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        t.ttu_add,
                        style: textTheme.bodyMedium!.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
