import 'package:biz/duel/room/duel_room_state.dart';
import 'package:biz/service_providers.dart';
import 'package:biz/ygo_data_service.dart';
import 'package:biz/ygo_sound_service.dart';
import 'package:duel_room1/waiting/waiting_room_page.dart';
import 'package:duel_room1/waiting/widgets/overlay_panel.dart';
import 'package:duelink/duelink.dart' hide CardInfo;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_data/ygo_data.dart';

/// 空卡片服务：布局测试不会真正加载卡图。
class _FakeCardService implements ICardService {
  @override
  dynamic envType;

  @override
  Future<Uint8List> getCardImage(int code) async => Uint8List(0);

  @override
  String getCardImageUrl(int code) => '';

  @override
  Future<CardInfo?> getCard(int code) async => null;

  @override
  Future<List<CardInfo>> searchCards(String keyword) async => [];

  @override
  Future<List<CardInfo>> searchCombined({
    String? query,
    int? cardType,
    int? attribute,
    int? race,
    int maxResults = 100,
  }) async => [];
}

class _FakeDeckService extends IDeckService {
  @override
  Future<List<DeckInfo>> loadDeckList() async => [];
}

class _FakeBanlistService extends IBanlistService {
  @override
  Future<LfTable?> getLfTable(int hash) async => null;
}

YgoDataService get _fakeDataService => YgoDataService(
  cardService: _FakeCardService(),
  deckService: _FakeDeckService(),
  banlistService: _FakeBanlistService(),
);

class _FakeDuelRoomNotifier extends DuelRoomNotifier {
  _FakeDuelRoomNotifier(this._state);

  final DuelRoomState _state;

  @override
  DuelRoomState build() => _state;

  @override
  Future<void> loadDecks() async {}

  @override
  Future<({ResolvedDeck? deck, String? error})> selectDeck(String? name) async {
    return (deck: null, error: null);
  }

  @override
  Future<String?> toggleReady() async => null;

  @override
  Future<String?> confirmSiding() async => null;

  @override
  Future<LfTable?> getLfTable(int hash) async => null;
}

void main() {
  Widget buildSubject() {
    YgoSoundService.enabled = false;
    addTearDown(() => YgoSoundService.enabled = true);

    final state = DuelRoomState(
      stage: RoomInLobby(
        selfType: PlayerType.player1,
        isHost: true,
        options: const RoomOptions(),
      ),
      selfType: PlayerType.player1,
      isHost: true,
      players: const [
        PlayerInfo(name: 'Player1', pos: 0, ready: false, host: true),
      ],
      observerCount: 0,
      availableDecks: const [],
      selectedDeckName: null,
    );

    return ProviderScope(
      overrides: [
        duelRoomProvider.overrideWith(() => _FakeDuelRoomNotifier(state)),
        dataServiceProvider.overrideWith((ref) => _fakeDataService),
        ygoSoundServiceProvider.overrideWith((ref) => YgoSoundService()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SizedBox.expand(child: WaitingRoomPage())),
      ),
    );
  }

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('WaitingRoomPage 响应式弹窗几何', () {
    testWidgets('宽屏视口下弹窗宽度有上限，不无限铺开', (tester) async {
      setSize(tester, const Size(1600, 900));
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final constrainedBox = tester.widget<ConstrainedBox>(
        find
            .ancestor(
              of: find.byType(OverlayPanel),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(constrainedBox.constraints.maxWidth, 560.0);
    });

    testWidgets('窄视口下弹窗宽度不溢出屏幕', (tester) async {
      const width = 360.0;
      setSize(tester, const Size(width, 640));
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final constrainedBox = tester.widget<ConstrainedBox>(
        find
            .ancestor(
              of: find.byType(OverlayPanel),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(constrainedBox.constraints.maxWidth, width - 32);
    });

    testWidgets('极端矮视口下弹窗高度有兜底', (tester) async {
      setSize(tester, const Size(800, 240));
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final constrainedBox = tester.widget<ConstrainedBox>(
        find
            .ancestor(
              of: find.byType(OverlayPanel),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(constrainedBox.constraints.maxHeight, 240 - 32);
    });

    for (final entry in const [
      (Size(640, 360), true),
      (Size(1280, 720), false),
    ]) {
      testWidgets('${entry.$1} 控制条滚动结构符合尺寸等级', (tester) async {
        setSize(tester, entry.$1);
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final controlsScrollable = find.ancestor(
          of: find.byKey(const ValueKey('waiting-room-controls')),
          matching: find.byType(Scrollable),
        );
        final contentScrollable = find.ancestor(
          of: find.byKey(const ValueKey('waiting-room-content')),
          matching: find.byType(Scrollable),
        );
        expect(contentScrollable, findsOneWidget);
        expect(controlsScrollable, entry.$2 ? findsOneWidget : findsNothing);
      });
    }
  });
}
