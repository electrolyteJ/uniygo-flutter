#!/usr/bin/env python3
"""生成 ygo-agent golden 样本（供 Dart 移植 features.py 做等价性校验）。

输出 samples/<id>.json，每个文件是一场"决策序列"（duel）：
    {"id", "description", "steps": [{"input": <Input>, "note"?}]}
其中 <Input> 严格遵循 ygoinf/ygoinf/models.py 的 Input schema（别名 "global"）。
gen_golden.py 会把这些 Input 依次喂给上游 features.predict()，
并按服务器协议维护 index / prev_action_idx 链。

卡牌数据来自 uniygopro 工程的 packages/ygo_card_mycard/assets/cards.cdb
（ocgcore 官方位掩码），保证样本是真实卡数据而非臆造。

响应值约定（与本仓库 ocgcore playerop.cpp 核对过）：
- select_idlecmd : response = (index << 16) | cmd, cmd 0..7（6=to_bp, 7=to_ep）
- select_battlecmd: response = (index << 16) | cmd（0=attack 1=activate, 2=to_m2, 3=to_ep）
- select_chain   : response = chain 下标；放弃 = -1
- select_position: response = 0x1/0x2/0x4/0x8
- select_card / select_tribute / select_sum / select_unselect_card / announce_number
                   / select_option / select_place: response = 列表下标
- announce_attrib: response = 属性位（EARTH 0x1 ... DIVINE 0x40）
"""
import json
import os

# ─────────────────────────────────────────────────────────────────────
# 卡牌数据库（来自 cards.cdb 的真实数据）
# code: (name, type_bits, atk, def, level, race_bits, attribute_bits)
# ─────────────────────────────────────────────────────────────────────
CARDS = {
    89631139: ("青眼白龙", 0x11, 3000, 2500, 8, 0x2000, 0x10),
    38517737: ("青眼亚白龙", 0x2000021, 3000, 2500, 8, 0x2000, 0x10),
    45467446: ("白色灵龙", 0x21, 2500, 2000, 8, 0x2000, 0x10),
    71039903: ("太古的白石", 0x1021, 600, 500, 1, 0x2000, 0x10),
    45644898: ("青色眼睛的祭司", 0x1021, 300, 1200, 1, 0x2000, 0x10),
    79814787: ("传说的白石", 0x1021, 300, 250, 1, 0x2000, 0x10),
    8240199: ("青色眼睛的贤士", 0x1021, 0, 1500, 1, 0x2, 0x10),
    97268402: ("效果遮蒙者", 0x1021, 0, 0, 1, 0x2, 0x10),
    23434538: ("增殖的G", 0x21, 500, 200, 2, 0x800, 0x1),
    65681983: ("抹杀之指名者", 0x10002, 0, 0, 0, 0, 0),
    43898403: ("双龙卷", 0x10002, 0, 0, 0, 0, 0),
    63356631: ("凤翼的爆风", 0x4, 0, 0, 0, 0, 0),
    83764718: ("死者苏生", 0x2, 0, 0, 0, 0, 0),
    48800175: ("龙觉醒的旋律", 0x2, 0, 0, 0, 0, 0),
    39701395: ("调和的宝札", 0x2, 0, 0, 0, 0, 0),
    2295440: ("一对一", 0x2, 0, 0, 0, 0, 0),
    40908371: ("苍眼银龙", 0x2021, 2500, 3000, 9, 0x2000, 0x10),
    59822133: ("青眼精灵龙", 0x2021, 2500, 3000, 9, 0x2000, 0x10),
    50954680: ("水晶翼同调龙", 0x2021, 3000, 2500, 8, 0x2000, 0x8),
    39030163: ("银河眼重铠光子龙", 0x800021, 4000, 3500, 8, 0x2000, 0x10),
    31801517: ("No.62 银河眼光子龙皇", 0x800021, 4000, 3000, 8, 0x2000, 0x10),
    41999284: ("连接栗子球", 0x4000021, 300, 2, 1, 0x1000000, 0x20),
}

