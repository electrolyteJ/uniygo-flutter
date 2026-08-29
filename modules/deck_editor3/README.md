# deck_editor3 —— 卡组中心

卡组市场（MDPro3 卡组广场协议）+ 我的卡组 + 全新组卡编辑器。库模块，
由宿主（uniygopro 路由 `/deck-square`）挂载。

## 功能

- **卡组市场**：搜索 / 排序（最新/点赞/天梯）/ 分页 / 详情 / 点赞 /
  复制到我的卡组 / YDK 导出剪贴板
- **我的卡组**：本地 CRUD（ygo_deck_mycard）、重命名、YDK 导入、
  发布到市场（需 MyCard 登录）
- **组卡编辑器**（全新 UI）：三栏布局（卡池搜索 | 卡组分区 Tab | 卡片详情），
  同卡限 3 / 分区容量（主 40-60、额外/副 15）/ 额外怪分区路由 /
  禁限表校验（IBanlistService）

## 卡组市场数据源

协议为 MDPro3 卡组广场（`packages/resource_deck_mdpro3` DeckApiClient）。
**注意：官方卡组广场域名 deck.moecube.com 已下线（NXDOMAIN）**，
baseUrl 可通过构造参数或编译期 `--dart-define=DECK_SQUARE_URL=...` 覆盖。

自建服务端：`servers/ygo_deck_server` 提供 /api/mdpro3 兼容层
（list/detail/deckId/like/sync single），本地验证：

```bash
cd servers/ygo_deck_server && dart_frog build && PORT=8901 dart run build/bin/server.dart
flutter run -t lib/main_deck3.dart --dart-define=DECK_SQUARE_URL=http://127.0.0.1:8901
```

## 调试入口

`apps/uniygopro/lib/main_deck3.dart` —— 直开卡组中心（含服务注册）。

## 结构

```
lib/
  deck_editor3.dart          导出 DeckHubPage
  src/
    deck_state/              Riverpod：square / my_decks / editor + 纯规则 editor_rules
    pages/                   hub / square / detail / my_decks / editor
    widgets/                 deck_zone_grid（三区网格，详情与编辑器共用）
```
