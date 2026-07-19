# OCGCore API 接口文档

## 概述

OCGCore 是游戏王卡牌对战引擎的核心库，提供卡牌游戏的逻辑处理能力。本文档描述其导出的 C 接口。

## 常量定义

### 基础常量

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `SEED_COUNT` | 8 | 随机种子序列长度 |
| `LEN_FAIL` | 0 | 操作失败时的数据长度 |
| `LEN_EMPTY` | 4 | 空数据时的最小长度 |
| `LEN_HEADER` | 8 | 消息头部长度 |
| `TEMP_CARD_ID` | 0 | 临时卡牌 ID |

### 操作结果常量

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `OPERATION_SUCCESS` | 1 | 操作成功 |
| `OPERATION_FAIL` | 0 | 操作失败 |
| `OPERATION_CANCELED` | -1 | 操作被取消 |
| `TRUE` | 1 | 真 |
| `FALSE` | 0 | 假 |

### 缓冲区大小常量

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `SIZE_MESSAGE_BUFFER` | 0x2000 | 消息缓冲区大小 |
| `SIZE_RETURN_VALUE` | 512 | 返回值缓冲区大小 |
| `SIZE_AI_NAME` | 128 | AI 名称最大长度 |
| `SIZE_HINT_MSG` | 1024 | 提示消息最大长度 |
| `SIZE_SETCODE` | 16 | 卡组代码数组长度 |

### 处理器状态常量

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `PROCESSOR_BUFFER_LEN` | 0x0fffffff | 处理器缓冲区长度 |
| `PROCESSOR_FLAG` | 0xf0000000 | 处理器状态标志位掩码 |
| `PROCESSOR_NONE` | 0 | 无状态 |
| `PROCESSOR_WAITING` | 0x10000000 | 等待中 |
| `PROCESSOR_END` | 0x20000000 | 决斗结束 |

### 大师规则常量

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `MASTER_RULE3` | 3 | Master Rule 3 (2014) |
| `NEW_MASTER_RULE` | 4 | New Master Rule (2017) |
| `MASTER_RULE_2020` | 5 | Master Rule 2020 |
| `CURRENT_RULE` | 5 | 当前使用的规则 |

## 类型定义

### 基础类型

- `byte`: 无符号 8 位整数 (`unsigned char`)
- `uint32_t`: 无符号 32 位整数
- `int32_t`: 有符号 32 位整数
- `uint_fast32_t`: 快速无符号 32 位整数
- `intptr_t`: 指针大小的整数类型，用于存储 duel 句柄

### 结构体

#### card_data

```c
struct card_data {
    uint32_t code;           // 卡牌编号
    uint32_t alias;          // 别名卡牌编号
    uint16_t setcode[16];    // 卡组代码数组
    uint32_t type;           // 卡牌类型
    uint32_t level;          // 等级/阶级
    uint32_t attribute;      // 属性
    uint32_t race;           // 种族
    int32_t attack;          // 攻击力
    int32_t defense;         // 守备力
    uint32_t lscale;         // 左刻度（灵摆）
    uint32_t rscale;         // 右刻度（灵摆）
    uint32_t link_marker;    // 连接标记
    uint32_t rule_code;      // 规则代码（FFI 扩展字段）
};
```

**注意**: `rule_code` 字段仅在 `ocgcore_ffi.h` 中存在，是 FFI 绑定版本的扩展字段。原始 `card_data.h` 中不包含此字段。

## 位置常量 (Location)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `LOCATION_DECK` | 0x01U | 卡组 |
| `LOCATION_HAND` | 0x02U | 手牌 |
| `LOCATION_MZONE` | 0x04U | 怪兽区域 |
| `LOCATION_SZONE` | 0x08U | 魔法陷阱区域 |
| `LOCATION_GRAVE` | 0x10U | 墓地 |
| `LOCATION_REMOVED` | 0x20U | 除外区 |
| `LOCATION_EXTRA` | 0x40U | 额外卡组 |
| `LOCATION_OVERLAY` | 0x80U | XYZ 素材 |
| `LOCATION_ONFIELD` | 0x0CU | 场上（怪兽+魔法陷阱区域） |
| `LOCATION_FZONE` | 0x100U | 场地魔法区域 |
| `LOCATION_PZONE` | 0x200U | 灵摆区域 |
| `LOCATION_DECKBOT` | 0x10001 | 返回卡组底部 |
| `LOCATION_DECKSHF` | 0x20001 | 返回卡组并洗牌 |

### 卡组顺序常量

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `SEQ_DECKTOP` | 0 | 返回卡组顶部 |
| `SEQ_DECKBOTTOM` | 1 | 返回卡组底部 |
| `SEQ_DECKSHUFFLE` | 2 | 返回卡组并洗牌 |

