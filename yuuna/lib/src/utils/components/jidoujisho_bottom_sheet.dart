import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuuna/pages.dart';

/// An option to show in a bottom sheet.
class JidoujishoBottomSheetOption {
  /// Defines an option in a bottom sheet.
  JidoujishoBottomSheetOption({
    required this.label,
    required this.icon,
    required this.action,
    this.active = false,
  });

  /// Label to display in the option.
  String label;

  /// Icon to display left of the label.
  IconData icon;

  /// Whether or not the option is available.
  bool active;

  /// Action to perform upon selecting the option.
  FutureOr<void> Function() action;
}

///
class JidoujishoBottomSheet extends ConsumerWidget {
  /// Initialise a bottom sheet.
  const JidoujishoBottomSheet({
    required this.options,
    this.scrollToExtent = true,
    super.key,
  });

  /// Options to show in the bottom sheet.
  final List<JidoujishoBottomSheetOption> options;

  /// Whether or not to scroll to bottom.
  final bool scrollToExtent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ThemeData theme = Theme.of(context);

    ScrollController scrollController = ScrollController();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients && scrollToExtent) {
        scrollController.jumpTo(
          scrollController.position.maxScrollExtent,
        );
      }
    });

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TtuSheetHandle(),
          Flexible(
            child: ListView.builder(
              controller: scrollController,
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              itemCount: options.length,
              itemBuilder: (context, i) {
                JidoujishoBottomSheetOption option = options[i];
                Color accent = theme.colorScheme.primary;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: option.active
                        ? accent.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        Navigator.of(context).pop();
                        await option.action();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Icon(option.icon, size: 20, color: accent),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                option.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  color: option.active ? accent : null,
                                  fontWeight: option.active
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
