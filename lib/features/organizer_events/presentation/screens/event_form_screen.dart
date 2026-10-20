import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/event_categories.dart';
import '../../data/models/event_form_input.dart';
import '../viewmodels/event_form_view_model.dart';

typedef EventFormSubmitCallback = Future<void> Function(EventFormInput input);

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({
    super.key,
    this.initialValue,
    this.onSubmit,
    this.onSuccess,
  });

  final EventFormInput? initialValue;
  final EventFormSubmitCallback? onSubmit;
  final VoidCallback? onSuccess;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String? _category;
  late final TextEditingController _location;
  late final TextEditingController _capacity;
  late DateTime _startAt;
  late DateTime _endAt;
  bool _completed = false;

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
  }

  @override
  void dispose() {
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
  }

  Future<void> _submit() async {
    final onSubmit = widget.onSubmit;
    if (_completed ||
        onSubmit == null ||
        ref.read(eventFormViewModelProvider).isSubmitting) {
      return;
    }

    final saved = await ref
        .read(eventFormViewModelProvider.notifier)
        .submit(_input, onSubmit, requireFutureStart: !_isEditMode);
    if (saved && mounted) {
      setState(() => _completed = true);
      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final submissionState = ref.watch(eventFormViewModelProvider);
    final isSubmitting = submissionState.isSubmitting;
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
                                        ? 'Saving...'
                                        : _canSubmit
                                        ? (_isEditMode
                                              ? 'Save event'
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

  Widget _categoryField(String? error, bool isSubmitting) =>
      DropdownButtonFormField<String>(
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
            : (value) => setState(() => _category = value),
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
