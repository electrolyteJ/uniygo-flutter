/// 卡组编辑器布局档位的纯函数推导。
///
/// 单独成文件以便在无 `ServiceSingleton` 依赖的情况下单测断点契约。
library;

/// 单栏 / 双栏 / 三栏 的栏数下界与上界。
const int kDeckEditorMinColumns = 1;
const int kDeckEditorMaxColumns = 3;

/// 解析卡组编辑器栏数。
///
/// [override] 非空时（宿主按 AppLayout 档位注入 compact 1 / regular 2 / wide 3）
/// 直接采用，并夹在 [kDeckEditorMinColumns]..[kDeckEditorMaxColumns] 之间；
/// 为空时按自身可用宽度推导：`< 600` 单栏，否则三栏（独立路由的旧行为）。
int resolveDeckEditorColumns({
  required double availableWidth,
  int? override,
}) {
  final columns = override ?? (availableWidth < 600 ? 1 : 3);
  if (columns < kDeckEditorMinColumns) return kDeckEditorMinColumns;
  if (columns > kDeckEditorMaxColumns) return kDeckEditorMaxColumns;
  return columns;
}