TYPE_BITS = [
    (0x1, "monster"), (0x2, "spell"), (0x4, "trap"), (0x10, "normal"),
    (0x20, "effect"), (0x40, "fusion"), (0x80, "ritual"),
    (0x100, "trap_monster"), (0x200, "spirit"), (0x400, "union"),
    (0x800, "dual"), (0x1000, "tuner"), (0x2000, "synchro"),
    (0x4000, "token"), (0x10000, "quick_play"), (0x20000, "continuous"),
    (0x40000, "equip"), (0x80000, "field"), (0x100000, "counter"),
    (0x200000, "flip"), (0x400000, "toon"), (0x800000, "xyz"),
    (0x1000000, "pendulum"), (0x2000000, "special"), (0x4000000, "link"),
]
RACE_BITS = [
    (0x1, "warrior"), (0x2, "spellcaster"), (0x4, "fairy"), (0x8, "fiend"),
    (0x10, "zombie"), (0x20, "machine"), (0x40, "aqua"), (0x80, "pyro"),
    (0x100, "rock"), (0x200, "windbeast"), (0x400, "plant"),
    (0x800, "insect"), (0x1000, "thunder"), (0x2000, "dragon"),
    (0x4000, "beast"), (0x8000, "beast_warrior"), (0x10000, "dinosaur"),
    (0x20000, "fish"), (0x40000, "sea_serpent"), (0x80000, "reptile"),
    (0x100000, "psycho"), (0x200000, "devine"), (0x400000, "creator_god"),
    (0x800000, "wyrm"), (0x1000000, "cyberse"), (0x2000000, "illusion"),
]
ATTR_BITS = [
    (0x1, "earth"), (0x2, "water"), (0x4, "fire"), (0x8, "wind"),
    (0x10, "light"), (0x20, "dark"), (0x40, "divine"),
]


def _bits(bits, table):
    return [name for mask, name in table if bits & mask]


def _single(bits, table):
    for mask, name in table:
        if bits == mask:
            return name
    return "none"


def C(code, controller, location, sequence=0, position=None, overlay=-1,
      counter=0, negated=False, attack=None, defense=None, level=None):
    """构造 Input.cards 的一张卡（字段语义见 models.py 的 Card）。"""
    name, type_bits, atk, dfn, lv, race, attr = CARDS[code]
    if position is None:
        position = {
            "hand": "facedown", "deck": "facedown", "extra": "facedown",
            "mzone": "faceup_attack", "szone": "faceup",
            "grave": "faceup", "removed": "faceup",
        }[location]
    return {
        "code": code,
        "location": location,
        "sequence": sequence if location in ("mzone", "szone", "grave") else 0,
        "controller": controller,
        "position": position if overlay == -1 else "faceup",
        "overlay_sequence": overlay,
        "attribute": _single(attr, ATTR_BITS),
        "race": _single(race, RACE_BITS),
        "level": lv if level is None else level,
        "counter": counter,
        "negated": negated,
        "attack": atk if attack is None else attack,
        "defense": dfn if defense is None else defense,
        "types": _bits(type_bits, TYPE_BITS),
    }


def G(my_lp, op_lp, turn, phase, is_first=False, is_my_turn=True):
    return {
        "my_lp": my_lp, "op_lp": op_lp, "turn": turn, "phase": phase,
        "is_first": is_first, "is_my_turn": is_my_turn,
    }


def DESC(code, idx=0):
    """ocgcore 卡牌效果描述符：(code << 4) | effect_index。"""
    return (code << 4) | idx


def CARD_INFO(code, controller, location, sequence=0, overlay=-1):
    return {
        "code": code, "controller": controller, "location": location,
        "sequence": sequence, "overlay_sequence": overlay,
    }


def CARD_LOC(controller, location, sequence, overlay=-1):
    return {
        "controller": controller, "location": location,
        "sequence": sequence, "overlay_sequence": overlay,
    }


# 响应值助手（与 ocgcore playerop.cpp 一致）
def idle_resp(idx, cmd):
    return (idx << 16) | cmd


def battle_resp(idx, cmd):
    return (idx << 16) | cmd


IDLE_TO_BP, IDLE_TO_EP = 6, 7
BATTLE_TO_M2, BATTLE_TO_EP = 2, 3

