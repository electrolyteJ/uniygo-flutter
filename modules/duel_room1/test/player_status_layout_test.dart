import 'package:duel_room1/field/util/duel_field_layout.dart';
import 'package:duel_room1/field/components/player_status/player_status_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayerStatusLayout', () {
    test('卡片紧贴场地左侧且不压棋盘', () {
      // 右缘距棋盘左沿（colX[0] 左沿 = -286）恰留 boardGap。
      final boardLeft =
          DuelFieldLayout.colX[0] - DuelFieldLayout.slotWidth / 2;
      final cardRight = PlayerStatusLayout.centerX + PlayerStatusLayout.cardWidth / 2;
      expect(boardLeft - cardRight, closeTo(PlayerStatusLayout.boardGap, 1e-9));
      // 左缘即相机内容需覆盖的最左点。
      expect(
        PlayerStatusLayout.leftEdge,
        closeTo(PlayerStatusLayout.centerX - PlayerStatusLayout.cardWidth / 2, 1e-9),
      );
    });

    test('双卡竖排不重叠且各靠近自家半场', () {
      const half = PlayerStatusLayout.cardHeight / 2;
      // 对方卡在上（y<0）、我方卡在下（y>0），两卡垂直不相交。
      expect(PlayerStatusLayout.oppCenterY, lessThan(0));
      expect(PlayerStatusLayout.selfCenterY, greaterThan(0));
      expect(
        PlayerStatusLayout.oppCenterY + half,
        lessThan(PlayerStatusLayout.selfCenterY - half),
      );
      // 两卡都在相机内容高度（510）内。
      expect(PlayerStatusLayout.selfCenterY + half, lessThanOrEqualTo(255));
      expect(-(PlayerStatusLayout.oppCenterY - half), lessThanOrEqualTo(255));
    });

    test('卡内布局：五行计数完整落在卡片高度内', () {
      final lastRowBottom =
          PlayerStatusLayout.rowCenterY(PlayerStatusLayout.rowLabels.length - 1) +
              PlayerStatusLayout.rowHeight / 2;
      expect(
        lastRowBottom + PlayerStatusLayout.padding,
        lessThanOrEqualTo(PlayerStatusLayout.cardHeight + 1e-9),
      );
      expect(PlayerStatusLayout.rowLabels, ['H', 'D', 'EX', 'GY', 'B']);
    });
  });
}
