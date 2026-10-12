import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/viewmodels/event_list_view_model.dart';
import '../../data/models/registration_model.dart';
import '../viewmodels/registration_view_model.dart';
import '../widgets/registration_status_chip.dart';

class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({
    super.key,
    required this.registrationId,
    this.initialRegistration,
    this.initialEvent,
  });

  final String registrationId;
  final RegistrationModel? initialRegistration;
  final EventModel? initialEvent;

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  RegistrationModel? _registration;
  EventModel? _event;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _registration = widget.initialRegistration;
    _event = widget.initialEvent;
    if (_registration != null && _event != null) {
      _isLoading = false;
    } else {
      _loadTicketData();
    }
  }

  Future<void> _loadTicketData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      RegistrationModel? reg = _registration;
      if (reg == null) {
        // Find in registrations list or fetch directly
        final list = await ref.read(myRegistrationsProvider.future);
        reg = list.where((r) => r.id == widget.registrationId).firstOrNull;
      }

      if (reg == null) {
        throw Exception('Không tìm thấy thông tin vé đăng ký');
      }

      _registration = reg;

      // Load event info if not already provided
      if (_event == null) {
        try {
          final eventRepo = ref.read(eventRepositoryProvider);
          _event = await eventRepo
              .getEventById(reg.eventId)
              .timeout(const Duration(seconds: 2));
        } catch (_) {
          // Fallback: event might be offline
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đăng ký sự kiện?'),
        content: const Text(
          'Bạn có chắc chắn muốn hủy vé tham gia sự kiện này không? '
          'Chỗ trống sẽ được giải phóng cho sinh viên khác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(registrationActionProvider.notifier).cancelRegistration(
          registrationId: _registration!.id,
          eventId: _registration!.eventId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy đăng ký thành công')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vé Tham Gia (E-Ticket)'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadTicketData,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildTicketContent(),
    );
  }

  Widget _buildTicketContent() {
    final reg = _registration!;
    final event = _event;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // Ticket Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RegistrationStatusChip(status: reg.status),
                          Text(
                            'Mã: ${reg.id.split('_').first}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Event Title
                      Text(
                        event?.title ?? 'Sự Kiện Trường',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (event != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                event.locationName,
                                style: TextStyle(color: Colors.grey.shade700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(event.startAt.toLocal()),
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ],

                      const Divider(height: 36, thickness: 1),

                      // QR Code Container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: reg.encodedQr,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 16),
                      Text(
                        'Đưa mã này cho Ban tổ chức tại cửa sự kiện',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Mã vé: ${reg.id}',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              if (reg.canCancel)
                OutlinedButton.icon(
                  onPressed: _confirmCancel,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('Hủy vé đăng ký', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