## 表示位置常量 (Position)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `POS_FACEUP_ATTACK` | 0x1 | 表侧攻击表示 |
| `POS_FACEDOWN_ATTACK` | 0x2 | 里侧攻击表示 |
| `POS_FACEUP_DEFENSE` | 0x4 | 表侧守备表示 |
| `POS_FACEDOWN_DEFENSE` | 0x8 | 里侧守备表示 |
| `POS_FACEUP` | 0x5 | 表侧表示 |
| `POS_FACEDOWN` | 0xa | 里侧表示 |
| `POS_ATTACK` | 0x3 | 攻击表示 |
| `POS_DEFENSE` | 0xc | 守备表示 |
| `NO_FLIP_EFFECT` | 0x10000 | 无反转效果标志 |

## 卡牌类型常量 (Type)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `TYPE_MONSTER` | 0x1 | 怪兽卡 |
| `TYPE_SPELL` | 0x2 | 魔法卡 |
| `TYPE_TRAP` | 0x4 | 陷阱卡 |
| `TYPE_NORMAL` | 0x10 | 通常怪兽 |
| `TYPE_EFFECT` | 0x20 | 效果怪兽 |
| `TYPE_FUSION` | 0x40 | 融合怪兽 |
| `TYPE_RITUAL` | 0x80 | 仪式怪兽 |
| `TYPE_TRAPMONSTER` | 0x100 | 陷阱怪兽 |
| `TYPE_SPIRIT` | 0x200 | 灵魂怪兽 |
| `TYPE_UNION` | 0x400 | 同盟怪兽 |
| `TYPE_DUAL` | 0x800 | 二重怪兽 |
| `TYPE_TUNER` | 0x1000 | 调整怪兽 |
| `TYPE_SYNCHRO` | 0x2000 | 同调怪兽 |
| `TYPE_TOKEN` | 0x4000 | 衍生物 |
| `TYPE_QUICKPLAY` | 0x10000 | 速攻魔法 |
| `TYPE_CONTINUOUS` | 0x20000 | 永续魔法/陷阱 |
| `TYPE_EQUIP` | 0x40000 | 装备魔法 |
| `TYPE_FIELD` | 0x80000 | 场地魔法 |
| `TYPE_COUNTER` | 0x100000 | 反击陷阱 |
| `TYPE_FLIP` | 0x200000 | 反转怪兽 |
| `TYPE_TOON` | 0x400000 | 卡通怪兽 |
| `TYPE_XYZ` | 0x800000 | XYZ 怪兽 |
| `TYPE_PENDULUM` | 0x1000000 | 灵摆怪兽 |
| `TYPE_SPSUMMON` | 0x2000000 | 特殊召唤怪兽 |
| `TYPE_LINK` | 0x4000000 | 连接怪兽 |

| 组合常量 | 值 | 说明 |
|----------|-----|------|
| `TYPES_EXTRA_DECK` | 0x4640 | 额外卡组怪兽类型（融合+同调+XYZ+连接） |

## 属性常量 (Attribute)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `ATTRIBUTES_COUNT` | 7 | 属性数量 |
| `ATTRIBUTE_ALL` | 0x7f | 所有属性 |
| `ATTRIBUTE_EARTH` | 0x01 | 地属性 |
| `ATTRIBUTE_WATER` | 0x02 | 水属性 |
| `ATTRIBUTE_FIRE` | 0x04 | 炎属性 |
| `ATTRIBUTE_WIND` | 0x08 | 风属性 |
| `ATTRIBUTE_LIGHT` | 0x10 | 光属性 |
| `ATTRIBUTE_DARK` | 0x20 | 暗属性 |
| `ATTRIBUTE_DEVINE` | 0x40 | 神属性 |

## 种族常量 (Race)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `RACES_COUNT` | 26 | 种族数量 |
| `RACE_ALL` | 0x3ffffff | 所有种族 |
| `RACE_WARRIOR` | 0x1 | 战士族 |
| `RACE_SPELLCASTER` | 0x2 | 魔法师族 |
| `RACE_FAIRY` | 0x4 | 天使族 |
| `RACE_FIEND` | 0x8 | 恶魔族 |
| `RACE_ZOMBIE` | 0x10 | 不死族 |
| `RACE_MACHINE` | 0x20 | 机械族 |
| `RACE_AQUA` | 0x40 | 水族 |
| `RACE_PYRO` | 0x80 | 炎族 |
| `RACE_ROCK` | 0x100 | 岩石族 |
| `RACE_WINDBEAST` | 0x200 | 鸟兽族 |
| `RACE_PLANT` | 0x400 | 植物族 |
| `RACE_INSECT` | 0x800 | 昆虫族 |
| `RACE_THUNDER` | 0x1000 | 雷族 |
| `RACE_DRAGON` | 0x2000 | 龙族 |
| `RACE_BEAST` | 0x4000 | 兽族 |
| `RACE_BEASTWARRIOR` | 0x8000 | 兽战士族 |
| `RACE_DINOSAUR` | 0x10000 | 恐龙族 |
| `RACE_FISH` | 0x20000 | 鱼族 |
| `RACE_SEASERPENT` | 0x40000 | 海龙族 |
| `RACE_REPTILE` | 0x80000 | 爬虫类族 |
| `RACE_PSYCHO` | 0x100000 | 念动力族 |
| `RACE_DEVINE` | 0x200000 | 幻神族 |
| `RACE_CREATORGOD` | 0x400000 | 创造神族 |
| `RACE_WYRM` | 0x800000 | 幻龙族 |
| `RACE_CYBERSE` | 0x1000000 | 电子界族 |
| `RACE_ILLUSION` | 0x2000000 | 幻兽神族 |

