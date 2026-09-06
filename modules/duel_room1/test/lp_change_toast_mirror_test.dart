/// LP 变动 toast 双方锚点的镜像关系测试。
///
/// 手牌栏已改为关于屏幕水平中线严格镜像；toast 锚点（我方手牌栏
/// 正上方 / 对方手牌栏正下方）必须保持同一镜像口径。
library;

import 'package:duel_room1/field/components/lp/lp_change_toast_component.dart';
import 'package:duel_room1/field/duel_field_game.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('双方 LP toast 锚点关于屏幕水平中线镜像', (tester) async {
    final game = DuelFieldGame();
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    final toasts = game.camera.viewport.children
        .query<LpChangeToastComponent>()
        .toList();
    final selfToast = toasts.singleWhere((t) => t.isSelf);
    final oppToast = toasts.singleWhere((t) => !t.isSelf);

    // 我方 toast 在手牌栏正上方、对方在正下方，且镜像：
    // y_opp = 画布高 - y_self（画布即视口屏幕空间）。
    expect(
      game.size.y - oppToast.position.y,
      closeTo(selfToast.position.y, 1e-9),
    );
  });
}
