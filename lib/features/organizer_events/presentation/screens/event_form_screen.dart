import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/event_categories.dart';
import '../../data/models/event_form_input.dart';
import '../viewmodels/event_form_view_model.dart';
import '../viewmodels/event_poster_view_model.dart';
import '../../../events/presentation/widgets/event_poster.dart';
import '../viewmodels/event_draft_controller.dart';
import '../viewmodels/event_draft_provider.dart';

typedef EventFormSubmitCallback = Future<void> Function(EventFormInput input);

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({
    super.key,
    this.initialValue,
    this.onSubmit,
    this.onSuccess,
    this.existingPosterUrl,
    this.onReload,
    this.draftOrganizerId,
  });

  final EventFormInput? initialValue;
  final EventFormSubmitCallback? onSubmit;
  final VoidCallback? onSuccess;
  final String? existingPosterUrl;
  final VoidCallback? onReload;
  final String? draftOrganizerId;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen>
    with WidgetsBindingObserver {
  EventDraftController? _draft;
  bool _restoring = false;
  bool _posterNeedsReselect = false;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String? _category;
  late final TextEditingController _location;
  late final TextEditingController _capacity;
  late DateTime _startAt;
  late DateTime _endAt;
  bool _completed = false;
  bool _submitPending = false;
  String _createRequestId = const Uuid().v4();

  bool get _isEditMode => widget.initialValue != null;
  bool get _canSubmit => widget.onSubmit != null;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    final now = DateTime.now();
    _title = TextEditingController(text: value?.title ?? '');
    _description = TextEditingController(text: value?.description ?? '');
    _category = EventCategories.labels.containsKey(value?.category)
        ? value?.category
        : null;
    _location = TextEditingController(text: value?.locationName ?? '');
    _capacity = TextEditingController(text: value?.capacity.toString() ?? '');
    _startAt = value?.startAt.toLocal() ?? now.add(const Duration(hours: 1));
    _endAt = value?.endAt.toLocal() ?? now.add(const Duration(hours: 2));

    _title.addListener(() => _clearFieldError('title'));
    _description.addListener(() => _clearFieldError('description'));
    _location.addListener(() => _clearFieldError('locationName'));
    _capacity.addListener(() => _clearFieldError('capacity'));
    WidgetsBinding.instance.addObserver(this);
    if (!_isEditMode && widget.draftOrganizerId != null) {
      _draft = ref
          .read(eventFormViewModelProvider.notifier)
          .openDraft(
            ref.read(eventDraftRepositoryProvider),
            widget.draftOrganizerId!,
          );
      _createRequestId = _draft!.id;
      _draft!.onChanged = () {
        if (mounted) setState(() {});
      };
      Future.microtask(_restoreDraft);
    }
  }

  Future<void> _restoreDraft() async {
    final draft = await _draft?.restore();
    if (!mounted || draft == null) return;
    _restoring = true;
    final fields = draft.fields;
    setState(() {
      _createRequestId = draft.id;
      _title.text = fields['title'] as String;
      _description.text = fields['description'] as String;
      _location.text = fields['locationName'] as String;
      _capacity.text = fields['capacity'] as String;
      _category = EventCategories.labels.containsKey(fields['category'])
          ? fields['category'] as String
          : null;
      _startAt = DateTime.parse(fields['startAt'] as String).toLocal();
      _endAt = DateTime.parse(fields['endAt'] as String).toLocal();
      _posterNeedsReselect = fields['posterSelected'] == true;
    });
    _restoring = false;
  }

  void _draftChanged() {
    if (_restoring || _completed || _draft == null) return;
    _draft!.changed({
      'title': _title.text,
      'description': _description.text,
      'category': _category ?? '',
      'locationName': _location.text,
      'capacity': _capacity.text,
      'startAt': _startAt.toUtc().toIso8601String(),
      'endAt': _endAt.toUtc().toIso8601String(),
      'posterSelected':
          _posterNeedsReselect ||
          ref.read(eventPosterViewModelProvider).selection != null,
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _draft?.flush();
  }

  Future<void> _discardDraft() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard draft?'),
        content: const Text('Remove the saved form from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    if (await _draft!.clear() && mounted) {
      _restoring = true;
      setState(() {
        _title.clear();
        _description.clear();
        _location.clear();
        _capacity.clear();
        _category = null;
        _posterNeedsReselect = false;
        _startAt = DateTime.now().add(const Duration(hours: 1));
        _endAt = _startAt.add(const Duration(hours: 1));
        _createRequestId = _draft!.id;
      });
      ref.invalidate(eventPosterViewModelProvider);
      ref.read(eventFormViewModelProvider.notifier).clearValidationErrors();
      _restoring = false;
    }
  }

  void _clearFieldError(String field) {
    if (!mounted) return;
    ref.read(eventFormViewModelProvider.notifier).clearFieldError(field);
    _draftChanged();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draft?.dispose();
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _capacity.dispose();
    super.dispose();
  }

  EventFormInput get _input => EventFormInput(
    title: _title.text,
    description: _description.text,
    category: _category ?? '',
    locationName: _location.text,
    startAt: _startAt,
    endAt: _endAt,
    capacity: int.tryParse(_capacity.text.trim()) ?? 0,
    posterSelection: ref.read(eventPosterViewModelProvider).selection,
    createRequestId: _createRequestId,
    currentRegisteredCount: widget.initialValue?.currentRegisteredCount,
  );

  Future<void> _selectDateTime(bool isStart) async {
    final current = isStart ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startAt = selected;
      } else {
        _endAt = selected;
      }
    });
    _clearFieldError(isStart ? 'startAt' : 'endAt');
    if (isStart) _clearFieldError('endAt');
  }

  Future<void> _submit() async {
    final onSubmit = widget.onSubmit;
    if (_completed ||
        _submitPending ||
        onSubmit == null ||
        ref.read(eventPosterViewModelProvider).selecting ||
        ref.read(eventFormViewModelProvider).isSubmitting) {
      return;
    }

    if (_posterNeedsReselect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the draft poster again before submitting.'),
        ),
      );
      return;
    }
    setState(() => _submitPending = true);
    try {
      _draftChanged();
      await _draft?.flush();
      if (!mounted) return;
      final saved = await ref
          .read(eventFormViewModelProvider.notifier)
          .submit(
            _input,
            onSubmit,
            requireFutureStart: !_isEditMode,
            currentRegisteredCount: widget.initialValue?.currentRegisteredCount,
          );
      if (saved) {
        _completed = true;
        final cleared = await _draft?.clear(submitted: true);
        if (!mounted) return;
        if (cleared == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event created, but local draft cleanup failed.'),
            ),
          );
        }
        widget.onSuccess?.call();
      }
    } finally {
      if (mounted) setState(() => _submitPending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(eventPosterViewModelProvider, (previous, next) {
      if (next.selection != previous?.selection) {
        _posterNeedsReselect = false;
        _draftChanged();
      }
    });
    final submissionState = ref.watch(eventFormViewModelProvider);
    final posterState = ref.watch(eventPosterViewModelProvider);
    final progress = ref.watch(eventPosterProgressProvider);
    final isSubmitting =
        _submitPending || submissionState.isSubmitting || posterState.selecting;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Event' : 'Create Event'),
        leading: IconButton(
          tooltip: 'Back to events',
          icon: const Icon(Icons.arrow_back),
          onPressed: isSubmitting
              ? null
              : () =>
                    context.canPop() ? context.pop() : context.go('/organizer'),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth >= 700 ? 720 : double.infinity,
                ),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children:
                          [
                                Text(
                                  _isEditMode ? 'Edit Event' : 'Create Event',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Fill in the details below so students can easily find and join your event.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 24),
                                if (_draft != null) ...[
                                  Text(
                                    _draft!.message,
                                    key: const Key('draftStatus'),
                                  ),
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      TextButton(
                                        onPressed: isSubmitting || _completed
                                            ? null
                                            : () {
                                                _draftChanged();
                                                _draft!.flush();
                                              },
                                        child: const Text('Save Draft'),
                                      ),
                                      TextButton(
                                        onPressed: isSubmitting || _completed
                                            ? null
                                            : _discardDraft,
                                        child: const Text('Discard Draft'),
                                      ),
                                      TextButton(
                                        onPressed: isSubmitting || _completed
                                            ? null
                                            : _restoreDraft,
                                        child: const Text('Retry Restore'),
                                      ),
                                    ],
                                  ),
                                ],
                                if (_posterNeedsReselect)
                                  const Text(
                                    'The previous poster was not stored. Select it again before submitting.',
                                    key: Key('draftPosterWarning'),
                                  ),
                                if (posterState.selection?.bytes != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      posterState.selection!.bytes!,
                                      key: const Key('posterPreview'),
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Text(
                                        'Cannot preview this poster.',
                                      ),
                                    ),
                                  )
                                else if (widget.existingPosterUrl != null)
                                  EventPoster(
                                    url: widget.existingPosterUrl,
                                    category: _category ?? '',
                                  ),
                                OutlinedButton.icon(
                                  key: const Key('selectPosterButton'),
                                  onPressed: isSubmitting || _completed
                                      ? null
                                      : () {
                                          _clearFieldError('poster');
                                          ref
                                              .read(
                                                eventPosterViewModelProvider
                                                    .notifier,
                                              )
                                              .select();
                                        },
                                  icon: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                  ),
                                  label: Text(
                                    posterState.selecting
                                        ? 'Selecting...'
                                        : posterState.selection != null ||
                                              widget.existingPosterUrl != null
                                        ? 'Change Poster'
                                        : 'Select Poster',
                                  ),
                                ),
                                const Text('JPG, PNG, or WebP · Maximum 5 MB'),
                                if (posterState.error != null ||
                                    submissionState
                                            .validationErrors['poster'] !=
                                        null)
                                  Text(
                                    posterState.error ??
                                        submissionState
                                            .validationErrors['poster']!,
                                    key: const Key('posterError'),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                if (submissionState.isSubmitting &&
                                    progress != null) ...[
                                  LinearProgressIndicator(
                                    value: progress,
                                    key: const Key('posterUploadProgress'),
                                  ),
                                  Text(
                                    'Uploading poster ${(progress * 100).round()}%',
                                  ),
                                ],
                                _textField(
                                  'titleField',
                                  _title,
                                  'Event title',
                                  'e.g. Flutter Career Workshop',
                                  submissionState.validationErrors['title'],
                                  isSubmitting,
                                ),
                                _textField(
                                  'descriptionField',
                                  _description,
                                  'Description',
                                  'Describe what students will learn or experience…',
                                  submissionState
                                      .validationErrors['description'],
                                  isSubmitting,
                                  minLines: 4,
                                  maxLines: 6,
                                ),
                                _categoryField(
                                  submissionState.validationErrors['category'],
                                  isSubmitting,
                                ),
                                _textField(
                                  'locationField',
                                  _location,
                                  'Location',
                                  'e.g. Innovation Hall, Room A204',
                                  submissionState
                                      .validationErrors['locationName'],
                                  isSubmitting,
                                ),
                                _dateTimeField(
                                  'startDateTimeField',
                                  'Start date & time',
                                  _startAt,
                                  submissionState.validationErrors['startAt'],
                                  isSubmitting,
                                  () => _selectDateTime(true),
                                ),
                                _dateTimeField(
                                  'endDateTimeField',
                                  'End date & time',
                                  _endAt,
                                  submissionState.validationErrors['endAt'],
                                  isSubmitting,
                                  () => _selectDateTime(false),
                                ),
                                _textField(
                                  'capacityField',
                                  _capacity,
                                  'Maximum attendees',
                                  'e.g. 80',
                                  submissionState.validationErrors['capacity'],
                                  isSubmitting,
                                  number: true,
                                ),
                                const SizedBox(height: 8),
                                if (submissionState.errorMessage != null)
                                  Text(
                                    submissionState.errorMessage!,
                                    key: const Key('submissionErrorMessage'),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                if (!_canSubmit)
                                  const Text(
                                    'Event saving is not available yet.',
                                    key: Key('eventSavingUnavailableMessage'),
                                  ),
                                if (submissionState.errorMessage != null &&
                                    widget.onReload != null)
                                  TextButton(
                                    onPressed: isSubmitting
                                        ? null
                                        : widget.onReload,
                                    child: const Text('Reload latest event'),
                                  ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  key: const Key('submitEventFormButton'),
                                  onPressed:
                                      isSubmitting || _completed || !_canSubmit
                                      ? null
                                      : _submit,
                                  icon: Icon(
                                    isSubmitting
                                        ? Icons.hourglass_top_rounded
                                        : Icons.check_circle_outline,
                                  ),
                                  label: Text(
                                    isSubmitting
                                        ? (progress != null
                                              ? 'Uploading poster...'
                                              : 'Saving...')
                                        : _canSubmit
                                        ? (_isEditMode
                                              ? 'Save Changes'
                                              : 'Create Event')
                                        : 'Saving unavailable',
                                  ),
                                ),
                              ]
                              .map(
                                (child) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: child,
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(
    String key,
    TextEditingController controller,
    String label,
    String hint,
    String? error,
    bool isSubmitting, {
    int? minLines,
    int? maxLines,
    bool number = false,
  }) {
    return TextFormField(
      key: Key(key),
      controller: controller,
      enabled: !isSubmitting,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: number ? TextInputType.number : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _categoryField(String? error, bool isSubmitting) => KeyedSubtree(
    key: ValueKey(_category),
    child: DropdownButtonFormField<String>(
      key: const Key('categoryField'),
      initialValue: _category,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Category',
        hintText: 'Select an event category',
        errorText: error,
        border: const OutlineInputBorder(),
      ),
      items: EventCategories.labels.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: isSubmitting
          ? null
          : (value) {
              setState(() => _category = value);
              _clearFieldError('category');
            },
    ),
  );

  Widget _dateTimeField(
    String key,
    String label,
    DateTime value,
    String? error,
    bool isSubmitting,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          key: Key(key),
          onPressed: isSubmitting ? null : onTap,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text('$label\n${_format(value)}'),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

String _format(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
