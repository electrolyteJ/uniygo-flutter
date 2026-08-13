#!/usr/bin/env python3
"""gen_golden.py — 生成 Dart 移植 ygo-agent features.py 所需的 golden 数据。

流程（严格复刻 ygoinf 服务器协议）：
  samples/*.json 的每场 duel 用一个全新 PredictState（零 rstate + 零历史动作）
  逐步喂给上游 features.predict()；每步的 prev_action_idx 取上一步模型输出的
  argmax 下标（等价于"模型自己下棋"），从而驱动 update_history_actions，
  让 RNN 隐状态和历史动作环在多步样本里真实传递。

采集方式：
  model_fn 外包一层透明 capture wrapper，记录进入模型前的全部输入张量
  （rstate1/rstate2/cards_/global_/actions_/h_actions_）与模型输出
  （新 rstate、原始 probs、value）。单动作短路路径（n_actions==1）不调用模型，
  只 dump 编码出的特征张量。

影子校验：
  每步额外用一份独立的 shadow PredictState + 未包装的 model_fn 重跑一遍
  上游 features.predict()，要求两路 MsgResponse 与最终 rstate 逐位相等，
  证明 wrapper 无侵入、且推理在 CPU 上确定。

输出：
  golden/manifest.json
  golden/<duel_id>/step_<NN>_input.json     # 原始 Input（喂给 predict 的）
  golden/<duel_id>/step_<NN>_tensors.npz    # 特征张量 + rstate(+模型输出)
  golden/<duel_id>/step_<NN>_pred.json      # probs/responses/can_finish/win_rate/choice
  golden/<duel_id>/step_<NN>_actions.json   # 完整合法动作表（LegalAction 字段）
"""
import argparse
import contextlib
import hashlib
import io
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

BASE = Path(__file__).resolve().parent
VENDOR_YGOINF = BASE / "vendor" / "ygo-agent" / "ygoinf"
MODEL_PATH = BASE / "models" / "0546_26550M.tflite"
CODE_LIST = BASE / "models" / "code_list.txt"
SAMPLES_DIR = BASE / "samples"
GOLDEN_DIR = BASE / "golden"

sys.path.insert(0, str(VENDOR_YGOINF))

# ── tflite runtime：优先 tflite-runtime，回退 ai-edge-litert ──────────
try:
    import tflite_runtime.interpreter  # noqa: F401
    TFLITE_MODULE = "tflite-runtime"
except ImportError:
    import types

    import ai_edge_litert.interpreter as _litert

    _m = types.ModuleType("tflite_runtime")
    _m.interpreter = _litert
    sys.modules["tflite_runtime"] = _m
    sys.modules["tflite_runtime.interpreter"] = _litert
    TFLITE_MODULE = "ai-edge-litert"

from ygoinf import features  # noqa: E402
from ygoinf.models import Input  # noqa: E402
from ygoinf.tflite_inf import load_model, predict_fn  # noqa: E402


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


class Capture:
    """透明包装 model_fn：只记录，不改变任何数值。"""

    def __init__(self, real_fn):
        self.real_fn = real_fn
        self.last = None

    def __call__(self, rstate, obs):
        self.last = {
            "rstate1_before": rstate[0].copy(),
            "rstate2_before": rstate[1].copy(),
            "cards_": obs["cards_"].copy(),
            "global_": obs["global_"].copy(),
            "actions_": obs["actions_"].copy(),
            "h_actions_": obs["h_actions_"].copy(),
        }
        new_rstate, probs, value = self.real_fn(rstate, obs)
        self.last["rstate1_after"] = new_rstate[0].copy()
        self.last["rstate2_after"] = new_rstate[1].copy()
        self.last["probs_raw"] = list(probs)
        self.last["value"] = float(value)
        return new_rstate, probs, value


def build_model_input(state, inp):
    """与 features.predict 内部一致的特征构造（独立对象，用于 dump）。

    注意：h_actions_ 不在此处构造 —— predict() 内部会先
    update_history_actions(prev_action_idx) 再编码历史动作，
    必须在 predict 返回后从同一 state 编码才能得到相同结果。
    """
    legal = features.get_legal_actions(inp.action_msg)
    cards, spec_infos = features.encode_cards(inp.cards)
    global_ = features.encode_global(inp.global_, inp.cards)
    actions = features.encode_legal_actions(legal, spec_infos)
    return legal, cards, global_, actions, spec_infos


def quiet(fn, *a, **kw):
    """屏蔽上游 encode_legal_actions 里的调试 print。"""
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        return fn(*a, **kw)