## 查询标志常量 (Query Flag)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `QUERY_CODE` | 0x1 | 查询卡牌编号 |
| `QUERY_POSITION` | 0x2 | 查询表示位置 |
| `QUERY_ALIAS` | 0x4 | 查询别名 |
| `QUERY_TYPE` | 0x8 | 查询类型 |
| `QUERY_LEVEL` | 0x10 | 查询等级 |
| `QUERY_RANK` | 0x20 | 查询阶级 |
| `QUERY_ATTRIBUTE` | 0x40 | 查询属性 |
| `QUERY_RACE` | 0x80 | 查询种族 |
| `QUERY_ATTACK` | 0x100 | 查询攻击力 |
| `QUERY_DEFENSE` | 0x200 | 查询守备力 |
| `QUERY_BASE_ATTACK` | 0x400 | 查询基础攻击力 |
| `QUERY_BASE_DEFENSE` | 0x800 | 查询基础守备力 |
| `QUERY_REASON` | 0x1000 | 查询原因 |
| `QUERY_REASON_CARD` | 0x2000 | 查询原因卡 |
| `QUERY_EQUIP_CARD` | 0x4000 | 查询装备卡 |
| `QUERY_TARGET_CARD` | 0x8000 | 查询目标卡 |
| `QUERY_OVERLAY_CARD` | 0x10000 | 查询 XYZ 素材 |
| `QUERY_COUNTERS` | 0x20000 | 查询计数器 |
| `QUERY_OWNER` | 0x40000 | 查询所有者 |
| `QUERY_STATUS` | 0x80000 | 查询状态 |
| `QUERY_LSCALE` | 0x200000 | 查询左刻度 |
| `QUERY_RSCALE` | 0x400000 | 查询右刻度 |
| `QUERY_LINK` | 0x800000 | 查询连接标记 |

## 连接标记常量 (Link Marker)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `LINK_MARKER_BOTTOM_LEFT` | 0x001 | 左下 |
| `LINK_MARKER_BOTTOM` | 0x002 | 下 |
| `LINK_MARKER_BOTTOM_RIGHT` | 0x004 | 右下 |
| `LINK_MARKER_LEFT` | 0x008 | 左 |
| `LINK_MARKER_RIGHT` | 0x020 | 右 |
| `LINK_MARKER_TOP_LEFT` | 0x040 | 左上 |
| `LINK_MARKER_TOP` | 0x080 | 上 |
| `LINK_MARKER_TOP_RIGHT` | 0x100 | 右上 |