LOCATION_ORDER = ["deck", "hand", "mzone", "szone", "grave", "removed", "extra"]


def sort_cards(cards):
    ctrl = {"me": 0, "opponent": 1}
    return sorted(
        cards,
        key=lambda c: (ctrl[c["controller"]], LOCATION_ORDER.index(c["location"]),
                       c["sequence"], c["overlay_sequence"]),
    )


def step(global_, cards, action_msg, note=""):
    s = {"input": {"global": global_, "cards": sort_cards(cards),
                   "action_msg": {"data": action_msg}}}
    if note:
        s["note"] = note
    return s


def duel(duel_id, description, steps):
    return {"id": duel_id, "description": description, "steps": steps}


# ─────────────────────────────────────────────────────────────────────
# 基准局面（青眼 vs 光子龙镜像风格）
# ─────────────────────────────────────────────────────────────────────
def base_field(*, my_hand=(89631139, 71039903, 43898403, 48800175),
               my_mzone=((38517737, 0, "faceup_attack"),),
               my_szone=((63356631, 1, "facedown"),),
               my_grave=(79814787,),
               op_hand=(97268402, 23434538),
               op_mzone=((31801517, 0, "faceup_attack"),),
               op_szone=((43898403, 0, "facedown"),),
               op_grave=(45644898,),
               xyz_materials=((31801517, 0, 89631139),),
               decks=3):
    """构造双方场面卡列表。xyz_materials: (宿主code, 宿主seq, 素材code)。"""
    cards = []
    for code in my_hand:
        cards.append(C(code, "me", "hand"))
    for code, seq, pos in my_mzone:
        cards.append(C(code, "me", "mzone", sequence=seq, position=pos))
    for code, seq, pos in my_szone:
        cards.append(C(code, "me", "szone", sequence=seq, position=pos))
    for code in my_grave:
        cards.append(C(code, "me", "grave"))
    cards.append(C(40908371, "me", "extra"))
    cards.append(C(59822133, "me", "extra"))
    for _ in range(decks):
        cards.append(C(89631139, "me", "deck"))
    for code in op_hand:
        cards.append(C(code, "opponent", "hand"))
    for code, seq, pos in op_mzone:
        cards.append(C(code, "opponent", "mzone", sequence=seq, position=pos))
    for code, seq, pos in op_szone:
        cards.append(C(code, "opponent", "szone", sequence=seq, position=pos))
    for code in op_grave:
        cards.append(C(code, "opponent", "grave"))
    cards.append(C(50954680, "opponent", "extra"))
    for _ in range(decks):
        cards.append(C(89631139, "opponent", "deck"))
    for host, seq, mat in xyz_materials:
        cards.append(C(mat, "opponent", "mzone", sequence=seq, overlay=0))
    return cards


# ─────────────────────────────────────────────────────────────────────
# 单步样本：覆盖全部 15 种 action_msg
# ─────────────────────────────────────────────────────────────────────
def s_idlecmd_rich():
    cards = base_field()
    msg = {
        "msg_type": "select_idlecmd",
        "idle_cmds": [
            {"cmd_type": "summon",
             "data": {"card_info": CARD_INFO(89631139, "me", "hand"),
                      "effect_description": 0, "response": idle_resp(0, 0)}},
            {"cmd_type": "summon",
             "data": {"card_info": CARD_INFO(71039903, "me", "hand"),
                      "effect_description": 0, "response": idle_resp(1, 0)}},
            {"cmd_type": "sp_summon",
             "data": {"card_info": CARD_INFO(38517737, "me", "hand"),
                      "effect_description": 0, "response": idle_resp(0, 1)}},
            {"cmd_type": "reposition",
             "data": {"card_info": CARD_INFO(38517737, "me", "mzone", 0),
                      "effect_description": 0, "response": idle_resp(0, 2)}},
            {"cmd_type": "mset",
             "data": {"card_info": CARD_INFO(71039903, "me", "hand"),
                      "effect_description": 0, "response": idle_resp(0, 3)}},
            {"cmd_type": "set",
             "data": {"card_info": CARD_INFO(43898403, "me", "hand"),
                      "effect_description": 0, "response": idle_resp(0, 4)}},
            {"cmd_type": "activate",
             "data": {"card_info": CARD_INFO(43898403, "me", "hand"),
                      "effect_description": DESC(43898403, 0),
                      "response": idle_resp(0, 5)}},
            {"cmd_type": "activate",
             "data": {"card_info": CARD_INFO(38517737, "me", "mzone", 0),
                      "effect_description": DESC(38517737, 1),
                      "response": idle_resp(1, 5)}},
            {"cmd_type": "activate",
             "data": {"card_info": CARD_INFO(65681983, "me", "hand"),
                      "effect_description": 94,
                      "response": idle_resp(2, 5)}},
            {"cmd_type": "to_bp", "data": None},
            {"cmd_type": "to_ep", "data": None},
        ],
    }
    return duel(
        "idlecmd_rich",
        "select_idlecmd 全命令类型：召唤×2/特召/改姿/里侧召唤/盖放/发动×3(含系统串)/进战阶/结束",
        [step(G(8000, 6500, 3, "main1"), cards, msg)],
    )


