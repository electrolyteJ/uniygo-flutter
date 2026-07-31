/// Ygopro 协议标识声明。
///
/// 定义了客户端到服务端（CtoS）、服务端到客户端（StoC）
/// 以及决斗对局内（Game Message）的所有协议命令号。
///
/// 参考 neos-ts 的 protoDecl.ts 定义。

// ============================================================================
// Protocol IDs — Client-to-Server（客户端发送到服务端的协议标识）
// ============================================================================
const int CTOS_RESPONSE = 1;
const int CTOS_UPDATE_DECK = 2;
const int CTOS_HAND_RESULT = 3;
const int CTOS_TP_RESULT = 4;
const int CTOS_PLAYER_INFO = 16;
const int CTOS_JOIN_GAME = 18;
const int CTOS_TIME_CONFIRM = 21;
const int CTOS_CHAT = 22;
/// CTOS_SURRENDER: 0x14 (20), 与 ygopro 服务端保留一致
const int CTOS_SURRENDER = 0x14;
const int CTOS_HS_TO_DUELIST = 32;
const int CTOS_HS_TO_OBSERVER = 33;
const int CTOS_HS_READY = 34;
const int CTOS_HS_NOT_READY = 35;
const int CTOS_HS_KICK = 36;
const int CTOS_HS_START = 37;

// ============================================================================
// Protocol IDs — Server-to-Client（服务端发送到客户端的协议标识）
// ============================================================================
const int STOC_GAME_MSG = 1;
const int STOC_ERROR_MSG = 2;
const int STOC_SELECT_HAND = 3;
const int STOC_SELECT_TP = 4;
const int STOC_HAND_RESULT = 5;
const int STOC_CHANGE_SIDE = 7;
const int STOC_WAITING_SIDE = 8;
const int STOC_DECK_COUNT = 9;
const int STOC_JOIN_GAME = 18;
const int STOC_TYPE_CHANGE = 19;
const int STOC_DUEL_START = 21;
const int STOC_DUEL_END = 22;
const int STOC_TIME_LIMIT = 24;
const int STOC_CHAT = 25;
const int STOC_HS_PLAYER_ENTER = 32;
const int STOC_HS_PLAYER_CHANGE = 33;
const int STOC_HS_WATCH_CHANGE = 34;

// ============================================================================
// Game Message sub-types（决斗对局内的子消息类型）
// ============================================================================

// ---- 基础流程消息 ----
const int MSG_RESPONSE = 1;
/// MSG_HINT: 服务端提示/描述文字
const int MSG_HINT = 2;
/// MSG_WAITING: 等待对手操作
const int MSG_WAITING = 3;
/// MSG_START: 对局开始，包含先/后攻信息与初始 LP、卡组数量
const int MSG_START = 4;
/// MSG_WIN: 胜负判定
const int MSG_WIN = 5;
/// MSG_UPDATE_DATA: 卡牌数据更新（flag 驱动，异步）
const int MSG_UPDATE_DATA = 6;
/// MSG_UPDATE_CARD: 单张卡牌数据更新
const int MSG_UPDATE_CARD = 7;

