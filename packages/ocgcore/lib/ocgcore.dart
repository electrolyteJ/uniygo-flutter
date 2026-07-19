import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'ocgcore_cc_adapter.dart';
export 'ocgcore.dart';

/// OCGCore API 接口常量和抽象类定义
///
/// 这些常量和接口用于与游戏王卡牌对战引擎的核心库进行交互。
/// 所有平台适配器（原生 FFI、WASM JS-interop）都实现此接口，
/// 使得上层代码可以与任何后端一起工作。

// ---------------------------------------------------------------------------
// 基础常量
// ---------------------------------------------------------------------------

/// 随机种子序列长度
const int SEED_COUNT = 8;

/// 操作失败时的数据长度
const int LEN_FAIL = 0;

/// 空数据时的最小长度
const int LEN_EMPTY = 4;

/// 消息头部长度
const int LEN_HEADER = 8;

/// 临时卡牌 ID
const int TEMP_CARD_ID = 0;

// ---------------------------------------------------------------------------
// 操作结果常量
// ---------------------------------------------------------------------------

/// 操作成功
const int OPERATION_SUCCESS = 1;

/// 操作失败
const int OPERATION_FAIL = 0;

/// 操作被取消
const int OPERATION_CANCELED = -1;

/// 真
const int TRUE = 1;

/// 假
const int FALSE = 0;

// ---------------------------------------------------------------------------
// 缓冲区大小常量
// ---------------------------------------------------------------------------

/// 消息缓冲区大小
const int SIZE_MESSAGE_BUFFER = 0x2000;

/// 返回值缓冲区大小
const int SIZE_RETURN_VALUE = 512;

/// AI 名称最大长度
const int SIZE_AI_NAME = 128;

/// 提示消息最大长度
const int SIZE_HINT_MSG = 1024;

/// 卡组代码数组长度
const int SIZE_SETCODE = 16;

// ---------------------------------------------------------------------------
// 处理器状态常量
// ---------------------------------------------------------------------------

/// 处理器缓冲区长度
const int PROCESSOR_BUFFER_LEN = 0x0fffffff;

/// 处理器状态标志位掩码
const int PROCESSOR_FLAG = 0xf0000000;

/// 无状态
const int PROCESSOR_NONE = 0;

/// 等待中
const int PROCESSOR_WAITING = 0x10000000;

/// 决斗结束
const int PROCESSOR_END = 0x20000000;

// ---------------------------------------------------------------------------
// 大师规则常量
// ---------------------------------------------------------------------------

/// Master Rule 3 (2014)
const int MASTER_RULE3 = 3;

/// New Master Rule (2017)
const int NEW_MASTER_RULE = 4;

/// Master Rule 2020
const int MASTER_RULE_2020 = 5;

/// 当前使用的规则
const int CURRENT_RULE = 5;

// ---------------------------------------------------------------------------
// 位置常量 (Location)
// ---------------------------------------------------------------------------

/// 卡组
const int LOCATION_DECK = 0x01;

/// 手牌
const int LOCATION_HAND = 0x02;

/// 怪兽区域
const int LOCATION_MZONE = 0x04;

/// 魔法陷阱区域
const int LOCATION_SZONE = 0x08;

/// 墓地
const int LOCATION_GRAVE = 0x10;

/// 除外区
const int LOCATION_REMOVED = 0x20;

/// 额外卡组
const int LOCATION_EXTRA = 0x40;

/// XYZ 素材
const int LOCATION_OVERLAY = 0x80;

/// 场上（怪兽+魔法陷阱区域）
const int LOCATION_ONFIELD = LOCATION_MZONE | LOCATION_SZONE;

/// 场地魔法区域
const int LOCATION_FZONE = 0x100;

/// 灵摆区域
const int LOCATION_PZONE = 0x200;

/// 返回卡组底部
const int LOCATION_DECKBOT = 0x10001;

/// 返回卡组并洗牌
const int LOCATION_DECKSHF = 0x20001;

// ---------------------------------------------------------------------------
// 卡组顺序常量
// ---------------------------------------------------------------------------

/// 返回卡组顶部
const int SEQ_DECKTOP = 0;

/// 返回卡组底部
const int SEQ_DECKBOTTOM = 1;

/// 返回卡组并洗牌
const int SEQ_DECKSHUFFLE = 2;

// ---------------------------------------------------------------------------
// 表示位置常量 (Position)
// ---------------------------------------------------------------------------

/// 表侧攻击表示
const int POS_FACEUP_ATTACK = 0x1;

/// 里侧攻击表示
const int POS_FACEDOWN_ATTACK = 0x2;

/// 表侧守备表示
const int POS_FACEUP_DEFENSE = 0x4;

/// 里侧守备表示
const int POS_FACEDOWN_DEFENSE = 0x8;

/// 表侧表示
const int POS_FACEUP = 0x5;

/// 里侧表示
const int POS_FACEDOWN = 0xA;

/// 攻击表示
const int POS_ATTACK = 0x3;

/// 守备表示
const int POS_DEFENSE = 0xC;

/// 无反转效果标志
const int NO_FLIP_EFFECT = 0x10000;

// ---------------------------------------------------------------------------
// 卡牌类型常量 (Type)
// ---------------------------------------------------------------------------

/// 怪兽卡
const int TYPE_MONSTER = 0x1;

/// 魔法卡
const int TYPE_SPELL = 0x2;

/// 陷阱卡
const int TYPE_TRAP = 0x4;

/// 通常怪兽
const int TYPE_NORMAL = 0x10;

/// 效果怪兽
const int TYPE_EFFECT = 0x20;

/// 融合怪兽
const int TYPE_FUSION = 0x40;

/// 仪式怪兽
const int TYPE_RITUAL = 0x80;

/// 陷阱怪兽
const int TYPE_TRAPMONSTER = 0x100;

/// 灵魂怪兽
const int TYPE_SPIRIT = 0x200;

/// 同盟怪兽
const int TYPE_UNION = 0x400;

/// 二重怪兽
const int TYPE_DUAL = 0x800;

/// 调整怪兽
const int TYPE_TUNER = 0x1000;