def s_idlecmd_minimal():
    cards = base_field(my_hand=(89631139,))
    msg = {"msg_type": "select_idlecmd",
           "idle_cmds": [{"cmd_type": "to_bp", "data": None}]}
    return duel(
        "idlecmd_minimal",
        "select_idlecmd 仅 to_bp —— 单动作短路路径（不调用模型，probs=[1.0]）",
        [step(G(8000, 8000, 1, "main1", is_first=True), cards, msg)],
    )


def s_chain_multiple():
    cards = base_field()
    msg = {
        "msg_type": "select_chain",
        "forced": False,
        "chains": [
            {"code": 43898403,
             "location": CARD_LOC("me", "hand", 0),
             "effect_description": DESC(43898403, 0), "response": 0},
            {"code": 89631139,
             "location": CARD_LOC("opponent", "mzone", 0, overlay=0),
             "effect_description": DESC(89631139, 0), "response": 1},
            {"code": 41999284,
             "location": CARD_LOC("me", "grave", 0),
             "effect_description": DESC(41999284, 1), "response": 2},
        ],
    }
    return duel(
        "chain_multiple",
        "select_chain 3 连锁（手牌/超量素材 overlay 位/墓地）+ 非强制 → 含 cancel(-1)",
        [step(G(8000, 6500, 3, "main1"), cards, msg)],
    )


def s_chain_forced_single():
    cards = base_field(op_mzone=(), xyz_materials=())
    msg = {
        "msg_type": "select_chain",
        "forced": True,
        "chains": [
            {"code": 23434538,
             "location": CARD_LOC("opponent", "hand", 0),
             "effect_description": 0, "response": 0},
        ],
    }
    return duel(
        "chain_forced_single",
        "select_chain 强制单连锁 —— 单动作短路路径",
        [step(G(8000, 8000, 2, "main1", is_my_turn=False), cards, msg)],
    )


def s_select_card():
    cards = base_field()
    msg = {
        "msg_type": "select_card",
        "cancelable": False, "min": 1, "max": 2,
        "cards": [
            {"location": CARD_LOC("me", "hand", 0), "response": 0},
            {"location": CARD_LOC("me", "hand", 0), "response": 1},
            {"location": CARD_LOC("me", "hand", 0), "response": 2},
            {"location": CARD_LOC("me", "mzone", 0), "response": 3},
            {"location": CARD_LOC("me", "grave", 0), "response": 4},
        ],
        "selected": [],
    }
    return duel(
        "select_card",
        "select_card min1 max2 选 5 张（手牌/场上/墓地混合），无 finish",
        [step(G(8000, 6500, 3, "main1"), cards, msg)],
    )


def s_select_card_selected():
    cards = base_field()
    msg = {
        "msg_type": "select_card",
        "cancelable": False, "min": 1, "max": 2,
        "cards": [
            {"location": CARD_LOC("me", "hand", 0), "response": 0},
            {"location": CARD_LOC("me", "hand", 0), "response": 1},
            {"location": CARD_LOC("me", "hand", 0), "response": 2},
            {"location": CARD_LOC("me", "mzone", 0), "response": 3},
        ],
        "selected": [3],
    }
    return duel(
        "select_card_selected",
        "select_card 已选 1 张（selected=[3]）→ 跳过已选 + 追加 finish(-1)",
        [step(G(8000, 6500, 3, "main1"), cards, msg)],
    )


