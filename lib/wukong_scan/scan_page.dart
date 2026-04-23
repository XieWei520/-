import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scan_result_page.dart';
import 'scan_service.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final TextEditingController _manualInputController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 500,
    facing: CameraFacing.back,
    autoStart: true,
  );
  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;
  bool _isAnalyzingImage = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String rawContent) async {
    final content = rawContent.trim();
    if (content.isEmpty || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await ScanService.instance.processScanResult(content);
      if (!mounted) {
        return;
      }
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ScanResultPage(result: result)));
    } catch (e) {
      if (mounted) {
        _showSnack('二维码处理失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pasteFromClipboard() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (!mounted) {
        return;
      }
      _showSnack('剪贴板里没有可用内容');
      return;
    }
    _manualInputController.text = text;
    await _handleScan(text);
  }

  Future<void> _analyzeFromGallery() async {
    if (_isAnalyzingImage) {
      return;
    }
    try {
      setState(() {
        _isAnalyzingImage = true;
      });
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        return;
      }
      await _scannerController.analyzeImage(picked.path);
    } catch (e) {
      _showSnack('解析图片失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingImage = false;
        });
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
    } catch (e) {
      _showSnack('切换闪光灯失败: $e');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _scannerController.switchCamera();
    } catch (e) {
      _showSnack('切换摄像头失败: $e');
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isSubmitting) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue ?? barcode.displayValue;
      if (value != null && value.trim().isNotEmpty) {
        _handleScan(value);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ɨһɨ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildScannerCard(context),
          const SizedBox(height: 20),
          _buildManualSection(context),
        ],
      ),
    );
  }

  Widget _buildScannerCard(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                final torchState = state.torchState;
                final bool torchOn = torchState == TorchState.on;
                final isTorchEnabled =
                    state.isRunning &&
                    torchState != TorchState.unavailable &&
                    torchOn;
                final canToggleTorch =
                    state.isRunning && torchState != TorchState.unavailable;
                final isFrontCamera =
                    state.cameraDirection == CameraFacing.front;
                final canSwitchCamera =
                    state.availableCameras == null ||
                    (state.availableCameras ?? 0) > 1;
                final hasError = state.error != null;
                final errorMessage =
                    state.error?.errorDetails?.message ?? '摄像头不可用';
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.black,
                      child: MobileScanner(
                        controller: _scannerController,
                        onDetect: _onDetect,
                        errorBuilder: (context, error, child) {
                          return _ScannerStatusPlaceholder(
                            message: error.errorDetails?.message ?? '摄像头不可用',
                            icon: Icons.videocam_off_outlined,
                          );
                        },
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ScannerActionButton(
                            icon: isTorchEnabled
                                ? Icons.flash_on
                                : Icons.flash_off_outlined,
                            label: isTorchEnabled ? '关闭闪光' : '打开闪光',
                            onTap: canToggleTorch ? _toggleTorch : null,
                          ),
                          _ScannerActionButton(
                            icon: Icons.image_outlined,
                            label: _isAnalyzingImage ? '解析中' : '相册二维码',
                            onTap: _isAnalyzingImage
                                ? null
                                : _analyzeFromGallery,
                          ),
                          _ScannerActionButton(
                            icon: Icons.cameraswitch_outlined,
                            label: isFrontCamera ? '使用后摄' : '切换前摄',
                            onTap: canSwitchCamera ? _switchCamera : null,
                          ),
                        ],
                      ),
                    ),
                    if (hasError)
                      _ScannerStatusPlaceholder(
                        message: errorMessage,
                        icon: Icons.videocam_off_outlined,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '对准二维码即可自动解析，也可以从相册选择二维码图片进行识别。',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildManualSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _manualInputController,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '二维码内容',
            hintText: '粘贴 http://103.207.68.33:8090/v1/qrcode/... 或其他二维码文本',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onSubmitted: (_) => _handleScan(_manualInputController.text),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _pasteFromClipboard,
                icon: const Icon(Icons.content_paste),
                label: const Text('从剪贴板解析'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _handleScan(_manualInputController.text),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_2),
                label: Text(_isSubmitting ? '解析中...' : '解析输入内容'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScannerActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ScannerActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerStatusPlaceholder extends StatelessWidget {
  final String message;
  final IconData icon;

  const _ScannerStatusPlaceholder({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
