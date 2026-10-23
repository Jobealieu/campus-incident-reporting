import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../application/incident_providers.dart';
import '../../domain/incident.dart';
import '../../domain/incident_enums.dart';
import 'incident_badges.dart';

Future<void> showStatusUpdateSheet(BuildContext context, Incident incident) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _StatusUpdateSheet(incident: incident),
    );

/// Staff-only form to move an incident through its lifecycle, set its
/// priority and leave a note that students see on the timeline.
class _StatusUpdateSheet extends ConsumerStatefulWidget {
  const _StatusUpdateSheet({required this.incident});

  final Incident incident;

  @override
  ConsumerState<_StatusUpdateSheet> createState() => _StatusUpdateSheetState();
}

class _StatusUpdateSheetState extends ConsumerState<_StatusUpdateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  late IncidentStatus _status = widget.incident.status;
  late IncidentPriority? _priority = widget.incident.priority;
  // Validate live once the user has tried to save, so errors clear as the
  // status or note changes.
  bool _attemptedSave = false;

  bool get _noteRequired =>
      _status == IncidentStatus.rejected || _status == IncidentStatus.resolved;

  bool get _hasChanges =>
      _status != widget.incident.status ||
      _priority != widget.incident.priority ||
      _note.text.trim().isNotEmpty;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _attemptedSave = true);
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(incidentActionsProvider.notifier)
        .updateStatus(
          widget.incident.id,
          status: _status,
          priority: _priority,
          note: _note.text,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      context.showSnack('Status updated. The reporter can see the change.');
    } else {
      context.showSnack(
        describeError(ref.read(incidentActionsProvider).error!),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSaving = ref.watch(incidentActionsProvider).isLoading;
    final label = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: _attemptedSave
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        onChanged: () => setState(() {}),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Update status', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                widget.incident.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text('Status', style: label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in IncidentStatus.values)
                    ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(status.icon, size: 18, color: status.color),
                      label: Text(status.label),
                      selected: _status == status,
                      onSelected: (_) => setState(() => _status = status),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Priority', style: label),
              const SizedBox(height: 8),
              SegmentedButton<IncidentPriority?>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(value: null, label: Text('None')),
                  for (final priority in IncidentPriority.values)
                    ButtonSegment(value: priority, label: Text(priority.label)),
                ],
                selected: {_priority},
                onSelectionChanged: (selection) =>
                    setState(() => _priority = selection.first),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (_noteRequired && text.length < 5) {
                    return _status == IncidentStatus.rejected
                        ? 'Explain why this report is being rejected'
                        : 'Describe how the issue was resolved';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: _noteRequired
                      ? 'Note for the reporter'
                      : 'Note for the reporter (optional)',
                  hintText: 'e.g. A technician is scheduled for tomorrow',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              LoadingButton(
                label: 'Save update',
                isLoading: isSaving,
                onPressed: _hasChanges ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