def s_select_tribute():
    cards = base_field(
        my_mzone=((71039903, 0, "faceup_attack"), (8240199, 1, "faceup_attack")))
    msg = {
        "msg_type": "select_tribute",
        "cancelable": False, "min": 1, "max": 1,
        "cards": [
            {"location": CARD_LOC("me", "mzone", 0), "level": 1, "response": 0},
            {"location": CARD_LOC("me", "mzone", 1), "level": 1, "response": 1},
        ],
        "selected": [],
    }
    return duel(
        "select_tribute",
        "select_tribute min=max=1，两张 1 星祭品",
        [step(G(8000, 8000, 3, "main1"), cards, msg)],
    )


def s_select_sum():
    cards = base_field(my_hand=(89631139, 50954680, 71039903, 8240199))
    msg = {
        "msg_type": "select_sum",
        "overflow": False,
        "level_sum": 9,
        "min": 1, "max": 2,
        "cards": [
            {"location": CARD_LOC("me", "hand", 0), "level1": 9, "level2": 0,
             "response": 0},
            {"location": CARD_LOC("me", "hand", 0), "level1": 8, "level2": 0,
             "response": 1},
            {"location": CARD_LOC("me", "hand", 0), "level1": 1, "level2": 0,
             "response": 2},
        ],
        "must_cards": [],
        "selected": [],
    }
    return duel(
        "select_sum",
        "select_sum level_sum=9：{lv9} 单卡可完 / {lv8+lv1} 两张组合 → can_finish 混合",
        [step(G(8000, 8000, 3, "main1"), cards, msg)],
    )


def s_select_position_two():
    cards = base_field()
    msg = {
        "msg_type": "select_position",
        "code": 89631139,
        "positions": ["faceup_defense", "facedown_defense"],
    }
    return duel(
        "select_position_two",
        "select_position 两种表示形式",
        [step(G(8000, 8000, 3, "main1"), cards, msg)],
    )


def s_select_position_single():
    cards = base_field()
    msg = {
        "msg_type": "select_position",
        "code": 38517737,
        "positions": ["faceup_defense"],
    }
    return duel(
        "select_position_single",
        "select_position 单一形式 —— 单动作短路路径",
        [step(G(8000, 8000, 3, "main1"), cards, msg)],
    )


def s_effectyn():
    cards = base_field()
    msg = {
        "msg_type": "select_effectyn",
        "code": 38517737,
        "location": CARD_LOC("me", "mzone", 0),
        "effect_description": DESC(38517737, 0),
    }
    return duel(
        "effectyn_card",
        "select_effectyn 卡牌效果询问（yes=1/no=0）",
        [step(G(8000, 8000, 2, "standby"), cards, msg)],
    )


def s_yesno_system():
    cards = base_field()
    msg = {"msg_type": "select_yesno", "effect_description": 94}
    return duel(
        "yesno_system",
        "select_yesno 系统串 desc=94",
        [step(G(8000, 6500, 4, "end"), cards, msg)],
    )


def s_yesno_card():
    cards = base_field()
    msg = {"msg_type": "select_yesno", "effect_description": DESC(65681983, 2)}
    return duel(
        "yesno_card",
        "select_yesno 卡牌效果 desc（code<<4|2）",
        [step(G(8000, 6500, 4, "main2"), cards, msg)],
    )


