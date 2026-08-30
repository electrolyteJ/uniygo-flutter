/// 确认面板队列化测试。
///
/// 背景：连续多条 MSG_CONFIRM_CARDS（连锁中多次展示卡）时，单槽位的
/// confirmPanel 会让「未确认的旧面板被最新面板直接覆盖」，且协调器在
/// 每条新消息到达时取消旧计时器，尚未弹出的面板甚至会整段丢失。
/// 现改为队列：新面板排队，关闭当前面板后按序接续。
library;

import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  CardConfirmNotifier notifier() =>
      container.read(cardConfirmProvider.notifier);
  CardConfirmState read() => container.read(cardConfirmProvider);

  group('确认面板队列', () {
    test('连续两条确认：旧面板不被覆盖，关闭后接续展示', () {
      notifier().showConfirmPanel(title: 'A', codes: const [1]);
      notifier().showConfirmPanel(title: 'B', codes: const [2]);

      // 只展示第一个，第二个排队。
      expect(read().confirmPanel?.title, 'A');

      notifier().dismissConfirmPanel();
      expect(read().confirmPanel?.title, 'B');
      expect(read().confirmPanel?.codes, [2]);

      notifier().dismissConfirmPanel();
      expect(read().confirmPanel, isNull);
    });

    test('揭示（高亮→面板）期间面板已打开：揭示完成后面板排队不覆盖', () {
      fakeAsync((async) {
        notifier().showConfirmPanel(title: '已打开', codes: const [9]);
        notifier().scheduleConfirmedReveal(
          fieldSlotKeys: const {'0_4_0'},
          handSequences: const {},
          handOwner: 0,
          panelCodes: const {100, 101},
          title: '对方 展示的卡片',
        );
        // 高亮中，面板未被顶掉。
        expect(read().confirmedFieldSlotKeys, {'0_4_0'});
        expect(read().confirmPanel?.title, '已打开');

        async.elapse(const Duration(milliseconds: 1600));
        // 揭示完成：高亮消退，新面板排队而非覆盖。
        expect(read().confirmedFieldSlotKeys, isEmpty);
        expect(read().confirmPanel?.title, '已打开');

        notifier().dismissConfirmPanel();
        expect(read().confirmPanel?.title, '对方 展示的卡片');
      });
    });

    test('新确认消息 flush 未决揭示：其面板入队不丢失', () {
      fakeAsync((async) {
        notifier().scheduleConfirmedReveal(
          fieldSlotKeys: const {},
          handSequences: const {1, 2},
          handOwner: 1,
          panelCodes: const {42},
          title: 'A',
        );
        // 300ms 后下一条确认消息到达：flush 立即结算上一条。
        async.elapse(const Duration(milliseconds: 300));
        notifier().flushPending();
        expect(read().confirmedHandSequences, isEmpty);
        expect(read().confirmPanel?.title, 'A');

        notifier().showConfirmPanel(title: 'B', codes: const [7]);
        expect(read().confirmPanel?.title, 'A');
        notifier().dismissConfirmPanel();
        expect(read().confirmPanel?.title, 'B');
      });
    });

    test('新对局 reset：队列与未决呈现全部清空', () {
      fakeAsync((async) {
        notifier().showConfirmPanel(title: 'A', codes: const [1]);
        notifier().showConfirmPanel(title: 'B', codes: const [2]);
        notifier().scheduleConfirmedReveal(
          fieldSlotKeys: const {'1_8_2'},
          handSequences: const {},
          handOwner: 0,
          panelCodes: const {5},
          title: 'C',
        );
        notifier().resetForNewDuel();
        expect(read().confirmPanel, isNull);
        expect(read().confirmedFieldSlotKeys, isEmpty);

        // 计时器已取消：elapse 后不会有队列面板复活。
        async.elapse(const Duration(seconds: 3));
        expect(read().confirmPanel, isNull);
      });
    });
  });
}
