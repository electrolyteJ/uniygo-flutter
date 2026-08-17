/// 场态 → ygo-agent [Input] 构建器 —— env（ygopro.h）观测构建语义的移植。
///
/// 等价于 env `_set_obs_cards` + `_set_obs_card_` + `get_legal_actions` 中
/// 组装 `Input` 的部分：
///  - 玩家遍历顺序 `(toPlay + pi) % 2`（pi = 0, 1），pi==1 为对手；
///  - 区域配置 [DECK 隐藏, HAND 隐藏, MZONE 公开, SZONE 公开, GRAVE 公开,
///    REMOVED 公开, EXTRA 隐藏]；
///  - 区域级隐藏：对手视角且 `revealed_` 为空时，隐藏区域只写
///    `fieldCount` 个占位行（code=0、位置特征全 0），对应 encodeCard 产出
///    "只有 location id + controller=对手" 的行；
///  - 单卡级隐藏：对手的里侧表示卡（且不在 revealed_ 中）写 code=0 的
///    暗牌行（保留真实 location/sequence/controller/position）。
///
/// [CodeList] 外的卡号会在 [features.encodeCards] 处抛错（与上游 Python
/// `get_code_id` 行为一致），集成层捕获后回退规则 AI。
library;

import 'dart:typed_data';

import 'package:ocgcore/ocgcore.dart';
import '../code_list.dart';
import '../enums.dart';
import '../legal_actions.dart';
import '../models.dart';

import 'action_msg_decoder.dart';
import 'duel_field_tracker.dart';
import 'field_query.dart';
import 'raw_field_cards.dart';
import 'raw_maps.dart';

/// env `_set_obs_cards` 使用的查询标志（ygopro.h :2421 附近）：
/// 不含 TYPE/ATTRIBUTE/RACE —— 那些字段走 DB（`c_get_card`）。
/// 这里额外带上 TYPE/ATTRIBUTE/RACE 以便 [cardData] 缺失时兜底，
/// 正常路径下它们不参与编码。
const int _envQueryFlags = QUERY_CODE |
    QUERY_POSITION |
    QUERY_LEVEL |
    QUERY_RANK |
    QUERY_ATTACK |
    QUERY_DEFENSE |
    QUERY_EQUIP_CARD |
    QUERY_OVERLAY_CARD |
    QUERY_COUNTERS |
    QUERY_STATUS |
    QUERY_LSCALE |
    QUERY_RSCALE |
    QUERY_LINK |
    QUERY_TYPE |
    QUERY_ATTRIBUTE |
    QUERY_RACE;

/// env 视为"已失效"的状态位（obs 的 negated 列）。
const int _negatedStatusMask = STATUS_DISABLED | STATUS_FORBIDDEN;

/// 区域遍历配置（env `_set_obs_cards` 中的 (location, hidden) 列表）。
const List<(int, bool)> _zoneConfigs = [
  (LOCATION_DECK, true),
  (LOCATION_HAND, true),
  (LOCATION_MZONE, false),
  (LOCATION_SZONE, false),
  (LOCATION_GRAVE, false),
  (LOCATION_REMOVED, false),
  (LOCATION_EXTRA, true),
];

/// 从场态 + 待应答消息构建模型 [Input]。
class AgentInputBuilder {
  AgentInputBuilder({
    required AgentFieldQuery field,
    required DuelFieldTracker tracker,
    CardData? Function(int code)? cardData,
  })  : _field = field,
        _tracker = tracker,
        _cardData = cardData ?? _noCardData;

  final AgentFieldQuery _field;
  final DuelFieldTracker _tracker;
  final CardData? Function(int code) _cardData;

  static CardData? _noCardData(int code) => null;

