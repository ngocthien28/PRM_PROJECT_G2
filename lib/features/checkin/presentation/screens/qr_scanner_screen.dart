import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../viewmodels/checkin_view_model.dart';
import 'checkin_result_screen.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({
    super.key,
    required this.eventId,
    this.eventTitle,
  });

  final String eventId;
  final String? eventTitle;

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _isTorchOn = false;
  bool _isProcessingScan = false;
  final TextEditingController _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualInputController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetection(BarcodeCapture capture) async {
    if (_isProcessingScan) return;

    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;

    if (rawValue == null || rawValue.isEmpty) return;

    await _processTicketPayload(rawValue);
  }

  Future<void> _processTicketPayload(String rawPayload) async {
    if (_isProcessingScan) return;

    setState(() => _isProcessingScan = true);

    final viewModel = ref.read(checkinViewModelProvider.notifier);
    final result = await viewModel.processBarcode(
      rawPayload,
      expectedEventId: widget.eventId,
      expectedEventTitle: widget.eventTitle,
    );

    if (!mounted) return;

    // Navigate to Result Screen
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CheckinResultScreen(
          result: result,
          onScanNext: () => Navigator.of(context).pop(true),
          onClose: () => Navigator.of(context).pop(false),
        ),
      ),
    );

    if (mounted) {
      viewModel.unlockScanner();
      setState(() => _isProcessingScan = false);
    }
  }

  Future<void> _showManualInputDialog() async {
    _manualInputController.clear();
    final enteredText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập Mã Vé Thủ Công'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập chuỗi JSON QR payload hoặc mã vé đăng ký:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('manualQrInputField'),
              controller: _manualInputController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '{"v":1,"rid":"...","eid":"...","t":"..."}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('submitManualQrButton'),
            onPressed: () {
              final text = _manualInputController.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(ctx).pop(text);
              }
            },
            child: const Text('Kiểm tra & Check-in'),
          ),
        ],
      ),
    );

    if (enteredText != null && enteredText.isNotEmpty) {
      await _processTicketPayload(enteredText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopPlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventTitle ?? 'Quét QR Check-in'),
        actions: [
          IconButton(
            key: const Key('manualInputIconButton'),
            tooltip: 'Nhập mã vé thủ công',
            icon: const Icon(Icons.keyboard_outlined),
            onPressed: _showManualInputDialog,
          ),
          if (!isDesktopPlatform)
            IconButton(
              tooltip: 'Bật/Tắt Đèn Flash',
              icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
              onPressed: () async {
                await _controller.toggleTorch();
                setState(() => _isTorchOn = !_isTorchOn);
              },
            ),
          if (!isDesktopPlatform)
            IconButton(
              tooltip: 'Đổi Camera',
              icon: const Icon(Icons.flip_camera_ios_outlined),
              onPressed: () => _controller.switchCamera(),
            ),
        ],
      ),
      body: isDesktopPlatform
          ? _buildDesktopFallbackView()
          : Stack(
              children: [
                // Camera Scanner Preview
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleBarcodeDetection,
                  errorBuilder: (context, error) {
                    return _buildCameraErrorView(error);
                  },
                ),

                // Targeting Overlay Cutout
                _buildScannerOverlay(),

                // Header Info Bar
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.eventTitle ?? 'Sự kiện #${widget.eventId}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Căn chỉnh mã QR vé của sinh viên vào khung ngắm',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Processing Indicator
                if (_isProcessingScan)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Đang xác thực vé...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('manualInputFab'),
        onPressed: _showManualInputDialog,
        icon: const Icon(Icons.keyboard),
        label: const Text('Nhập mã thủ công'),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = constraints.maxWidth * 0.7;

        return Center(
          child: Container(
            width: scanAreaSize,
            height: scanAreaSize,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Corner accents
                Align(
                  alignment: Alignment.topLeft,
                  child: _CornerMark(corner: _Corner.topLeft),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: _CornerMark(corner: _Corner.topRight),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: _CornerMark(corner: _Corner.bottomLeft),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: _CornerMark(corner: _Corner.bottomRight),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraErrorView(MobileScannerException error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              size: 64,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            const Text(
              'Không thể truy cập máy ảnh',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Nguyên nhân: ${error.errorCode.name}. '
              'Vui lòng cấp quyền truy cập camera trong Cài đặt hoặc dùng chức năng nhập mã thủ công.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _showManualInputDialog,
              icon: const Icon(Icons.keyboard),
              label: const Text('Nhập mã vé thủ công'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopFallbackView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cổng Check-in Ban Tổ Chức',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sự kiện: ${widget.eventTitle ?? widget.eventId}',
                    style: TextStyle(color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Trên môi trường Desktop/Mô phỏng, bạn có thể kiểm tra quy trình check-in bằng cách dán mã QR payload hoặc mã vé.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _showManualInputDialog,
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Nhập mã vé để Check-in'),
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

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerMark extends StatelessWidget {
  const _CornerMark({required this.corner});

  final _Corner corner;

  @override
  Widget build(BuildContext context) {
    const size = 24.0;
    const thickness = 4.0;
    const color = Colors.tealAccent;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border(
          top: corner == _Corner.topLeft || corner == _Corner.topRight
              ? const BorderSide(color: color, width: thickness)
              : BorderSide.none,
          bottom: corner == _Corner.bottomLeft || corner == _Corner.bottomRight
              ? const BorderSide(color: color, width: thickness)
              : BorderSide.none,
          left: corner == _Corner.topLeft || corner == _Corner.bottomLeft
              ? const BorderSide(color: color, width: thickness)
              : BorderSide.none,
          right: corner == _Corner.topRight || corner == _Corner.bottomRight
              ? const BorderSide(color: color, width: thickness)
              : BorderSide.none,
        ),
      ),
    );
  }
}