/// 同调怪兽
const int TYPE_SYNCHRO = 0x2000;

/// 衍生物
const int TYPE_TOKEN = 0x4000;

/// 速攻魔法
const int TYPE_QUICKPLAY = 0x10000;

/// 永续魔法/陷阱
const int TYPE_CONTINUOUS = 0x20000;

/// 装备魔法
const int TYPE_EQUIP = 0x40000;

/// 场地魔法
const int TYPE_FIELD = 0x80000;

/// 反击陷阱
const int TYPE_COUNTER = 0x100000;

/// 反转怪兽
const int TYPE_FLIP = 0x200000;

/// 卡通怪兽
const int TYPE_TOON = 0x400000;

/// XYZ 怪兽
const int TYPE_XYZ = 0x800000;

/// 灵摆怪兽
const int TYPE_PENDULUM = 0x1000000;

/// 特殊召唤怪兽
const int TYPE_SPSUMMON = 0x2000000;

/// 连接怪兽
const int TYPE_LINK = 0x4000000;

/// 额外卡组怪兽类型（融合+同调+XYZ+连接）
const int TYPES_EXTRA_DECK = 0x4640;

// ---------------------------------------------------------------------------
// 属性常量 (Attribute)
// ---------------------------------------------------------------------------

/// 属性数量
const int ATTRIBUTES_COUNT = 7;

/// 所有属性
const int ATTRIBUTE_ALL = 0x7f;

/// 地属性
const int ATTRIBUTE_EARTH = 0x01;

/// 水属性
const int ATTRIBUTE_WATER = 0x02;

/// 炎属性
const int ATTRIBUTE_FIRE = 0x04;

/// 风属性
const int ATTRIBUTE_WIND = 0x08;

/// 光属性
const int ATTRIBUTE_LIGHT = 0x10;

/// 暗属性
const int ATTRIBUTE_DARK = 0x20;

/// 神属性
const int ATTRIBUTE_DEVINE = 0x40;

// ---------------------------------------------------------------------------
// 种族常量 (Race)
// ---------------------------------------------------------------------------

/// 种族数量
const int RACES_COUNT = 26;

/// 所有种族
const int RACE_ALL = 0x3ffffff;

/// 战士族
const int RACE_WARRIOR = 0x1;

/// 魔法师族
const int RACE_SPELLCASTER = 0x2;

/// 天使族
const int RACE_FAIRY = 0x4;

/// 恶魔族
const int RACE_FIEND = 0x8;

/// 不死族
const int RACE_ZOMBIE = 0x10;

/// 机械族
const int RACE_MACHINE = 0x20;

/// 水族
const int RACE_AQUA = 0x40;

/// 炎族
const int RACE_PYRO = 0x80;

/// 岩石族
const int RACE_ROCK = 0x100;

/// 鸟兽族
const int RACE_WINDBEAST = 0x200;

/// 植物族
const int RACE_PLANT = 0x400;

/// 昆虫族
const int RACE_INSECT = 0x800;

/// 雷族
const int RACE_THUNDER = 0x1000;

/// 龙族
const int RACE_DRAGON = 0x2000;

/// 兽族
const int RACE_BEAST = 0x4000;

/// 兽战士族
const int RACE_BEASTWARRIOR = 0x8000;

/// 恐龙族
const int RACE_DINOSAUR = 0x10000;

/// 鱼族
const int RACE_FISH = 0x20000;

/// 海龙族
const int RACE_SEASERPENT = 0x40000;

/// 爬虫类族
const int RACE_REPTILE = 0x80000;

/// 念动力族
const int RACE_PSYCHO = 0x100000;

/// 幻神族
const int RACE_DEVINE = 0x200000;

/// 创造神族
const int RACE_CREATORGOD = 0x400000;

/// 幻龙族
const int RACE_WYRM = 0x800000;

/// 电子界族
const int RACE_CYBERSE = 0x1000000;

/// 幻兽神族
const int RACE_ILLUSION = 0x2000000;

// ---------------------------------------------------------------------------
// 查询标志常量 (Query Flag)
// ---------------------------------------------------------------------------

/// 查询卡牌编号
const int QUERY_CODE = 0x1;

/// 查询表示位置
const int QUERY_POSITION = 0x2;

/// 查询别名
const int QUERY_ALIAS = 0x4;

/// 查询类型
const int QUERY_TYPE = 0x8;

/// 查询等级
const int QUERY_LEVEL = 0x10;

/// 查询阶级
const int QUERY_RANK = 0x20;

/// 查询属性
const int QUERY_ATTRIBUTE = 0x40;

/// 查询种族
const int QUERY_RACE = 0x80;

/// 查询攻击力
const int QUERY_ATTACK = 0x100;

/// 查询守备力
const int QUERY_DEFENSE = 0x200;

/// 查询基础攻击力
const int QUERY_BASE_ATTACK = 0x400;

/// 查询基础守备力
const int QUERY_BASE_DEFENSE = 0x800;

/// 查询原因
const int QUERY_REASON = 0x1000;

/// 查询原因卡
const int QUERY_REASON_CARD = 0x2000;

/// 查询装备卡
const int QUERY_EQUIP_CARD = 0x4000;

/// 查询目标卡
const int QUERY_TARGET_CARD = 0x8000;

/// 查询 XYZ 素材
const int QUERY_OVERLAY_CARD = 0x10000;

/// 查询计数器
const int QUERY_COUNTERS = 0x20000;

/// 查询所有者
const int QUERY_OWNER = 0x40000;

/// 查询状态
const int QUERY_STATUS = 0x80000;

/// 查询左刻度
const int QUERY_LSCALE = 0x200000;

/// 查询右刻度
const int QUERY_RSCALE = 0x400000;

/// 查询连接标记
const int QUERY_LINK = 0x800000;

// ---------------------------------------------------------------------------
// 连接标记常量 (Link Marker)
// ---------------------------------------------------------------------------

/// 左下
const int LINK_MARKER_BOTTOM_LEFT = 0x001;

/// 下
const int LINK_MARKER_BOTTOM = 0x002;

