import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../incidents/application/incident_providers.dart';
import '../../incidents/domain/incident.dart';
import '../../incidents/domain/incident_enums.dart';
import '../../incidents/domain/incident_summary.dart';
import '../../incidents/presentation/widgets/incident_badges.dart';
import '../../incidents/presentation/widgets/incident_card.dart';
import '../../incidents/presentation/widgets/summary_tile.dart';

/// Profile header, personal report stats and the user's own reports.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

enum _MyFilter { all, open, resolved }

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  _MyFilter _filter = _MyFilter.all;

  Future<void> _signOut() async {
    final confirmed = await context.confirm(
      title: 'Sign out?',
      message: 'You can sign back in any time with your ALU account.',
      confirmLabel: 'Sign out',
    );
    if (confirmed) await ref.read(authControllerProvider.notifier).signOut();
  }

  List<Incident> _applyFilter(List<Incident> incidents) => switch (_filter) {
    _MyFilter.all => incidents,
    _MyFilter.open => incidents.where((i) => i.status.isOpen).toList(),
    _MyFilter.resolved =>
      incidents.where((i) => i.status == IncidentStatus.resolved).toList(),
  };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return const SizedBox.shrink();
    final myIncidents = ref.watch(myIncidentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _signOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _ProfileHeader(user: user),
          if (user.isAdmin) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Manage staff access'),
                subtitle: const Text('Promote or demote campus staff'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/admin/users'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          AsyncValueView(
            value: myIncidents,
            onRetry: () => ref.invalidate(myIncidentsProvider),
            data: (incidents) {
              final summary = IncidentSummary.of(incidents);
              final filtered = _applyFilter(incidents);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SummaryRow(
                    tiles: [
                      SummaryTile(
                        label: 'Total',
                        count: summary.total,
                        icon: Icons.article_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SummaryTile(
                        label: 'In progress',
                        count: summary.submitted + summary.active,
                        icon: IncidentStatus.inProgress.icon,
                        color: IncidentStatus.underReview.color,
                      ),
                      SummaryTile(
                        label: 'Resolved',
                        count: summary.resolved,
                        icon: IncidentStatus.resolved.icon,
                        color: IncidentStatus.resolved.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'My reports',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<_MyFilter>(
                    segments: const [
                      ButtonSegment(value: _MyFilter.all, label: Text('All')),
                      ButtonSegment(value: _MyFilter.open, label: Text('Open')),
                      ButtonSegment(
                        value: _MyFilter.resolved,
                        label: Text('Resolved'),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (selection) =>
                        setState(() => _filter = selection.first),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    EmptyState(
                      icon: Icons.inbox_outlined,
                      title: incidents.isEmpty
                          ? "You haven't reported anything yet"
                          : 'Nothing here',
                      action: incidents.isEmpty
                          ? FilledButton.icon(
                              onPressed: () => context.push('/report/new'),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Report an issue'),
                            )
                          : null,
                    )
                  else
                    for (final incident in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: IncidentCard(incident: incident),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            UserAvatar(name: user.displayName, radius: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TintedBadge(
                    label: user.role.label,
                    icon: user.isStaff
                        ? Icons.verified_user_outlined
                        : Icons.school_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