## 消息类型常量 (Message)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `MSG_RETRY` | 1 | 重试 |
| `MSG_HINT` | 2 | 提示 |
| `MSG_WIN` | 5 | 胜利 |
| `MSG_SELECT_BATTLECMD` | 10 | 选择战斗命令 |
| `MSG_SELECT_IDLECMD` | 11 | 选择空闲命令 |
| `MSG_SELECT_EFFECTYN` | 12 | 选择效果是否发动 |
| `MSG_SELECT_YESNO` | 13 | 选择是/否 |
| `MSG_SELECT_OPTION` | 14 | 选择选项 |
| `MSG_SELECT_CARD` | 15 | 选择卡牌 |
| `MSG_SELECT_CHAIN` | 16 | 选择连锁 |
| `MSG_SELECT_PLACE` | 18 | 选择位置 |
| `MSG_SELECT_POSITION` | 19 | 选择表示位置 |
| `MSG_SELECT_TRIBUTE` | 20 | 选择祭品 |
| `MSG_SELECT_COUNTER` | 22 | 选择计数器 |
| `MSG_SELECT_SUM` | 23 | 选择召唤方式 |
| `MSG_SELECT_DISFIELD` | 24 | 选择场地魔法 |
| `MSG_SORT_CARD` | 25 | 排序卡牌 |
| `MSG_SELECT_UNSELECT_CARD` | 26 | 选择/取消选择卡牌 |
| `MSG_CONFIRM_DECKTOP` | 30 | 确认卡组顶部 |
| `MSG_CONFIRM_CARDS` | 31 | 确认卡牌 |
| `MSG_SHUFFLE_DECK` | 32 | 洗卡组 |
| `MSG_SHUFFLE_HAND` | 33 | 洗手牌 |
| `MSG_SWAP_GRAVE_DECK` | 35 | 交换墓地和卡组 |
| `MSG_SHUFFLE_SET_CARD` | 36 | 洗牌组设定卡 |
| `MSG_REVERSE_DECK` | 37 | 反转卡组 |
| `MSG_DECK_TOP` | 38 | 卡组顶部 |
| `MSG_SHUFFLE_EXTRA` | 39 | 洗额外卡组 |
| `MSG_NEW_TURN` | 40 | 新回合 |
| `MSG_NEW_PHASE` | 41 | 新阶段 |
| `MSG_CONFIRM_EXTRATOP` | 42 | 确认额外卡组顶部 |
| `MSG_MOVE` | 50 | 移动 |
| `MSG_POS_CHANGE` | 53 | 表示形式变更 |
| `MSG_SET` | 54 | 放置 |
| `MSG_SWAP` | 55 | 交换 |
| `MSG_FIELD_DISABLED` | 56 | 场地无效 |
| `MSG_SUMMONING` | 60 | 召唤中 |
| `MSG_SUMMONED` | 61 | 已召唤 |
| `MSG_SPSUMMONING` | 62 | 特殊召唤中 |
| `MSG_SPSUMMONED` | 63 | 已特殊召唤 |
| `MSG_FLIPSUMMONING` | 64 | 反转召唤中 |
| `MSG_FLIPSUMMONED` | 65 | 已反转召唤 |
| `MSG_CHAINING` | 70 | 连锁中 |
| `MSG_CHAINED` | 71 | 已连锁 |
| `MSG_CHAIN_SOLVING` | 72 | 连锁处理中 |
| `MSG_CHAIN_SOLVED` | 73 | 连锁处理完毕 |
| `MSG_CHAIN_END` | 74 | 连锁结束 |
| `MSG_CHAIN_NEGATED` | 75 | 连锁被无效 |
| `MSG_CHAIN_DISABLED` | 76 | 连锁无效化 |
| `MSG_RANDOM_SELECTED` | 81 | 随机选择 |
| `MSG_BECOME_TARGET` | 83 | 成为目标 |
| `MSG_DRAW` | 90 | 抽卡 |
| `MSG_DAMAGE` | 91 | 伤害 |
| `MSG_RECOVER` | 92 | 回复 |
| `MSG_EQUIP` | 93 | 装备 |
| `MSG_LPUPDATE` | 94 | 生命值更新 |
| `MSG_CARD_TARGET` | 96 | 卡牌目标 |
| `MSG_CANCEL_TARGET` | 97 | 取消目标 |
| `MSG_PAY_LPCOST` | 100 | 支付生命值 |
| `MSG_ADD_COUNTER` | 101 | 添加计数器 |
| `MSG_REMOVE_COUNTER` | 102 | 移除计数器 |
| `MSG_ATTACK` | 110 | 攻击 |
| `MSG_BATTLE` | 111 | 战斗 |
| `MSG_ATTACK_DISABLED` | 112 | 攻击无效 |
| `MSG_DAMAGE_STEP_START` | 113 | 伤害步骤开始 |
| `MSG_DAMAGE_STEP_END` | 114 | 伤害步骤结束 |
| `MSG_MISSED_EFFECT` | 120 | 错过效果时机 |
| `MSG_TOSS_COIN` | 130 | 投掷硬币 |
| `MSG_TOSS_DICE` | 131 | 投掷骰子 |
| `MSG_ROCK_PAPER_SCISSORS` | 132 | 猜拳 |
| `MSG_HAND_RES` | 133 | 手牌结果 |
| `MSG_ANNOUNCE_RACE` | 140 | 宣言种族 |
| `MSG_ANNOUNCE_ATTRIB` | 141 | 宣言属性 |
| `MSG_ANNOUNCE_CARD` | 142 | 宣言卡牌 |
| `MSG_ANNOUNCE_NUMBER` | 143 | 宣言数值 |
| `MSG_CARD_HINT` | 160 | 卡牌提示 |
| `MSG_TAG_SWAP` | 161 | 双人对战切换 |
| `MSG_RELOAD_FIELD` | 162 | 重新加载场地 |
| `MSG_AI_NAME` | 163 | AI 名称 |
| `MSG_SHOW_HINT` | 164 | 显示提示 |
| `MSG_PLAYER_HINT` | 165 | 玩家提示 |
| `MSG_MATCH_KILL` | 170 | 一击必杀 |
| `MSG_CUSTOM_MSG` | 180 | 自定义消息 |

## 阶段常量 (Phase)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `PHASE_DRAW` | 0x01 | 抽卡阶段 |
| `PHASE_STANDBY` | 0x02 | 准备阶段 |
| `PHASE_MAIN1` | 0x04 | 主要阶段1 |
| `PHASE_BATTLE_START` | 0x08 | 战斗阶段开始 |
| `PHASE_BATTLE_STEP` | 0x10 | 战斗步骤 |
| `PHASE_DAMAGE` | 0x20 | 伤害步骤 |
| `PHASE_DAMAGE_CAL` | 0x40 | 伤害计算 |
| `PHASE_BATTLE` | 0x80 | 战斗阶段 |
| `PHASE_MAIN2` | 0x100 | 主要阶段2 |
| `PHASE_END` | 0x200 | 结束阶段 |