/// 右下
const int LINK_MARKER_BOTTOM_RIGHT = 0x004;

/// 左
const int LINK_MARKER_LEFT = 0x008;

/// 右
const int LINK_MARKER_RIGHT = 0x020;

/// 左上
const int LINK_MARKER_TOP_LEFT = 0x040;

/// 上
const int LINK_MARKER_TOP = 0x080;

/// 右上
const int LINK_MARKER_TOP_RIGHT = 0x100;

// ---------------------------------------------------------------------------
// 消息类型常量 (Message)
// ---------------------------------------------------------------------------

/// 重试
const int MSG_RETRY = 1;

/// 提示
const int MSG_HINT = 2;

/// 胜利
const int MSG_WIN = 5;

/// 选择战斗命令
const int MSG_SELECT_BATTLECMD = 10;

/// 选择空闲命令
const int MSG_SELECT_IDLECMD = 11;

/// 选择效果是否发动
const int MSG_SELECT_EFFECTYN = 12;

/// 选择是/否
const int MSG_SELECT_YESNO = 13;

/// 选择选项
const int MSG_SELECT_OPTION = 14;

/// 选择卡牌
const int MSG_SELECT_CARD = 15;

/// 选择连锁
const int MSG_SELECT_CHAIN = 16;

/// 选择位置
const int MSG_SELECT_PLACE = 18;

/// 选择表示位置
const int MSG_SELECT_POSITION = 19;

/// 选择祭品
const int MSG_SELECT_TRIBUTE = 20;

/// 选择计数器
const int MSG_SELECT_COUNTER = 22;

/// 选择召唤方式
const int MSG_SELECT_SUM = 23;

/// 选择场地魔法
const int MSG_SELECT_DISFIELD = 24;

/// 排序卡牌
const int MSG_SORT_CARD = 25;

/// 选择/取消选择卡牌
const int MSG_SELECT_UNSELECT_CARD = 26;

/// 确认卡组顶部
const int MSG_CONFIRM_DECKTOP = 30;

/// 确认卡牌
const int MSG_CONFIRM_CARDS = 31;

/// 洗卡组
const int MSG_SHUFFLE_DECK = 32;

/// 洗手牌
const int MSG_SHUFFLE_HAND = 33;

/// 交换墓地和卡组
const int MSG_SWAP_GRAVE_DECK = 35;

/// 洗牌组设定卡
const int MSG_SHUFFLE_SET_CARD = 36;

/// 反转卡组
const int MSG_REVERSE_DECK = 37;

/// 卡组顶部
const int MSG_DECK_TOP = 38;

/// 洗额外卡组
const int MSG_SHUFFLE_EXTRA = 39;

/// 新回合
const int MSG_NEW_TURN = 40;

/// 新阶段
const int MSG_NEW_PHASE = 41;

/// 确认额外卡组顶部
const int MSG_CONFIRM_EXTRATOP = 42;

/// 移动
const int MSG_MOVE = 50;

/// 表示形式变更
const int MSG_POS_CHANGE = 53;

/// 放置
const int MSG_SET = 54;

/// 交换
const int MSG_SWAP = 55;

/// 场地无效
const int MSG_FIELD_DISABLED = 56;

/// 召唤中
const int MSG_SUMMONING = 60;

/// 已召唤
const int MSG_SUMMONED = 61;

/// 特殊召唤中
const int MSG_SPSUMMONING = 62;

/// 已特殊召唤
const int MSG_SPSUMMONED = 63;

/// 反转召唤中
const int MSG_FLIPSUMMONING = 64;

/// 已反转召唤
const int MSG_FLIPSUMMONED = 65;

/// 连锁中
const int MSG_CHAINING = 70;

/// 已连锁
const int MSG_CHAINED = 71;

/// 连锁处理中
const int MSG_CHAIN_SOLVING = 72;

/// 连锁处理完毕
const int MSG_CHAIN_SOLVED = 73;

/// 连锁结束
const int MSG_CHAIN_END = 74;

/// 连锁被无效
const int MSG_CHAIN_NEGATED = 75;

/// 连锁无效化
const int MSG_CHAIN_DISABLED = 76;

/// 随机选择
const int MSG_RANDOM_SELECTED = 81;

/// 成为目标
const int MSG_BECOME_TARGET = 83;

/// 抽卡
const int MSG_DRAW = 90;

/// 伤害
const int MSG_DAMAGE = 91;

/// 回复
const int MSG_RECOVER = 92;

/// 装备
const int MSG_EQUIP = 93;

/// 生命值更新
const int MSG_LPUPDATE = 94;

/// 卡牌目标
const int MSG_CARD_TARGET = 96;

/// 取消目标
const int MSG_CANCEL_TARGET = 97;

/// 支付生命值
const int MSG_PAY_LPCOST = 100;

/// 添加计数器
const int MSG_ADD_COUNTER = 101;

/// 移除计数器
const int MSG_REMOVE_COUNTER = 102;

/// 攻击
const int MSG_ATTACK = 110;

/// 战斗
const int MSG_BATTLE = 111;

/// 攻击无效
const int MSG_ATTACK_DISABLED = 112;

/// 伤害步骤开始
const int MSG_DAMAGE_STEP_START = 113;

/// 伤害步骤结束
const int MSG_DAMAGE_STEP_END = 114;

/// 错过效果时机
const int MSG_MISSED_EFFECT = 120;

/// 投掷硬币
const int MSG_TOSS_COIN = 130;

/// 投掷骰子
const int MSG_TOSS_DICE = 131;

/// 猜拳
const int MSG_ROCK_PAPER_SCISSORS = 132;

/// 手牌结果
const int MSG_HAND_RES = 133;

/// 宣言种族
const int MSG_ANNOUNCE_RACE = 140;

/// 宣言属性
const int MSG_ANNOUNCE_ATTRIB = 141;

/// 宣言卡牌
const int MSG_ANNOUNCE_CARD = 142;

/// 宣言数值
const int MSG_ANNOUNCE_NUMBER = 143;

/// 卡牌提示
const int MSG_CARD_HINT = 160;