// ---- 交互选择消息 ----
/// MSG_SELECT_BATTLE_CMD: 选择战斗阶段指令
const int MSG_SELECT_BATTLE_CMD = 10;
/// MSG_SELECT_IDLE_CMD: 选择主阶段空闲指令（召唤、盖放、发动效果等动作可选列表）
const int MSG_SELECT_IDLE_CMD = 11;
/// MSG_SELECT_EFFECTYN: 选择是否发动效果
const int MSG_SELECT_EFFECTYN = 12;
/// MSG_SELECT_YES_NO: 选择是/否
const int MSG_SELECT_YES_NO = 13;
/// MSG_SELECT_OPTION: 选项选择（多选项）
const int MSG_SELECT_OPTION = 14;
/// MSG_SELECT_CARD: 选卡（单张或多张）
const int MSG_SELECT_CARD = 15;
/// MSG_SELECT_CHAIN: 选择连锁
const int MSG_SELECT_CHAIN = 16;
/// MSG_SELECT_PLACE: 选位置（不指定区域）
const int MSG_SELECT_PLACE = 18;
/// MSG_SELECT_POSITION: 选表示形式
const int MSG_SELECT_POSITION = 19;
/// MSG_SELECT_TRIBUTE: 选择解放素材
const int MSG_SELECT_TRIBUTE = 20;
/// MSG_SELECT_COUNTER: 选择计数器
const int MSG_SELECT_COUNTER = 22;
/// MSG_SELECT_SUM: 选择合计数值
const int MSG_SELECT_SUM = 23;
/// MSG_SELECT_DISFIELD: 禁止选卡位（区域禁用显示）
const int MSG_SELECT_DISFIELD = 24;
/// MSG_SORT_CARD: 排卡序
const int MSG_SORT_CARD = 25;
/// MSG_SELECT_UNSELECT_CARD: 反选卡
const int MSG_SELECT_UNSELECT_CARD = 26;

// ---- 卡牌信息消息 ----
/// MSG_CONFIRM_CARDS: 确认卡牌（展示卡片列表）
const int MSG_CONFIRM_CARDS = 30;
/// MSG_CONFIRM_DECKTOP: 确认卡组顶部卡片
const int MSG_CONFIRM_DECKTOP = 31;

// ---- 洗牌消息 ----
/// MSG_SHUFFLE_DECK: 洗主卡组
const int MSG_SHUFFLE_DECK = 32;
/// MSG_SHUFFLE_HAND: 洗手牌
const int MSG_SHUFFLE_HAND = 33;
const int MSG_SWAP_GRAVE_DECK = 35;
/// MSG_SHUFFLE_SET_CARD: 盖放卡位置随机交换
const int MSG_SHUFFLE_SET_CARD = 36;
/// MSG_SHUFFLE_EXTRA: 洗额外卡组
const int MSG_SHUFFLE_EXTRA = 39;

// ---- 回合/阶段消息 ----
/// MSG_NEW_TURN: 新回合
const int MSG_NEW_TURN = 40;
/// MSG_NEW_PHASE: 新阶段
const int MSG_NEW_PHASE = 41;

// ---- 卡牌移动/状态消息 ----
/// MSG_MOVE: 卡牌位置移动
const int MSG_MOVE = 50;
/// MSG_POS_CHANGE: 卡牌表示形式变化
const int MSG_POS_CHANGE = 53;
/// MSG_SET: 盖卡
const int MSG_SET = 54;
/// MSG_SWAP: 场上的两张卡交换位置
const int MSG_SWAP = 55;
/// MSG_FIELD_DISABLED: 区域禁用（不能使用某些区域）
const int MSG_FIELD_DISABLED = 56;

// ---- 召唤消息 ----
/// MSG_SUMMONING: 通常召唤宣言（code + 位置）
const int MSG_SUMMONING = 60;
/// MSG_SUMMONED: 通常召唤完成通知
const int MSG_SUMMONED = 61;
/// MSG_SP_SUMMONING: 特殊召唤宣言
const int MSG_SP_SUMMONING = 62;
/// MSG_SP_SUMMONED: 特殊召唤完成通知
const int MSG_SP_SUMMONED = 63;
/// MSG_FLIP_SUMMONING: 反转召唤宣言
const int MSG_FLIP_SUMMONING = 64;
/// MSG_FLIP_SUMMONED: 反转召唤完成通知
const int MSG_FLIP_SUMMONED = 65;

// ---- 连锁消息 ----
/// MSG_CHAINING: 连锁开始
const int MSG_CHAINING = 70;
/// MSG_CHAIN_SOLVED: 连锁逆解中（单步处理）
const int MSG_CHAIN_SOLVED = 73;
/// MSG_CHAIN_END: 连锁结束
const int MSG_CHAIN_END = 74;

