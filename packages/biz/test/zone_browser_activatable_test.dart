/// 区域浏览器「可发动」标记的派生 provider 测试。
///
/// zoneBrowserActivatableSequencesProvider 的口径与
/// zoneBrowserEntriesProvider 的可发动卡合并、zoneBrowserActionsProvider
/// 的动作匹配一致：idle 指令窗口 + 己方窗口时，按 controller+location
/// 收集 selectedIdleActions 的 locationSequence。
library;

import 'dart:typed_data';

import 'package:biz/duel/field/duel_field_derived.dart';
import 'package:biz/duel/field/duel_field_state.dart';
import 'package:biz/duel/field/select_window_state.dart';
import 'package:biz/duel/models/idle_action.dart';
import 'package:biz/duel/models/select_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/ygo_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── 服务桩（与 attack_event_test 同一套：provider 链会触达数据服务）──

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: [
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

  void setSelect(SelectWindowState s) =>
      container.read(selectWindowProvider.notifier).state = s;

  Set<int> read(String zoneKey) =>
      container.read(zoneBrowserActivatableSequencesProvider(zoneKey));

  const idleWindow = SelectState(type: SelectType.idleCmd, player: 0);

  test('idle 窗口下按区域收集可发动卡位 sequence', () {
    setSelect(
      const SelectWindowState(
        currentSelect: idleWindow,
        selectedIdleActions: [
          // 己方墓地两张可发动。
          IdleAction(
            type: 5,
            sequence: 5,
            code: 70095155,
            controller: 0,
            location: CARD_ZONE_GRAVE,
            locationSequence: 2,
            position: 0,
          ),
          IdleAction(
            type: 5,
            sequence: 6,
            code: 70095156,
            controller: 0,
            location: CARD_ZONE_GRAVE,
            locationSequence: 4,
            position: 0,
          ),
          // 己方额外一张可特殊召唤。
          IdleAction(
            type: 1,
            sequence: 9,
            code: 84815190,
            controller: 0,
            location: CARD_ZONE_EXTRA,
            locationSequence: 0,
            position: 0,
          ),
          // 己方除外一张可发动（除外的卡也纳入标记）。
          IdleAction(
            type: 5,
            sequence: 11,
            code: 222,
            controller: 0,
            location: CARD_ZONE_REMOVED,
            locationSequence: 1,
            position: 0,
          ),
          // 对方墓地一张可发动（我的效果可以动对方的卡时，
          // 浏览对方墓地同样要标记——与动作匹配口径一致）。
          IdleAction(
            type: 5,
            sequence: 10,
            code: 111,
            controller: 1,
            location: CARD_ZONE_GRAVE,
            locationSequence: 7,
            position: 0,
          ),
        ],
      ),
    );

    expect(read('self_grave'), {2, 4});
    expect(read('self_extra'), {0});
    expect(read('self_removed'), {1});
    expect(read('opp_grave'), {7});
  });

  test('无 idle 窗口时为空（残留动作不标记）', () {
    setSelect(
      const SelectWindowState(
        currentSelect: SelectState(type: SelectType.card, player: 0),
        selectedIdleActions: [
          IdleAction(
            type: 5,
            sequence: 5,
            code: 70095155,
            controller: 0,
            location: CARD_ZONE_GRAVE,
            locationSequence: 2,
            position: 0,
          ),
        ],
      ),
    );
    expect(read('self_grave'), isEmpty);
  });

  test('窗口不属于己方时不标记', () {
    // myController 默认 0；窗口属于对方（player=1）。
    setSelect(
      const SelectWindowState(
        currentSelect: SelectState(type: SelectType.idleCmd, player: 1),
        selectedIdleActions: [
          IdleAction(
            type: 5,
            sequence: 5,
            code: 70095155,
            controller: 0,
            location: CARD_ZONE_GRAVE,
            locationSequence: 2,
            position: 0,
          ),
        ],
      ),
    );
    expect(read('self_grave'), isEmpty);
  });
}