## 决斗选项常量 (Options)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `DUEL_TEST_MODE` | 0x01 | 测试模式 |
| `DUEL_ATTACK_FIRST_TURN` | 0x02 | 第一回合可攻击 |
| `DUEL_OBSOLETE_RULING` | 0x08 | 使用旧规则 |
| `DUEL_PSEUDO_SHUFFLE` | 0x10 | 伪随机洗牌 |
| `DUEL_TAG_MODE` | 0x20 | 双人对战模式 |
| `DUEL_SIMPLE_AI` | 0x40 | 简单 AI |
| `DUEL_RETURN_DECK_TOP` | 0x80 | 返回卡组顶部 |
| `DUEL_REVEAL_DECK_SEQ` | 0x100 | 显示卡组顺序 |

## 原因常量 (Reason)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `REASON_DESTROY` | 0x1 | 破坏 |
| `REASON_RELEASE` | 0x2 | 解放 |
| `REASON_TEMPORARY` | 0x4 | 临时 |
| `REASON_MATERIAL` | 0x8 | 素材 |
| `REASON_SUMMON` | 0x10 | 召唤 |
| `REASON_BATTLE` | 0x20 | 战斗 |
| `REASON_EFFECT` | 0x40 | 效果 |
| `REASON_COST` | 0x80 | 代价 |
| `REASON_ADJUST` | 0x100 | 调整 |
| `REASON_LOST_TARGET` | 0x200 | 失去目标 |
| `REASON_RULE` | 0x400 | 规则 |
| `REASON_SPSUMMON` | 0x800 | 特殊召唤 |
| `REASON_DISSUMMON` | 0x1000 | 解除召唤 |
| `REASON_FLIP` | 0x2000 | 反转 |
| `REASON_DISCARD` | 0x4000 | 丢弃 |
| `REASON_RDAMAGE` | 0x8000 | 伤害 |
| `REASON_RRECOVER` | 0x10000 | 回复 |
| `REASON_RETURN` | 0x20000 | 返回 |
| `REASON_FUSION` | 0x40000 | 融合 |
| `REASON_SYNCHRO` | 0x80000 | 同调 |
| `REASON_RITUAL` | 0x100000 | 仪式 |
| `REASON_XYZ` | 0x200000 | XYZ |
| `REASON_REPLACE` | 0x1000000 | 替换 |
| `REASON_DRAW` | 0x2000000 | 抽卡 |
| `REASON_REDIRECT` | 0x4000000 | 重定向 |
| `REASON_REVEAL` | 0x8000000 | 展示 |
| `REASON_LINK` | 0x10000000 | 连接 |
| `REASON_LOST_OVERLAY` | 0x20000000 | 失去素材 |
| `REASON_MAINTENANCE` | 0x40000000 | 维护 |
| `REASON_ACTION` | 0x80000000 | 动作 |

| 组合常量 | 值 | 说明 |
|----------|-----|------|
| `REASONS_PROCEDURE` | 0xa80000 | 特殊召唤流程（同调+XYZ+连接） |

## 状态常量 (Status)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `STATUS_DISABLED` | 0x0001 | 已禁用 |
| `STATUS_TO_ENABLE` | 0x0002 | 待启用 |
| `STATUS_TO_DISABLE` | 0x0004 | 待禁用 |
| `STATUS_PROC_COMPLETE` | 0x0008 | 处理完成 |
| `STATUS_SET_TURN` | 0x0010 | 放置回合 |
| `STATUS_NO_LEVEL` | 0x0020 | 无等级 |
| `STATUS_BATTLE_RESULT` | 0x0040 | 战斗结果 |
| `STATUS_SPSUMMON_STEP` | 0x0080 | 特殊召唤步骤 |
| `STATUS_CANNOT_CHANGE_FORM` | 0x0100 | 不能变更表示形式 |
| `STATUS_SUMMONING` | 0x0200 | 召唤中 |
| `STATUS_EFFECT_ENABLED` | 0x0400 | 效果已启用 |
| `STATUS_SUMMON_TURN` | 0x0800 | 召唤回合 |
| `STATUS_DESTROY_CONFIRMED` | 0x1000 | 破坏已确认 |
| `STATUS_LEAVE_CONFIRMED` | 0x2000 | 离场已确认 |
| `STATUS_BATTLE_DESTROYED` | 0x4000 | 战斗破坏 |
| `STATUS_COPYING_EFFECT` | 0x8000 | 复制效果中 |
| `STATUS_CHAINING` | 0x10000 | 连锁中 |
| `STATUS_SUMMON_DISABLED` | 0x20000 | 召唤被禁用 |
| `STATUS_ACTIVATE_DISABLED` | 0x40000 | 发动被禁用 |
| `STATUS_EFFECT_REPLACED` | 0x80000 | 效果已替换 |
| `STATUS_FLIP_SUMMONING` | 0x100000 | 反转召唤中 |
| `STATUS_ATTACK_CANCELED` | 0x200000 | 攻击已取消 |
| `STATUS_INITIALIZING` | 0x400000 | 初始化中 |
| `STATUS_TO_HAND_WITHOUT_CONFIRM` | 0x800000 | 不确认回手 |
| `STATUS_JUST_POS` | 0x1000000 | 刚变更位置 |
| `STATUS_CONTINUOUS_POS` | 0x2000000 | 持续位置 |
| `STATUS_FORBIDDEN` | 0x4000000 | 禁止 |
| `STATUS_ACT_FROM_HAND` | 0x8000000 | 从手牌发动 |
| `STATUS_OPPO_BATTLE` | 0x10000000 | 对方战斗 |
| `STATUS_FLIP_SUMMON_TURN` | 0x20000000 | 反转召唤回合 |
| `STATUS_SPSUMMON_TURN` | 0x40000000 | 特殊召唤回合 |
| `STATUS_FLIP_SUMMON_DISABLED` | 0x80000000 | 反转召唤被禁用 |

