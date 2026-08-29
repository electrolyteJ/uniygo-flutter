/// 卡组编辑器：store 纯逻辑 + 纯 UI 组件的集成测试。
///
/// UI 组件均为「数据 + 回调注入」，不依赖网络/ServiceSingleton；
/// store 需要 registerAllServices() 初始化服务注册表（构造时惰性读取
/// dataService，但本文件只测不触网的方法）。
library;

import 'package:deck_editor1/deck_editor1.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:biz/service_loader.registrations.g.dart';
import 'package:resource_data/card_info.dart' as pkg;
import 'package:resource_data/deck_info.dart';

pkg.CardInfo _card(
  int code, {
  String name = '',
  int type = 0x1, // 通常怪兽
}) =>
    pkg.CardInfo(code: code, type: type, name: name, attack: 1000, defense: 1000);

const _fusion = 0x1 | 0x40; // 怪兽 | 融合

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('banlist 徽标', () {
    test('状态颜色与短标签', () {
      expect(banlistStatusShortLabel('禁止'), '禁');
      expect(banlistStatusShortLabel('限制'), '限');
      expect(banlistStatusShortLabel('准限制'), '准');
      expect(banlistStatusShortLabel('无限制'), '无限制');
    });

    testWidgets('BanlistDot / BanlistCornerBadge', (tester) async {
      await tester.pumpWidget(_wrap(const BanlistDot(status: '限制')));
      expect(find.byType(Tooltip), findsOneWidget);
      await tester.pumpWidget(_wrap(const BanlistDot(status: '无限制')));
      expect(find.byType(Tooltip), findsNothing);
      await tester.pumpWidget(_wrap(const BanlistCornerBadge(status: '禁止')));
      expect(find.text('禁'), findsOneWidget);
    });
  });

  group('CardGrid / CardList', () {
    testWidgets('空态与有数据态', (tester) async {
      String? Function(pkg.CardInfo) statusOf = (_) => null;
      String urlOf(int code) => '';
      var added = <int>[];

      await tester.pumpWidget(_wrap(CardGridView(
        cards: const [],
        banlistStatusOf: statusOf,
        cardImageUrlOf: urlOf,
        onAddCard: (_) {},
      )));
      expect(find.text('无搜索结果'), findsOneWidget);

      final card = _card(1, name: '青眼白龙');
      await tester.pumpWidget(_wrap(CardGridView(
        cards: [card],
        banlistStatusOf: statusOf,
        cardImageUrlOf: urlOf,
        onAddCard: (c) => added.add(c.code),
      )));
      expect(find.text('青眼白龙'), findsOneWidget);

      await tester.pumpWidget(_wrap(CardListView(
        cards: const [],
        banlistStatusOf: statusOf,
        cardImageUrlOf: urlOf,
        onAddCard: (_) {},
      )));
      expect(find.text('无搜索结果'), findsOneWidget);

      await tester.pumpWidget(_wrap(CardListView(
        cards: [card],
        banlistStatusOf: statusOf,
        cardImageUrlOf: urlOf,
        onAddCard: (c) => added.add(c.code),
      )));
      expect(find.text('青眼白龙'), findsOneWidget);
    });
  });

  group('DeckZoneWidget', () {
    testWidgets('空态与有数据态 + 删除', (tester) async {
      var removed = <String>[];
      final card = _card(1, name: '怪兽');
      await tester.pumpWidget(_wrap(DeckZoneWidget(
        type: DeckZoneType.main,
        cards: const [],
        cardImageUrlOf: (_) => '',
        banlistStatusOf: (_) => null,
        onAcceptCard: (_, _) {},
        onRemoveCard: (_, _) {},
      )));
      expect(find.text('拖拽卡牌到此处'), findsOneWidget);

      await tester.pumpWidget(_wrap(DeckZoneWidget(
        type: DeckZoneType.main,
        cards: [card],
        cardImageUrlOf: (_) => '',
        banlistStatusOf: (_) => null,
        onAcceptCard: (_, _) {},
        onRemoveCard: (zone, _) => removed.add(zone),
      )));
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      expect(removed, ['main']);
    });
  });

  group('DeckListPanel', () {
    testWidgets('空态 / 列表 / 新建 / 删除', (tester) async {
      var created = <String>[];
      var deleted = <String>[];
      var selected = <String>[];
      final deck = DeckInfo(deckName: '卡组1', isBuiltin: true);
      await tester.pumpWidget(_wrap(DeckListPanel(
        decks: const [],
        currentDeckName: null,
        isLocked: false,
        onSelectDeck: selected.add,
        onCreateDeck: created.add,
        onDeleteDeck: deleted.add,
      )));
      expect(find.text('新建卡组'), findsOneWidget);

      await tester.pumpWidget(_wrap(DeckListPanel(
        decks: [deck],
        currentDeckName: '卡组1',
        isLocked: false,
        onSelectDeck: selected.add,
        onCreateDeck: created.add,
        onDeleteDeck: deleted.add,
      )));
      expect(find.text('卡组1'), findsOneWidget);
      await tester.tap(find.text('卡组1'));
      expect(selected, ['卡组1']);

      // 新建
      await tester.tap(find.text('新建卡组'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '新卡组');
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();
      expect(created, ['新卡组']);

      // 删除
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(deleted, ['卡组1']);
    });
  });

  group('DeckEditPanel', () {
    testWidgets('空态与有数据态 + 清空确认', (tester) async {
      var cleared = 0;
      final empty = EditingDeck(deckName: '');
      await tester.pumpWidget(_wrap(DeckEditPanel(
        deck: empty,
        onShuffle: () {},
        onSort: () {},
        onClear: () => cleared++,
        cardImageUrlOf: (_) => '',
        banlistStatusOf: (_) => null,
        onAddCard: (_, {targetZone}) {},
        onRemoveCard: (_, _) {},
      )));
      expect(find.text('主卡组 (0)'), findsOneWidget);

      final deck = EditingDeck(deckName: 'D', main: [_card(1, name: '怪兽')]);
      await tester.pumpWidget(_wrap(DeckEditPanel(
        deck: deck,
        onShuffle: () {},
        onSort: () {},
        onClear: () => cleared++,
        cardImageUrlOf: (_) => '',
        banlistStatusOf: (_) => null,
        onAddCard: (_, {targetZone}) {},
        onRemoveCard: (_, _) {},
      )));
      expect(find.text('主卡组 (1)'), findsOneWidget);
      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清空').last);
      await tester.pumpAndSettle();
      expect(cleared, 1);
    });
  });

  group('DeckEditorStore 纯逻辑', () {
    setUpAll(registerAllServices);

    test('addCard 自动分区与上限校验', () async {
      final store = DeckEditorStore();
      final monster = _card(1, name: '通常怪兽');
      final fusion = _card(2, name: '融合怪兽', type: _fusion);

      expect(await store.addCard(monster), isTrue);
      expect(store.editingDeck.mainCount, 1);
      expect(await store.addCard(fusion), isTrue);
      expect(store.editingDeck.extraCount, 1);

      // 额外卡组不接受通常怪兽
      final ok = await store.addCard(monster, targetZone: 'extra');
      expect(ok, isFalse);
      expect(store.errorMessage, contains('额外卡组只能放入'));

      // 同名卡最多 3 张
      expect(await store.addCard(monster), isTrue);
      expect(await store.addCard(monster), isTrue);
      expect(await store.addCard(monster), isFalse);
      expect(store.errorMessage, contains('同名卡最多3张'));
    });

    test('主卡组 60 张上限', () async {
      final store = DeckEditorStore();
      for (var i = 0; i < 60; i++) {
        await store.addCard(_card(1000 + i));
      }
      expect(store.editingDeck.mainCount, 60);
      final ok = await store.addCard(_card(9999));
      expect(ok, isFalse);
      expect(store.errorMessage, contains('主卡组已满'));
    });

    test('remove / clear / shuffle / sort / rename / view / zone', () async {
      final store = DeckEditorStore();
      final a = _card(1, name: 'A');
      final b = _card(2, name: 'B');
      await store.addCard(a);
      await store.addCard(b);
      expect(store.editingDeck.mainCount, 2);

      store.removeCard('main', a);
      expect(store.editingDeck.mainCount, 1);

      store.shuffleDeck();
      store.sortDeck();
      expect(store.editingDeck.isDirty, isTrue);

      store.renameEditingDeck('新名字');
      expect(store.editingDeck.deckName, '新名字');

      expect(store.isGridView, isTrue);
      store.toggleViewMode();
      expect(store.isGridView, isFalse);

      store.setAddTargetZone('side');
      expect(store.addTargetZone, 'side');

      store.clearDeck();
      expect(store.editingDeck.totalCount, 0);
    });

    test('filter / banlist / markDirty / toDeckInfo / lastSaveResultForRoute',
        () async {
      final store = DeckEditorStore();
      expect(store.filter.isDefault, isFalse); // 默认带 env:0
      store.updateFilter(const CardFilter(cardType: 0x1));
      expect(store.filter.cardType, 0x1);
      store.resetSearchFilters();
      expect(store.filter.cardType, isNull);

      store.selectBanlist(123);
      expect(store.selectedBanlistHash, 123);
      expect(store.getBanlistStatus(_card(1)), isNull); // 无表 → null

      await store.addCard(_card(7, name: '七'));
      final info = store.toDeckInfo();
      expect(info.mainCount, 1);

      store.markDirty();
      expect(store.editingDeck.isDirty, isTrue);
      expect(store.lastSaveResultForRoute, isNull); // 尚未保存

      store.clearError();
      expect(store.errorMessage, isNull);
    });

    test('configureSession 解析等待室参数', () async {
      final store = DeckEditorStore();
      await store.configureSession({
        'noCheckDeck': true,
        'lfTableHash': 42,
        'lockDeckSelection': true,
        'lockDeckName': true,
      });
      expect(store.isWaitingRoomSession, isTrue);
      expect(store.lockDeckSelection, isTrue);
      expect(store.lockDeckName, isTrue);
      // preferredHash=42 不在真实禁限表里时，会回退到可用的第一张表；
      // 这里只断言最终确实解析出一张表（configureSession 会真实拉取禁限表）。
      expect(store.selectedBanlistHash, isNotNull);
    });
  });
}