/// 双人对战切换
const int MSG_TAG_SWAP = 161;

/// 重新加载场地
const int MSG_RELOAD_FIELD = 162;

/// AI 名称
const int MSG_AI_NAME = 163;

/// 显示提示
const int MSG_SHOW_HINT = 164;

/// 玩家提示
const int MSG_PLAYER_HINT = 165;

/// 一击必杀
const int MSG_MATCH_KILL = 170;

/// 自定义消息
const int MSG_CUSTOM_MSG = 180;

// ---------------------------------------------------------------------------
// 阶段常量 (Phase)
// ---------------------------------------------------------------------------

/// 抽卡阶段
const int PHASE_DRAW = 0x01;

/// 准备阶段
const int PHASE_STANDBY = 0x02;

/// 主要阶段1
const int PHASE_MAIN1 = 0x04;

/// 战斗阶段开始
const int PHASE_BATTLE_START = 0x08;

/// 战斗步骤
const int PHASE_BATTLE_STEP = 0x10;

/// 伤害步骤
const int PHASE_DAMAGE = 0x20;

/// 伤害计算
const int PHASE_DAMAGE_CAL = 0x40;

/// 战斗阶段
const int PHASE_BATTLE = 0x80;

/// 主要阶段2
const int PHASE_MAIN2 = 0x100;

/// 结束阶段
const int PHASE_END = 0x200;

// ---------------------------------------------------------------------------
// 决斗选项常量 (Options)
// ---------------------------------------------------------------------------

/// 测试模式
const int DUEL_TEST_MODE = 0x01;

/// 第一回合可攻击
const int DUEL_ATTACK_FIRST_TURN = 0x02;

/// 使用旧规则
const int DUEL_OBSOLETE_RULING = 0x08;

/// 伪随机洗牌
const int DUEL_PSEUDO_SHUFFLE = 0x10;

/// 双人对战模式
const int DUEL_TAG_MODE = 0x20;

/// 简单 AI
const int DUEL_SIMPLE_AI = 0x40;

/// 返回卡组顶部
const int DUEL_RETURN_DECK_TOP = 0x80;

/// 显示卡组顺序
const int DUEL_REVEAL_DECK_SEQ = 0x100;

// ---------------------------------------------------------------------------
// 原因常量 (Reason)
// ---------------------------------------------------------------------------

/// 破坏
const int REASON_DESTROY = 0x1;

/// 解放
const int REASON_RELEASE = 0x2;

/// 临时
const int REASON_TEMPORARY = 0x4;

/// 素材
const int REASON_MATERIAL = 0x8;

/// 召唤
const int REASON_SUMMON = 0x10;

/// 战斗
const int REASON_BATTLE = 0x20;

/// 效果
const int REASON_EFFECT = 0x40;

/// 代价
const int REASON_COST = 0x80;

/// 调整
const int REASON_ADJUST = 0x100;

/// 失去目标
const int REASON_LOST_TARGET = 0x200;

/// 规则
const int REASON_RULE = 0x400;

/// 特殊召唤
const int REASON_SPSUMMON = 0x800;

/// 解除召唤
const int REASON_DISSUMMON = 0x1000;

/// 反转
const int REASON_FLIP = 0x2000;

/// 丢弃
const int REASON_DISCARD = 0x4000;

/// 伤害
const int REASON_RDAMAGE = 0x8000;

/// 回复
const int REASON_RRECOVER = 0x10000;

/// 返回
const int REASON_RETURN = 0x20000;

/// 融合
const int REASON_FUSION = 0x40000;

/// 同调
const int REASON_SYNCHRO = 0x80000;

/// 仪式
const int REASON_RITUAL = 0x100000;

/// XYZ
const int REASON_XYZ = 0x200000;

/// 替换
const int REASON_REPLACE = 0x1000000;

/// 抽卡
const int REASON_DRAW = 0x2000000;

/// 重定向
const int REASON_REDIRECT = 0x4000000;

/// 展示
const int REASON_REVEAL = 0x8000000;

/// 连接
const int REASON_LINK = 0x10000000;

/// 失去素材
const int REASON_LOST_OVERLAY = 0x20000000;

/// 维护
const int REASON_MAINTENANCE = 0x40000000;

/// 动作
const int REASON_ACTION = 0x80000000;

/// 特殊召唤流程（同调+XYZ+连接）
const int REASONS_PROCEDURE = 0xa80000;

// ---------------------------------------------------------------------------
// 状态常量 (Status)
// ---------------------------------------------------------------------------

/// 已禁用
const int STATUS_DISABLED = 0x0001;

/// 待启用
const int STATUS_TO_ENABLE = 0x0002;

/// 待禁用
const int STATUS_TO_DISABLE = 0x0004;

/// 处理完成
const int STATUS_PROC_COMPLETE = 0x0008;

/// 放置回合
const int STATUS_SET_TURN = 0x0010;

/// 无等级
const int STATUS_NO_LEVEL = 0x0020;

/// 战斗结果
const int STATUS_BATTLE_RESULT = 0x0040;

/// 特殊召唤步骤
const int STATUS_SPSUMMON_STEP = 0x0080;

/// 不能变更表示形式
const int STATUS_CANNOT_CHANGE_FORM = 0x0100;

/// 召唤中
const int STATUS_SUMMONING = 0x0200;

/// 效果已启用
const int STATUS_EFFECT_ENABLED = 0x0400;

/// 召唤回合
const int STATUS_SUMMON_TURN = 0x0800;

/// 破坏已确认
const int STATUS_DESTROY_CONFIRMED = 0x1000;

/// 离场已确认
const int STATUS_LEAVE_CONFIRMED = 0x2000;

/// 战斗破坏
const int STATUS_BATTLE_DESTROYED = 0x4000;

/// 复制效果中
const int STATUS_COPYING_EFFECT = 0x8000;

/// 连锁中
const int STATUS_CHAINING = 0x10000;

/// 召唤被禁用
const int STATUS_SUMMON_DISABLED = 0x20000;

/// 发动被禁用
const int STATUS_ACTIVATE_DISABLED = 0x40000;