// ---- 效果/目标 ----
/// MSG_BECOME_TARGET: 成为效果对象
const int MSG_BECOME_TARGET = 83;

// ---- 抽牌/LP/伤害 ----
/// MSG_DRAW: 抽牌
const int MSG_DRAW = 90;
/// MSG_DAMAGE: 效果伤害
const int MSG_DAMAGE = 91;
/// MSG_RECOVER: LP 恢复
const int MSG_RECOVER = 92;
/// MSG_LP_UPDATE: LP 变化通知（用于 Damage+Recover 合并后的更新）
const int MSG_LP_UPDATE = 94;
/// MSG_PAY_LP_COST: 支付 LP 代价
const int MSG_PAY_LP_COST = 100;

// ---- 计数器 ----
/// MSG_ADD_COUNTER: 添加计数器
const int MSG_ADD_COUNTER = 101;
/// MSG_REMOVE_COUNTER: 移除计数器
const int MSG_REMOVE_COUNTER = 102;

// ---- 战斗 ----
/// MSG_ATTACK: 攻击宣言（全零 target = 直接攻击）
const int MSG_ATTACK = 110;
/// MSG_ATTACK_DISABLE: 攻击无效/无法攻击
const int MSG_ATTACK_DISABLE = 112;

// ---- 随机 ----
/// MSG_TOSS_COIN: 掷硬币
const int MSG_TOSS_COIN = 130;
/// MSG_TOSS_DICE: 掷骰子
const int MSG_TOSS_DICE = 131;
/// MSG_ROCK_PAPER_SCISSORS: 猜拳
const int MSG_ROCK_PAPER_SCISSORS = 132;
/// MSG_HAND_RES: 猜拳结果
const int MSG_HAND_RES = 133;

// ---- 宣言 ----
/// MSG_ANNOUNCE_RACE: 宣言种族
const int MSG_ANNOUNCE_RACE = 140;
/// MSG_ANNOUNCE_ATTRIB: 宣言属性
const int MSG_ANNOUNCE_ATTRIB = 141;
/// MSG_ANNOUNCE_CARD: 宣言卡名
const int MSG_ANNOUNCE_CARD = 142;
/// MSG_ANNOUNCE_NUMBER: 宣言数值
const int MSG_ANNOUNCE_NUMBER = 143;

// ---- 其他 ----
/// MSG_RELOAD_FIELD: 刷新整个场地（含卡组状态）
const int MSG_RELOAD_FIELD = 162;
/// MSG_SIBYL_NAME: 神托/占卜选名
const int MSG_SIBYL_NAME = 235;

// ============================================================================
// 域枚举与位掩码常量
// ============================================================================

// HandType enum values（猜拳类型）
const int HAND_TYPE_UNKNOWN = 0;
const int HAND_TYPE_SCISSORS = 1;
const int HAND_TYPE_ROCK = 2;
const int HAND_TYPE_PAPER = 3;

// CardZone hex values（卡牌区域标识，与 ygopro 核心一致）
const int CARD_ZONE_DECK = 0x01;
const int CARD_ZONE_HAND = 0x02;
const int CARD_ZONE_MZONE = 0x04;
const int CARD_ZONE_SZONE = 0x08;
const int CARD_ZONE_GRAVE = 0x10;
const int CARD_ZONE_REMOVED = 0x20;
const int CARD_ZONE_EXTRA = 0x40;
const int CARD_ZONE_ONFIELD = 0x0c; // MZONE | SZONE
const int CARD_ZONE_FZONE = 0x100;
const int CARD_ZONE_PZONE = 0x200;
const int CARD_ZONE_TZONE = 0x300;
/// LOCATION_OVERLAY: 超量素材标记，写入 location 字段即表示该卡为叠放素材
const int LOCATION_OVERLAY = 0x80;