  /// 构建 [Input]。
  ///
  /// [func]/[payload]：待应答消息（payload 不含 func 头字节）；
  /// [toPlay]：待应答玩家 id（引擎绝对坐标），同时作为模型"我方"视角。
  ///
  /// 对 env 不支持的消息形状抛 [NotSupportedException]。
  Input build({
    required int func,
    required Uint8List payload,
    required int toPlay,
  }) {
    final msg = decodeAgentActionMsg(func, payload);
    final cards = _buildCards(toPlay);
    final global = _buildGlobal(toPlay);
    return Input(
      global: global,
      cards: cards,
      actionMsg: ActionMsg(data: msg.data),
    );
  }

  // ── 卡牌列表（env `_set_obs_cards` 语义） ───────────────────────────

  List<Card> _buildCards(int toPlay) {
    final cards = <Card>[];
    for (var pi = 0; pi < 2; pi++) {
      final player = (toPlay + pi) % 2;
      final opponent = pi == 1;
      // env：对手视角且 revealed_ 非空时，原本隐藏的区域也逐卡观测
      // （hidden_for_opponent = false）。
      final zoneHiddenForOpponent = !(_tracker.revealed.isNotEmpty);
      for (final (loc, hiddenByDefault) in _zoneConfigs) {
        final hidden = opponent && hiddenByDefault && zoneHiddenForOpponent;
        if (hidden) {
          _appendHiddenZone(cards, player, loc);
        } else {
          _appendZone(cards, player, loc, opponent: opponent, toPlay: toPlay);
        }
      }
    }
    return cards;
  }

  /// 区域级隐藏：只写数量，不写任何卡面特征。
  ///
  /// env 写 n 行"col2=location id、col4=1，其余全 0"。占位 Card 经
  /// [encodeCard] 恰好产出同样的行：code=0 → 保留填充 id 0；
  /// controller=opponent → col4=1；position none → col5=0；
  /// 隐藏区域只会是 deck/hand/extra，encodeCard 对这些区域不写
  /// sequence 列，col3 保持 0。
  void _appendHiddenZone(List<Card> cards, int player, int loc) {
    final n = _field.fieldCount(player, loc);
    final location = locationFromRaw(loc);
    if (location == null) return;
    for (var i = 0; i < n; i++) {
      cards.add(_hiddenZoneCard(location));
    }
  }

  Card _hiddenZoneCard(Location location) => Card(
        code: 0,
        location: location,
        sequence: 0,
        controller: Controller.opponent,
        position: Position.none,
        overlaySequence: -1,
        attribute: Attribute.none,
        race: Race.none,
        level: 0,
        counter: 0,
        negated: false,
        attack: 0,
        defense: 0,
        types: const [],
      );

  /// 逐卡观测一个区域（env `get_cards_in_location` 记录解析 +
  /// `_set_obs_card_` 特征填充的移植）。
  void _appendZone(List<Card> cards, int player, int loc,
      {required bool opponent, required int toPlay}) {
    final buffer = _field.fieldCards(player, loc, _envQueryFlags);
    final location = locationFromRaw(loc);
    if (location == null) return;
    for (final raw in parseFieldCards(buffer)) {
      // env：素材先于宿主入列。
      for (var i = 0; i < raw.overlayCodes.length; i++) {
        cards.add(
            _materialCard(raw.overlayCodes[i], raw, location, i, toPlay));
      }
      cards.add(_hostCard(raw, location, opponent: opponent, toPlay: toPlay));
    }
  }

  /// XYZ 素材行（env `_set_obs_card_` overlay 分支）：
  /// 强制可见、position 列写 faceup id、overlay 列 = 1，其余特征来自
  /// 素材卡自身的 DB 数据（`c_get_card`）。
  Card _materialCard(int code, RawFieldCard host, Location hostLocation,
      int overlayIndex, int toPlay) {
    final data = _cardData(code);
    // env 的 DB 层恒存正数 level（`level & 0xff`）；本工程 CardData 对
    // XYZ 存负数，这里取绝对值对齐 env 语义（encodeCard 再 clamp 到 13）。
    return Card(
      code: code,
      location: hostLocation,
      sequence: host.sequence,
      controller: _controller(host.controller, toPlay),
      position: Position.none, // encodeCard 对 overlay 强制 faceup
      overlaySequence: overlayIndex,
      attribute:
          data != null ? attributeFromRaw(data.attribute) : Attribute.none,
      race: data != null ? raceFromRaw(data.race) : Race.none,
      level: data != null ? data.level.abs() : 0,
      counter: 0,
      negated: false,
      attack: data?.attack ?? 0,
      defense: data?.defense ?? 0,
      types: data != null ? typesFromRaw(data.type) : const [],
    );
  }

