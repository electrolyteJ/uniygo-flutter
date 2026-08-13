# ygo_agent_golden — ygo-agent 模型嵌入 Flutter 的 golden 数据工具链

本目录为「把 [ygo-agent](https://github.com/sbl1996/ygo-agent) 的 RL 模型
（`0546_26550M.tflite`）直接嵌入 uniygopro Flutter 应用、离线推理」这一目标的
**第一步产物**：一套可复现的 Python 工具链，从上游参考实现
（`ygoinf/features.py`）dump 出逐位（bit-exact）的 golden 数据，
供后续 Dart 移植版做等价性测试。

整体路线（三步，本目录覆盖第 1 步）：

1. **golden 数据**（本目录）：用上游 `features.predict()` + tflite 模型，对覆盖
   全部 15 种 `action_msg` 的样本局面 dump 输入张量与输出概率。
2. **Dart 特征移植**：把 `features.py`（约 1150 行）移植为 Dart，用本目录
   golden 的 `*_tensors.npz` 做逐字节等价测试。
3. **tflite_flutter 接入**：模型作为 asset 打包，挂到 `duelink_ai` 的
   `DuelEngine._tryAutoAnswer()` 同步钩子（`DuelAutoAnswer`），
   不支持的局面回退现有规则 AI。

---

## 目录结构

```
tools/ygo_agent_golden/
├── make_samples.py          # 样本生成器：22 场决策局面（含 2 场多步序列）
├── gen_golden.py            # golden 生成：复刻 ygoinf 服务器协议跑样本并 dump
├── verify_golden.py         # golden 全面校验（形状/语义/连续性/影子一致性）
├── samples/*.json           # 样本 Input（遵循 ygoinf/models.py schema）
├── golden/                  # ★ Dart 测试要用的 golden 输出
│   ├── manifest.json        # 模型 sha256、解释器张量规格、常量、上游补丁记录
│   └── <duel_id>/step_NN_{input.json,tensors.npz,pred.json,actions.json}
├── models/
│   ├── 0546_26550M.tflite   # v0.1 release 模型（17MB，训练步数 26550M）
│   └── code_list.txt        # ★ 训练期 864 卡池（commit e319152f0b 版本，勿替换）
└── vendor/ygo-agent/        # 上游 submodule（锁定 rev 见 golden/manifest.json
                             #   的 ygo_agent_rev；含 1 处最小补丁，见下）
```

## 复现步骤

```bash
# 上游仓库以 submodule 形式引入；克隆本仓库后需初始化
git submodule update --init tools/ygo_agent_golden/vendor/ygo-agent
# 应用 golden 生成所依赖的上游 bug 修复（记录于 manifest.vendor_patches）
git -C tools/ygo_agent_golden/vendor/ygo-agent apply \
    tools/ygo_agent_golden/vendor_patches/features_announce_number_fix.patch

cd tools/ygo_agent_golden
uv venv --python 3.11            # numpy 1.26 / tflite 均不支持 3.14
. .venv/bin/activate
uv pip install 'pydantic<2' 'numpy<2' optree
uv pip install tflite-runtime    # Linux x86_64；macOS arm64 无 wheel，
uv pip install ai-edge-litert    #   改用 ai-edge-litert（gen_golden.py 自动回退）
python make_samples.py           # 生成 samples/*.json
python gen_golden.py             # 生成 golden/（含逐位影子校验）
python verify_golden.py          # 全量校验，全绿退出码 0
```

当前环境实测：Python 3.11.15 / numpy 1.26.4 / pydantic 1.10.26 /
ai-edge-litert（macOS arm64）。生成结果：22 场样本、29 个决策步全部通过。

## golden 文件格式

每个决策步一个 `step_NN_` 四件套：

| 文件 | 内容 |
|---|---|
| `input.json` | 喂给 `features.predict()` 的原始 Input |
| `tensors.npz` | 特征张量（**未 batch** 标准形）+ RNN 状态 + 模型原始输出 |
| `pred.json` | probs / responses / can_finish / win_rate / chosen_idx / chosen_response |
| `actions.json` | 完整合法动作表（LegalAction 全字段） |

`tensors.npz` 键：

| 键 | 形状 | dtype | 说明 |
|---|---|---|---|
| `cards_` | (160, 41) | uint8 | 双方场上/手牌等全部卡（每卡一行 41 维） |
| `global_` | (23,) | uint8 | LP/回合/阶段/14 个区域计数等 |
| `actions_` | (24, 12) | uint8 | 合法动作编码，超出 n_legal 的行全零 |
| `h_actions_` | (32, 14) | uint8 | 历史动作环（第 0 步全零） |
| `rstate1_before` / `rstate2_before` | (1, 512) | float32 | 进入本步的 LSTM 隐状态 |
| `rstate1_after` / `rstate2_after` | (1, 512) | float32 | 模型输出的新隐状态（短路步无） |
| `probs_raw` | (24,) | float32 | 模型 softmax 原始输出（短路步无） |
| `value` | 标量 | float32 | 价值头输出；win_rate = (value+1)/2 |

字节序约定：所有 2 字节整数（code_id、atk、def、lp）均为
**高字节在前**：`x[0] = v >> 8, x[1] = v & 0xff`（上游 `int_transform`/
`float_transform`）。

### ★ 模型张量绑定顺序（与直觉不同，务必照此实现）

manifest `interpreter.inputs` 记录了 tflite 解释器的真实输入表。
上游用 `optree.tree_leaves((rstate, obs))` 按叶子序绑定，obs 是 dict、
optree 按 **key 字母序**展开，因此绑定顺序是：

| # | 张量 | 模型输入形状 |
|---|---|---|
| 0 | rstate1 | (1, 512) f32 |
| 1 | rstate2 | (1, 512) f32 |
| 2 | **actions_** | (1, 24, 12) u8 |
| 3 | **cards_** | (1, 160, 41) u8 |
| 4 | **global_** | (1, 23) u8 |
| 5 | **h_actions_** | (1, 32, 14) u8 |

输出顺序：`rstate1', rstate2', probs(1,24), value(1,1)`。
golden 里存的是未 batch 特征，Dart 侧喂模型时需补 batch 维。

### 多步协议（seq_* 样本）

多步样本模拟服务器协议：每步的 `prev_action_idx` 是上一步 `pred.json` 的
`chosen_idx`（模型自弈）。`predict()` 在处理当前步**之前**先把上一步动作压入
历史动作环——因此 `h_actions_` 必须在 update 之后编码（gen_golden.py 已按此
实现；`seq_*` 样本校验了 `rstate_before[k+1] == rstate_after[k]` 的连续性）。

## 上游行为备忘（Dart 移植必须逐条复刻）

1. **单动作短路**：`n_legal == 1` 时不调用模型，`probs=[1.0]`、`win_rate=-1`。
2. **`add_skipped_back`**：select_card/tribute 在 `selected` 下标处插入
   `prob=-1`；select_sum 对未出现在合法动作中的卡插入 `prob=-1`；
   选卡类补 finish（prob=-1，response=-1）。
3. **zip 截断（上游怪癖）**：`predict()` 末尾
   `zip(probs, responses, can_finish)` 按最短截断。select 类插入 -1 后
   probs 变长而 can_finish 不变，**最后一个合法动作（常是 finish）会被丢弃**。
   golden 的 `select_card_selected` 即此情况（4 个合法动作只输出 3 个概率）。
4. **`transform_select_idx`**：客户端回报的 idx 是含 -1 槽位的全局下标，
   更新历史动作前要先换算成模型动作下标。
5. **encode_legal_actions 带调试 print**（`print(actions[0].msg)`），Dart 勿复刻。
6. **上游 bug（已补丁，记录于 manifest.vendor_patches）**：
   `announce_number` 分支 `number <= 0` 拿 pydantic 对象与 int 比较，
   必崩；已改为 `number.number <= 0`。golden 中的 announce_number 数据
   基于补丁后的行为。
7. **不支持的局面抛 NotImplementedError**：select_card min=0、
   select_tribute min≠max 或非 1 星、select_sum overflow/must>2/空组合、
   announce count≠1、announce_number 超 1-12、select_chain 无动作等。
   Dart 侧对应场景应回退规则 AI。

## 响应值 → ocgcore 协议映射（DuelEngine 集成用）

golden `pred.json` 的 `chosen_response` 就是各消息的语义响应，
接入 `DuelEngine` 时按下表转成引擎应答：

| 消息 | features 响应语义 | DuelEngine 需要的字节 |
|---|---|---|
| select_idlecmd | `(index<<16)\|cmd`，6=to_bp、7=to_ep | int32 小端原样发 |
| select_battlecmd | `(index<<16)\|cmd`，2=to_m2、3=to_ep | int32 小端原样发 |
| select_chain | 连锁下标；-1 = 放弃 | int32 小端 |
| select_position | 0x1/0x2/0x4/0x8 | int32 小端 |
| announce_attrib | 属性位（EARTH 0x1 … DIVINE 0x40） | int32 小端 |
| announce_number | options 下标 | int32 小端 |
| select_option | options 下标 | int32 小端 |
| select_card / select_tribute / select_sum / select_unselect_card | 列表下标 | 字节数组 `[count, idx...]`，多选时逐次累积 |
| select_place / select_disfield | places 列表枚举下标 | ★ 需换算：取 `places[idx]`，按 `[player, location, sequence]` 三元组字节序回复（见 `playerop.cpp::select_place` 的 returns.bvalue 布局） |

## 集成注意事项

- **卡池限制**：模型只认识 `models/code_list.txt` 的 864 张卡
  （训练期卡池，commit `e319152f0b` 的 `scripts/code_list.txt`，
  与 `embed864.pkl` 对应；仓库当前 13472 行版本格式不同且含训练后新增卡，
  **不可用**）。已验证本工程 `assets/deck/*.ydk` 全部卡组都在池内。
  对局中出现池外卡 → 回退规则 AI。
- **code_to_id**：0 保留，其余按文件行序从 1 编号；Dart 必须随包附带同一份
  code_list.txt 并保持顺序。
- **平台**：tflite_flutter 不支持 web 目标。
- **挂点**：`packages/duelink_ai/lib/src/ai_connection.dart` 的
  `DuelEngine.setAutoAnswer(...)`（同步钩子，AI 固定为 player 1）。

### 遗留待确认（不影响 golden 正确性）

- Input.cards 是否应枚举卡组里的卡：上游 env 会提供全部卡（含卡组），
  本工具样本按此包含 deck 卡；`encode_global` 的区域计数也包含 deck。
- Link 怪兽场上 defense 的取值语义（样本暂用 cdb 原值，如连接栗子鸟=2）。

## 校验结果

`verify_golden.py` 全量通过（22 duels / 29 steps）：
manifest sha256 与张量规格、每步文件完整性、张量形状/dtype、
global 特征逐维重算核对、cards 行 code_id 合法性、actions 尾行全零、
step0 全零、probs_raw 归一、chosen==argmax、响应前缀一致性、
各消息响应取值范围、多步 rstate/h_actions 连续性。

gen_golden.py 内部还做了影子校验：每步用独立 PredictState + 未包装 model_fn
重跑 `features.predict()`，MsgResponse 与 rstate 逐位相等。
