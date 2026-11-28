import 'package:duel_room3/util/invite/qr_scan_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(void Function(String?) onDone) => MaterialApp(
    home: Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async =>
                onDone(await showRoomQrScanDialog(ctx, cameraSupported: false)),
            child: const Text('scan'),
          ),
        ),
      ),
    ),
  );

  testWidgets('桌面/Web（无相机）：粘贴邀请码后原样返回', (tester) async {
    String? scanned;
    await tester.pumpWidget(host((value) => scanned = value));

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    expect(find.text('扫码加入房间'), findsOneWidget);
    expect(find.text('粘贴邀请链接或房间号'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('qr-scan-input')),
      'uniygo://duel?room=462890',
    );
    await tester.tap(find.byKey(const ValueKey('qr-scan-submit')));
    await tester.pumpAndSettle();

    expect(scanned, 'uniygo://duel?room=462890');
    expect(find.text('扫码加入房间'), findsNothing);
  });

  testWidgets('空白输入不返回', (tester) async {
    String? scanned;
    await tester.pumpWidget(host((value) => scanned = value));
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('qr-scan-submit')));
    await tester.pumpAndSettle();

    expect(scanned, isNull);
    expect(find.text('扫码加入房间'), findsOneWidget);
  });

  testWidgets('关闭不返回结果', (tester) async {
    String? scanned;
    await tester.pumpWidget(host((value) => scanned = value));
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('qr-scan-close')));
    await tester.pumpAndSettle();

    expect(scanned, isNull);
  });

  test('平台能力：移动端取景，桌面与 Web 走粘贴', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(isRoomQrScanCameraSupported, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(isRoomQrScanCameraSupported, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(isRoomQrScanCameraSupported, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
