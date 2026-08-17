/// [AgentAutoAnswer] 测试：假模型（受控概率队列）+ 假场态查询，
/// 验证各消息的应答字节格式、多选驱动（select_card/tribute/sum）、
/// 完整响应空间 argmax、历史动作 threading 与规则 AI 回退。
library;

import 'dart:typed_data';

import 'package:duelink/duelink.dart' show BufferReader, BufferWriter;
import 'package:duelink_ai_ygo_agent_tflite/duelink_ai_ygo_agent_tflite.dart';
import 'package:duelink_ai_ygo_agent/duelink_ai_ygo_agent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocgcore/ocgcore.dart';

// ───────────────────────── 假模型 ─────────────────────────

/// 按队列依次返回 probs 的受控模型；记录每次推理的 [ModelInput]。
class FakeModel {
  FakeModel(List<List<double>> probQueue) : _queue = probQueue;

  final List<List<double>> _queue;
  final inputs = <ModelInput>[];
  int calls = 0;

  ModelOutput call(RState rstate, ModelInput input) {
    inputs.add(input);
    final probs = _queue[calls];
    calls++;
    return ModelOutput(
      rstate: initRstate(),
      probs: probs,
      value: 0.0,
    );
  }
}

// ───────────────────────── 假场态 ─────────────────────────

Uint8List cardRecord({
  required int code,
  required int controller,
  required int location,
  required int sequence,
  required int position,
  int level = 0,
  int attack = 0,
  int defense = 0,
}) {
  final inner = BufferWriter();
  inner.writeUint32(code);
  inner.writeUint8(controller);
  inner.writeUint8(location);
  inner.writeUint8(sequence);
  inner.writeUint8(position);
  inner.writeUint32(level);
  inner.writeUint32(0); // rank
  inner.writeInt32(attack);
  inner.writeInt32(defense);
  inner.writeUint32(0); // status

  final w = BufferWriter();
  final bytes = inner.toBytes();
  w.writeUint32(8 + bytes.length);
  w.writeUint32(
    QUERY_CODE |
        QUERY_POSITION |
        QUERY_LEVEL |
        QUERY_RANK |
        QUERY_ATTACK |
        QUERY_DEFENSE |
        QUERY_STATUS,
  );
  w.writeBytes(bytes);
  return w.toBytes();
}

class FakeField implements AgentFieldQuery {
  final Map<(int, int), Uint8List> buffers = {};

  void put(int player, int location, Uint8List buffer) {
    buffers[(player, location)] = buffer;
  }

  void clear() => buffers.clear();

  @override
  int fieldCount(int player, int location) => 0;

  @override
  Uint8List fieldCards(int player, int location, int queryFlag) =>
      buffers[(player, location)] ?? Uint8List(0);
}

// ───────────────────────── 载荷构造 ─────────────────────────

Uint8List idleCmdPayload() {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint8(1); // summon ×1
  w.writeUint32(100);
  w.writeUint8(1);
  w.writeUint8(LOCATION_MZONE);
  w.writeUint8(2);
  for (var i = 0; i < 5; i++) {
    w.writeUint8(0); // sp_summon/repos/mset/set/activate 计数
  }
  w.writeUint8(1); // to_bp
  w.writeUint8(0); // to_ep
  w.writeUint8(1); // can_shuffle
  return w.toBytes();
}

Uint8List selectCardPayload({int min = 1, int max = 2, int count = 3}) {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint8(0); // cancelable
  w.writeUint8(min);
  w.writeUint8(max);
  w.writeUint8(count);
  for (var i = 0; i < count; i++) {
    w.writeUint32(500 + i);
    w.writeUint8(1);
    w.writeUint8(LOCATION_MZONE);
    w.writeUint8(i);
    w.writeUint8(POS_FACEUP_ATTACK);
  }
  return w.toBytes();
}

Uint8List tributePayload() {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint8(0); // cancelable
  w.writeUint8(2); // min
  w.writeUint8(2); // max
  w.writeUint8(3); // count
  for (var i = 0; i < 3; i++) {
    w.writeUint32(600 + i);
    w.writeUint8(1);
    w.writeUint8(LOCATION_MZONE);
    w.writeUint8(i);
    w.writeUint8(1); // release_param
  }
  return w.toBytes();
}