def s_battlecmd():
    cards = base_field(
        my_mzone=((89631139, 0, "faceup_attack"), (38517737, 1, "faceup_attack")),
        my_szone=((43898403, 0, "facedown"),))
    msg = {
        "msg_type": "select_battlecmd",
        "battle_cmds": [
            {"cmd_type": "attack",
             "data": {"card_info": CARD_INFO(89631139, "me", "mzone", 0),
                      "effect_description": 0, "direct_attackable": False,
                      "response": battle_resp(0, 0)}},
            {"cmd_type": "attack",
             "data": {"card_info": CARD_INFO(38517737, "me", "mzone", 1),
                      "effect_description": 0, "direct_attackable": True,
                      "response": battle_resp(1, 0)}},
            {"cmd_type": "activate",
             "data": {"card_info": CARD_INFO(43898403, "me", "szone", 0),
                      "effect_description": DESC(43898403, 0),
                      "direct_attackable": False,
                      "response": battle_resp(0, 1)}},
            {"cmd_type": "to_m2", "data": None},
            {"cmd_type": "to_ep", "data": None},
        ],
    }
    return duel(
        "battlecmd_rich",
        "select_battlecmd：普攻/直攻/战阶发动/进 M2/结束",
        [step(G(8000, 6500, 3, "battle_step"), cards, msg)],
    )


def s_unselect_card():
    cards = base_field()
    msg = {
        "msg_type": "select_unselect_card",
        "finishable": True,
        "cancelable": False,
        "min": 1, "max": 1,
        "selected_cards": [],
        "selectable_cards": [
            {"location": CARD_LOC("me", "hand", 0), "response": 0},
            {"location": CARD_LOC("me", "hand", 0), "response": 1},
            {"location": CARD_LOC("opponent", "mzone", 0), "response": 2},
        ],
    }
    return duel(
        "unselect_card",
        "select_unselect_card finishable → 追加 finish(-1)",
        [step(G(8000, 8000, 3, "main1"), cards, msg)],
    )


def s_select_option():
    cards = base_field()
    msg = {
        "msg_type": "select_option",
        "options": [
            {"code": 1050, "response": 0},
            {"code": DESC(48800175, 0), "response": 1},
        ],
    }
    return duel(
        "select_option",
        "select_option：系统串选项 + 卡牌效果选项",
        [step(G(8000, 8000, 3, "main1"), cards, msg)],
    )


def s_select_place():
    cards = base_field()
    msg = {
        "msg_type": "select_place",
        "count": 1,
        "places": [
            {"controller": "me", "location": "mzone", "sequence": 2},
            {"controller": "opponent", "location": "szone", "sequence": 1},
        ],
    }
    return duel(
        "select_place",
        "select_place 两个候选格（我方 M3 / 对方 S2）",
        [step(G(8000, 8000, 3, "main1"), cards, msg)],
    )


def s_select_disfield():
    cards = base_field()
    msg = {
        "msg_type": "select_disfield",
        "count": 1,
        "places": [
            {"controller": "me", "location": "szone", "sequence": 3},
        ],
    }
    return duel(
        "select_disfield",
        "select_disfield 单格 —— 单动作短路且 response=-1",
        [step(G(8000, 6500, 3, "main2"), cards, msg)],
    )


def s_announce_attrib():
    cards = base_field()
    msg = {
        "msg_type": "announce_attrib",
        "count": 1,
        "attributes": [
            {"attribute": "light", "response": 0x10},
            {"attribute": "dark", "response": 0x20},
            {"attribute": "fire", "response": 0x4},
        ],
    }
    return duel(
        "announce_attrib",
        "announce_attrib 三属性单选（response=属性位）",
        [step(G(8000, 8000, 3, "main1"), cards, msg)],
    )


def s_announce_number():
    cards = base_field()
    msg = {
        "msg_type": "announce_number",
        "count": 1,
        "numbers": [
            {"number": 1, "response": 0},
            {"number": 2, "response": 1},
            {"number": 3, "response": 2},
            {"number": 4, "response": 3},
            {"number": 5, "response": 4},
            {"number": 6, "response": 5},
        ],
    }
    return duel(
        "announce_number",
        "announce_number 骰子 1-6（response=选项下标）",
        [step(G(8000, 8000, 2, "main1"), cards, msg)],
    )


