import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/event_form_input.dart';
import '../viewmodels/event_form_view_model.dart';

typedef EventFormSubmitCallback = Future<void> Function(EventFormInput input);

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({
    super.key,
    this.initialValue,
    required this.onSubmit,
  });

  final EventFormInput? initialValue;
  final EventFormSubmitCallback onSubmit;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _category;
  late final TextEditingController _location;
  late final TextEditingController _capacity;
  late DateTime _startAt;
  late DateTime _endAt;

  bool get _isEditMode => widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    final now = DateTime.now();
    _title = TextEditingController(text: value?.title ?? '');
    _description = TextEditingController(text: value?.description ?? '');
    _category = TextEditingController(text: value?.category ?? '');
    _location = TextEditingController(text: value?.locationName ?? '');
    _capacity = TextEditingController(text: value?.capacity.toString() ?? '');
    _startAt = value?.startAt ?? now.add(const Duration(hours: 1));
    _endAt = value?.endAt ?? now.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    _location.dispose();
    _capacity.dispose();
    super.dispose();
  }

  EventFormInput get _input => EventFormInput(
        title: _title.text,
        description: _description.text,
        category: _category.text,
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
    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startAt = selected;
      } else {
        _endAt = selected;
      }
    });
  }

  Future<void> _submit() async {
    if (ref.read(eventFormViewModelProvider).isSubmitting) return;

    await ref
        .read(eventFormViewModelProvider.notifier)
        .submit(_input, widget.onSubmit);
  }

  @override
  Widget build(BuildContext context) {
    final submissionState = ref.watch(eventFormViewModelProvider);
    final isSubmitting = submissionState.isSubmitting;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? 'Edit Event' : 'Create Event')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth >= 700 ? 680 : double.infinity),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_isEditMode ? 'Edit Event' : 'Create Event', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    _textField('titleField', _title, 'Title', submissionState.validationErrors['title'], isSubmitting),
                    _textField('descriptionField', _description, 'Description', submissionState.validationErrors['description'], isSubmitting, minLines: 4, maxLines: 6),
                    // Temporary text input until the shared category list exists.
                    _textField('categoryField', _category, 'Category', submissionState.validationErrors['category'], isSubmitting),
                    _textField('locationField', _location, 'Location', submissionState.validationErrors['locationName'], isSubmitting),
                    _dateTimeField('startDateTimeField', 'Start date and time', _startAt, null, isSubmitting, () => _selectDateTime(true)),
                    _dateTimeField('endDateTimeField', 'End date and time', _endAt, submissionState.validationErrors['endAt'], isSubmitting, () => _selectDateTime(false)),
                    _textField('capacityField', _capacity, 'Capacity', submissionState.validationErrors['capacity'], isSubmitting, number: true),
                    const SizedBox(height: 8),
                    if (submissionState.errorMessage != null)
                      Text(
                        submissionState.errorMessage!,
                        key: const Key('submissionErrorMessage'),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    FilledButton(
                      key: const Key('submitEventFormButton'),
                      onPressed: isSubmitting ? null : _submit,
                      child: Text(isSubmitting ? 'Saving...' : 'Save Event'),
                    ),
                  ].map((child) => Padding(padding: const EdgeInsets.only(bottom: 16), child: child)).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(String key, TextEditingController controller, String label, String? error, bool isSubmitting, {int? minLines, int? maxLines, bool number = false}) {
    return TextFormField(
      key: Key(key), controller: controller, enabled: !isSubmitting,
      minLines: minLines, maxLines: maxLines,
      keyboardType: number ? TextInputType.number : null,
      decoration: InputDecoration(labelText: label, errorText: error, border: const OutlineInputBorder()),
    );
  }

  Widget _dateTimeField(String key, String label, DateTime value, String? error, bool isSubmitting, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      OutlinedButton.icon(
        key: Key(key), onPressed: isSubmitting ? null : onTap,
        icon: const Icon(Icons.schedule_outlined), label: Align(alignment: Alignment.centerLeft, child: Text('$label: ${_format(value)}')),
      ),
      if (error != null) Padding(padding: const EdgeInsets.only(left: 12, top: 4), child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ]);
  }
}

String _format(DateTime value) => '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