Uint8List sumPayload() {
  final w = BufferWriter();
  w.writeUint8(0); // mode → 非 overflow
  w.writeUint8(1); // player
  w.writeInt32(4); // level sum
  w.writeUint8(1); // min
  w.writeUint8(2); // max
  w.writeUint8(0); // must count
  w.writeUint8(3); // selectable count：level1 = 4 / 2 / 2
  final levels = [4, 2, 2];
  for (var i = 0; i < 3; i++) {
    w.writeUint32(800 + i);
    w.writeUint8(1);
    w.writeUint8(LOCATION_MZONE);
    w.writeUint8(i);
    w.writeUint32(levels[i]);
  }
  return w.toBytes();
}

Uint8List unselectPayload({required bool finishable, int selectable = 2}) {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint8(finishable ? 1 : 0);
  w.writeUint8(0); // cancelable
  w.writeUint8(1); // min
  w.writeUint8(1); // max
  w.writeUint8(selectable);
  for (var i = 0; i < selectable; i++) {
    w.writeUint32(700 + i);
    w.writeUint8(1);
    w.writeUint8(LOCATION_HAND);
    w.writeUint8(i);
    w.writeUint8(POS_FACEDOWN);
  }
  w.writeUint8(0); // selected count
  return w.toBytes();
}

Uint8List chainPayload() {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint8(1); // size
  w.writeUint8(0); // spe_count
  w.writeUint32(0); // hint0
  w.writeUint32(0); // hint1
  w.writeUint8(1); // c（我方）
  w.writeUint8(0); // 非强制
  w.writeUint32(400);
  w.writeUint8(1);
  w.writeUint8(LOCATION_SZONE);
  w.writeUint8(0);
  w.writeUint8(POS_FACEUP);
  w.writeUint32(31); // desc
  return w.toBytes();
}

Uint8List placePayload() {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint8(0); // count → 1
  // byte0 我方怪兽区 bit0 清除（m1）；byte2 对方怪兽区 bit2 清除（om3）
  final flag = 0xfe | (0xff << 8) | (0xfb << 16) | (0xff << 24);
  w.writeUint32(flag);
  return w.toBytes();
}

Uint8List effectYnPayload() {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint32(950);
  w.writeUint8(1);
  w.writeUint8(LOCATION_MZONE);
  w.writeUint8(0);
  w.writeUint8(POS_FACEUP);
  w.writeUint32((950 << 4) | 1); // desc = 卡牌效果（code<<4|idx）
  return w.toBytes();
}

Uint8List counterPayload() {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint16(1); // counter type
  w.writeUint16(4); // total
  w.writeUint8(2); // count
  w.writeUint32(101); // cap 3
  w.writeUint8(1);
  w.writeUint8(LOCATION_MZONE);
  w.writeUint8(0);
  w.writeUint16(3);
  w.writeUint32(102); // cap 5
  w.writeUint8(1);
  w.writeUint8(LOCATION_MZONE);
  w.writeUint8(1);
  w.writeUint16(5);
  return w.toBytes();
}

Uint8List racePayload() {
  final w = BufferWriter();
  w.writeUint8(1); // player
  w.writeUint8(1); // count
  w.writeUint32((1 << 5) | (1 << 2)); // available
  return w.toBytes();
}

// ───────────────────────── 装配 ─────────────────────────

/// 码表外的卡号 999 刻意不包含。
CodeList testCodeList() => CodeList.parse([
      for (var c = 100; c <= 102; c++) c,
      200, 201, 300, 301, 400,
      for (var c = 500; c <= 502; c++) c,
      for (var c = 600; c <= 602; c++) c,
      700, 701, 710,
      for (var c = 800; c <= 802; c++) c,
      900, 950,
    ].join('\n'));

class Harness {
  Harness(this.model, {int startLp = 8000}) {
    field = FakeField();
    autoAnswer = AgentAutoAnswer(
      runtime: AgentRuntime(modelFn: model.call, codeList: testCodeList()),
      field: field,
      startLp: startLp,
    );
  }

  final FakeModel model;
  late final FakeField field;
  late final AgentAutoAnswer autoAnswer;
}

