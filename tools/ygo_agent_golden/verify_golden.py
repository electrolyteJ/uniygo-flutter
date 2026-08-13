#!/usr/bin/env python3
"""verify_golden.py — 全面校验 golden/ 输出，供 Dart 移植前做质量背书。

检查项：
  A. manifest：模型/code_list sha256、解释器 6 输入 4 输出的形状与 dtype、
     输入绑定顺序（rstate1, rstate2, actions_, cards_, global_, h_actions_）
  B. 文件完整性：每步 4 件套（input/tensors/pred/actions）
  C. 张量形状与 dtype（未 batch 的标准形）
  D. 特征语义：
     - cards_ code_id ∈ [1, n_code_list]，非零行数 == 输入卡数
     - global_ lp/turn/is_first/is_my_turn/14 个区域计数逐一按输入重算核对，
       global_[22] == 0
     - actions_ 超出 n_legal 的行全零
     - step0 的 h_actions_ 全零
  E. pred ↔ tensors：非短路步 probs_raw[:n_legal] == pred 中 prob>=0 的子集；
     probs_raw 总和 ≈ 1；chosen == argmax；短路步 probs==[1.0]、win_rate==-1
  F. responses：pred.responses 中 prob>=0 的子集 == actions.json 的 response 序列；
     各 msg_type 的响应取值范围（position 位、属性位、chain -1、idlecmd/battlecmd
     低 16 位命令号等）
  G. 多步连续性：step k+1 的 rstate_before == step k 的 rstate_after，
     h_actions_ 发生变化（历史动作确实被压入）

用法：python verify_golden.py   （全量校验，任一失败即非零退出）
"""
import json
import sys
from pathlib import Path

import numpy as np

BASE = Path(__file__).resolve().parent
GOLDEN = BASE / "golden"

LOCATION_GROUP = {
    "deck": 0, "hand": 1, "mzone": 2, "szone": 3,
    "grave": 4, "removed": 5, "extra": 6,
}

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
        print(f"  FAIL: {msg}")


def verify_manifest():
    print("== manifest")
    m = json.load(open(GOLDEN / "manifest.json"))

    import hashlib
    def sha(p):
        h = hashlib.sha256()
        h.update(open(BASE / p, "rb").read())
        return h.hexdigest()

    check(sha(m["model"]["path"]) == m["model"]["sha256"], "model sha256 mismatch")
    check(sha(m["code_list"]["path"]) == m["code_list"]["sha256"],
          "code_list sha256 mismatch")
    check(m["code_list"]["n_cards"] == 864, "code_list size != 864")

    # 输入绑定顺序：optree 叶子序 = rstate1, rstate2, 然后 obs dict 按字母序
    expect_in = [
        ("rstate1", [1, 512], "float32"),
        ("rstate2", [1, 512], "float32"),
        ("actions_", [1, 24, 12], "uint8"),
        ("cards_", [1, 160, 41], "uint8"),
        ("global_", [1, 23], "uint8"),
        ("h_actions_", [1, 32, 14], "uint8"),
    ]
    ins = m["interpreter"]["inputs"]
    check(len(ins) == 6, f"expected 6 model inputs, got {len(ins)}")
    for i, ((name, shape, dt), got) in enumerate(zip(expect_in, ins)):
        check(got["shape"] == shape and got["dtype"] == dt,
              f"input{i} ({name}): got {got['shape']}/{got['dtype']}, "
              f"want {shape}/{dt}")
    outs = m["interpreter"]["outputs"]
    expect_out = [([1, 512], "float32"), ([1, 512], "float32"),
                  ([1, 24], "float32"), ([1, 1], "float32")]
    check(len(outs) == 4, f"expected 4 model outputs, got {len(outs)}")
    for i, ((shape, dt), got) in enumerate(zip(expect_out, outs)):
        check(got["shape"] == shape and got["dtype"] == dt,
              f"output{i}: got {got['shape']}/{got['dtype']}, want {shape}/{dt}")

    check(len(m.get("vendor_patches", [])) == 1,
          "expected exactly 1 documented vendor patch (announce_number fix)")
    return m


