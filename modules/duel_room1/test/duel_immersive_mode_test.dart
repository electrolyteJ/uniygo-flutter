import 'dart:async';

import 'package:duel_room1/platform/duel_immersive_mode.dart';
import 'package:duel_room1/platform/platform_adaptive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('defaults to the adaptive target platform', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final modes = <SystemUiMode>[];

    await tester.pumpWidget(
      DuelImmersiveMode(
        controller: DuelSystemUiController(
          setter: (mode) async => modes.add(mode),
        ),
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
    expect(modes, [SystemUiMode.immersiveSticky, SystemUiMode.edgeToEdge]);
  });

  testWidgets('mobile enters immersive mode and restores edge to edge', (
    tester,
  ) async {
    final modes = <SystemUiMode>[];
    final controller = DuelSystemUiController(
      setter: (mode) async => modes.add(mode),
    );

    await tester.pumpWidget(
      DuelImmersiveMode(
        platform: DuelPlatform.android,
        controller: controller,
        child: const SizedBox(),
      ),
    );
    await tester.pump();

    expect(modes, [SystemUiMode.immersiveSticky]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(modes, [SystemUiMode.immersiveSticky, SystemUiMode.edgeToEdge]);
  });

  testWidgets('iOS uses the mobile immersive lifecycle', (tester) async {
    final modes = <SystemUiMode>[];

    await tester.pumpWidget(
      DuelImmersiveMode(
        platform: DuelPlatform.ios,
        controller: DuelSystemUiController(
          setter: (mode) async => modes.add(mode),
        ),
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(modes, [SystemUiMode.immersiveSticky, SystemUiMode.edgeToEdge]);
  });

  for (final platform in [
    DuelPlatform.web,
    DuelPlatform.windows,
    DuelPlatform.macos,
    DuelPlatform.linux,
  ]) {
    testWidgets('$platform does not change system UI mode', (tester) async {
      final modes = <SystemUiMode>[];

      await tester.pumpWidget(
        DuelImmersiveMode(
          platform: platform,
          controller: DuelSystemUiController(
            setter: (mode) async => modes.add(mode),
          ),
          child: const SizedBox(),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(modes, isEmpty);
    });
  }

  testWidgets('a new enter supersedes a queued edge-to-edge restore', (
    tester,
  ) async {
    final modes = <SystemUiMode>[];
    final completions = <Completer<void>>[];
    final controller = DuelSystemUiController(
      setter: (mode) {
        modes.add(mode);
        final completion = Completer<void>();
        completions.add(completion);
        return completion.future;
      },
    );

    await tester.pumpWidget(
      DuelImmersiveMode(
        key: const ValueKey('first-room'),
        platform: DuelPlatform.android,
        controller: controller,
        child: const SizedBox(),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      DuelImmersiveMode(
        key: const ValueKey('second-room'),
        platform: DuelPlatform.android,
        controller: controller,
        child: const SizedBox(),
      ),
    );
    await tester.pump();

    expect(modes, [SystemUiMode.immersiveSticky]);

    completions[0].complete();
    await tester.pump();
    expect(modes, [SystemUiMode.immersiveSticky]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(modes, [SystemUiMode.immersiveSticky, SystemUiMode.edgeToEdge]);

    completions[1].complete();
  });

  testWidgets('controller updates transfer the active lease', (tester) async {
    final firstModes = <SystemUiMode>[];
    final secondModes = <SystemUiMode>[];
    final first = DuelSystemUiController(
      setter: (mode) async => firstModes.add(mode),
    );
    final second = DuelSystemUiController(
      setter: (mode) async => secondModes.add(mode),
    );

    await tester.pumpWidget(
      DuelImmersiveMode(
        platform: DuelPlatform.android,
        controller: first,
        child: const SizedBox(),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      DuelImmersiveMode(
        platform: DuelPlatform.android,
        controller: second,
        child: const SizedBox(),
      ),
    );
    await tester.pump();

    expect(firstModes, [SystemUiMode.immersiveSticky, SystemUiMode.edgeToEdge]);
    expect(secondModes, [SystemUiMode.immersiveSticky]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(secondModes, [
      SystemUiMode.immersiveSticky,
      SystemUiMode.edgeToEdge,
    ]);
  });

  testWidgets('platform updates acquire and release the active lease', (
    tester,
  ) async {
    final modes = <SystemUiMode>[];
    final controller = DuelSystemUiController(
      setter: (mode) async => modes.add(mode),
    );

    await tester.pumpWidget(
      DuelImmersiveMode(
        platform: DuelPlatform.windows,
        controller: controller,
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(
      DuelImmersiveMode(
        platform: DuelPlatform.android,
        controller: controller,
        child: const SizedBox(),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      DuelImmersiveMode(
        platform: DuelPlatform.windows,
        controller: controller,
        child: const SizedBox(),
      ),
    );
    await tester.pump();

    expect(modes, [SystemUiMode.immersiveSticky, SystemUiMode.edgeToEdge]);
  });
}
