import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:duelink_ai/ai_strategy.dart';
import 'package:duelink_ai/duelink_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocgcore/ocgcore.dart' show DuelEngine, ScriptLoader;
import 'package:resource_data/card_info.dart';

/// 与 ai_duel_test.dart 相同的 harness。
ffi.DynamicLibrary? _loadCoreLib() {
  if (Platform.isMacOS) {
    for (final p in [
      '../ocgcore/macos/Frameworks/libocgcore.dylib',
      'packages/ocgcore/macos/Frameworks/libocgcore.dylib',
      'macos/Frameworks/libocgcore.dylib',
    ]) {
      try {
        return ffi.DynamicLibrary.open(p);
      } catch (_) {}
    }
  }
  return null;
}

class _FileScriptLoader extends ScriptLoader {
  static const _roots = [
    'packages/ocgcore/vendor/scripts/',
    '../ocgcore/vendor/scripts/',
  ];

  final _fsCache = <String, Uint8List>{};

  @override
  Future<Uint8List?> load(String name) async {
    final cached = _fsCache[name];
    if (cached != null) return cached;
    for (final root in _roots) {
      final file = File('$root$name');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        _fsCache[name] = bytes;
        return bytes;
      }
    }
    return super.load(name);
  }
}

CardInfo _mon(int code, int level, int atk, int def) => CardInfo(
      code: code,
      type: 0x11,
      level: level,
      attribute: 0x01,
      race: 0x1,
      attack: atk,
      defense: def,
      name: 'card-$code',
    );

void main() {
  test(
    'AI 应答被引擎拒绝（MSG_RETRY）时恢复重答而非死锁',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      final cardInfos = <int, CardInfo>{
        91152256: _mon(91152256, 4, 1400, 1200),
        76184692: _mon(76184692, 4, 1200, 1000),
        13039848: _mon(13039848, 3, 1300, 2000),
        15025844: _mon(15025844, 4, 800, 2000),
        88819587: _mon(88819587, 4, 1200, 700),
      };
      final deck = <int>[
        91152256, 76184692, 13039848, 15025844, 88819587,
        91152256, 76184692, 13039848, 15025844, 88819587,
        91152256, 76184692, 13039848, 15025844, 88819587,
        91152256, 76184692, 13039848, 15025844, 88819587,
      ];

      final emitted = <Uint8List>[];
      final engine = DuelEngine(
        emit: emitted.add,
        splitMessages: splitGameMessages,
        scriptLoader: _FileScriptLoader(),
      );
      final loader = CardDataLoader(
        cardConverter: (code) async => cardInfos[code],
      );
      engine.setCardReader(loader.load);
      final ruleAnswer = aiAutoAnswer(loader.levelOf);

      // 第一次 AI 应答故意给出非法响应（chain 窗口 0 选项时答 index 5，
      // 引擎校验 5 >= 0 → MSG_RETRY），之后全部正常应答。
      var firstAnswer = true;
      var retryCount = 0;
      engine.setAutoAnswer((func, payload) {
        if (firstAnswer && func == MSG_SELECT_CHAIN) {
          firstAnswer = false;
          return CtosGameMsgResponse.selectSingle(5).encode(); // 非法
        }
        if (func == MSG_SELECT_CHAIN && !firstAnswer) retryCount++;
        return ruleAnswer(func, payload);
      });

      expect(await engine.init(_loadCoreLib()), isTrue);
      final info = await engine.startDuel(deck, simpleAi: false);
      expect(info, isNotNull);
      await engine.pump();

      // 人类（player 0）结束回合 → 引擎应把连锁窗发给 AI（player 1）。
      for (var step = 0; step < 20; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (emitted.any((m) => m[0] == MSG_SELECT_IDLE_CMD && m[1] == 0)) {
          await engine.onResponse(
            CtosGameMsgResponse.selectIdleCmd(7).encode(),
          );
          break;
        }
      }

      // 等待对局推进到 AI 的主阶段（func 11 player 1）。修复前：
      // 非法应答触发 MSG_RETRY 后 pending 已清、pump 退出 → 永远等不到。
      var aiTurnSeen = false;
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        // 顺带应答人类的空连锁窗（func 16 player 0）
        if (emitted.any((m) => m[0] == MSG_SELECT_CHAIN && m[1] == 0)) {
          await engine.onResponse(
            CtosGameMsgResponse.selectSingle(-1).encode(),
          );
        }
        if (emitted.any((m) => m[0] == MSG_SELECT_IDLE_CMD && m[1] == 1)) {
          aiTurnSeen = true;
          break;
        }
      }
      expect(
        aiTurnSeen,
        isTrue,
        reason: 'AI 非法应答触发 MSG_RETRY 后应对局继续推进到 AI 主阶段',
      );
      expect(retryCount, greaterThanOrEqualTo(1), reason: '应发生了重答');
    },
  );
}
