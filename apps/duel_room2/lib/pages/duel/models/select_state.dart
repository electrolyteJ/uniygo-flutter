const Object _selectStateKeep = Object();

class SelectState {
  final SelectType type;
  final int player;
  final List<SelectOption> options;
  final int min;
  final int max;
  final bool cancelable;
  final bool finishable;
  final bool immediateSingleToggle;
  final List<int> initialSelectedIndices;
  final int? effectDescription;

  /// 窗口序号：每开一个新选择窗口自增。UI 渲染时记下该值，
  /// 回包时原样带回，服务端窗口已更换后到达的陈旧响应会被丢弃。
  final int generation;

  /// MSG_SELECT_SUM 的必选段（must_select_cards）。
  /// 回包时占位用，不参与勾选；[options] 只含可选段。
  final List<SelectOption> mustOptions;

  /// MSG_SELECT_SUM 目标合计（msg.levelSum，引擎 acc）。
  final int sumTarget;

  /// MSG_SELECT_SUM 精确合计模式（msg.max == 0）：无数量上限，
  /// 可行性按引擎 `mx >= acc && sum - mn < acc` 窗口判定。
  final bool sumExact;

  /// MSG_SELECT_COUNTER 需移除的指示物总数（msg.min）。
  final int counterRequired;

  const SelectState({
    required this.type,
    required this.player,
    this.options = const [],
    this.min = 1,
    this.max = 1,
    this.cancelable = false,
    this.finishable = false,
    this.immediateSingleToggle = false,
    this.initialSelectedIndices = const [],
    this.effectDescription,
    this.generation = 0,
    this.mustOptions = const [],
    this.sumTarget = 0,
    this.sumExact = false,
    this.counterRequired = 0,
  });

  SelectState copyWith({
    SelectType? type,
    int? player,
    List<SelectOption>? options,
    int? min,
    int? max,
    bool? cancelable,
    bool? finishable,
    bool? immediateSingleToggle,
    List<int>? initialSelectedIndices,
    Object? effectDescription = _selectStateKeep,
    int? generation,
    List<SelectOption>? mustOptions,
    int? sumTarget,
    bool? sumExact,
    int? counterRequired,
  }) {
    return SelectState(
      type: type ?? this.type,
      player: player ?? this.player,
      options: options ?? this.options,
      min: min ?? this.min,
      max: max ?? this.max,
      cancelable: cancelable ?? this.cancelable,
      finishable: finishable ?? this.finishable,
      immediateSingleToggle:
          immediateSingleToggle ?? this.immediateSingleToggle,
      initialSelectedIndices:
          initialSelectedIndices ?? this.initialSelectedIndices,
      effectDescription: identical(effectDescription, _selectStateKeep)
          ? this.effectDescription
          : effectDescription as int?,
      generation: generation ?? this.generation,
      mustOptions: mustOptions ?? this.mustOptions,
      sumTarget: sumTarget ?? this.sumTarget,
      sumExact: sumExact ?? this.sumExact,
      counterRequired: counterRequired ?? this.counterRequired,
    );
  }
}

class SelectOption {
  final int code;
  final int controller;
  final int zone;
  final int sequence;

  /// SUM 选项：合计参数 1（引擎 sum_param 的 o1）。
  /// COUNTER 选项：该卡当前可用的指示物数。
  final int? level;

  /// SUM 选项：合计参数 2（引擎 sum_param 的 o2）。
  /// null 或 0 表示与 [level] 相同（引擎 o2==0 时只有 o1 生效）。
  final int? level2;
  final int? position;
  final String? label;

  const SelectOption({
    required this.code,
    this.controller = 0,
    this.zone = 0,
    this.sequence = 0,
    this.level,
    this.level2,
    this.position,
    this.label,
  });
}

/// 服务端下发的选择题类型，与 ocgcore 的 MSG_SELECT_* 消息一一对应，
/// 决定 [SelectState] 的呈现方式与响应编码。
/// 选择提示的统一呈现方式：由业务侧（store）判定，
/// 页面只消费该结果插入对应 UI，不再各自判断互斥关系。
enum SelectPromptMode {
  /// 无选择窗口，或阶段指令窗口（由阶段菜单处理）。
  none,

  /// 放置选择：可放置槽位已在场地组件上高亮，仅显示提示横幅。
  place,

  /// 就地选择：高亮手牌/场上卡 + 底部操作栏。
  inline,

  /// 模态弹窗（CardSelector / PositionSelector 等阻断式 UI）。
  modal,
}

enum SelectType {
  /// MSG_SELECT_IDLE_CMD：主要阶段空闲指令窗口
  /// （发动/召唤/盖放/转阶段等），由阶段菜单与手牌/场上操作承载。
  idleCmd,

  /// MSG_SELECT_CARD：从若干张卡中选 min~max 张（效果取对象等）。
  card,

  /// MSG_SELECT_CHAIN：连锁窗口，选择要发动连锁的卡；
  /// 响应 -1 表示放弃连锁。
  chain,

  /// MSG_SELECT_OPTION：从若干效果选项中选一项。
  option,

  /// MSG_ANNOUNCE_CARD：宣言一个卡名（输入检索后选定，如「禁止令」）。
  announceCard,

  /// MSG_SELECT_POSITION：选择怪兽的表示形式
  /// （表侧/里侧 × 攻击/守备）。
  position,

  /// MSG_SELECT_EFFECTYN：是否发动指定卡的效果（带卡图的是/否确认）。
  effectYn,

  /// MSG_SELECT_YES_NO：一般的是/否确认。
  yesNo,

  /// MSG_SELECT_BATTLE_CMD：战斗阶段指令窗口（攻击宣言/进入 M2/EP 等），
  /// 由阶段菜单与场上操作承载。
  battleCmd,

  /// MSG_SELECT_PLACE / MSG_SELECT_DISFIELD：选择卡的放置位置
  /// （召唤/盖放到哪个区域），可放置槽位高亮后直接点选。
  place,

  /// MSG_SELECT_TRIBUTE：选择上级召唤/效果要解放的怪兽。
  tribute,

  /// MSG_SELECT_UNSELECT_CARD：在候选卡中切换勾选（重选效果对象等），
  /// 点卡即向服务端切换，满足条件后「完成」确认。
  unselect,

  /// MSG_SELECT_SUM：按等级/数值合计达到指定值来选卡。
  sum,

  /// MSG_SELECT_COUNTER：选择移除指示物的数量与分布。
  counter,

  /// MSG_SORT_CARD：调整若干张卡的顺序（如卡组顶部的回放顺序）。
  sort,
}
