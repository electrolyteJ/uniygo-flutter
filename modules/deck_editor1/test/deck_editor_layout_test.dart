/// 卡组编辑器栏数断点契约（compact 单栏 / regular 双栏 / wide 三栏）。
library;

import 'package:deck_editor1/deck_editor1.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveDeckEditorColumns', () {
    test('宿主注入档位优先：AppLayout contentColumns 1/2/3 原样采用', () {
      for (final columns in const [1, 2, 3]) {
        expect(
          resolveDeckEditorColumns(availableWidth: 1600, override: columns),
          columns,
        );
      }
    });

    test('注入档位不受可用宽度影响（窄栏保持宿主判定）', () {
      expect(
        resolveDeckEditorColumns(availableWidth: 380, override: 2),
        2,
      );
    });

    test('未注入时按可用宽度推导：<600 单栏，>=600 三栏', () {
      expect(resolveDeckEditorColumns(availableWidth: 599), 1);
      expect(resolveDeckEditorColumns(availableWidth: 600), 3);
      expect(resolveDeckEditorColumns(availableWidth: 1920), 3);
    });

    test('越界值夹到 1..3，不产生负数或零栏', () {
      expect(resolveDeckEditorColumns(availableWidth: 800, override: 0), 1);
      expect(resolveDeckEditorColumns(availableWidth: 800, override: -3), 1);
      expect(resolveDeckEditorColumns(availableWidth: 800, override: 9), 3);
    });
  });
}
