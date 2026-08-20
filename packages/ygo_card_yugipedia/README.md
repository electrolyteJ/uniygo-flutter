# ygo_card_yugipedia

[Yugipedia](https://yugipedia.com)（MediaWiki）卡数据客户端：**多语言卡名与卡面文本**（含简体中文 `sc_name`/`sc_text`、繁体中文 `tc_*`）。

实现 `ygo_data` 的 `ICardService`，经 `service_loader` 注册（模式同 `ygo_card_baige`）。

## 定位

Yugipedia 的价值不是"又一个卡数据库"，而是**多语言覆盖**——当你需要中文卡名/中文效果文本而不想自建翻译库时用它。英文卡数据与卡图请用 `ygo_card_ygoprodeck` / `ygo_card_baige`。

## 能力矩阵

| 能力 | 支持 | 说明 |
|---|---|---|
| 按卡密查询 `getCard(code)` | ✅ | 经 Yugipedia 密码重定向页（`titles=<code>&redirects=1` → 卡页） |
| 卡名搜索 `searchCards(kw)` | ✅ | MediaWiki `prefixsearch` + 批量拉取（一次请求多页） |
| 中文卡名/文本 | ✅ | `sc_name`/`sc_text`（缺中文时回退繁中→英文） |
| 组合过滤 `searchCombined` | ⚠️ 仅卡名 | 类型/属性/种族过滤不支持（抛 `UnsupportedError`） |
| 卡图 | ❌ | 无按卡密直链（卡图是卡页内文件名引用，需二级解析，未实现） |
| 禁限卡表/卡组校验 | ❌ | — |

## 用法

```dart
import 'package:ygo_card_yugipedia/ygo_card_yugipedia.dart';

final client = YugipediaApiClient();
final card = await client.fetchCard(89631139);
// card.info.name = '青眼白龙'（sc_name 优先）
// card.info.desc = '以高攻击力著称的传说之龙。任何对手都能粉碎，其破坏力不可估量。'
// card.nameEn = 'Blue-Eyes White Dragon'（页面标题）

// 默认中文优先；需要英文原文时：
final cardEn = CardTable2Parser.parse(wikitext, pageTitle: title, preferChinese: false);
```

## 数据来源与解析

- 卡页 wikitext 的 `{{CardTable2}}` 模板（`action=query&prop=revisions&rvprop=content&rvsection=0`）
- 卡密：`password` 字段（剥前导零）
- 类型推断：怪兽 `types`（`Dragon / Normal` 首段为种族，其余为类型修饰位）；魔法/陷阱 `card_type` + `property`
- 位掩码数值与 `packages/ocgcore/lib/ocgcore.dart` 同源（本包为纯数据客户端，不依赖引擎插件；常量更新时需同步）
- 英文 `text` 中的 wiki 标记会清洗（`[[a|b]]→b`、斜体标记、简单模板剥壳取正文段）

## 已知限制

- MediaWiki 1.31，响应解析兼容旧式 `revisions[0]['*']` 与 slots 结构
- Yugipedia 响应偏慢（建议 `timeout ≥ 30s`，本包默认 45s）；搜索为"前缀匹配+批量拉详情"，不适合高频调用
- Link 怪的 link rating：CardTable2 无独立字段，`level` 字段可能为空（按 0 处理）
- 攻击/守备力未知（`?`）时按 0 处理
- 请遵守 Yugipedia 的 robots 与社区礼仪（自带 User-Agent 标识）

## 测试

```
dart test
```

`CardTable2Parser` 为纯函数，测试用真实 wikitext 样本驱动（fixture 内嵌，注明取样日期）。