/// 效果已替换
const int STATUS_EFFECT_REPLACED = 0x80000;

/// 反转召唤中
const int STATUS_FLIP_SUMMONING = 0x100000;

/// 攻击已取消
const int STATUS_ATTACK_CANCELED = 0x200000;

/// 初始化中
const int STATUS_INITIALIZING = 0x400000;

/// 不确认回手
const int STATUS_TO_HAND_WITHOUT_CONFIRM = 0x800000;

/// 刚变更位置
const int STATUS_JUST_POS = 0x1000000;

/// 持续位置
const int STATUS_CONTINUOUS_POS = 0x2000000;

/// 禁止
const int STATUS_FORBIDDEN = 0x4000000;

/// 从手牌发动
const int STATUS_ACT_FROM_HAND = 0x8000000;

/// 对方战斗
const int STATUS_OPPO_BATTLE = 0x10000000;

/// 反转召唤回合
const int STATUS_FLIP_SUMMON_TURN = 0x20000000;

/// 特殊召唤回合
const int STATUS_SPSUMMON_TURN = 0x40000000;

/// 反转召唤被禁用
const int STATUS_FLIP_SUMMON_DISABLED = 0x80000000;

// ---------------------------------------------------------------------------
// 玩家常量 (Player)
// ---------------------------------------------------------------------------

/// 无玩家
const int PLAYER_NONE = 2;

/// 所有玩家
const int PLAYER_ALL = 3;

/// 自身描述
const int PLAYER_SELFDES = 5;

// ---------------------------------------------------------------------------
// 提示类型常量 (Hint)
// ---------------------------------------------------------------------------

/// 事件提示
const int HINT_EVENT = 1;

/// 消息提示
const int HINT_MESSAGE = 2;

/// 选择消息提示
const int HINT_SELECTMSG = 3;

/// 选项已选择提示
const int HINT_OPSELECTED = 4;

/// 效果提示
const int HINT_EFFECT = 5;

/// 种族提示
const int HINT_RACE = 6;

/// 属性提示
const int HINT_ATTRIB = 7;

/// 卡牌编号提示
const int HINT_CODE = 8;

/// 数值提示
const int HINT_NUMBER = 9;

/// 卡牌提示
const int HINT_CARD = 10;

/// 区域提示
const int HINT_ZONE = 11;

/// 回合卡牌提示
const int CHINT_TURN = 1;

/// 卡牌提示
const int CHINT_CARD = 2;

/// 种族卡牌提示
const int CHINT_RACE = 3;

/// 属性卡牌提示
const int CHINT_ATTRIBUTE = 4;

/// 数值卡牌提示
const int CHINT_NUMBER = 5;

/// 描述添加卡牌提示
const int CHINT_DESC_ADD = 6;

/// 描述移除卡牌提示
const int CHINT_DESC_REMOVE = 7;

/// 描述添加玩家提示
const int PHINT_DESC_ADD = 6;

/// 描述移除玩家提示
const int PHINT_DESC_REMOVE = 7;

/// 操作效果描述
const int EDESC_OPERATION = 1;

/// 重置效果描述
const int EDESC_RESET = 2;

// ---------------------------------------------------------------------------
// 操作码常量 (Opcode)
// ---------------------------------------------------------------------------

/// 加法操作码
const int OPCODE_ADD = 0x40000000;

/// 减法操作码
const int OPCODE_SUB = 0x40000001;

/// 乘法操作码
const int OPCODE_MUL = 0x40000002;

/// 除法操作码
const int OPCODE_DIV = 0x40000003;

/// 与运算操作码
const int OPCODE_AND = 0x40000004;

/// 或运算操作码
const int OPCODE_OR = 0x40000005;

/// 取反操作码
const int OPCODE_NEG = 0x40000006;

/// 非运算操作码
const int OPCODE_NOT = 0x40000007;

/// 判断卡牌编号操作码
const int OPCODE_ISCODE = 0x40000100;

/// 判断卡组卡牌操作码
const int OPCODE_ISSETCARD = 0x40000101;

/// 判断类型操作码
const int OPCODE_ISTYPE = 0x40000102;

/// 判断种族操作码
const int OPCODE_ISRACE = 0x40000103;

/// 判断属性操作码
const int OPCODE_ISATTRIBUTE = 0x40000104;

// ---------------------------------------------------------------------------
// 活动常量 (Activity)
// ---------------------------------------------------------------------------

/// 召唤活动
const int ACTIVITY_SUMMON = 1;

/// 通常召唤活动
const int ACTIVITY_NORMALSUMMON = 2;

/// 特殊召唤活动
const int ACTIVITY_SPSUMMON = 3;

/// 反转召唤活动
const int ACTIVITY_FLIPSUMMON = 4;

/// 攻击活动
const int ACTIVITY_ATTACK = 5;

/// 战斗阶段活动
const int ACTIVITY_BATTLE_PHASE = 6;

/// 连锁活动
const int ACTIVITY_CHAIN = 7;

// ---------------------------------------------------------------------------
// 返回标志常量 (Return)
// ---------------------------------------------------------------------------

/// 临时除外返回场地
const int RETURN_TEMP_REMOVE_TO_FIELD = 1;

/// 陷阱怪兽返回魔法陷阱区域
const int RETURN_TRAP_MONSTER_TO_SZONE = 2;

// ---------------------------------------------------------------------------
// 回调函数类型定义
// ---------------------------------------------------------------------------

/// 脚本读取回调函数类型
///
/// 用于异步读取卡牌脚本文件。
///
/// [scriptName]: 脚本文件名
///
/// 返回值: 包含脚本数据的 Future<Uint8List?>
typedef ScriptReader = Future<Uint8List?> Function(String scriptName);

/// 卡牌数据读取回调函数类型
///
/// 用于异步读取卡牌定义数据。
///
/// [code]: 卡牌编号
///
/// 返回值: 包含卡牌数据的 Future<CardData?>，为 null 表示读取失败
typedef CardReader = Future<CardData?> Function(int code);

