/// 双方手牌垂直镜像的纯几何测试。
///
/// 锁定：对方手牌是我方手牌关于屏幕水平中线的严格镜像 ——
/// 对方手牌到屏顶的间距 == 我方手牌到屏底的间距（含底部出血，
/// 不再避让顶部 HUD）。
library;

import 'package:duel_room1/field/components/hand_card/hand_bar_component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HandBarComponent.baseLineYFor 双方手牌垂直镜像', () {
    for (final edgeInset in [0.0, 16.0]) {
      test('edgeInset=$edgeInset 时顶/底间距严格相等', () {
        const viewportHeight = 800.0;
        final selfY = HandBarComponent.baseLineYFor(
          isSelfSide: true,
          viewportHeight: viewportHeight,
          edgeInset: edgeInset,
        );
        final oppY = HandBarComponent.baseLineYFor(
          isSelfSide: false,
          viewportHeight: viewportHeight,
          edgeInset: edgeInset,
        );
        // 屏幕水平中线为轴的严格镜像：y_opp = 屏高 - y_self。
        expect(viewportHeight - oppY, selfY);
      });
    }
  });
}
