import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../application/incident_providers.dart';
import '../domain/incident.dart';
import '../domain/incident_enums.dart';
import 'widgets/incident_badges.dart';
import 'widgets/incident_photo.dart';
import 'widgets/status_timeline.dart';
import 'widgets/status_update_sheet.dart';

class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({required this.incidentId, super.key});

  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incident = ref.watch(incidentProvider(incidentId));
    final user = ref.watch(currentUserProvider).value;

    return AsyncPageView(
      value: incident,
      title: 'Incident details',
      onRetry: () => ref.invalidate(incidentProvider(incidentId)),
      data: (incident) {
        if (incident == null || user == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'This report is no longer available',
              message: 'It may have been withdrawn or removed by staff.',
            ),
          );
        }
        return _IncidentDetail(incident: incident, user: user);
      },
    );
  }
}

enum _MenuAction { edit, delete }

class _IncidentDetail extends ConsumerWidget {
  const _IncidentDetail({required this.incident, required this.user});

  final Incident incident;
  final AppUser user;

  bool get _canEdit => incident.canBeChangedByReporter(user.uid);
  bool get _canDelete => _canEdit || user.isStaff;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await context.confirm(
      title: user.isStaff && !incident.isReportedBy(user.uid)
          ? 'Remove this report?'
          : 'Withdraw this report?',
      message:
          'The report, its photo and its history will be deleted. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ref
        .read(incidentActionsProvider.notifier)
        .delete(incident);
    if (!context.mounted) return;
    if (ok) {
      context.showSnack('Report deleted');
      context.pop();
    } else {
      context.showSnack(
        describeError(ref.read(incidentActionsProvider).error!),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident details'),
        actions: [
          if (_canDelete)
            PopupMenuButton<_MenuAction>(
              onSelected: (action) => switch (action) {
                _MenuAction.edit => context.push(
                  AppRoutes.editIncident(incident.id),
                ),
                _MenuAction.delete => _delete(context, ref),
              },
              itemBuilder: (_) => [
                if (_canEdit)
                  const PopupMenuItem(
                    value: _MenuAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit report'),
                    ),
                  ),
                const PopupMenuItem(
                  value: _MenuAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Delete report'),
                  ),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: user.isStaff
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  onPressed: () => showStatusUpdateSheet(context, incident),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Update status'),
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (incident.hasPhoto) ...[
            _Photo(incident: incident),
            const SizedBox(height: 16),
          ],
          Text(
            incident.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(incident.status),
              TintedBadge(
                label: incident.category.label,
                icon: incident.category.icon,
                color: theme.colorScheme.primary,
              ),
              if (incident.priority != null)
                TintedBadge(
                  label: '${incident.priority!.label} priority',
                  icon: Icons.flag_outlined,
                  color: incident.priority!.color,
                ),
              if (incident.isPrivate)
                TintedBadge(
                  label: 'Private',
                  icon: Icons.lock_outline_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _MetaRow(icon: Icons.place_outlined, text: incident.location),
          _MetaRow(
            icon: Icons.calendar_today_outlined,
            text: 'Submitted ${formatTimestamp(incident.createdAt)}',
          ),
          _ReporterRow(incident: incident, viewer: user),
          const SizedBox(height: 24),
          const _Heading('Status'),
          StatusTimeline(status: incident.status),
          const SizedBox(height: 24),
          const _Heading('Description'),
          Text(incident.description, style: theme.textTheme.bodyLarge),
          if (!user.isStaff &&
              !incident.isReportedBy(user.uid) &&
              incident.status.isOpen) ...[
            const SizedBox(height: 20),
            _MeTooButton(incident: incident, uid: user.uid),
          ],
          const SizedBox(height: 24),
          const _Heading('Activity'),
          _ActivityLog(incident: incident),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

/// Students never see who filed an anonymous report; staff do, so they can
/// follow up.
class _ReporterRow extends ConsumerWidget {
  const _ReporterRow({required this.incident, required this.viewer});

  final Incident incident;
  final AppUser viewer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String text;
    if (incident.isReportedBy(viewer.uid)) {
      text = incident.isAnonymous
          ? 'Reported by you (anonymous to other students)'
          : 'Reported by you';
    } else if (!incident.isAnonymous) {
      text = 'Reported by ${incident.reporterName ?? 'an ALU member'}';
    } else if (viewer.isStaff) {
      final reporter = ref.watch(userProfileProvider(incident.reporterId));
      final name = reporter.value?.displayName ?? '…';
      text = 'Reported by $name (anonymous to students)';
    } else {
      text = 'Reported anonymously';
    }
    return _MetaRow(icon: Icons.person_outline_rounded, text: text);
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.incident});

  final Incident incident;

  static const _broken = Center(
    child: Icon(Icons.broken_image_outlined, size: 40),
  );

  void _openFullScreen(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: IncidentPhotoImage(
                  incident: incident,
                  fit: BoxFit.contain,
                  fallback: _broken,
                ),
              ),
            ),
            SafeArea(
              child: IconButton(
                tooltip: 'Close',
                color: Colors.white,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Incident photo. Tap to enlarge.',
      button: true,
      child: GestureDetector(
        onTap: () => _openFullScreen(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: IncidentPhotoImage(incident: incident, fallback: _broken),
          ),
        ),
      ),
    );
  }
}

class _MeTooButton extends ConsumerWidget {
  const _MeTooButton({required this.incident, required this.uid});

  final Incident incident;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upvoted = incident.hasUpvoted(uid);
    final count = incident.upvoteCount;
    final label = upvoted ? 'You are affected too' : 'This affects me too';
    final countText = count == 0
        ? 'Be the first to confirm this issue'
        : '$count ${count == 1 ? 'person has' : 'people have'} confirmed this';

    Future<void> toggle() async {
      final ok = await ref
          .read(incidentActionsProvider.notifier)
          .toggleUpvote(incident);
      if (!ok && context.mounted) {
        context.showSnack(
          describeError(ref.read(incidentActionsProvider).error!),
          isError: true,
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        upvoted
            ? FilledButton.tonalIcon(
                onPressed: toggle,
                icon: const Icon(Icons.people_alt_rounded),
                label: Text(label),
              )
            : OutlinedButton.icon(
                onPressed: toggle,
                icon: const Icon(Icons.people_alt_outlined),
                label: Text(label),
              ),
        const SizedBox(height: 6),
        Text(
          countText,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ActivityLog extends ConsumerWidget {
  const _ActivityLog({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(incidentUpdatesProvider(incident.id)),
      data: (updates) => Column(
        children: [
          _ActivityEntry(
            color: IncidentStatus.submitted.color,
            icon: IncidentStatus.submitted.icon,
            title: 'Report submitted',
            time: incident.createdAt,
          ),
          for (final update in updates)
            _ActivityEntry(
              color: update.status.color,
              icon: update.status.icon,
              title: '${update.status.label} · ${update.authorName}',
              note: update.note,
              time: update.createdAt,
            ),
        ],
      ),
    );
  }
}

class _ActivityEntry extends StatelessWidget {
  const _ActivityEntry({
    required this.color,
    required this.icon,
    required this.title,
    required this.time,
    this.note,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? note;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (note != null) ...[
                  const SizedBox(height: 4),
                  Text(note!, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 2),
                Text(
                  formatTimestamp(time),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
