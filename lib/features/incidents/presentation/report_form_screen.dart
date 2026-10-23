
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../core/widgets/state_views.dart';
import '../application/incident_providers.dart';
import '../domain/campus_locations.dart';
import '../domain/incident.dart';
import '../domain/incident_enums.dart';
import 'widgets/incident_badges.dart';

/// Creates a report, or edits one when [incidentId] is given.
class ReportFormScreen extends ConsumerWidget {
  const ReportFormScreen({this.incidentId, super.key});

  final String? incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = incidentId;
    if (id == null) return const _ReportForm();

    return AsyncValueView(
      value: ref.watch(incidentProvider(id)),
      onRetry: () => ref.invalidate(incidentProvider(id)),
      data: (incident) => incident == null
          ? const Scaffold(
              body: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'This report no longer exists',
              ),
            )
          : _ReportForm(existing: incident),
    );
  }
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({this.existing});

  final Incident? existing;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  static const _titleMax = 80;
  static const _descriptionMax = 1000;

  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(
    text: widget.existing?.description,
  );
  late final _location = TextEditingController(text: widget.existing?.location);
  late IncidentCategory? _category = widget.existing?.category;
  Uint8List? _photo;
  bool _isAnonymous = false;
  bool _isPrivate = false;
  bool _showCategoryError = false;
  bool _isDirty = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  void _markDirty() => _isDirty = true;

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(source: source);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _photo = bytes;
        _isDirty = true;
      });
    } on PlatformException {
      if (mounted) {
        context.showSnack(
          'Could not open the camera or gallery. Check app permissions.',
          isError: true,
        );
      }
    }
  }

  Future<void> _pickLocation() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final place in campusLocations)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(place),
                onTap: () => Navigator.pop(context, place),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      _location.text = picked;
      _isDirty = true;
    }
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    setState(() => _showCategoryError = _category == null);
    if (!formValid || _category == null) return;
    FocusScope.of(context).unfocus();

    final actions = ref.read(incidentActionsProvider.notifier);
    final existing = widget.existing;
    if (existing != null) {
      final ok = await actions.updateDetails(
        existing.id,
        title: _title.text,
        description: _description.text,
        location: _location.text,
      );
      if (!mounted) return;
      if (ok) {
        _isDirty = false;
        context.showSnack('Report updated');
        context.pop();
      } else {
        _showError();
      }
      return;
    }

    final id = await actions.submit(
      IncidentDraft(
        title: _title.text,
        description: _description.text,
        category: _category!,
        location: _location.text,
        isAnonymous: _isAnonymous,
        isPrivate: _isPrivate,
      ),
      _photo,
    );
    if (!mounted) return;
    if (id == null) return _showError();
    _isDirty = false;
    context.showSnack('Report submitted. Staff have been notified.');
    context.pushReplacement('/incident/$id');
  }

  void _showError() => context.showSnack(
    describeError(ref.read(incidentActionsProvider).error!),
    isError: true,
  );

  Future<void> _confirmDiscard() async {
    final discard = await context.confirm(
      title: 'Discard this report?',
      message: 'Your changes will be lost.',
      confirmLabel: 'Discard',
      isDestructive: true,
    );
    if (discard && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSaving = ref.watch(incidentActionsProvider).isLoading;
    final forcedPrivate = _category?.isAlwaysPrivate ?? false;

    return PopScope(
      canPop: !_isDirty || isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit report' : 'Report an incident'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            onChanged: _markDirty,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _SectionLabel(_isEditing ? 'Category' : 'Select a category'),
                _CategoryPicker(
                  selected: _category,
                  enabled: !_isEditing,
                  onSelected: (category) => setState(() {
                    _category = category;
                    _showCategoryError = false;
                    _isDirty = true;
                  }),
                ),
                if (_showCategoryError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Choose the category that best fits the issue',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const _SectionLabel('Title'),
                TextFormField(
                  controller: _title,
                  maxLength: _titleMax,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  validator: Validators.requiredText(
                    'Title',
                    min: 5,
                    max: _titleMax,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Briefly describe the issue',
                  ),
                ),
                const _SectionLabel('Description'),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: _descriptionMax,
                  textCapitalization: TextCapitalization.sentences,
                  validator: Validators.requiredText(
                    'Description',
                    min: 10,
                    max: _descriptionMax,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'What happened, when, and how it affects people',
                    alignLabelWithHint: true,
                  ),
                ),
                const _SectionLabel('Location'),
                TextFormField(
                  controller: _location,
                  textCapitalization: TextCapitalization.words,
                  validator: Validators.requiredText(
                    'Location',
                    min: 2,
                    max: 100,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Library, 2nd floor',
                    prefixIcon: const Icon(Icons.place_outlined),
                    suffixIcon: IconButton(
                      tooltip: 'Choose a campus location',
                      icon: const Icon(Icons.expand_more_rounded),
                      onPressed: _pickLocation,
                    ),
                  ),
                ),
                if (!_isEditing) ...[
                  const _SectionLabel('Add a photo (optional)'),
                  _PhotoPicker(
                    photo: _photo,
                    onPick: _pickPhoto,
                    onRemove: () => setState(() => _photo = null),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isAnonymous,
                    onChanged: (value) => setState(() {
                      _isAnonymous = value;
                      _isDirty = true;
                    }),
                    title: const Text('Report anonymously'),
                    subtitle: const Text(
                      'Your name is hidden from other students. Staff can '
                      'still follow up with you.',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isPrivate || forcedPrivate,
                    onChanged: forcedPrivate
                        ? null
                        : (value) => setState(() {
                            _isPrivate = value;
                            _isDirty = true;
                          }),
                    title: const Text('Keep private'),
                    subtitle: Text(
                      forcedPrivate
                          ? 'Safety reports are always visible only to you '
                                'and campus staff.'
                          : 'Only you and campus staff will see this report.',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                LoadingButton(
                  label: _isEditing ? 'Save changes' : 'Submit report',
                  isLoading: isSaving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final IncidentCategory? selected;
  final bool enabled;
  final ValueChanged<IncidentCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.9,
      children: [
        for (final category in IncidentCategory.values)
          Semantics(
            selected: category == selected,
            button: true,
            child: Material(
              color: category == selected
                  ? scheme.primary
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: enabled ? () => onSelected(category) : null,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        category.icon,
                        color: category == selected
                            ? scheme.onPrimary
                            : scheme.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: category == selected
                              ? scheme.onPrimary
                              : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photo,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(14);

    if (photo != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: radius,
            child: Image.memory(
              photo!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              tooltip: 'Remove photo',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: radius,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: scheme.outlineVariant),
          color: scheme.surfaceContainerLowest,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: scheme.primary),
            const SizedBox(height: 8),
            const Text('Tap to add a photo'),
            Text(
              'Location data is removed before upload',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