/// 卡牌数据类
///
/// 用于封装卡牌的所有属性，作为异步卡牌读取器的返回类型。
class CardData {
  /// 卡牌编号（唯一标识）
  ///
  /// 游戏王卡牌的唯一识别码，通常为 8 位数字。
  /// 例如：黑魔导为 36996508，青眼白龙为 89631139。
  final int code;

  /// 卡牌别名编号
  ///
  /// 当多张卡牌共享同一效果或信息时，使用别名编号关联它们。
  /// 通常用于衍生物、二重怪兽等卡牌。值为 0 表示没有别名。
  final int alias;

  /// 卡组代码数组
  ///
  /// 标识卡牌所属卡组系列的代码数组，最多包含 [SIZE_SETCODE]（16）个元素。
  /// 例如：黑魔导卡组的 setcode 包含 0x1000000、0x2000000 等。
  /// 数组中值为 0 的元素表示未使用。
  final List<int> setcode;

  /// 卡牌类型标志位
  ///
  /// 使用位掩码表示卡牌的各种类型属性，可通过位运算组合多种类型。
  /// 参见 [TYPE_MONSTER]、[TYPE_SPELL]、[TYPE_TRAP]、[TYPE_EFFECT]、[TYPE_FUSION] 等常量。
  /// 例如：效果怪兽为 TYPE_MONSTER | TYPE_EFFECT。
  final int type;

  /// 卡牌等级/阶级
  ///
  /// - 通常怪兽、效果怪兽、融合怪兽等使用等级（1-12）
  /// - XYZ 怪兽使用阶级（1-13），存储为负数（如阶级 4 存储为 -4）
  /// - 连接怪兽不使用此字段（值为 0）
  final int level;

  /// 卡牌属性
  ///
  /// 使用位掩码表示卡牌属性，参见 [ATTRIBUTE_EARTH]、[ATTRIBUTE_WATER]、
  /// [ATTRIBUTE_FIRE]、[ATTRIBUTE_WIND]、[ATTRIBUTE_LIGHT]、[ATTRIBUTE_DARK]、
  /// [ATTRIBUTE_DEVINE] 等常量。
  final int attribute;

  /// 卡牌种族
  ///
  /// 使用位掩码表示卡牌种族，参见 [RACE_WARRIOR]、[RACE_DRAGON]、[RACE_SPELLCASTER]
  /// 等常量。魔法卡和陷阱卡的种族值通常为 0。
  final int race;

  /// 攻击力
  ///
  /// 怪兽卡的攻击力数值。魔法卡和陷阱卡的攻击力值为 0。
  /// 连接怪兽的攻击力也存储在此字段。
  final int attack;

  /// 守备力
  ///
  /// 怪兽卡的守备力数值。魔法卡和陷阱卡的守备力值为 0。
  /// XYZ 怪兽在守备表示时使用此值。
  final int defense;

  /// 灵摆左刻度
  ///
  /// 灵摆怪兽的左刻度值，用于灵摆召唤时的刻度计算。
  /// 非灵摆怪兽的左刻度值为 0。
  final int lscale;

  /// 灵摆右刻度
  ///
  /// 灵摆怪兽的右刻度值，用于灵摆召唤时的刻度计算。
  /// 非灵摆怪兽的右刻度值为 0。
  final int rscale;

  /// 连接标记
  ///
  /// 连接怪兽的连接标记标志位，表示连接怪兽可以连接的方向。
  /// 参见 [LINK_MARKER_BOTTOM]、[LINK_MARKER_LEFT]、[LINK_MARKER_RIGHT]、[LINK_MARKER_TOP]
  /// 等常量。非连接怪兽的连接标记值为 0。
  final int linkMarker;

  /// 规则代码
  ///
  /// 用于标识特殊规则或限制的代码，通常用于标记禁限卡表状态。
  /// 值为 0 表示没有特殊规则限制。
  final int ruleCode;
  final String name;
  final String desc;

  CardData({
    required this.code,
    required this.alias,
    required this.setcode,
    required this.type,
    required this.level,
    required this.attribute,
    required this.race,
    required this.attack,
    required this.defense,
    required this.lscale,
    required this.rscale,
    required this.linkMarker,
    required this.ruleCode,
    required this.name, required this.desc,

  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'alias': alias,
      'type': type,
      'level': level,
      'attribute': attribute,
      'race': race,
      'attack': attack,
      'defense': defense,
      'lscale': lscale,
      'rscale': rscale,
      'linkMarker': linkMarker,
      'setcode': setcode,
      'name': name,
      'desc': desc,
    };
  }

  factory CardData.fromJson(Map<String, dynamic> json) {
    return CardData(
      code: json['code'] ?? 0,
      alias: json['alias'] ?? 0,
      type: json['type'] ?? 0,
      level: json['level'] ?? 0,
      attribute: json['attribute'] ?? 0,
      race: json['race'] ?? 0,
      attack: json['attack'] ?? 0,
      defense: json['defense'] ?? 0,
      lscale: json['lscale'] ?? 0,
      rscale: json['rscale'] ?? 0,
      linkMarker: json['linkMarker'] ?? 0,
      setcode: json['setcode'] is List ? List<int>.from(json['setcode']) : [],
      ruleCode: 0,
      name: json['name'] ?? '', desc: json['desc'] ?? '',
    );
  }

  bool get isMonster => (type & 0x1) != 0;
  bool get isSpell => (type & 0x2) != 0;
  bool get isTrap => (type & 0x4) != 0;
  bool get isNormal => (type & 0x10) != 0;
  bool get isEffect => (type & 0x20) != 0;
  bool get isFusion => (type & 0x40) != 0;
  bool get isRitual => (type & 0x80) != 0;
  bool get isSynchro => (type & 0x2000) != 0;
  bool get isXyz => (type & 0x800000) != 0;
  bool get isLink => (type & 0x4000000) != 0;
  bool get isPendulum => (type & 0x1000000) != 0;

