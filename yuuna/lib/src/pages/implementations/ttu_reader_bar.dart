import 'package:flutter/material.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// The bar at the top of the Reader tab when ッツ Ebook Reader is the source:
/// a labelled source switcher, Add, and one settings button.
class TtuReaderBar extends BasePage {
  /// Create the bar.
  const TtuReaderBar({super.key});

  @override
  BasePageState<TtuReaderBar> createState() => _TtuReaderBarState();
}

class _TtuReaderBarState extends BasePageState<TtuReaderBar> {
  ReaderTtuSource get source => ReaderTtuSource.instance;

  @override
  Widget build(BuildContext context) {
    Color chipColor = appModel.isDarkMode
        ? const Color.fromARGB(255, 30, 30, 30)
        : const Color.fromARGB(255, 229, 229, 229);
    Color red = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Flexible(
              child: Material(
                color: chipColor,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => showTtuSheet<void>(
                    context: context,
                    builder: (_) => const TtuSourcePickerSheet(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(source.icon, size: 20),
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
                        const SizedBox(width: 2),
                        Icon(
                          Ui.expand_more,
                          size: 20,
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
              color: red.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => source.pickAndImport(
                  context: context,
                  appModel: appModelNoUpdate,
                  ref: ref,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Ui.add, size: 20, color: red),
                      const SizedBox(width: 2),
                      Text(
                        t.ttu_add,
                        style: textTheme.bodyMedium!.copyWith(
                          color: red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: t.ttu_reader_settings,
              icon: const Icon(Ui.settings_outlined),
              onPressed: () => source.showSettings(
                context: context,
                appModel: appModelNoUpdate,
                ref: ref,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
