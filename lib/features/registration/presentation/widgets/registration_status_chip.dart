import 'package:flutter/material.dart';
import '../../../../shared/enums/registration_status.dart';

class RegistrationStatusChip extends StatelessWidget {
  const RegistrationStatusChip({
    super.key,
    required this.status,
  });

  final RegistrationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = switch (status) {
      RegistrationStatus.registered => (
        'Đã đăng ký',
        Icons.confirmation_number_outlined,
        Colors.blue.shade50,
        Colors.blue.shade800,
      ),
      RegistrationStatus.checkedIn => (
        'Đã check-in',
        Icons.check_circle_outline,
        Colors.green.shade50,
        Colors.green.shade800,
      ),
      RegistrationStatus.cancelled => (
        'Đã hủy',
        Icons.cancel_outlined,
        Colors.red.shade50,
        Colors.red.shade800,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