  String get typeText {
    List<String> types = [];
    if (isMonster) types.add('怪兽');
    if (isSpell) types.add('魔法');
    if (isTrap) types.add('陷阱');
    if (isNormal) types.add('通常');
    if (isEffect) types.add('效果');
    if (isFusion) types.add('融合');
    if (isRitual) types.add('仪式');
    if (isSynchro) types.add('同调');
    if (isXyz) types.add('XYZ');
    if (isLink) types.add('连接');
    if (isPendulum) types.add('灵摆');
    return types.join(' ');
  }

  String get attributeText {
    switch (attribute) {
      case 0x01: return '地';
      case 0x02: return '水';
      case 0x04: return '炎';
      case 0x08: return '风';
      case 0x10: return '光';
      case 0x20: return '暗';
      case 0x40: return '神';
      default: return '无';
    }
  }

  String get raceText {
    const races = {
      0x1: '战士', 0x2: '魔法师', 0x4: '天使', 0x8: '恶魔',
      0x10: '不死', 0x20: '机械', 0x40: '水族', 0x80: '炎族',
      0x100: '岩石', 0x200: '鸟兽', 0x400: '植物', 0x800: '昆虫',
      0x1000: '雷族', 0x2000: '龙', 0x4000: '兽', 0x8000: '兽战士',
      0x10000: '恐龙', 0x20000: '鱼', 0x40000: '海龙', 0x80000: '爬虫类',
      0x100000: '念动力', 0x200000: '幻神', 0x400000: '创造神',
      0x800000: '幻龙', 0x1000000: '电子界', 0x2000000: '幻兽神',
    };
    return races[race] ?? '未知';
  }
}

/// 消息处理回调函数类型
///
/// 用于异步处理游戏消息。
///
/// [pduel]: duel 句柄
/// [msgType]: 消息类型
///
/// 返回值: 包含处理结果状态码的 Future<int>
typedef MessageHandler = Future<int> Function(int pduel, int msgType);

// ---------------------------------------------------------------------------
// 创建 OcgCore 实例
// ---------------------------------------------------------------------------

/// 创建 OcgCore 实例
///
/// 根据当前平台返回对应的适配器实例：
/// - Android: 使用原生 FFI 适配器
/// - macOS: 使用原生 FFI 适配器
/// - iOS: 使用原生 FFI 适配器
/// - Linux: 使用原生 FFI 适配器
/// - Windows: 使用原生 FFI 适配器
/// - 其他平台: 返回 null
///
/// 使用示例：
/// ```dart
/// final ocgCore = createOcgCore();
/// if (ocgCore != null) {
///   // 使用 ocgCore
/// }
/// ```
Future<OcgCore?> createOcgCore([ffi.DynamicLibrary? lib]) async {
  if (Platform.isAndroid ||
      Platform.isMacOS ||
      Platform.isIOS ||
      Platform.isLinux ||
      Platform.isWindows)  {
    var ocgCoreNativeAdapter = OcgCoreNativeAdapter();
    ocgCoreNativeAdapter.initialize(lib);
    return ocgCoreNativeAdapter;
  } else {
    return null;
  }
}

/// OcgCore 引擎适配器的抽象基类
///
/// 所有平台适配器（原生 FFI、WASM JS-interop）都实现此接口，
/// 使得上层代码可以与任何后端一起工作。
///
/// 所有缓冲区参数使用 `Uint8List`（由调用方预分配）。
///
/// 使用流程：
/// 1. 设置回调函数：[setScriptReader]、[setCardReader]、[setMessageHandler]
/// 2. 创建 Duel：调用 [createDuel] 或 [createDuelV2]
/// 3. 设置玩家：调用 [setPlayerInfo]
/// 4. 添加卡牌：使用 [newCard]
/// 5. 开始决斗：调用 [startDuel]
/// 6. 游戏循环：循环调用 [process] 和 [getMessage]
/// 7. 响应询问：根据消息类型调用 [setResponsei] 或 [setResponseb]
/// 8. 查询状态：使用 [queryCard] 等函数
/// 9. 结束决斗：调用 [endDuel]
abstract class OcgCore {
  // ---------------------------------------------------------------------------
  // 回调设置函数
  // ---------------------------------------------------------------------------

  /// 设置脚本读取回调函数
  ///
  /// [f]: ScriptReader 类型的异步回调函数，为 null 时使用默认实现
  void setScriptReader(ScriptReader? f);

  /// 设置卡牌数据读取回调函数
  ///
  /// [f]: CardReader 类型的异步回调函数，为 null 时使用默认实现
  void setCardReader(CardReader? f);

  /// 设置消息处理回调函数
  ///
  /// [f]: MessageHandler 类型的回调函数，为 null 时使用默认实现
  void setMessageHandler(MessageHandler? f);

  // ---------------------------------------------------------------------------
  // Duel 生命周期
  // ---------------------------------------------------------------------------

  /// 创建一个 duel 实例（v1 版本）
  ///
  /// 使用单个 [seed] 初始化随机数生成器。
  ///
  /// [seed]: 32 位随机种子
  ///
  /// 返回值: duel 句柄（int），失败返回 0
  int createDuel(int seed);

  /// 创建一个 duel 实例（v2 版本）
  ///
  /// 使用 8 元素的种子序列初始化随机数生成器。
  ///
  /// [seeds]: 随机种子序列数组，长度应为 [SEED_COUNT]（8）
  ///
  /// 返回值: duel 句柄（int），失败返回 0
  int createDuelV2(Uint32List seeds);

  /// 开始决斗
  ///
  /// 在调用此方法前，需要先设置玩家信息和添加卡牌。
  ///
  /// [pduel]: duel 句柄
  /// [options]: 决斗选项标志位，参见 [DUEL_TEST_MODE]、[DUEL_ATTACK_FIRST_TURN] 等常量
  void startDuel(int pduel, int options);

  /// 结束并销毁 duel 实例
  ///
  /// 释放所有与该 duel 相关的资源。
  ///
  /// [pduel]: duel 句柄
  void endDuel(int pduel);

  // ---------------------------------------------------------------------------
  // 玩家信息设置
  // ---------------------------------------------------------------------------

