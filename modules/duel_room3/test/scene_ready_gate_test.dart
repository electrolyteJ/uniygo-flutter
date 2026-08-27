/// 场景就绪闸（SceneReadyGate）单测（B1 回归）。
///
/// 背景：onLoad 完成前 game 的 zoneGrid/standees/effects 是未初始化
/// late 字段，进房瞬间 MSG_START/MSG_UPDATE_DATA 驱动的桥接调用必现
/// LateError。闸的语义：快照类缓存最新一帧待就绪后重放，事件类丢弃。
///（Duel3DGame 本体构造即要 GPU，测试环境不可达——闸抽成纯 Dart
/// 类承载全部关键语义。）
library;

import 'package:duel_room3/bridge/duel_3d_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SceneReadyGate', () {
    test('未就绪：快照缓存最新一帧，事件丢弃', () {
      final gate = SceneReadyGate<String>();
      expect(gate.isReady, isFalse);

      expect(gate.offerSnapshot('s1'), isFalse); // 缓存
      expect(gate.offerSnapshot('s2'), isFalse); // 覆盖旧帧
      expect(gate.offerEvent(), isFalse); // 事件丢弃

      expect(gate.markReadyAndTakePending(), 's2'); // 只回放最新帧
      expect(gate.isReady, isTrue);
    });

    test('就绪后：快照直通，不再缓存', () {
      final gate = SceneReadyGate<String>();
      gate.markReadyAndTakePending();
      expect(gate.offerSnapshot('s3'), isTrue);
      expect(gate.offerEvent(), isTrue);
    });

    test('就绪前无快照：markReady 返回 null', () {
      final gate = SceneReadyGate<String>();
      expect(gate.markReadyAndTakePending(), isNull);
    });

    test('reset 复位（detach 语义）', () {
      final gate = SceneReadyGate<String>();
      gate.offerSnapshot('s1');
      gate.markReadyAndTakePending();
      gate.reset();
      expect(gate.isReady, isFalse);
      expect(gate.offerSnapshot('s4'), isFalse);
    });
  });
}
