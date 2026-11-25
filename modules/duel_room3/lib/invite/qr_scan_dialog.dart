/// 扫一扫：相机扫码加入房间；桌面 / Web 退化为粘贴邀请码。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'duel_invite.dart';

/// 当前平台是否支持实时取景扫码（仅移动端；桌面/Web 走粘贴兜底）。
bool get isRoomQrScanCameraSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// 打开扫码弹窗，返回扫到 / 粘贴到的原始文本。
///
/// 返回的只是原文：解析交给 [DuelInvite.tryParse]，选择环境与真正进房由
/// 宿主 app 负责（模块不依赖建房/进房逻辑）。
Future<String?> showRoomQrScanDialog(
  BuildContext context, {
  bool? cameraSupported,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (_) => RoomQrScanDialog(cameraSupported: cameraSupported),
  );
}

/// 扫码弹窗：相机取景（移动端）或粘贴输入（桌面/Web、相机不可用时）。
class RoomQrScanDialog extends StatefulWidget {
  const RoomQrScanDialog({super.key, this.cameraSupported});

  /// 覆盖「当前平台是否取景扫码」；为空时按 [isRoomQrScanCameraSupported] 判断。
  ///
  /// 宿主在明确知道拿不到相机（如 Web/桌面构建）或测试里固定走粘贴兜底时传入。
  final bool? cameraSupported;

  @override
  State<RoomQrScanDialog> createState() => _RoomQrScanDialogState();
}

class _RoomQrScanDialogState extends State<RoomQrScanDialog> {
  static const Color _bg = Color(0xFF05070F);
  static const Color _line = Color(0xFF1B3A52);
  static const Color _accent = Color(0xFF22D3EE);

  final TextEditingController _text = TextEditingController();
  MobileScannerController? _controller;
  late bool _camera = widget.cameraSupported ?? isRoomQrScanCameraSupported;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    if (_camera) _controller = _createController();
  }

  MobileScannerController _createController() => MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    _text.dispose();
    super.dispose();
  }

  void _finish(String raw) {
    final value = raw.trim();
    if (_finished || value.isEmpty) return;
    _finished = true;
    Navigator.of(context).pop(value);
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _finish(value);
        return;
      }
    }
  }

  void _toCamera() {
    setState(() {
      _camera = true;
      _controller ??= _createController();
    });
  }

  void _toManual() {
    setState(() => _camera = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  '扫码加入房间',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey('qr-scan-close'),
                  visualDensity: VisualDensity.compact,
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_camera) _cameraView() else _manualView(),
            const SizedBox(height: 8),
            Text(
              _camera ? '把好友的邀请二维码放进取景框' : '粘贴邀请链接或房间号',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: const ValueKey('qr-scan-toggle-mode'),
              onPressed: _camera ? _toManual : _toCamera,
              child: Text(_camera ? '没有相机权限？手动输入' : '改用相机扫码'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraView() {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _cameraError(error),
              placeholderBuilder: (context) => const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Text('相机启动中…', style: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    border: Border.all(color: _accent, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraError(MobileScannerException error) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white38),
              const SizedBox(height: 8),
              const Text(
                '无法打开相机',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                error.errorCode.name,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _toManual,
                child: const Text('改用手动输入'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _manualView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('qr-scan-input'),
          controller: _text,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            hintText: 'uniygo://duel?room=462890',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
            isDense: true,
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: _line),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: _accent),
            ),
          ),
          onSubmitted: _finish,
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('qr-scan-submit'),
          onPressed: () => _finish(_text.text),
          child: const Text('加入'),
        ),
      ],
    );
  }
}
