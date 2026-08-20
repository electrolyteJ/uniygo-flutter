/// deck_editor1 —— 卡组编辑器 UI 包（自 apps/uniygopro 下沉）。
///
/// 宿主 app（如 uniygopro）通过包依赖复用：
/// ```dart
/// import 'package:deck_editor1/deck_editor1.dart';
/// ```
/// 入口为 [DeckEditorPage]（配合 go_router 路由使用），
/// 依赖的卡组数据 store 见 [DeckEditorStore] / [DeckEditorSession]。
library;

export 'src/models/deck_model.dart';
export 'src/pages/deck_editor_page.dart';
export 'src/pages/deck_editor_session.dart';
export 'src/pages/deck_editor_store.dart';
export 'src/widgets/banlist_status_badge.dart';
export 'src/widgets/card_grid_view.dart';
export 'src/widgets/card_list_view.dart';
export 'src/widgets/card_search_bar.dart';
export 'src/widgets/deck_edit_panel.dart';
export 'src/widgets/deck_list_panel.dart';
export 'src/widgets/deck_zone_widget.dart';
