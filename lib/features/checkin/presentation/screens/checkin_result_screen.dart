import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../viewmodels/checkin_view_model.dart';

/// Screen displaying the outcome of a participant check-in attempt.
class CheckinResultScreen extends StatelessWidget {
  const CheckinResultScreen({
    super.key,
    required this.result,
    this.onScanNext,
    this.onClose,
  });

  final CheckinResult result;
  final VoidCallback? onScanNext;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuccess = result.isSuccess;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSuccess ? 'Kết Quả Check-in' : 'Lỗi Check-in'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Đóng',
            icon: const Icon(Icons.close),
            onPressed: () {
              if (onClose != null) {
                onClose!();
              } else {
                Navigator.of(context).pop(false);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Status Icon Card
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSuccess
                            ? Colors.green.shade400
                            : Colors.red.shade400,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      isSuccess
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 56,
                      color: isSuccess
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header Title
                  Text(
                    isSuccess ? 'Check-in Thành Công!' : 'Check-in Thất Bại',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSuccess
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Message description
                  Text(
                    result.message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Details Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSuccess
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isSuccess) ...[
                            _DetailRow(
                              icon: Icons.person_outline,
                              label: 'Người tham gia',
                              value: result.participantName ?? 'Sinh viên',
                            ),
                            if (result.participantEmail != null &&
                                result.participantEmail!.isNotEmpty) ...[
                              const Divider(height: 20),
                              _DetailRow(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: result.participantEmail!,
                              ),
                            ],
                            const Divider(height: 20),
                            _DetailRow(
                              icon: Icons.event_outlined,
                              label: 'Sự kiện',
                              value: result.eventTitle ?? 'Sự kiện CampusHub',
                            ),
                            const Divider(height: 20),
                            _DetailRow(
                              icon: Icons.access_time_outlined,
                              label: 'Thời gian check-in',
                              value: DateFormat('dd/MM/yyyy HH:mm:ss').format(
                                (result.checkedInAt ?? DateTime.now()).toLocal(),
                              ),
                            ),
                            if (result.registration != null) ...[
                              const Divider(height: 20),
                              _DetailRow(
                                icon: Icons.confirmation_number_outlined,
                                label: 'Mã vé',
                                value: result.registration!.id,
                              ),
                            ],
                          ] else ...[
                            _FailureReasonBox(result: result),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      key: const Key('checkinResultScanNextButton'),
                      onPressed: () {
                        if (onScanNext != null) {
                          onScanNext!();
                        } else {
                          Navigator.of(context).pop(true);
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(
                        isSuccess ? 'Quét vé tiếp theo' : 'Thử quét lại',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      key: const Key('checkinResultCloseButton'),
                      onPressed: () {
                        if (onClose != null) {
                          onClose!();
                        } else {
                          Navigator.of(context).pop(false);
                        }
                      },
                      child: const Text('Đóng'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FailureReasonBox extends StatelessWidget {
  const _FailureReasonBox({required this.result});

  final CheckinResult result;

  @override
  Widget build(BuildContext context) {
    String heading;
    String tip;

    switch (result.errorCode) {
      case 'duplicate_checkin':
        heading = 'Vé Đã Quét Trùng';
        tip = 'Mã vé này đã được ghi nhận check-in trước đó. Hệ thống tự động ngăn chặn gian lận điểm danh.';
        break;
      case 'wrong_event':
        heading = 'Vé Nhầm Sự Kiện';
        tip = 'Mã QR này được cấp cho một sự kiện khác, không khớp với sự kiện Ban tổ chức đang quét.';
        break;
      case 'invalid_qr':
        heading = 'Mã QR Không Hợp Lệ';
        tip = 'Mã QR không đúng định dạng chuẩn của CampusHub hoặc chứa dữ liệu không xác định.';
        break;
      case 'permission_denied':
        heading = 'Từ Chối Quyền Truy Cập';
        tip = 'Tài khoản của bạn không được phân quyền quản trị hoặc tổ chức sự kiện này.';
        break;
      case 'event_cancelled':
        heading = 'Sự Kiện Không Mở';
        tip = 'Sự kiện này đã kết thúc, bị hủy hoặc chưa mở đăng ký check-in.';
        break;
      default:
        heading = 'Lỗi Xác Thực Vé';
        tip = result.message;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(
              heading,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          tip,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
        ),
      ],
    );
  }
}