  /// 设置玩家初始信息
  ///
  /// 在开始决斗前，需要为双方玩家调用此方法。
  ///
  /// [pduel]: duel 句柄
  /// [playerid]: 玩家 ID（0 或 1）
  /// [lp]: 初始生命值
  /// [startCount]: 初始手牌数量
  /// [drawCount]: 每回合抽牌数量
  void setPlayerInfo(
    int pduel,
    int playerid,
    int lp,
    int startCount,
    int drawCount,
  );

  // ---------------------------------------------------------------------------
  // 卡牌操作
  // ---------------------------------------------------------------------------

  /// 在场上创建一张卡牌
  ///
  /// [pduel]: duel 句柄
  /// [code]: 卡牌编号
  /// [owner]: 卡牌所有者（0 或 1）
  /// [playerid]: 控制玩家（0 或 1）
  /// [location]: 卡牌位置，参见 [LOCATION_DECK]、[LOCATION_HAND] 等常量
  /// [sequence]: 位置序号
  /// [position]: 卡牌状态，参见 [POS_FACEUP_ATTACK]、[POS_FACEDOWN_DEFENSE] 等常量
  void newCard(
    int pduel,
    int code,
    int owner,
    int playerid,
    int location,
    int sequence,
    int position,
  );

  /// 创建一张标签卡牌（用于衍生物等）
  ///
  /// [pduel]: duel 句柄
  /// [code]: 卡牌编号
  /// [owner]: 卡牌所有者（0 或 1）
  /// [location]: 卡牌位置
  void newTagCard(int pduel, int code, int owner, int location);

  // ---------------------------------------------------------------------------
  // 游戏流程
  // ---------------------------------------------------------------------------

  /// 处理游戏流程，执行一步操作
  ///
  /// 返回值: 处理结果状态码，参见 [PROCESSOR_NONE]、[PROCESSOR_WAITING]、[PROCESSOR_END] 等常量
  ///
  /// [pduel]: duel 句柄
  int process(int pduel);

  /// 获取游戏消息
  ///
  /// 将消息数据写入 [out] 缓冲区。
  ///
  /// [pduel]: duel 句柄
  /// [out]: 输出缓冲区，用于存储消息数据
  ///
  /// 返回值: 消息长度（[LEN_FAIL]=0 表示失败）
  int getMessage(int pduel, Uint8List out);

  /// 获取日志消息
  ///
  /// [pduel]: duel 句柄
  ///
  /// 返回值: 日志消息字符串
  String getLogMessage(int pduel);

  // ---------------------------------------------------------------------------
  // 查询函数
  // ---------------------------------------------------------------------------

  /// 查询指定位置的卡牌数量
  ///
  /// [pduel]: duel 句柄
  /// [playerid]: 玩家 ID（0 或 1）
  /// [location]: 卡牌位置
  ///
  /// 返回值: 卡牌数量
  int queryFieldCount(int pduel, int playerid, int location);

  /// 查询指定位置的卡牌信息
  ///
  /// 将查询结果写入 [out] 缓冲区。
  ///
  /// [pduel]: duel 句柄
  /// [playerid]: 玩家 ID（0 或 1）
  /// [location]: 卡牌位置
  /// [sequence]: 位置序号
  /// [queryFlag]: 查询标志位，参见 [QUERY_CODE]、[QUERY_TYPE] 等常量
  /// [out]: 输出缓冲区
  /// [useCache]: 是否使用缓存（0 或 1）
  ///
  /// 返回值: 查询到的数据长度
  int queryCard(
    int pduel,
    int playerid,
    int location,
    int sequence,
    int queryFlag,
    Uint8List out,
    int useCache,
  );

  /// 查询场上所有卡牌的信息
  ///
  /// 将查询结果写入 [out] 缓冲区。
  ///
  /// [pduel]: duel 句柄
  /// [playerid]: 玩家 ID（0 或 1）
  /// [location]: 卡牌位置
  /// [queryFlag]: 查询标志位
  /// [out]: 输出缓冲区
  /// [useCache]: 是否使用缓存
  ///
  /// 返回值: 查询到的数据长度
  int queryFieldCard(
    int pduel,
    int playerid,
    int location,
    int queryFlag,
    Uint8List out,
    int useCache,
  );

  /// 查询整个场地的信息
  ///
  /// 将查询结果写入 [out] 缓冲区。
  ///
  /// [pduel]: duel 句柄
  /// [out]: 输出缓冲区
  ///
  /// 返回值: 查询到的数据长度
  int queryFieldInfo(int pduel, Uint8List out);

  // ---------------------------------------------------------------------------
  // 响应函数
  // ---------------------------------------------------------------------------

  /// 设置整数类型的响应（用于处理游戏询问）
  ///
  /// [pduel]: duel 句柄
  /// [value]: 响应值
  void setResponsei(int pduel, int value);

  /// 设置字节数组类型的响应（用于处理游戏询问）
  ///
  /// [pduel]: duel 句柄
  /// [data]: 响应数据缓冲区
  void setResponseb(int pduel, Uint8List data);

  // ---------------------------------------------------------------------------
  // 脚本预加载
  // ---------------------------------------------------------------------------

  /// 预加载指定脚本文件
  ///
  /// [pduel]: duel 句柄
  /// [name]: 脚本文件名
  ///
  /// 返回值: 预加载结果状态码
  int preloadScript(int pduel, String name);

  /// 默认的脚本读取器实现
  ///
  /// 从文件系统读取脚本文件。
  ///
  /// [scriptName]: 脚本文件名
  /// [len]: 输出参数，返回数据长度
  ///
  /// 返回值: 指向脚本数据的 Uint8List
  Uint8List? defaultScriptReader(String scriptName, List<int> len);

  /// 异步预加载脚本数据到缓存
  ///
  /// 在调用 [process] 之前使用此方法预加载脚本，确保 FFI 回调能从缓存读取。
  ///
  /// [name]: 脚本文件名
  Future<void> preloadScriptAsync(String name);

  /// 异步预加载卡片数据到缓存
  ///
  /// 在调用 [process] 之前使用此方法预加载卡片数据，确保 FFI 回调能从缓存读取。
  ///
  /// [code]: 卡片编号
  Future<void> preloadCardAsync(int code);
}