## 玩家常量 (Player)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `PLAYER_NONE` | 2 | 无玩家 |
| `PLAYER_ALL` | 3 | 所有玩家 |
| `PLAYER_SELFDES` | 5 | 自身描述 |

## 提示类型常量 (Hint)

### 普通提示

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `HINT_EVENT` | 1 | 事件 |
| `HINT_MESSAGE` | 2 | 消息 |
| `HINT_SELECTMSG` | 3 | 选择消息 |
| `HINT_OPSELECTED` | 4 | 选项已选择 |
| `HINT_EFFECT` | 5 | 效果 |
| `HINT_RACE` | 6 | 种族 |
| `HINT_ATTRIB` | 7 | 属性 |
| `HINT_CODE` | 8 | 卡牌编号 |
| `HINT_NUMBER` | 9 | 数值 |
| `HINT_CARD` | 10 | 卡牌 |
| `HINT_ZONE` | 11 | 区域 |

### 卡牌提示

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `CHINT_TURN` | 1 | 回合 |
| `CHINT_CARD` | 2 | 卡牌 |
| `CHINT_RACE` | 3 | 种族 |
| `CHINT_ATTRIBUTE` | 4 | 属性 |
| `CHINT_NUMBER` | 5 | 数值 |
| `CHINT_DESC_ADD` | 6 | 描述添加 |
| `CHINT_DESC_REMOVE` | 7 | 描述移除 |

### 玩家提示

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `PHINT_DESC_ADD` | 6 | 描述添加 |
| `PHINT_DESC_REMOVE` | 7 | 描述移除 |

### 效果描述

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `EDESC_OPERATION` | 1 | 操作 |
| `EDESC_RESET` | 2 | 重置 |

## 操作码常量 (Opcode)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `OPCODE_ADD` | 0x40000000 | 加法 |
| `OPCODE_SUB` | 0x40000001 | 减法 |
| `OPCODE_MUL` | 0x40000002 | 乘法 |
| `OPCODE_DIV` | 0x40000003 | 除法 |
| `OPCODE_AND` | 0x40000004 | 与运算 |
| `OPCODE_OR` | 0x40000005 | 或运算 |
| `OPCODE_NEG` | 0x40000006 | 取反 |
| `OPCODE_NOT` | 0x40000007 | 非运算 |
| `OPCODE_ISCODE` | 0x40000100 | 判断卡牌编号 |
| `OPCODE_ISSETCARD` | 0x40000101 | 判断卡组卡牌 |
| `OPCODE_ISTYPE` | 0x40000102 | 判断类型 |
| `OPCODE_ISRACE` | 0x40000103 | 判断种族 |
| `OPCODE_ISATTRIBUTE` | 0x40000104 | 判断属性 |

## 活动常量 (Activity)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `ACTIVITY_SUMMON` | 1 | 召唤 |
| `ACTIVITY_NORMALSUMMON` | 2 | 通常召唤 |
| `ACTIVITY_SPSUMMON` | 3 | 特殊召唤 |
| `ACTIVITY_FLIPSUMMON` | 4 | 反转召唤 |
| `ACTIVITY_ATTACK` | 5 | 攻击 |
| `ACTIVITY_BATTLE_PHASE` | 6 | 战斗阶段 |
| `ACTIVITY_CHAIN` | 7 | 连锁 |

## 返回标志常量 (Return)

| 常量名 | 值 | 说明 |
|--------|-----|------|
| `RETURN_TEMP_REMOVE_TO_FIELD` | 1 | 临时除外返回场地 |
| `RETURN_TRAP_MONSTER_TO_SZONE` | 2 | 陷阱怪兽返回魔法陷阱区域 |

## 回调函数类型

### script_reader

```c
typedef byte* (*script_reader)(const char* script_name, int* len);
```

脚本读取回调函数，用于读取卡牌脚本文件。