# ─────────────────────────────────────────────────────────────────────
# 多步序列：验证 RNN 隐状态与历史动作链（index / prev_action_idx）
# ─────────────────────────────────────────────────────────────────────
def seq_summon_battle():
    steps = []
    # s1: M1 — 召唤青眼
    f1 = base_field(my_hand=(89631139, 43898403, 48800175, 71039903),
                    my_mzone=((38517737, 0, "faceup_attack"),))
    steps.append(step(
        G(8000, 6500, 3, "main1"), f1,
        {"msg_type": "select_idlecmd", "idle_cmds": [
            {"cmd_type": "summon",
             "data": {"card_info": CARD_INFO(89631139, "me", "hand"),
                      "effect_description": 0, "response": idle_resp(0, 0)}},
            {"cmd_type": "set",
             "data": {"card_info": CARD_INFO(43898403, "me", "hand"),
                      "effect_description": 0, "response": idle_resp(0, 4)}},
            {"cmd_type": "activate",
             "data": {"card_info": CARD_INFO(38517737, "me", "mzone", 0),
                      "effect_description": DESC(38517737, 0),
                      "response": idle_resp(0, 5)}},
            {"cmd_type": "to_bp", "data": None},
            {"cmd_type": "to_ep", "data": None},
        ]},
        note="M1: 召唤/盖放/发动/进战阶"))
    # s2: 青眼已在场上（seq1），再次 idlecmd
    f2 = base_field(my_hand=(43898403, 48800175, 71039903),
                    my_mzone=((38517737, 0, "faceup_attack"),
                              (89631139, 1, "faceup_attack")))
    steps.append(step(
        G(8000, 6500, 3, "main1"), f2,
        {"msg_type": "select_idlecmd", "idle_cmds": [
            {"cmd_type": "activate",
             "data": {"card_info": CARD_INFO(43898403, "me", "hand"),
                      "effect_description": DESC(43898403, 0),
                      "response": idle_resp(0, 5)}},
            {"cmd_type": "to_bp", "data": None},
            {"cmd_type": "to_ep", "data": None},
        ]},
        note="青眼召唤后回到 idlecmd"))
    # s3: 战阶 — 攻击指令
    steps.append(step(
        G(8000, 6500, 3, "battle_step"), f2,
        {"msg_type": "select_battlecmd", "battle_cmds": [
            {"cmd_type": "attack",
             "data": {"card_info": CARD_INFO(89631139, "me", "mzone", 1),
                      "effect_description": 0, "direct_attackable": False,
                      "response": battle_resp(0, 0)}},
            {"cmd_type": "attack",
             "data": {"card_info": CARD_INFO(38517737, "me", "mzone", 0),
                      "effect_description": 0, "direct_attackable": False,
                      "response": battle_resp(1, 0)}},
            {"cmd_type": "to_m2", "data": None},
            {"cmd_type": "to_ep", "data": None},
        ]},
        note="BP: 攻击选择"))
    # s4: 对方连锁响应（攻击宣言时点）
    f4 = base_field(my_hand=(43898403, 48800175, 71039903),
                    my_mzone=((38517737, 0, "faceup_attack"),
                              (89631139, 1, "faceup_attack")))
    steps.append(step(
        G(8000, 6500, 3, "battle_step"), f4,
        {"msg_type": "select_chain", "forced": False, "chains": [
            {"code": 43898403,
             "location": CARD_LOC("opponent", "szone", 0),
             "effect_description": DESC(43898403, 0), "response": 0},
            {"code": 65681983,
             "location": CARD_LOC("me", "hand", 0),
             "effect_description": DESC(65681983, 0), "response": 1},
        ]},
        note="攻击宣言: 是否连锁"))
    # s5: M2 — 盖放后结束
    f5 = base_field(my_hand=(48800175, 71039903),
                    my_mzone=((38517737, 0, "faceup_attack"),
                              (89631139, 1, "faceup_attack")),
                    my_szone=((63356631, 1, "facedown"),
                              (43898403, 2, "facedown")))
    steps.append(step(
        G(8000, 5200, 3, "main2"), f5,
        {"msg_type": "select_idlecmd", "idle_cmds": [
            {"cmd_type": "set",
             "data": {"card_info": CARD_INFO(48800175, "me", "hand"),
                      "effect_description": 0, "response": idle_resp(0, 4)}},
            {"cmd_type": "to_ep", "data": None},
        ]},
        note="M2: 盖放/结束回合"))
    return duel(
        "seq_summon_battle",
        "多步链：M1 召唤 → idlecmd → BP 攻击 → 连锁响应 → M2 盖放（跨 5 个决策，"
        "验证 RNN rstate 与 history_actions 传递）",
        steps,
    )


