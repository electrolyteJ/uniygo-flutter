"""Ground truth for the Dart PyIntSet simulator.

Generates randomized cases exercising CPython `set` behavior that the
select_sum branch of get_legal_actions depends on:
  - set construction from ordered value lists -> iteration order
  - `set(c) - set(selected)` -> iteration order (both CPython strategies)
  - the full select_sum combination pipeline -> (card_index, can_finish)
    action order

Output: packages/ygo_agent/test/data/pysim_truth.json
"""

import json
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "vendor/ygo-agent/ygoinf"))

from ygoinf.features import sum_to2, combinations_with_weight2  # noqa: E402

rng = random.Random(20260812)


def gen_build_cases(n=20000):
    """Random insertion lists -> iteration order."""
    cases = []
    for i in range(n):
        if i < 100:
            # Heavy collisions: all values share low bits (slot 0 at size 8).
            vals = [rng.choice([0, 8, 16, 24, 32, 40, 48, 56])
                    for _ in range(rng.randint(0, 12))]
        elif i < 200:
            # Sizes crossing growth boundaries (5th and 19th insert grow).
            m = rng.choice([4, 5, 6, 18, 19, 20])
            vals = rng.sample(range(40), m)
        elif i < 300:
            # Values chosen to collide pairwise mod 8 and mod 32.
            base = rng.randint(0, 7)
            vals = [base + 8 * k for k in rng.sample(range(8), rng.randint(0, 8))]
            rng.shuffle(vals)
        else:
            hi = rng.choice([8, 16, 32, 40, 100])
            vals = [rng.randint(0, hi - 1) for _ in range(rng.randint(0, 20))]
        cases.append([vals, list(set(vals))])
    return cases


def gen_diff_cases(n=20000):
    """set(c) - set(selected) -> iteration order."""
    cases = []
    for i in range(n):
        if i < 200:
            # Targeted: len(c) around the (len(c) >> 2) > len(selected)
            # strategy boundary with empty/non-empty selected.
            m = rng.choice([3, 4, 5, 8, 9])
            c = rng.sample(range(24), m)
            selected = rng.sample(c, rng.randint(0, min(2, len(c))))
        else:
            c = rng.sample(range(32), rng.randint(0, 12))
            pool = c + [rng.randint(0, 31) for _ in range(3)]
            selected = rng.sample(pool, rng.randint(0, min(4, len(pool))))
        result = list(set(c) - set(selected))
        cases.append([c, selected, result])
    return cases


def sum_pipeline(card_levels, level_sum, selected_list):
    """Upstream select_sum combination pipeline, verbatim."""
    combs = combinations_with_weight2(card_levels, level_sum)
    selected = set(selected_list)
    combs = [
        c - selected for c in combs if c.intersection(selected) == selected
    ]
    combs2 = []
    for c in combs:
        if c not in combs2:
            combs2.append(c)
    if set() in combs2:
        return {"error": "empty"}
    can_finish = {}
    for c in combs2:
        i = next(iter(c))
        f = len(c) == 1
        if i not in can_finish:
            can_finish[i] = f
        else:
            can_finish[i] = can_finish[i] or f
    # JSON keys must be strings; preserve dict insertion order.
    return {"actions": [[int(k), bool(v)] for k, v in can_finish.items()]}


def gen_sum_cases(n=4000):
    cases = []
    for i in range(n):
        n_cards = rng.randint(1, 12)
        card_levels = []
        for _ in range(n_cards):
            l1 = rng.randint(1, 12)
            levels = [l1]
            if rng.random() < 0.4:
                l2 = rng.randint(1, 12)
                if l2 != l1:
                    levels.append(l2)
            card_levels.append(levels)
        level_sum = rng.randint(0, 24)
        selected = rng.sample(range(n_cards), rng.randint(0, min(3, n_cards)))
        cases.append([card_levels, level_sum, selected,
                      sum_pipeline(card_levels, level_sum, selected)])
    return cases


def main():
    data = {
        "build": gen_build_cases(),
        "diff": gen_diff_cases(),
        "sum": gen_sum_cases(),
    }
    out = (Path(__file__).resolve().parent.parent.parent
           / "packages/ygo_agent/test/data/pysim_truth.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, separators=(",", ":")))
    print(f"wrote {out} ({out.stat().st_size} bytes)")
    print(f"build={len(data['build'])} diff={len(data['diff'])} "
          f"sum={len(data['sum'])}")


if __name__ == "__main__":
    main()
