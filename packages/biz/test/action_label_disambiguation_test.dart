/// 特殊召唤动作标签消歧测试。
///
/// 引擎对一张卡（如坏兽）注册多个特召规则时，会下发多个「特殊召唤」选项，
/// 但协议里不带特召去向，导致菜单出现多个一模一样的条目。
/// [disambiguateActionLabels] 应按去向/序号为它们生成可区分的标签。
library;

import 'package:biz/duel/field/duel_field_derived.dart';
import 'package:biz/duel/models/playmat_resolved_action.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/card_info.dart' as pkg;

void main() {
  PlaymatResolvedAction sp(int response) => PlaymatResolvedAction(
        label: '特殊召唤（己方）',
        response: response,
        kind: PlaymatResolvedActionKind.specialSummon,
      );

  // 坏星坏兽 基兹基尔（Kaiju，setcode 低 16 位 0xd3）。
  final kaiju = pkg.CardInfo(code: 63941210, type: 0x1, setcode: const [0xd3]);
  // 非坏兽的普通怪兽。
  final nonKaiju = pkg.CardInfo(code: 12345678, type: 0x1, setcode: const [0x42]);

  test('坏兽两个特召选项按去向区分', () {
    final labels = disambiguateActionLabels([sp(0), sp(1)], kaiju);
    expect(labels, ['特殊召唤（到对方场上）', '特殊召唤（到自己场上）']);
  });

  test('非坏兽多个特召选项按序号区分', () {
    final labels = disambiguateActionLabels([sp(0), sp(1)], nonKaiju);
    expect(labels, ['特殊召唤（方式1）', '特殊召唤（方式2）']);
  });

  test('单个特召选项保持不变', () {
    final labels = disambiguateActionLabels([sp(0)], kaiju);
    expect(labels, ['特殊召唤（己方）']);
  });

  test('混合动作时只消歧特召项', () {
    final actions = [
      sp(0),
      PlaymatResolvedAction(
        label: '发动',
        response: 1,
        kind: PlaymatResolvedActionKind.activate,
      ),
      sp(2),
    ];
    final labels = disambiguateActionLabels(actions, kaiju);
    expect(labels, [
      '特殊召唤（到对方场上）',
      '发动',
      '特殊召唤（到自己场上）',
    ]);
  });
}