**参数**:
- `script_name`: 脚本文件名
- `len`: 输出参数，返回读取到的数据长度

**返回值**: 指向脚本数据的指针，调用方负责释放内存

---

### card_reader

```c
typedef uint32_t (*card_reader)(uint32_t code, card_data* data);
```

卡牌数据读取回调函数，用于读取卡牌定义数据。

**参数**:
- `code`: 卡牌编号
- `data`: 输出参数，用于填充卡牌数据

**返回值**: `OPERATION_SUCCESS` (1) 表示成功，`OPERATION_FAIL` (0) 表示失败

---

### message_handler

```c
typedef uint32_t (*message_handler)(intptr_t pduel, uint32_t msg_type);
```

消息处理回调函数，用于处理游戏消息。

**参数**:
- `pduel`: duel 句柄
- `msg_type`: 消息类型

**返回值**: 处理结果状态码

## 接口函数

### 回调设置函数

#### set_script_reader

```c
OCGCORE_API void set_script_reader(script_reader f);
```

设置脚本读取回调函数。

**参数**:
- `f`: script_reader 类型的回调函数指针

---

#### set_card_reader

```c
OCGCORE_API void set_card_reader(card_reader f);
```

设置卡牌数据读取回调函数。

**参数**:
- `f`: card_reader 类型的回调函数指针

---

#### set_message_handler

```c
OCGCORE_API void set_message_handler(message_handler f);
```

设置消息处理回调函数。

**参数**:
- `f`: message_handler 类型的回调函数指针

---

### 辅助函数（非导出）

#### read_script

```c
byte* read_script(const char* script_name, int* len);
```

读取脚本文件（内部使用）。

---

#### read_card

```c
uint32_t read_card(uint32_t code, card_data* data);
```

读取卡牌数据（内部使用）。

---

#### handle_message

```c
uint32_t handle_message(void* pduel, uint32_t message_type);
```

处理消息（内部使用）。

---

### Duel 管理函数

#### create_duel

```c
OCGCORE_API intptr_t create_duel(uint_fast32_t seed);
```

创建一个新的 duel 实例（v1 版本）。

**参数**:
- `seed`: 32 位随机种子

**返回值**: duel 句柄（intptr_t），失败返回 0

---

#### create_duel_v2

```c
OCGCORE_API intptr_t create_duel_v2(uint32_t seed_sequence[]);
```

创建一个新的 duel 实例（v2 版本）。

**参数**:
- `seed_sequence`: 随机种子序列数组，长度应为 `SEED_COUNT`（8）

**返回值**: duel 句柄（intptr_t），失败返回 0

---

#### start_duel

```c
OCGCORE_API void start_duel(intptr_t pduel, uint32_t options);
```

开始 duel。

