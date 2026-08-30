/// MSG_SELECT_OPTION 选项文案解析测试。
///
/// 协议：选项 desc 值按 ocgcore GetDesc 语义编码——
/// desc < 10000 为 strings.conf !system 系统文案；否则 desc>>4 为卡码、
/// desc&0xf 为该卡 texts.str1~16 的下标（脚本 aux.Stringid 的效果选项文本）。
/// 解析不到时兜底「选项 N」；卡信息未缓存时先兜底、异步拉取后刷新。
library;

import 'dart:typed_data';

import 'package:biz/duel/field/card_confirm_state.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/field_overlay_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/ygo_data.dart';
import 'package:resource_strings_mycard/ygo_strings_mycard.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 可按需返回带 strings 卡信息的桩卡服务。
class _StubCardService extends ICardService {
  _StubCardService(this._cards);

  final Map<int, CardInfo> _cards;

  @override
  dynamic envType;

  @override
  Future<CardInfo?> getCard(int code) async => _cards[code];

  @override
  Future<Uint8List> getCardImage(int code) => throw UnimplementedError();

  @override
  String getCardImageUrl(int code) => '';

  @override
  Future<List<CardInfo>> searchCards(String keyword) async => const [];

  @override
  Future<List<CardInfo>> searchCombined({
    String? query,
    int? cardType,
    int? attribute,
    int? race,
    int maxResults = 100,
  }) async => const [];
}

class _StubDeckService extends IDeckService {
  @override
  Future<List<DeckInfo>> loadDeckList() async => const [];

  @override
  Future<DeckInfo?> loadDeck(String deckKey) async => null;
}

class _StubBanlistService extends IBanlistService {
  @override
  Future<LfTable?> getLfTable(int hash) async => null;
}

class _FakeDuelService implements IDuelService {
  @override
  Stream<RoomStage> get onRoomStageChange => const Stream.empty();
  @override
  Stream<YgoStocMsg> get onServerMessage => const Stream.empty();
  @override
  Stream<YgoStocMsg> get onChatServerMessage => const Stream.empty();
  @override
  Stream<DuelPhase> get onDuelPhaseMessage => const Stream.empty();
  @override
  ConnectionState get connectionState => ConnectionConnected();
  @override
  Future<void> connect(Uri address) async {}
  @override
  Future<void> disconnect() async {}
  @override
  void setPlayerName(String name) {}
  @override
  void enterRoom(String password) {}
  @override
  void submitDeck(
    Uint8List mainDeck,
    Uint8List extraDeck, [
    Uint8List? sideDeck,
  ]) {}
  @override
  void ready() {}
  @override
  void unready() {}
  @override
  void startDuel() {}
  @override
  void kickPlayer(int pos) {}
  @override
  void becomeObserver() {}
  @override
  void becomeDuelist() {}
  @override
  void chooseHand(HandType hand) {}
  @override
  void chooseTurnOrder(bool goFirst) {}
  @override
  void playGameResponse(CtosGameMsgResponse response) {}
  @override
  void surrender() {}
  @override
  void confirmTime() {}
  @override
  void sendChat(String message) {}
}

/// aux.Stringid(code, i) 编码：desc = code*16 + i。
int stringId(int code, int i) => code * 16 + i;

const _code = 12345678;

({ProviderContainer room, YgoDataService data}) _harness() {
  SharedPreferences.setMockInitialValues({});
  final data = YgoDataService(
    cardService: _StubCardService({
      _code: CardInfo(
        code: _code,
        type: 0x11,
        name: '测试怪兽',
        strings: const ['选卡破坏', '选卡送回卡组', '选卡除外'],
      ),
    }),
    deckService: _StubDeckService(),
    banlistService: _StubBanlistService(),
  );
  final appContainer = ProviderContainer(
    overrides: [
      duelServiceProvider.overrideWithValue(_FakeDuelService()),
      dataServiceProvider.overrideWithValue(data),
      ygoSoundServiceProvider.overrideWithValue(YgoSoundService()),
      stringsServiceProvider.overrideWithValue(
        StringsService.seeded(system: const {60: '正面', 61: '反面'}),
      ),
    ],
  );
  final room = ProviderContainer(
    parent: appContainer,
    overrides: [
      duelRoomProvider.overrideWith(DuelRoomNotifier.new),
      duelFieldProvider.overrideWith(DuelFieldNotifier.new),
      selectWindowProvider.overrideWith(SelectWindowNotifier.new),
      cardConfirmProvider.overrideWith(CardConfirmNotifier.new),
      fieldOverlayProvider.overrideWith(FieldOverlayNotifier.new),
    ],
  );
  addTearDown(() {
    room.dispose();
    appContainer.dispose();
  });
  return (room: room, data: data);
}

SelectState _open(ProviderContainer room, List<int> descs) {
  room
      .read(selectWindowProvider.notifier)
      .applySelectOption(
        MsgSelectOption(player: 0, count: descs.length, codes: descs),
      );
  final select = room.read(selectWindowProvider).currentSelect;
  expect(select, isNotNull, reason: '选项窗口应已打开');
  return select!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Stringid desc：卡字符串缓存命中时直接显示效果文本', () async {
    final h = _harness();
    await h.data.getCard(_code); // 预热缓存

    final select = _open(h.room, [
      stringId(_code, 0),
      stringId(_code, 1),
      stringId(_code, 2),
    ]);

    expect(select.options[0].label, '选卡破坏');
    expect(select.options[1].label, '选卡送回卡组');
    expect(select.options[2].label, '选卡除外');
  });

  test('系统 desc（<10000）：显示 strings.conf !system 文案', () {
    final h = _harness();

    final select = _open(h.room, [60, 61]);

    expect(select.options[0].label, '正面');
    expect(select.options[1].label, '反面');
  });

  test('解析不到（未知卡/未知系统串）→ 兜底「选项 N」', () {
    final h = _harness();

    final select = _open(h.room, [stringId(99999999, 0), 9999]);

    expect(select.options[0].label, '选项 1');
    expect(select.options[1].label, '选项 2');
  });

  test('卡信息未缓存：先兜底「选项 N」，异步拉取后刷新为效果文本', () async {
    final h = _harness();
    // 不预热：开窗时缓存未命中
    final select = _open(h.room, [stringId(_code, 0), stringId(_code, 1)]);
    expect(select.options[0].label, '选项 1');
    expect(select.options[1].label, '选项 2');

    // 等异步补齐（getCard 为立即完成的 Future）
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
      final cur = h.room.read(selectWindowProvider).currentSelect;
      if (cur != null && cur.options[0].label == '选卡破坏') break;
    }
    final refreshed = h.room.read(selectWindowProvider).currentSelect;
    expect(refreshed, isNotNull);
    expect(refreshed!.options[0].label, '选卡破坏', reason: '卡信息到达后应刷新文案');
    expect(refreshed.options[1].label, '选卡送回卡组');
  });

  test('异步补齐期间窗口已关闭：迟到结果不写 state', () async {
    final h = _harness();
    final select = _open(h.room, [stringId(_code, 0)]);
    expect(select.options[0].label, '选项 1');
    h.room.read(selectWindowProvider.notifier).clearSelect();

    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      h.room.read(selectWindowProvider).currentSelect,
      isNull,
      reason: '窗口已关闭，迟到的文案刷新不得复活窗口',
    );
  });
}