  /// 宿主卡行（env `_set_obs_card_` 常规分支 + 单卡隐藏）。
  Card _hostCard(RawFieldCard raw, Location location,
      {required bool opponent, required int toPlay}) {
    final controller = _controller(raw.controller, toPlay);
    // 单卡隐藏判定：对手视角 + 里侧表示 + 未被 CONFIRM_CARDS 公开。
    // spec 与 env 一致用迭代侧 opponent 标志（get_spec(opponent)）。
    final spec = DuelFieldTracker.lsToSpec(
        raw.location, raw.sequence, raw.position,
        opponent: opponent);
    final hide = opponent &&
        (raw.position & POS_FACEDOWN) != 0 &&
        !_tracker.revealed.contains(spec);
    if (hide) {
      // 暗牌行：保留真实位置信息，卡面特征全 0（code=0）。
      return Card(
        code: 0,
        location: location,
        sequence: raw.sequence,
        controller: controller,
        position: positionFromRaw(raw.position),
        overlaySequence: -1,
        attribute: Attribute.none,
        race: Race.none,
        level: 0,
        counter: 0,
        negated: false,
        attack: 0,
        defense: 0,
        types: const [],
      );
    }
    return _visibleCard(raw, location, controller);
  }

  Card _visibleCard(
      RawFieldCard raw, Location location, Controller controller) {
    // DB 优先（env `c_get_card` 语义：attribute/race/type/攻防来自 DB），
    // 查询结果兜底（DB 缺失时退而求其次，训练分布中不会出现）。
    final data = _cardData(raw.code);
    final attribute = data != null
        ? attributeFromRaw(data.attribute)
        : attributeFromRaw(raw.attribute);
    final race =
        data != null ? raceFromRaw(data.race) : raceFromRaw(raw.race);
    final types =
        data != null ? typesFromRaw(data.type) : typesFromRaw(raw.type);

    // env 的 level 链：QUERY_LEVEL → QUERY_RANK → QUERY_LINK，均只在
    // 低字节 > 0 时覆写。
    var level = data?.level ?? 0;
    if ((raw.level & 0xff) > 0) level = raw.level & 0xff;
    if ((raw.rank & 0xff) > 0) level = raw.rank & 0xff;
    if ((raw.link & 0xff) > 0) level = raw.link & 0xff;

    // env：link_marker > 0 时 defense 列写 link_marker。
    final defense = raw.linkMarker > 0 ? raw.linkMarker : raw.defense;

    return Card(
      code: raw.code,
      location: location,
      sequence: raw.sequence,
      controller: controller,
      position: positionFromRaw(raw.position),
      overlaySequence: -1,
      attribute: attribute,
      race: race,
      level: level,
      counter: raw.counter,
      negated: (raw.status & _negatedStatusMask) != 0,
      attack: raw.attack,
      defense: defense,
      types: types,
    );
  }

  /// env col4 语义：`(c.controler_ != to_play_) ? 1 : 0` —— 按应答玩家
  /// 相对化，而不是按绝对玩家 0。
  Controller _controller(int c, int toPlay) =>
      c == toPlay ? Controller.me : Controller.opponent;

  // ── 全局特征（env `_set_obs_global` 语义） ─────────────────────────

  Global _buildGlobal(int toPlay) => Global(
        myLp: _tracker.lp[toPlay],
        opLp: _tracker.lp[1 - toPlay],
        turn: _tracker.turn,
        phase: phaseFromRaw(_tracker.rawPhase) ?? Phase.draw,
        isFirst: toPlay == 0,
        isMyTurn: toPlay == _tracker.turnPlayer,
      );
}
