import 'package:flutter/material.dart';
import '../../../../core/constants/event_categories.dart';
import '../../data/models/event_filter.dart';

Future<EventFilter?> showEventFilterSheet(
  BuildContext context,
  EventFilter current,
) => showModalBottomSheet<EventFilter>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _EventFilterSheet(filter: current),
);

class _EventFilterSheet extends StatefulWidget {
  const _EventFilterSheet({required this.filter});
  final EventFilter filter;
  @override
  State<_EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends State<_EventFilterSheet> {
  late String? _category = widget.filter.category;
  late bool _available = widget.filter.onlyAvailable;
  late EventSort _sort = widget.filter.sort;
  late DateTime? _from = widget.filter.fromDate;
  late DateTime? _to = widget.filter.toDate;

  Future<void> _pickDates() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final firstDate = _from != null && _from!.isBefore(now) ? _from! : now;
    final lastDate = DateTime(now.year + 5, 12, 31);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (picked != null && mounted) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Filter events', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          key: ValueKey('category-$_category'),
          initialValue: _category ?? '',
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            const DropdownMenuItem(value: '', child: Text('All categories')),
            ...EventCategories.labels.entries.map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ),
            if (_category != null &&
                !EventCategories.labels.containsKey(_category))
              DropdownMenuItem(value: _category, child: Text(_category!)),
          ],
          onChanged: (value) =>
              setState(() => _category = value == '' ? null : value),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickDates,
          icon: const Icon(Icons.date_range),
          label: Text(
            _from == null
                ? 'Choose date range'
                : '${MaterialLocalizations.of(context).formatCompactDate(_from!)} – ${MaterialLocalizations.of(context).formatCompactDate(_to!)}',
          ),
        ),
        if (_from != null)
          TextButton(
            onPressed: () => setState(() {
              _from = null;
              _to = null;
            }),
            child: const Text('Remove dates'),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Only events with places available'),
          value: _available,
          onChanged: (value) => setState(() => _available = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<EventSort>(
          key: ValueKey('sort-$_sort'),
          initialValue: _sort,
          decoration: const InputDecoration(labelText: 'Sắp xếp theo'),
          items: EventSort.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
              .toList(),
          onChanged: (value) =>
              setState(() => _sort = value ?? EventSort.nearest),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            EventFilter(
              keyword: widget.filter.keyword,
              category: _category,
              fromDate: _from,
              toDate: _to,
              onlyAvailable: _available,
              sort: _sort,
            ),
          ),
          child: const Text('Apply filters'),
        ),
        TextButton(
          onPressed: () => setState(() {
            _category = null;
            _from = null;
            _to = null;
            _available = false;
            _sort = EventSort.nearest;
          }),
          child: const Text('Reset filters'),
        ),
      ],
    ),
  );
}
