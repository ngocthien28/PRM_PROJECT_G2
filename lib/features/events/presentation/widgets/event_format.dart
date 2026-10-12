import 'package:flutter/material.dart';

String eventDateTime(BuildContext context, DateTime date) {
  final local = date.toLocal();
  final localization = MaterialLocalizations.of(context);
  return '${localization.formatMediumDate(local)} · ${localization.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
}
