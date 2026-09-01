/// 组卡编辑器的核心规则（纯 Dart，可单测）。
///
/// 规则语义与 YGO 通用规则一致：
/// - 主卡组 40~60 张；额外/副卡组各 0~15 张
/// - 同一卡号在主+额外+副合计最多 3 张（禁限表 0/1/2 由 IBanlistService 另行校验）
/// - 融合/同调/超量/链接怪只能进额外卡组；魔法/陷阱只能进主/副卡组
library;

import 'package:resource_data/card_info.dart';
import 'package:resource_data/deck_info.dart';

/// 卡组分区。
enum DeckZone { main, extra, side }

/// 编辑中的卡组（可变结构，编辑器状态用）。
class DeckEditState {
  DeckEditState({
    this.name = '新卡组',
    List<DeckCard>? main,
    List<DeckCard>? extra,
    List<DeckCard>? side,
  })  : main = main ?? [],
        extra = extra ?? [],
        side = side ?? [];

  String name;
  final List<DeckCard> main;
  final List<DeckCard> extra;
  final List<DeckCard> side;

  List<DeckCard> zoneOf(DeckZone zone) => switch (zone) {
        DeckZone.main => main,
        DeckZone.extra => extra,
        DeckZone.side => side,
      };

  int zoneCount(DeckZone zone) =>
      zoneOf(zone).fold(0, (sum, c) => sum + c.count);

  /// 某卡号在全卡组（三区合计）的数量。
  int countOf(int code) =>
      (main + extra + side)
          .where((c) => c.code == code)
          .fold(0, (sum, c) => sum + c.count);

  DeckEditState copy() => DeckEditState(
        name: name,
        main: List.of(main),
        extra: List.of(extra),
        side: List.of(side),
      );

  /// 从持久化模型载入。
  factory DeckEditState.fromDeckInfo(DeckInfo deck) => DeckEditState(
        name: deck.deckName,
        main: List.of(deck.mainDeck),
        extra: List.of(deck.extraDeck),
        side: List.of(deck.sideDeck),
      );

  /// 导出为持久化模型。
  DeckInfo toDeckInfo() => DeckInfo(
        deckName: name,
        mainDeck: List.unmodifiable(main),
        extraDeck: List.unmodifiable(extra),
        sideDeck: List.unmodifiable(side),
      );
}

/// 加卡结果。
enum AddCardResult {
  ok,

  /// 同卡超过 3 张
  copyLimitExceeded,

  /// 目标区已满（主 60 / 额外 15 / 副 15）
  zoneFull,

  /// 卡类型不允许进该区（额外怪进主卡组等）
  wrongZone,
}

/// 该卡允许进入的分区。
Set<DeckZone> allowedZones(CardInfo info) {
  if (info.isFusion || info.isSynchro || info.isXyz || info.isLink) {
    return {DeckZone.extra};
  }
  // 怪兽/魔法/陷阱（含仪式/灵摆）主副皆可
  return {DeckZone.main, DeckZone.side};
}

/// 尝试加卡：校验规则，通过则原地修改 state 并返回 [AddCardResult.ok]。
AddCardResult tryAddCard(DeckEditState state, CardInfo info, DeckZone zone) {
  if (!allowedZones(info).contains(zone)) {
    return AddCardResult.wrongZone;
  }
  if (state.countOf(info.code) >= 3) {
    return AddCardResult.copyLimitExceeded;
  }
  final cap = switch (zone) {
    DeckZone.main => 60,
    DeckZone.extra || DeckZone.side => 15,
  };
  if (state.zoneCount(zone) >= cap) {
    return AddCardResult.zoneFull;
  }
  final cards = state.zoneOf(zone);
  final index = cards.indexWhere((c) => c.code == info.code);
  if (index >= 0) {
    cards[index] = DeckCard(code: info.code, count: cards[index].count + 1);
  } else {
    cards.add(DeckCard(code: info.code));
  }
  return AddCardResult.ok;
}

/// 减卡：目标区该卡 -1，减到 0 移除；不存在返回 false。
bool tryRemoveCard(DeckEditState state, int code, DeckZone zone) {
  final cards = state.zoneOf(zone);
  final index = cards.indexWhere((c) => c.code == code);
  if (index < 0) return false;
  final count = cards[index].count - 1;
  if (count <= 0) {
    cards.removeAt(index);
  } else {
    cards[index] = DeckCard(code: code, count: count);
  }
  return true;
}

/// 结构校验错误（禁限表之外的规则）。
List<String> structuralErrors(DeckEditState state) {
  final errors = <String>[];
  final main = state.zoneCount(DeckZone.main);
  if (main < 40) errors.add('主卡组不足 40 张（当前 $main 张）');
  if (main > 60) errors.add('主卡组超过 60 张（当前 $main 张）');
  if (state.zoneCount(DeckZone.extra) > 15) errors.add('额外卡组超过 15 张');
  if (state.zoneCount(DeckZone.side) > 15) errors.add('副卡组超过 15 张');
  return errors;
}
