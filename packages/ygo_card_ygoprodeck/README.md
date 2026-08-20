# ygo_card_ygoprodeck

[YGOPRODeck API v7](https://db.ygoprodeck.com/api-guide/) 客户端：免费、无需鉴权的英文卡数据 + 卡图 CDN。

实现 `ygo_data` 的 `ICardService`，经 `service_loader` 注册（模式同 `ygo_card_baige`）。

## 能力矩阵

| 能力 | 支持 | 说明 |
|---|---|---|
| 按卡密查询 `getCard(code)` | ✅ | `cardinfo.php?id=<code>` |
| 模糊搜索 `searchCards(kw)` | ✅ | `?fname=` 卡名片段 |
| 组合过滤 `searchCombined` | ✅ | type/attribute/race 位掩码反查为 API 字符串；type 仅支持主类别单值（Spell/Trap/Link/XYZ/Synchro/Fusion/Ritual/Normal/Effect Monster），泛型 `TYPE_MONSTER`/`TYPE_PENDULUM` 无法映射（该维度被忽略而非窄化） |
| 卡图 URL `getCardImageUrl` | ✅ | `https://images.ygoprodeck.com/images/cards/<code>.jpg`（另有 `_small`/`_cropped` 变体） |
| 卡图二进制 `getCardImage` | ✅ | 直取 CDN bytes |
| 中文卡名/文本 | ❌ | 英文 TCG 数据（中文需求用 `ygo_card_yugipedia`） |
| 禁限卡表 | ❌ | 用 `ygo_banlist_mycard` |
| 卡组校验 | ❌ | — |

## 用法

```dart
import 'package:ygo_card_ygoprodeck/ygo_card_ygoprodeck.dart';

final client = YgoprodeckApiClient();
final card = await client.fetchCard(89631139); // 青眼白龙
final cards = await client.searchCards('blue-eyes');

// 服务形态（经 service_loader 注册后由宿主取用）
final service = YgoprodeckCardService();
```

## 字段映射（API 字符串 → OCG 位掩码）

映射表在 `lib/src/ocg_strings.dart`，数值与 `packages/ocgcore/lib/ocgcore.dart` 同源（本包为纯数据客户端，不依赖引擎插件）：

- `attribute`：`LIGHT→0x10`、`DARK→0x20` 等七属性
- `race`（怪兽）：`Dragon→0x2000`、`Cyberse→0x1000000`、`Illusion→0x2000000` 等 26 种族
- `type` + `typeline`：合并扫描关键词位（`Normal/Effect/Fusion/Synchro/Xyz/Link/Pendulum/Tuner/Flip/Gemini/Toon/Spirit/Union/Token`）
- 魔法/陷阱的 `race` 字段承载 property（`Quick-Play/Continuous/Equip/Field/Counter/Ritual`），映射到 type 位；`CardInfo.race` 置 0
- `linkmarkers`：`Top→0x080`、`Bottom-Left→0x001` 等（含官方 0x010 保留位跳号）
- **Link 怪**：`def` 为 null → 0；`CardInfo.level` 存 `linkval`（cdb 惯例）
- **灵摆怪**：`scale` 写入 `lscale`/`rscale`（YGOPRODeck 只给单刻度，双侧同值）

## 错误处理

- 无结果：API 返回 HTTP 400 + `{"error": ...}`，本包归一为空列表/null（不抛异常）
- 网络/5xx：抛 `YgoCardDeckException`（同 baige 的错误语义）

## 注意

- API 有速率限制倾向（社区公约 ≤ 20 req/s），批量拉取请自加节流
- 数据为 TCG 英文，新卡同步略慢于 OCG 源（百鸽/萌卡）

## 测试

```
dart test
```

解析层为纯函数（`YgoprodeckApiClient.parseCard` / `ocg_strings.dart`），测试用真实 API 响应样本驱动（fixture 内嵌于测试文件，注明取样日期）。
