import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/theme/typography.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/number_input_dialog.dart';
import '../../widgets/snackbars.dart';
import 'body_page.dart';

/// Körper → "Einträge" (1.6.1): all weight entries, newest first; tap to
/// edit, swipe to delete (with undo).
class BodyEntriesPage extends ConsumerStatefulWidget {
  const BodyEntriesPage({super.key});

  @override
  ConsumerState<BodyEntriesPage> createState() => _BodyEntriesPageState();
}

class _BodyEntriesPageState extends ConsumerState<BodyEntriesPage> {
  /// Deleted entries hidden at once until the stream catches up.
  final _hidden = <int>{};

  Future<void> _delete(BodyWeightEntry entry) async {
    setState(() => _hidden.add(entry.id));
    final repo = ref.read(bodyWeightRepositoryProvider);
    try {
      await repo.delete(entry.id);
      if (!mounted) return;
      showMessage(
        context,
        S.entryDeleted(formatShortDate(entry.date.toLocalDateTime())),
        onUndo: () => repo.restore(entry).catchError((Object e) {
          if (mounted) showError(context, e);
        }),
      );
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _hidden.remove(entry.id));
    }
  }

  Future<void> _edit(BodyWeightEntry entry) async {
    final kg = await showNumberInputDialog<double>(
      context,
      title:
          '${S.editEntry} · ${formatShortDate(entry.date.toLocalDateTime())}',
      initialText: formatDecimal1(entry.weightKg),
      decimal: true,
      parse: parseBodyWeight,
    );
    if (kg == null) return;
    try {
      await ref.read(bodyWeightRepositoryProvider).save(entry.date, kg);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(bodyWeightsProvider).value;
    final entries = [
      for (final e in all ?? const <BodyWeightEntry>[])
        if (!_hidden.contains(e.id)) e,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text(S.bodyEntries)),
      body: all == null
          ? const SizedBox.shrink()
          : entries.isEmpty
          ? const Center(child: Text(S.bodyEntriesEmpty))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: entries.length,
              itemBuilder: (context, i) => _EntryTile(
                entry: entries[i],
                onDelete: _delete,
                onTap: _edit,
              ),
            ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onDelete,
    required this.onTap,
  });

  final BodyWeightEntry entry;
  final ValueChanged<BodyWeightEntry> onDelete;
  final ValueChanged<BodyWeightEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => onDelete(entry),
      child: ListTile(
        title: Text(
          formatKg1(entry.weightKg),
          style: NumberStyles.small.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(formatWeekdayDate(entry.date.toLocalDateTime())),
        trailing: const Icon(Icons.edit_outlined, size: 20),
        onTap: () => onTap(entry),
      ),
    );
  }
}