**参数**:
- `pduel`: duel 句柄
- `options`: 决斗选项标志位，参见 [决斗选项常量](#决斗选项常量-options)

---

#### end_duel

```c
OCGCORE_API void end_duel(intptr_t pduel);
```

结束并销毁 duel 实例。

**参数**:
- `pduel`: duel 句柄

---

### 玩家信息函数

#### set_player_info

```c
OCGCORE_API void set_player_info(intptr_t pduel, int32_t playerid, int32_t lp, int32_t startcount, int32_t drawcount);
```

设置玩家初始信息。

**参数**:
- `pduel`: duel 句柄
- `playerid`: 玩家 ID（0 或 1）
- `lp`: 初始生命值
- `startcount`: 初始手牌数量
- `drawcount`: 每回合抽牌数量

---

### 消息获取函数

#### get_log_message

```c
OCGCORE_API void get_log_message(intptr_t pduel, char* buf);
```

获取日志消息。

**参数**:
- `pduel`: duel 句柄
- `buf`: 输出缓冲区，用于存储日志消息

---

#### get_message

```c
OCGCORE_API int32_t get_message(intptr_t pduel, byte* buf);
```

获取游戏消息。

**参数**:
- `pduel`: duel 句柄
- `buf`: 输出缓冲区，用于存储消息数据

**返回值**: 消息长度（`LEN_FAIL`=0 表示失败）

---

### 游戏流程函数

#### process

```c
OCGCORE_API uint32_t process(intptr_t pduel);
```

处理游戏流程，执行一步操作。

**参数**:
- `pduel`: duel 句柄

**返回值**: 处理结果状态码，参见 [处理器状态常量](#处理器状态常量)

---

### 卡牌操作函数

#### new_card

```c
OCGCORE_API void new_card(intptr_t pduel, uint32_t code, uint8_t owner, uint8_t playerid, uint8_t location, uint8_t sequence, uint8_t position);
```

在场上创建一张卡牌。

**参数**:
- `pduel`: duel 句柄
- `code`: 卡牌编号
- `owner`: 卡牌所有者（0 或 1）
- `playerid`: 控制玩家（0 或 1）
- `location`: 卡牌位置，参见 [位置常量](#位置常量-location)
- `sequence`: 位置序号
- `position`: 卡牌状态，参见 [表示位置常量](#表示位置常量-position)

---

#### new_tag_card

```c
OCGCORE_API void new_tag_card(intptr_t pduel, uint32_t code, uint8_t owner, uint8_t location);
```

创建一张标签卡牌（用于衍生物等）。

**参数**:
- `pduel`: duel 句柄
- `code`: 卡牌编号
- `owner`: 卡牌所有者（0 或 1）
- `location`: 卡牌位置

---

### 查询函数

#### query_card

```c
OCGCORE_API int32_t query_card(intptr_t pduel, uint8_t playerid, uint8_t location, uint8_t sequence, int32_t query_flag, byte* buf, int32_t use_cache);
```

查询指定位置的卡牌信息。

**参数**:
- `pduel`: duel 句柄
- `playerid`: 玩家 ID（0 或 1）
- `location`: 卡牌位置
- `sequence`: 位置序号
- `query_flag`: 查询标志位，参见 [查询标志常量](#查询标志常量-query-flag)
- `buf`: 输出缓冲区
- `use_cache`: 是否使用缓存（0 或 1）

**返回值**: 查询到的数据长度

---

#### query_field_count

```c
OCGCORE_API int32_t query_field_count(intptr_t pduel, uint8_t playerid, uint8_t location);
```

查询指定位置的卡牌数量。

**参数**:
- `pduel`: duel 句柄
- `playerid`: 玩家 ID（0 或 1）
- `location`: 卡牌位置

**返回值**: 卡牌数量

---

#### query_field_card

```c
OCGCORE_API int32_t query_field_card(intptr_t pduel, uint8_t playerid, uint8_t location, uint32_t query_flag, byte* buf, int32_t use_cache);
```

查询场上所有卡牌的信息。

**参数**:
- `pduel`: duel 句柄
- `playerid`: 玩家 ID（0 或 1）
- `location`: 卡牌位置
- `query_flag`: 查询标志位
- `buf`: 输出缓冲区
- `use_cache`: 是否使用缓存

**返回值**: 查询到的数据长度

---

#### query_field_info

```c
OCGCORE_API int32_t query_field_info(intptr_t pduel, byte* buf);
```

查询整个场地的信息。

**参数**:
- `pduel`: duel 句柄
- `buf`: 输出缓冲区

**返回值**: 查询到的数据长度

---

### 响应函数

#### set_responsei

```c
OCGCORE_API void set_responsei(intptr_t pduel, int32_t value);
```

设置整数类型的响应（用于处理游戏询问）。

**参数**:
- `pduel`: duel 句柄
- `value`: 响应值

---

#### set_responseb

```c
OCGCORE_API void set_responseb(intptr_t pduel, byte* buf);
```

设置字节数组类型的响应（用于处理游戏询问）。

**参数**:
- `pduel`: duel 句柄
- `buf`: 响应数据缓冲区

---

### 脚本预加载

#### preload_script

```c
OCGCORE_API int32_t preload_script(intptr_t pduel, const char* script_name);
```

预加载指定脚本文件。

**参数**:
- `pduel`: duel 句柄
- `script_name`: 脚本文件名

**返回值**: 预加载结果状态码

---

### 默认脚本读取器

#### default_script_reader

```c
OCGCORE_API byte* default_script_reader(const char* script_name, int* len);
```

默认的脚本读取器实现，从文件系统读取脚本。

**参数**:
- `script_name`: 脚本文件名
- `len`: 输出参数，返回数据长度

**返回值**: 指向脚本数据的指针

---

## 接口分类汇总

| 分类 | 函数 |
|------|------|
| **回调设置** | `set_script_reader`, `set_card_reader`, `set_message_handler` |
| **Duel 管理** | `create_duel`, `create_duel_v2`, `start_duel`, `end_duel` |
| **玩家信息** | `set_player_info` |
| **消息获取** | `get_log_message`, `get_message` |
| **游戏流程** | `process` |
| **卡牌操作** | `new_card`, `new_tag_card` |
| **查询** | `query_card`, `query_field_count`, `query_field_card`, `query_field_info` |
| **响应** | `set_responsei`, `set_responseb` |
| **脚本** | `preload_script`, `default_script_reader` |

## 使用流程

1. **初始化**: 设置 `script_reader`、`card_reader`、`message_handler` 回调函数
2. **创建 Duel**: 调用 `create_duel` 或 `create_duel_v2` 创建决斗实例
3. **设置玩家**: 调用 `set_player_info` 设置双方玩家初始信息
4. **添加卡牌**: 使用 `new_card` 添加卡组、手牌、场地卡牌
5. **开始决斗**: 调用 `start_duel`
6. **游戏循环**: 循环调用 `process` 和 `get_message` 处理游戏流程
7. **响应询问**: 根据消息类型调用 `set_responsei` 或 `set_responseb`
8. **查询状态**: 使用 `query_card` 等函数查询卡牌状态
9. **结束决斗**: 调用 `end_duel` 销毁实例