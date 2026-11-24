/// deck_editor3 —— 卡组中心模块：卡组市场（MDPro3 卡组广场）+
/// 我的卡组 + 全新组卡编辑器。库模块，由宿主路由挂载。
///
/// 公开面只有 [DeckHubPage]：三段内容（市场 / 我的卡组 / 组卡器）都是它的
/// 内部实现，外部一旦需要独立挂载某一段，应通过 [DeckHubPage] 的参数
/// （`embedded` / `editorBuilder`）表达，而不是把子页面加进导出面——
/// 否则三段式「唯一 UI 实现」的约束会被导出面再次打散。
library;

export 'src/deck_hub_page.dart';
