import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../application/incident_providers.dart';
import '../domain/incident_enums.dart';
import '../domain/incident_summary.dart';
import 'widgets/incident_badges.dart';
import 'widgets/incident_card.dart';
import 'widgets/summary_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _recentCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return const SizedBox.shrink();
    final summary = ref.watch(dashboardSummaryProvider);
    final incidents = ref.watch(visibleIncidentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            _Greeting(user: user),
            const SizedBox(height: 20),
            user.isStaff
                ? _StaffHero(newCount: summary.value?.submitted ?? 0)
                : const _StudentHero(),
            const SizedBox(height: 24),
            Text(
              user.isStaff ? 'Campus overview' : 'Your reports',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            AsyncValueView(
              value: summary,
              data: (summary) => _SummaryTiles(
                summary: summary,
                totalLabel: user.isStaff ? 'Total' : 'My reports',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent reports',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.reports),
                  child: const Text('See all'),
                ),
              ],
            ),
            AsyncValueView(
              value: incidents,
              data: (incidents) => incidents.isEmpty
                  ? const EmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'No reports yet',
                      message: 'When someone reports an issue, it shows here.',
                    )
                  : Column(
                      children: [
                        for (final incident in incidents.take(_recentCount))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: IncidentCard(incident: incident),
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

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${user.firstName} 👋',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.isStaff
                    ? "Here's what needs attention on campus."
                    : 'Report issues and track their resolution.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Open profile',
          onPressed: () => context.go(AppRoutes.profile),
          icon: UserAvatar(name: user.displayName, radius: 24),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.inversePrimary, 0.45)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.surface,
              foregroundColor: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentHero extends StatelessWidget {
  const _StudentHero();

  @override
  Widget build(BuildContext context) => _HeroCard(
    title: 'See an issue on campus?',
    message: 'Report it and help improve our learning environment.',
    actionLabel: 'Report an issue',
    onAction: () => context.push(AppRoutes.newReport),
  );
}

class _StaffHero extends ConsumerWidget {
  const _StaffHero({required this.newCount});

  final int newCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _HeroCard(
    title: newCount == 0
        ? 'All caught up'
        : '$newCount new report${newCount == 1 ? '' : 's'}',
    message: newCount == 0
        ? 'No reports are waiting for review right now.'
        : 'Review new reports and keep students updated on progress.',
    actionLabel: 'Review reports',
    onAction: () {
      final filter = ref.read(incidentFilterProvider.notifier)..clear();
      if (newCount > 0) filter.setStatus(IncidentStatus.submitted);
      context.go(AppRoutes.reports);
    },
  );
}

class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({required this.summary, required this.totalLabel});

  final IncidentSummary summary;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    return SummaryRow(
      tiles: [
        SummaryTile(
          label: totalLabel,
          count: summary.total,
          icon: Icons.article_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        SummaryTile(
          label: 'Submitted',
          count: summary.submitted,
          icon: IncidentStatus.submitted.icon,
          color: IncidentStatus.submitted.color,
        ),
        SummaryTile(
          label: 'In progress',
          count: summary.active,
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
    );
  }
}
