/// 对方里侧卡在场面状态中的存续测试（攻击里侧怪兽场景回归）。
///
/// 背景：ygopro 服务端把对方里侧卡的 UPDATE_DATA 记录 payload 置零，
/// 解析层（duelink）曾丢弃该记录，导致 biz 整区重建时里侧卡被抹掉；
/// 攻击宣言后的目标选择窗口因场上找不到卡而退化为模态弹窗
/// （只见「对方怪兽区」占位，无法确认）。
///
/// 修复后链路：解析层生成占位 action → applyUpdateData 重建出
/// code=0 的卡背占位 → 攻击目标选择走场上内联点击。
library;

import 'dart:typed_data';

import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/field_zone_key.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/ygo_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubCardService extends ICardService {
  @override
  dynamic envType;
  @override
  Future<CardInfo?> getCard(int code) async => null;
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
  void submitDeck(Uint8List mainDeck, Uint8List extraDeck,
      [Uint8List? sideDeck]) {}
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

/// 组一条对方怪兽区快照：7 槽，[hiddenSlots] 为里侧隐藏卡（len=16 全零），
/// 其余空槽。与 ygopro RefreshMzone  memset 后的线格式一致。
Uint8List _oppMzoneWithHidden(List<int> hiddenSlots) {
  final w = BytesBuilder();
  w.add([1, CARD_ZONE_MZONE]); // player=1（对方）, zone=MZONE
  for (var s = 0; s < 7; s++) {
    if (hiddenSlots.contains(s)) {
      final len = Uint8List(4)
        ..buffer.asByteData().setInt32(0, 16, Endian.little);
      w.add(len);
      w.add(Uint8List(12)); // 全零 payload
    } else {
      final len = Uint8List(4)
        ..buffer.asByteData().setInt32(0, 4, Endian.little);
      w.add(len); // 空槽
    }
  }
  return w.toBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: [
      duelServiceProvider.overrideWithValue(_FakeDuelService()),
      dataServiceProvider.overrideWithValue(
        YgoDataService(
          cardService: _StubCardService(),
          deckService: _StubDeckService(),
          banlistService: _StubBanlistService(),
        ),
      ),
      ygoSoundServiceProvider.overrideWithValue(YgoSoundService()),
    ]);
  });
  tearDown(() => container.dispose());

  DuelFieldState read() => container.read(duelFieldProvider);
  DuelFieldNotifier notifier() => container.read(duelFieldProvider.notifier);

  test('里侧怪兽在整区重建后存续：占位卡背，位置里侧守备', () {
    final msg = MsgUpdateData.decode(_oppMzoneWithHidden([2]));
    expect(msg.actions, hasLength(1)); // 解析层占位

    notifier().applyUpdateData(msg);
    final key = zoneKeyOf(1, CARD_ZONE_MZONE, 2);
    final card = read().fieldCards[key];
    expect(card, isNotNull, reason: '里侧卡必须在场上占槽');
    expect(card!.code, 0, reason: '里侧卡码不可见，0 渲染卡背');
    expect(card.position, POS_FACEDOWN_DEFENSE);

    // 日志里的真实场景：同样的快照反复推送，里侧卡不得消失。
    notifier().applyUpdateData(MsgUpdateData.decode(_oppMzoneWithHidden([2])));
    expect(read().fieldCards[key], isNotNull);
  });

  test('攻击里侧怪兽：目标选择走内联（不回退模态弹窗）', () {
    notifier().applyUpdateData(
      MsgUpdateData.decode(_oppMzoneWithHidden([2])),
    );
    // 攻击目标选择窗口：唯一选项为对方里侧怪兽（code=0，与线协议一致）。
    const select = SelectState(
      type: SelectType.card,
      player: 0,
      min: 1,
      max: 1,
      cancelable: true,
      options: [
        SelectOption(
          code: 0,
          controller: 1,
          zone: CARD_ZONE_MZONE,
          sequence: 2,
        ),
      ],
    );
    expect(
      resolveInlineSelectActive(select, read()),
      isTrue,
      reason: '里侧卡在场上存在时应走内联点选，而不是模态弹窗',
    );
    // resolveSelectPromptMode 是 resolveInlineSelectActive 的薄封装
    // （inline 条件不满足才回退 modal），此处不再重复构造 SelectWindowState。
  });
}
