import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const responsiveViewports = <Size>[
  Size(640, 360),
  Size(800, 450),
  Size(1280, 720),
  Size(1920, 1080),
];

Future<void> pumpResponsiveWidget(
  WidgetTester tester,
  Widget child,
  Size size, {

  /// System-obscured area represented as [MediaQueryData.viewPadding].
  EdgeInsets safePadding = EdgeInsets.zero,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  final mediaPadding = EdgeInsets.fromLTRB(
    (safePadding.left - viewInsets.left).clamp(0, double.infinity),
    (safePadding.top - viewInsets.top).clamp(0, double.infinity),
    (safePadding.right - viewInsets.right).clamp(0, double.infinity),
    (safePadding.bottom - viewInsets.bottom).clamp(0, double.infinity),
  );
  final mediaQueryData = MediaQueryData(
    size: size,
    padding: mediaPadding,
    viewPadding: safePadding,
    viewInsets: viewInsets,
    textScaler: textScaler,
  );
  final spec = DuelRoomLayoutSpec.resolve(size, safePadding: safePadding);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, appChild) =>
          MediaQuery(data: mediaQueryData, child: appChild!),
      home: Scaffold(
        body: DuelRoomLayout(spec: spec, child: child),
      ),
    ),
  );
  await tester.pump();
}
