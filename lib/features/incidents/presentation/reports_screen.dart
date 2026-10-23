import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../application/incident_providers.dart';
import '../domain/incident_enums.dart';
import '../domain/incident_filter.dart';
import 'widgets/incident_badges.dart';
import 'widgets/incident_card.dart';

/// Browse, search and filter every report the user is allowed to see.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late final _search = TextEditingController(
    text: ref.read(incidentFilterProvider).query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearAll() {
    _search.clear();
    ref.read(incidentFilterProvider.notifier).clear();
  }

  Future<void> _pickCategory(IncidentFilter filter) async {
    final notifier = ref.read(incidentFilterProvider.notifier);
    // Wrapped in a record so "All categories" (null) differs from dismissal.
    final choice = await showModalBottomSheet<({IncidentCategory? value})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            RadioGroup<IncidentCategory?>(
              groupValue: filter.category,
              onChanged: (value) => Navigator.pop(context, (value: value)),
              child: Column(
                children: [
                  const RadioListTile<IncidentCategory?>(
                    value: null,
                    title: Text('All categories'),
                  ),
                  for (final category in IncidentCategory.values)
                    RadioListTile<IncidentCategory?>(
                      value: category,
                      title: Text(category.label),
                      secondary: Icon(category.icon),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (choice != null) notifier.setCategory(choice.value);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(incidentFilterProvider);
    final notifier = ref.read(incidentFilterProvider.notifier);
    final results = ref.watch(filteredIncidentsProvider);
    // Keep the field in sync when another screen resets the filter.
    ref.listen(incidentFilterProvider, (_, next) {
      if (next.query != _search.text) _search.text = next.query;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Campus reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              controller: _search,
              hintText: 'Search title, description or location',
              leading: const Icon(Icons.search_rounded),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: notifier.setQuery,
              trailing: [
                if (filter.query.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _search.clear();
                      notifier.setQuery('');
                    },
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ActionChip(
                  avatar: Icon(filter.category?.icon ?? Icons.tune_rounded),
                  label: Text(filter.category?.label ?? 'Category'),
                  onPressed: () => _pickCategory(filter),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All'),
                  selected: filter.status == null,
                  onSelected: (_) => notifier.setStatus(null),
                ),
                for (final status in IncidentStatus.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(status.label),
                    selected: filter.status == status,
                    onSelected: (selected) =>
                        notifier.setStatus(selected ? status : null),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: results,
              data: (incidents) {
                if (incidents.isEmpty) {
                  return EmptyState(
                    icon: filter.isActive
                        ? Icons.filter_alt_off_outlined
                        : Icons.task_alt_rounded,
                    title: filter.isActive
                        ? 'No reports match your filters'
                        : 'No reports yet',
                    message: filter.isActive
                        ? 'Try a different search or clear the filters.'
                        : 'Reports from across campus will appear here.',
                    action: filter.isActive
                        ? OutlinedButton(
                            onPressed: _clearAll,
                            child: const Text('Clear filters'),
                          )
                        : null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: incidents.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _ResultsHeader(
                        count: incidents.length,
                        onClear: filter.isActive ? _clearAll : null,
                      );
                    }
                    return IncidentCard(incident: incidents[index - 1]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count, this.onClear});

  final int count;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count report${count == 1 ? '' : 's'}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (onClear != null)
          TextButton(onPressed: onClear, child: const Text('Clear filters')),
      ],
    );
  }
}