def run_duel(duel, interpreter, capture, shadow_capture):
    """按服务器协议跑一场 duel，落盘所有 golden 文件。返回概要。"""
    out_dir = GOLDEN_DIR / duel["id"]
    out_dir.mkdir(parents=True, exist_ok=True)

    state = features.PredictState()
    shadow_state = features.PredictState()
    prev_idx = None
    summary = []

    for i, step in enumerate(duel["steps"]):
        inp = Input.parse_obj(step["input"])

        # 与 predict 内部一致的特征（cards/global/actions 在 predict 前取；
        # h_actions_ 必须在 predict 后取，见 build_model_input 说明）
        legal, cards, global_, actions, _ = quiet(
            build_model_input, state, inp)
        rstate_before = (state.rstate[0].copy(), state.rstate[1].copy())
        n_legal = len(legal)
        assert n_legal >= 1, f"{duel['id']} step{i}: no legal actions"

        capture.last = None
        resp = quiet(features.predict, capture, inp, prev_idx, state)

        # 影子校验：独立状态 + 未包装 model_fn 重跑，必须逐位一致
        shadow_resp = quiet(features.predict, shadow_capture.real_fn,
                            inp, prev_idx, shadow_state)
        assert resp.json() == shadow_resp.json(), \
            f"{duel['id']} step{i}: shadow MsgResponse mismatch"
        for a, b in zip(state.rstate, shadow_state.rstate):
            assert np.array_equal(a, b), \
                f"{duel['id']} step{i}: shadow rstate mismatch"

        # predict 已把 prev_action 压入环形缓冲；此时编码即模型实际所见
        h_actions = state.history_actions.encode(inp.global_.turn)

        probs = [p for p in resp.action_preds]
        prob_list = [p.prob for p in probs]
        resp_list = [p.response for p in probs]
        finish_list = [p.can_finish for p in probs]
        chosen = int(np.argmax(np.array(prob_list, dtype=np.float64)))
        assert prob_list[chosen] >= 0, f"{duel['id']} step{i}: chose skipped action"

        msg_type = inp.action_msg.data.msg_type
        shortcut = n_legal == 1

        # ── dump tensors ──
        npz = {
            "rstate1_before": rstate_before[0],
            "rstate2_before": rstate_before[1],
            "cards_": cards,
            "global_": global_,
            "actions_": actions,
            "h_actions_": h_actions,
        }
        if not shortcut:
            assert capture.last is not None
            # 一致性：我们自行构造的张量必须与 wrapper 捕获的完全一致
            for k in ("cards_", "global_", "actions_", "h_actions_"):
                assert np.array_equal(npz[k], capture.last[k]), \
                    f"{duel['id']} step{i}: reconstructed {k} != captured"
            for rk, ck in (("rstate1_before", "rstate1_before"),
                           ("rstate2_before", "rstate2_before")):
                assert np.array_equal(npz[rk], capture.last[ck])
            npz.update({
                "rstate1_after": capture.last["rstate1_after"],
                "rstate2_after": capture.last["rstate2_after"],
                "probs_raw": np.array(capture.last["probs_raw"], dtype=np.float32),
                "value": np.array(capture.last["value"], dtype=np.float32),
            })
        np.savez_compressed(out_dir / f"step_{i:02d}_tensors.npz", **npz)

        # ── dump input / pred / actions ──
        with open(out_dir / f"step_{i:02d}_input.json", "w", encoding="utf-8") as f:
            json.dump(step["input"], f, ensure_ascii=False, indent=1)

        pred = {
            "msg_type": msg_type,
            "n_legal_actions": n_legal,
            "single_action_shortcut": shortcut,
            "win_rate": resp.win_rate,
            "probs": prob_list,
            "responses": resp_list,
            "can_finish": finish_list,
            "chosen_idx": chosen,
            "chosen_response": resp_list[chosen],
            "prev_action_idx": prev_idx,
        }
        if step.get("note"):
            pred["note"] = step["note"]
        with open(out_dir / f"step_{i:02d}_pred.json", "w", encoding="utf-8") as f:
            json.dump(pred, f, ensure_ascii=False, indent=1)

        action_rows = [json.loads(a.json()) for a in legal]
        with open(out_dir / f"step_{i:02d}_actions.json", "w", encoding="utf-8") as f:
            json.dump(action_rows, f, ensure_ascii=False, indent=1)

        summary.append({
            "step": i, "msg_type": msg_type, "n_legal": n_legal,
            "shortcut": shortcut, "chosen_idx": chosen,
            "chosen_response": resp_list[chosen],
            "win_rate": resp.win_rate,
        })
        prev_idx = chosen

    return summary


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--duel", help="只跑指定 id 的样本")
    ap.add_argument("--num-threads", type=int, default=1)
    args = ap.parse_args()

    assert MODEL_PATH.exists(), f"missing {MODEL_PATH}"
    assert CODE_LIST.exists(), f"missing {CODE_LIST}"

    features.init_code_list(str(CODE_LIST))
    interpreter = load_model(str(MODEL_PATH), num_threads=args.num_threads)
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    capture = Capture(lambda rstate, obs: predict_fn(interpreter, rstate, obs))
    shadow_capture = Capture(lambda rstate, obs: predict_fn(interpreter, rstate, obs))

    # 预热 + 记录真实张量规格（Dart 侧按此对齐形状/顺序）
    rstate0 = features.init_rstate()
    quiet(predict_fn, interpreter, rstate0, features.sample_input())

    sample_files = sorted(SAMPLES_DIR.glob("*.json"))
    if args.duel:
        sample_files = [p for p in sample_files if p.stem == args.duel]
    assert sample_files, "no samples found; run make_samples.py first"

    GOLDEN_DIR.mkdir(exist_ok=True)
    manifest = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "model": {
            "path": str(MODEL_PATH.relative_to(BASE)),
            "sha256": sha256(MODEL_PATH),
            "bytes": MODEL_PATH.stat().st_size,
        },
        "code_list": {
            "path": str(CODE_LIST.relative_to(BASE)),
            "sha256": sha256(CODE_LIST),
            "n_cards": sum(1 for line in open(CODE_LIST) if line.strip()),
        },
        "tflite_runtime": TFLITE_MODULE,
        "interpreter": {
            "inputs": [
                {"index": int(d["index"]), "name": d["name"],
                 "shape": [int(s) for s in d["shape"]],
                 "dtype": d["dtype"].__name__}
                for d in input_details],
            "outputs": [
                {"index": int(d["index"]), "name": d["name"],
                 "shape": [int(s) for s in d["shape"]],
                 "dtype": d["dtype"].__name__}
                for d in output_details],
        },
        "constants": {
            "N_CARD_FEATURES": features.N_CARD_FEATURES,
            "MAX_CARDS": features.MAX_CARDS,
            "MAX_ACTIONS": features.MAX_ACTIONS,
            "N_ACTION_FEATURES": features.N_ACTION_FEATURES,
            "N_GLOBAL_FEATURES": features.N_GLOBAL_FEATURES,
            "N_HISTORY_ACTIONS": features.N_HISTORY_ACTIONS,
            "H_ACTIONS_FEATS": features.H_ACTIONS_FEATS,
            "N_RNN_CHANNELS": features.N_RNN_CHANNELS,
            "DESCRIPTION_LIMIT": features.DESCRIPTION_LIMIT,
            "CARD_EFFECT_OFFSET": features.CARD_EFFECT_OFFSET,
        },
        "duels": [],
    }
    try:
        rev = subprocess.run(
            ["git", "-C", str(BASE / "vendor" / "ygo-agent"), "rev-parse", "HEAD"],
            capture_output=True, text=True, check=True).stdout.strip()
        manifest["ygo_agent_rev"] = rev
    except Exception:
        manifest["ygo_agent_rev"] = None
    # 对 vendored 上游代码的最小补丁（否则 golden 无法生成），逐项记录
    manifest["vendor_patches"] = [
        {
            "file": "ygoinf/ygoinf/features.py",
            "where": "get_legal_actions / announce_number branch",
            "change": "range check 'number <= 0 or number > 12' -> "
                      "'number.number <= 0 or number.number > 12'",
            "reason": "upstream TypeError: compares AnnounceNumber object to int; "
                      "announce_number branch unusable without fix",
        },
    ]

    for fp in sample_files:
        duel = json.load(open(fp, encoding="utf-8"))
        print(f"== {duel['id']} ({len(duel['steps'])} steps)")
        summary = run_duel(duel, interpreter, capture, shadow_capture)
        for row in summary:
            print(f"   step{row['step']} {row['msg_type']:<20} "
                  f"n={row['n_legal']:<3} shortcut={row['shortcut']!s:<5} "
                  f"chosen={row['chosen_idx']} resp={row['chosen_response']} "
                  f"win={row['win_rate']}")
        manifest["duels"].append({
            "id": duel["id"],
            "description": duel["description"],
            "steps": summary,
        })

    manifest["versions"] = {
        "python": sys.version.split()[0],
        "numpy": np.__version__,
    }
    with open(GOLDEN_DIR / "manifest.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
    print(f"\nwrote {GOLDEN_DIR}/manifest.json + "
          f"{len(sample_files)} duel dirs; shadow verification passed for all steps")


if __name__ == "__main__":
    main()