int int32Of(Uint8List bytes) => BufferReader(bytes).readInt32();

void main() {
  group('AgentAutoAnswer 单步消息', () {
    test('idlecmd：argmax 选 to_bp → int32 6', () {
      final h = Harness(FakeModel([
        [0.3, 0.7], // summon, to_bp
      ]));
      final resp = h.autoAnswer.answer(MSG_SELECT_IDLECMD, idleCmdPayload());
      expect(int32Of(resp!), 6);
      expect(h.model.calls, 1);
    });

    test('effectyn / yesno / option / position：int32 = response', () {
      final h = Harness(FakeModel([
        [0.9, 0.1], // effectyn: yes(1), no(0)
        [0.2, 0.8], // yesno: yes(1), no(0)
        [0.1, 0.2, 0.7], // option: 3 项
        [0.3, 0.7], // position: faceupAttack, faceupDefense
      ]));

      expect(int32Of(h.autoAnswer.answer(MSG_SELECT_EFFECTYN,
          effectYnPayload())!), 1);

      final yesNo = BufferWriter()
        ..writeUint8(1)
        ..writeUint32((950 << 4) | 0);
      expect(
          int32Of(
              h.autoAnswer.answer(MSG_SELECT_YESNO, yesNo.toBytes())!),
          0);

      final opt = BufferWriter()
        ..writeUint8(1)
        ..writeUint8(3)
        ..writeUint32((950 << 4) | 0)
        ..writeUint32((950 << 4) | 1)
        ..writeUint32((950 << 4) | 2);
      expect(
          int32Of(
              h.autoAnswer.answer(MSG_SELECT_OPTION, opt.toBytes())!),
          2);

      final pos = BufferWriter()
        ..writeUint8(1)
        ..writeUint32(900)
        ..writeUint8(0x5);
      expect(
          int32Of(
              h.autoAnswer.answer(MSG_SELECT_POSITION, pos.toBytes())!),
          POS_FACEUP_DEFENSE);
      expect(h.model.calls, 4);
    });

    test('chain：非强制时 cancel → int32 -1', () {
      final h = Harness(FakeModel([
        [0.3, 0.7], // chain0, cancel
      ]));
      final resp = h.autoAnswer.answer(MSG_SELECT_CHAIN, chainPayload());
      expect(int32Of(resp!), -1);
    });

    test('place：对方区域 plr = 1 - player', () {
      final h = Harness(FakeModel([
        [0.2, 0.8], // m1, om3
      ]));
      final resp = h.autoAnswer.answer(MSG_SELECT_PLACE, placePayload())!;
      expect(resp, [0, LOCATION_MZONE, 2]); // player=1 → plr 0，om3 → seq 2
    });

    test('unselect：finish → int32 -1；选卡 → [1][idx]', () {
      final h = Harness(FakeModel([
        [0.1, 0.1, 0.8], // card0, card1, finish
        [0.2, 0.8], // card0, card1（无 finish）
      ]));
      expect(
        int32Of(h.autoAnswer.answer(
            MSG_SELECT_UNSELECT_CARD, unselectPayload(finishable: true))!),
        -1,
      );
      final resp = h.autoAnswer.answer(
          MSG_SELECT_UNSELECT_CARD, unselectPayload(finishable: false))!;
      expect(resp, [1, 1]);
    });
  });

  group('AgentAutoAnswer 多选驱动', () {
    test('select_card：完整响应空间 argmax + finish 槽 + 历史 threading', () {
      final h = Harness(FakeModel([
        // step1：3 卡无 finish → recordedProbs [0.1, 0.7, 0.2, -1]
        [0.1, 0.7, 0.2],
        // step2：card0/card2/finish → 插入后 [0.05, -1, 0.10, 0.85]
        [0.05, 0.10, 0.85],
      ]));
      final resp =
          h.autoAnswer.answer(MSG_SELECT_CARD, selectCardPayload())!;
      expect(resp, [1, 1]); // 选卡 1 后 finish
      expect(h.model.calls, 2);
      // 第二次推理的 h_actions 必须已写入第一步的动作（历史 threading）
      expect(h.model.inputs[0].hActions.every((b) => b == 0), isTrue);
      expect(h.model.inputs[1].hActions.any((b) => b != 0), isTrue);
    });

    test('select_card：max 强制结束（不请求多余推理）', () {
      final h = Harness(FakeModel([
        [0.6, 0.3, 0.1], // step1 → 卡 0
        [0.2, 0.8], // step2：卡 1/卡 2（finish 非法：1 < min=2）→ 卡 2
      ]));
      final resp = h.autoAnswer.answer(
          MSG_SELECT_CARD, selectCardPayload(min: 2, max: 2))!;
      expect(resp, [2, 0, 2]);
      expect(h.model.calls, 2);
    });

    test('tribute：release_param=1 双祭品', () {
      final h = Harness(FakeModel([
        [0.6, 0.3, 0.1], // step1 → 卡 0
        [0.2, 0.8], // step2：卡 1/卡 2 → 卡 2，达 max 强制结束
      ]));
      final resp = h.autoAnswer.answer(MSG_SELECT_TRIBUTE, tributePayload())!;
      expect(resp, [2, 0, 2]);
    });

    test('select_sum：沿 canFinish 结束，应答 [n][idx...]', () {
      final h = Harness(FakeModel([
        // 组合：{0}（level4）与 {1,2}（2+2）。argmax 选卡 1（canFinish=false）。
        [0.1, 0.8, 0.1],
        // step2：唯一动作卡 2（canFinish=true）→ nActions==1 捷径，不调模型。
      ]));
      final resp = h.autoAnswer.answer(MSG_SELECT_SUM, sumPayload())!;
      expect(resp, [2, 1, 2]); // must=0，n=2
      expect(h.model.calls, 1);
    });
  });

  group('AgentAutoAnswer 非模型消息', () {
    test('sort_card：保持原序哨兵 0xff', () {
      final h = Harness(FakeModel([]));
      final resp = h.autoAnswer.answer(
          MSG_SORT_CARD, Uint8List.fromList([1, 2, 0, 0, 0, 0]))!;
      expect(resp, [0xff]);
      expect(h.model.calls, 0);
    });

    test('counter：贪心分配 int16，和 == total', () {
      final h = Harness(FakeModel([]));
      final resp = h.autoAnswer.answer(MSG_SELECT_COUNTER, counterPayload())!;
      final r = BufferReader(resp);
      expect(r.readInt16(), 3); // cap 3 放满
      expect(r.readInt16(), 1); // 剩余 1
    });

    test('announce_race：取 available 中前 count 个位', () {
      final h = Harness(FakeModel([]));
      final resp = h.autoAnswer.answer(MSG_ANNOUNCE_RACE, racePayload())!;
      expect(int32Of(resp), 1 << 2);
    });
  });

  group('AgentAutoAnswer 不支持处理', () {
    test('不支持的形状打日志并返回 null：select_card min=0 / announce_card',
        () {
      final h = Harness(FakeModel([]));
      expect(
        h.autoAnswer.answer(
            MSG_SELECT_CARD, selectCardPayload(min: 0, max: 1)),
        isNull,
      );
      expect(
        h.autoAnswer.answer(MSG_ANNOUNCE_CARD, Uint8List.fromList([1, 1])),
        isNull,
      );
      expect(h.model.calls, 0);
    });

    test('码表外卡号返回 null，且不污染模型状态（下一条仍走模型）', () {
      final h = Harness(FakeModel([
        [0.9, 0.1], // 回退后的下一条 effectyn 由模型应答
      ]));
      h.field.put(
        1,
        LOCATION_MZONE,
        cardRecord(
          code: 999, // 不在码表
          controller: 1,
          location: LOCATION_MZONE,
          sequence: 0,
          position: POS_FACEUP_ATTACK,
        ),
      );
      expect(
        h.autoAnswer.answer(MSG_SELECT_EFFECTYN, effectYnPayload()),
        isNull,
      );
      expect(h.model.calls, 0);

      // 清除码表外卡后，模型恢复正常应答。
      h.field.clear();
      expect(
        int32Of(h.autoAnswer.answer(MSG_SELECT_EFFECTYN, effectYnPayload())!),
        1,
      );
      expect(h.model.calls, 1);
    });
  });
}
