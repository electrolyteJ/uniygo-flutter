import 'dart:typed_data';

import 'package:ocgcore/ocgcore.dart';

/// 场态查询抽象 —— ygo-agent 输入构建器所需的最小引擎查询面。
///
/// 与 [DuelEngine] 解耦，便于测试中用假实现注入构造好的记录字节流。
abstract interface class AgentFieldQuery {
  /// 指定玩家区域中的卡牌数量（ocgcore `query_field_count`）。
  int fieldCount(int player, int location);

  /// 指定玩家区域中全部卡牌的查询记录字节流（ocgcore `query_field_card`），
  /// 记录格式见 [parseFieldCards]。
  Uint8List fieldCards(int player, int location, int queryFlag);
}

/// 基于 [DuelEngine] 的 [AgentFieldQuery] 实现。
class DuelEngineFieldQuery implements AgentFieldQuery {
  DuelEngineFieldQuery(this._engine);

  final DuelEngine _engine;

  @override
  int fieldCount(int player, int location) =>
      _engine.queryFieldCount(player, location);

  @override
  Uint8List fieldCards(int player, int location, int queryFlag) =>
      _engine.queryFieldCard(player, location, queryFlag);
}
