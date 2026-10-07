import 'package:flutter/material.dart';
import 'package:yuuna/utils.dart';

/// What a dictionary says about itself in its `index.json`: its
/// description, author, attribution and address, on a rounded card under
/// "About". Nothing is shown when it says nothing.
class DictionaryAbout extends StatelessWidget {
  /// Describe a dictionary.
  const DictionaryAbout({
    this.description,
    this.author,
    this.attribution,
    this.url,
    super.key,
  });

  /// The dictionary's own description.
  final String? description;

  /// Who made it.
  final String? author;

  /// Its sources and licence.
  final String? attribution;

  /// Where it comes from.
  final String? url;

  /// Whether there is anything to show.
  bool get isEmpty => [description, author, attribution, url]
      .every((value) => value == null || value.trim().isEmpty);

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return const SizedBox.shrink();
    }
    ThemeData theme = Theme.of(context);
    Color muted = theme.unselectedWidgetColor;
    TextStyle small = theme.textTheme.bodySmall!.copyWith(color: muted);
    bool has(String? value) => value != null && value.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.dictionary_about.toUpperCase(),
            style: theme.textTheme.labelSmall!.copyWith(
              color: muted,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          if (has(description)) ...[
            const SizedBox(height: 6),
            SelectableText(
              description!.trim(),
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (has(author)) ...[
            const SizedBox(height: 6),
            SelectableText(t.dictionary_by(author: author!.trim()),
                style: small),
          ],
          if (has(attribution)) ...[
            const SizedBox(height: 6),
            SelectableText(attribution!.trim(), style: small),
          ],
          if (has(url)) ...[
            const SizedBox(height: 6),
            SelectableText(
              url!.trim(),
              style: small.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}