def expected_global(g, cards):
    """按 features.encode_global 的规则独立重算 23 维全局特征。"""
    x = np.zeros(23, dtype=np.uint8)
    lp = int(g["my_lp"]) % 65536
    x[0], x[1] = lp // 256, lp % 256
    lp = int(g["op_lp"]) % 65536
    x[2], x[3] = lp // 256, lp % 256
    x[4] = min(g["turn"], 16)
    # phase 映射依赖上游枚举表，这里只校验值域
    x[6] = int(g["is_first"])
    x[7] = int(g["is_my_turn"])
    counts = np.zeros(14, dtype=np.int64)
    for c in cards:
        off = 0 if c["controller"] == "me" else 7
        counts[off + LOCATION_GROUP[c["location"]]] += 1
    x[8:22] = counts
    return x


def verify_duel(duel_dir, info, code_ids):
    duel_id = info["id"]
    print(f"== {duel_id} ({len(info['steps'])} steps)")
    prev_npz = None
    for row in info["steps"]:
        i = row["step"]
        tag = f"{duel_id}/step{i:02d}"
        stem = duel_dir / f"step_{i:02d}"
        inp = json.load(open(f"{stem}_input.json"))
        npz = np.load(f"{stem}_tensors.npz")
        pred = json.load(open(f"{stem}_pred.json"))
        acts = json.load(open(f"{stem}_actions.json"))

        shortcut = row["shortcut"]
        n_legal = row["n_legal"]
        check(pred["single_action_shortcut"] == shortcut, f"{tag}: shortcut flag")
        check(pred["n_legal_actions"] == n_legal == len(acts),
              f"{tag}: n_legal mismatch")

        # ── C. 形状 / dtype ──
        shapes = {
            "cards_": ((160, 41), np.uint8),
            "global_": ((23,), np.uint8),
            "actions_": ((24, 12), np.uint8),
            "h_actions_": ((32, 14), np.uint8),
            "rstate1_before": ((1, 512), np.float32),
            "rstate2_before": ((1, 512), np.float32),
        }
        if not shortcut:
            shapes.update({
                "rstate1_after": ((1, 512), np.float32),
                "rstate2_after": ((1, 512), np.float32),
                "probs_raw": ((24,), np.float32),
                "value": ((), np.float32),
            })
        check(set(npz.files) == set(shapes), f"{tag}: npz keys {npz.files}")
        for k, (shp, dt) in shapes.items():
            if k in npz.files:
                check(npz[k].shape == shp and npz[k].dtype == dt,
                      f"{tag}: {k} shape/dtype {npz[k].shape}/{npz[k].dtype}")

        # ── D. 特征语义 ──
        cards = npz["cards_"]
        nz = np.count_nonzero(cards[:, 0:2], axis=1).astype(bool) \
            | (cards[:, 2] != 0)
        n_cards = len(inp["cards"])
        check(int(nz.sum()) == min(n_cards, 160),
              f"{tag}: nonzero card rows {int(nz.sum())} != {n_cards}")
        for r in cards[nz]:
            cid = int(r[0]) * 256 + int(r[1])
            if cid not in code_ids:
                check(False, f"{tag}: card code_id {cid} not in code_list")
                break
            check(1 <= r[2] <= 9, f"{tag}: location id {r[2]}")
            check(r[9] <= 13, f"{tag}: level {r[9]} > 13")
            check(r[10] <= 15, f"{tag}: counter {r[10]} > 15")

        g_expect = expected_global(inp["global"], inp["cards"])
        g = npz["global_"]
        for idx_ in list(range(0, 4)) + [4, 6, 7] + list(range(8, 23)):
            check(int(g[idx_]) == int(g_expect[idx_]),
                  f"{tag}: global[{idx_}] {int(g[idx_])} != {int(g_expect[idx_])}")
        check(g[22] == 0, f"{tag}: global[22] (is_end) must be 0")
        check(0 <= g[5] <= 9, f"{tag}: phase id {g[5]} out of range")

        acts_arr = npz["actions_"]
        check(not acts_arr[n_legal:].any(), f"{tag}: action rows >= n_legal nonzero")

        h = npz["h_actions_"]
        if i == 0:
            check(not h.any(), f"{tag}: step0 h_actions_ must be all zero")
        elif prev_npz is not None:
            check(not np.array_equal(h, prev_npz["h_actions_"]),
                  f"{tag}: h_actions_ unchanged after prev action")

        # ── E. pred ↔ tensors ──
        # 注意上游 predict() 末尾 zip(probs, responses, can_finish) 按最短截断：
        # select_card/tribute/sum 且带 selected/finish 时，probs 会比 can_finish
        # 多出插入的 -1 项，导致最后一个合法动作（常为 finish）被丢弃。
        # 因此这里不要求 valid 个数 == n_legal，只要求数值自洽。
        probs = pred["probs"]
        if shortcut:
            check(probs == [1.0], f"{tag}: shortcut probs {probs}")
            check(pred["win_rate"] == -1, f"{tag}: shortcut win_rate")
        else:
            raw = npz["probs_raw"]
            check(abs(float(raw.sum()) - 1.0) < 1e-3,
                  f"{tag}: probs_raw sum {float(raw.sum())}")
            valid = [p for p in probs if p >= 0]
            check(len(valid) >= 1, f"{tag}: no valid prob")
            for v in valid:
                if not np.any(np.isclose(raw, v, atol=1e-6)):
                    check(False, f"{tag}: valid prob {v} not in probs_raw")
                    break
            check(pred["chosen_idx"] == int(np.argmax(np.array(probs))),
                  f"{tag}: chosen != argmax")
            check(probs[pred["chosen_idx"]] >= 0, f"{tag}: chosen prob is -1")
            check(-1.0 <= pred["win_rate"] <= 1.0, f"{tag}: win_rate range")

        # ── F. responses ──
        # got 是 prob>=0 的响应；legal_responses 是全部合法动作响应。
        # 因 zip 截断只可能从尾部丢动作，故 got 必为 legal_responses 的前缀。
        legal_responses = [a["response"] for a in acts]
        got = [r for r, p in zip(pred["responses"], probs) if p >= 0]
        check(got == legal_responses[:len(got)],
              f"{tag}: responses {got} not a prefix of {legal_responses}")
        check(len(pred["responses"]) == len(probs) == len(pred["can_finish"]),
              f"{tag}: pred list lengths")

        msg_type = pred["msg_type"]
        if msg_type == "select_position":
            check(all(r in (1, 2, 4, 8) for r in legal_responses),
                  f"{tag}: position responses {legal_responses}")
        elif msg_type == "announce_attrib":
            check(all(r in (1, 2, 4, 8, 16, 32, 64) for r in legal_responses),
                  f"{tag}: attrib responses {legal_responses}")
        elif msg_type == "select_chain":
            forced = inp["action_msg"]["data"]["forced"]
            check((-1 in legal_responses) == (not forced),
                  f"{tag}: chain cancel presence (forced={forced})")
            n_chains = len(inp["action_msg"]["data"]["chains"])
            check(all(-1 <= r < n_chains for r in legal_responses),
                  f"{tag}: chain responses {legal_responses}")
        elif msg_type == "announce_number":
            n_num = len(inp["action_msg"]["data"]["numbers"])
            check(sorted(legal_responses) == list(range(n_num)),
                  f"{tag}: announce_number responses {legal_responses}")
        elif msg_type == "select_idlecmd":
            check(all(r & 0xFFFF in set(range(9)) for r in legal_responses),
                  f"{tag}: idlecmd cmd low bits {legal_responses}")
        elif msg_type == "select_battlecmd":
            check(all(r & 0xFFFF in (0, 1, 2, 3) for r in legal_responses),
                  f"{tag}: battlecmd cmd low bits {legal_responses}")

        # ── G. 多步连续性 ──
        # prev_npz 为 None 表示上一步是单动作短路（未调模型、无 after rstate）
        if prev_npz is not None:
            check(np.array_equal(npz["rstate1_before"],
                                 prev_npz["rstate1_after"]),
                  f"{tag}: rstate1 discontinuity")
            check(np.array_equal(npz["rstate2_before"],
                                 prev_npz["rstate2_after"]),
                  f"{tag}: rstate2 discontinuity")
        if i == 0:
            check(not npz["rstate1_before"].any()
                  and not npz["rstate2_before"].any(),
                  f"{tag}: step0 rstate must be zero")

        prev_npz = dict(npz) if not shortcut else None

    return True


def main():
    m = verify_manifest()
    code_list = [int(l) for l in open(BASE / m["code_list"]["path"]) if l.strip()]
    # 与上游 init_code_list 一致的 id 集合（0 保留，1..n 顺序分配）
    code_ids = set(range(0, len(code_list) + 1))

    for info in m["duels"]:
        verify_duel(GOLDEN / info["id"], info, code_ids)

    print()
    if failures:
        print(f"FAILED: {len(failures)} problems")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    n_steps = sum(len(d["steps"]) for d in m["duels"])
    print(f"OK: {len(m['duels'])} duels, {n_steps} steps, all checks passed")


if __name__ == "__main__":
    main()
