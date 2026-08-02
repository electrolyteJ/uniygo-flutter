import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/config/servers.dart';
import 'package:uniygopro/widgets/create_room/env_selector.dart';

void main() {
  testWidgets('EnvSelector fits narrow row width without overflow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            child: EnvSelector(
              value: DuelEnvironment.koishi_preRelease,
              onChanged: _noopOnChanged,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

void _noopOnChanged(DuelEnvironment _) {}
