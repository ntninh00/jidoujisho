import 'package:flutter/material.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Picks the group a book is in, or makes a new one. With no groups yet,
/// the first one also groups the shelf by them.
class TtuGroupSheet extends StatefulWidget {
  /// Create the sheet for [book].
  const TtuGroupSheet({required this.book, super.key});

  /// The book to put in a group.
  final TtuBook book;

  @override
  State<TtuGroupSheet> createState() => _TtuGroupSheetState();
}

class _TtuGroupSheetState extends State<TtuGroupSheet> {
  final TextEditingController _name = TextEditingController();
  ReaderTtuSource get _source => ReaderTtuSource.instance;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choose(String? group) async {
    bool first = _source.shelfGroups.isEmpty;
    await _source.setGroupOf(widget.book, group);
    if (group != null &&
        first &&
        _source.shelfGrouping == TtuShelfGrouping.none) {
      await _source.setShelfGrouping(TtuShelfGrouping.groups);
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    String? current = _source.groupOf(widget.book);
    List<String> groups = _source.shelfGroups;

    Widget option(String? group) {
      bool selected = group == current;
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _choose(group),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                group == null ? Ui.cross : Ui.folder,
                size: 18,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.unselectedWidgetColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group ?? t.ttu_group_none,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge!.copyWith(
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                ),
              ),
              if (selected)
                Icon(Ui.check, size: 18, color: theme.colorScheme.primary),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TtuSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 0, 6),
                child: Row(
                  children: [
                    Text(
                      t.ttu_group,
                      style: theme.textTheme.titleLarge!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    JidoujishoInfoButton(message: t.ttu_group_info),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    option(null),
                    for (String group in groups) option(group),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _name,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _choose(value);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: t.ttu_new_group,
                        isDense: true,
                        filled: true,
                        fillColor: theme.dividerColor.withOpacity(0.08),
                        prefixIcon: const Icon(Ui.plus, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _name,
                    builder: (context, value, _) => IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: value.text.trim().isEmpty
                          ? null
                          : () => _choose(value.text),
                      icon: const Icon(Ui.check, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renames or deletes one of the user's groups. Deleting a group keeps its
/// books, which are then in none.
class TtuGroupMenuSheet extends StatefulWidget {
  /// Create the sheet for [group].
  const TtuGroupMenuSheet({required this.group, super.key});

  /// The group's name.
  final String group;

  @override
  State<TtuGroupMenuSheet> createState() => _TtuGroupMenuSheetState();
}

class _TtuGroupMenuSheetState extends State<TtuGroupMenuSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.group);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    await ReaderTtuSource.instance.renameGroup(widget.group, _name.text);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    await ReaderTtuSource.instance.deleteGroup(widget.group);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TtuSheetHandle(),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _rename(),
                decoration: InputDecoration(
                  labelText: t.ttu_group_name,
                  isDense: true,
                  filled: true,
                  fillColor: theme.dividerColor.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        side: BorderSide(color: Colors.red.shade400),
                        shape: const StadiumBorder(),
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: _delete,
                      icon: const Icon(Ui.delete_outline, size: 18),
                      label: Text(t.ttu_delete_group),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: _rename,
                      icon: const Icon(Ui.edit_outlined, size: 18),
                      label: Text(t.ttu_rename_group),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