// CardPosition bitfield values（卡牌表示形式位掩码）
const int POS_FACEUP_ATTACK = 0x1;
const int POS_FACEDOWN_ATTACK = 0x2;
const int POS_FACEUP_DEFENSE = 0x4;
const int POS_FACEDOWN_DEFENSE = 0x8;
const int POS_FACEUP = 0x5;
const int POS_FACEDOWN = 0xa;
const int POS_ATTACK = 0x3;
const int POS_DEFENSE = 0xc;

// HsPlayerChange states（等待房间玩家状态变更标识）
const int HS_PLAYER_STATE_MOVE = 0;
const int HS_PLAYER_STATE_READY = 1;
const int HS_PLAYER_STATE_NO_READY = 2;
const int HS_PLAYER_STATE_LEAVE = 3;
const int HS_PLAYER_STATE_TO_OBSERVER = 4;

// Error types（服务端错误类型）
const int ERROR_TYPE_JOIN = 0;
const int ERROR_TYPE_DECK = 1;
const int ERROR_TYPE_SIDE = 2;
const int ERROR_TYPE_VERSION = 3;

// Self types（自身玩家类型）
const int SELF_TYPE_PLAYER1 = 0;
const int SELF_TYPE_PLAYER2 = 1;
const int SELF_TYPE_OBSERVER = 7;

// Update action flags（UPDATE_DATA 的 flag 位掩码，决定后续读取哪些字段）
const int UPDATE_FLAG_CODE = 0x1;
const int UPDATE_FLAG_POSITION = 0x2;
const int UPDATE_FLAG_ALIAS = 0x4;
const int UPDATE_FLAG_TYPE = 0x8;
const int UPDATE_FLAG_LEVEL = 0x10;
const int UPDATE_FLAG_RANK = 0x20;
const int UPDATE_FLAG_ATTRIBUTE = 0x40;
const int UPDATE_FLAG_RACE = 0x80;
const int UPDATE_FLAG_ATTACK = 0x100;
const int UPDATE_FLAG_DEFENSE = 0x200;
const int UPDATE_FLAG_BASE_ATTACK = 0x400;
const int UPDATE_FLAG_BASE_DEFENSE = 0x800;
const int UPDATE_FLAG_REASON = 0x1000;
const int UPDATE_FLAG_REASON_CARD = 0x2000;
const int UPDATE_FLAG_EQUIP_CARD = 0x4000;
const int UPDATE_FLAG_TARGET_CARD = 0x8000;
const int UPDATE_FLAG_OVERLAY_CARD = 0x10000;
const int UPDATE_FLAG_COUNTERS = 0x20000;
const int UPDATE_FLAG_OWNER = 0x40000;
const int UPDATE_FLAG_STATUS = 0x80000;
const int UPDATE_FLAG_LSCALE = 0x100000;
const int UPDATE_FLAG_RSCALE = 0x200000;
const int UPDATE_FLAG_LINK = 0x400000;

// Phase values（阶段值，支持位掩码组合）
const int PHASE_DRAW = 0x01;
const int PHASE_STANDBY = 0x02;
const int PHASE_MAIN1 = 0x04;
const int PHASE_BATTLE_START = 0x08;
const int PHASE_BATTLE_STEP = 0x10;
const int PHASE_DAMAGE = 0x20;
const int PHASE_DAMAGE_CAL = 0x40;
const int PHASE_BATTLE = 0x80;
const int PHASE_MAIN2 = 0x100;
const int PHASE_END = 0x200;

// Hint commands（Hint 消息中的提示类型）
const int HINT_EVENT = 1;
const int HINT_MESSAGE = 2;
const int HINT_SELECTMSG = 3;
const int HINT_OPSELECTED = 4;
const int HINT_EFFECT = 5;
const int HINT_RACE = 6;
const int HINT_ATTRIB = 7;
const int HINT_CODE = 8;
const int HINT_NUMBER = 9;
const int HINT_CARD = 10;
const int HINT_ZONE = 11;