def seq_defense_opponent_turn():
    steps = []
    f_base = base_field(my_hand=(39701395, 71039903),
                        my_mzone=((89631139, 0, "faceup_attack"),),
                        op_mzone=((31801517, 0, "faceup_attack"),))
    # s1: 对方回合 — 效果询问
    steps.append(step(
        G(7400, 8000, 4, "main1", is_my_turn=False), f_base,
        {"msg_type": "select_effectyn", "code": 31801517,
         "location": CARD_LOC("opponent", "mzone", 0),
         "effect_description": DESC(31801517, 0)},
        note="对方回合: No.62 效果询问"))
    # s2: 凤翼爆风弃卡代价
    steps.append(step(
        G(7400, 8000, 4, "main1", is_my_turn=False), f_base,
        {"msg_type": "select_card", "cancelable": False, "min": 1, "max": 1,
         "cards": [
             {"location": CARD_LOC("me", "hand", 0), "response": 0},
             {"location": CARD_LOC("me", "hand", 0), "response": 1},
         ],
         "selected": []},
        note="弃卡代价 select_card min=max=1"))
    # s3: 连锁（对方发动效果，我方可用抹杀之指名者）
    steps.append(step(
        G(7400, 8000, 4, "main1", is_my_turn=False), f_base,
        {"msg_type": "select_chain", "forced": False, "chains": [
            {"code": 31801517,
             "location": CARD_LOC("opponent", "mzone", 0),
             "effect_description": DESC(31801517, 1), "response": 0},
            {"code": 65681983,
             "location": CARD_LOC("me", "hand", 0),
             "effect_description": DESC(65681983, 0), "response": 1},
        ]},
        note="对方发动: 连锁决策"))
    # s4: 回到我方回合
    f4 = base_field(my_hand=(71039903,),
                    my_mzone=((89631139, 0, "faceup_attack"),),
                    op_mzone=((31801517, 0, "faceup_attack"),))
    steps.append(step(
        G(7400, 8000, 5, "main1", is_my_turn=True), f4,
        {"msg_type": "select_idlecmd", "idle_cmds": [
            {"cmd_type": "summon",
             "data": {"card_info": CARD_INFO(71039903, "me", "hand"),
                      "effect_description": 0, "response": idle_resp(0, 0)}},
            {"cmd_type": "activate",
             "data": {"card_info": CARD_INFO(89631139, "me", "mzone", 0),
                      "effect_description": DESC(89631139, 0),
                      "response": idle_resp(0, 5)}},
            {"cmd_type": "to_bp", "data": None},
            {"cmd_type": "to_ep", "data": None},
        ]},
        note="我方回合: 抽卡后 idlecmd"))
    return duel(
        "seq_defense_opponent_turn",
        "多步链：对方回合 effectyn → 弃卡代价 → 连锁 → 我方回合（跨回合边界）",
        steps,
    )


ALL_BUILDERS = [
    s_idlecmd_rich, s_idlecmd_minimal,
    s_chain_multiple, s_chain_forced_single,
    s_select_card, s_select_card_selected,
    s_select_tribute, s_select_sum,
    s_select_position_two, s_select_position_single,
    s_effectyn, s_yesno_system, s_yesno_card,
    s_battlecmd, s_unselect_card,
    s_select_option, s_select_place, s_select_disfield,
    s_announce_attrib, s_announce_number,
    seq_summon_battle, seq_defense_opponent_turn,
]


def main():
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "samples")
    os.makedirs(out_dir, exist_ok=True)
    for builder in ALL_BUILDERS:
        d = builder()
        fp = os.path.join(out_dir, f"{d['id']}.json")
        with open(fp, "w", encoding="utf-8") as f:
            json.dump(d, f, ensure_ascii=False, indent=1)
        print(f"wrote samples/{d['id']}.json ({len(d['steps'])} steps)")


if __name__ == "__main__":
    main()
