/// 04 对战：页壳（顶部信息 + Flutter TabBar / TabBarView + 共享背景）。
///
/// 四个页签各自是独立 widget（自带状态与业务逻辑）：
/// - 匹配：[MatchTab]
/// - 好友对战：[FriendTab]
/// - 练习：[TrainTab]
/// - 自由房间：[FreeTab]
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/route.dart';
import '../ui/duel_canvas.dart';
import 'package:ygo_settings/theme/duel_controls.dart';
import 'package:ygo_settings/theme/duel_sound.dart';
import 'package:ygo_settings/theme/duel_theme.dart';
import 'free/free_tab.dart';
import 'friend/friend_tab.dart';
import 'match/match_tab.dart';
import 'models/mode_models.dart';
import 'train/train_tab.dart';

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key, this.autoStart = false});

  /// 从主页「开始匹配」进入时自动开始匹配。
  final bool autoStart;

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _labels = ['匹配', '好友对战', '练习', '自由房间'];

  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    // 恢复上次停留的页签：按 ModeSelection 里的当前模式反查。
    var initial = 0;
    final current = ModeSelection.instance.current;
    for (var t = 0; t < DuelModes.tabs.length; t++) {
      if (DuelModes.tabs[t].entries.any((e) => identical(e, current))) {
        initial = t;
        break;
      }
    }
    // 切换动画设为 0：页签是整屏舞台，滑动过渡期间两页共存会让
    // 页面用例的 find.text 命中两份，也容易闪一下另一个页签的盘。
    _tabs = TabController(
      length: _labels.length,
      vsync: this,
      initialIndex: initial,
      animationDuration: Duration.zero,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _back() {
    DuelSounds.pageTransition();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuelColors.base,
      resizeToAvoidBottomInset: false,
      // 页签只用一套机制：TabController + TabBar（底栏）+ TabBarView（内容）。
      // 不挂 Scaffold.bottomNavigationBar —— 那是第二种切换入口，而且
      // BottomNavigationBar 画不出设计稿的短下划线。
      body: DuelStage(
        backdrop: DuelBackdropKind.page,
        child: Stack(
          children: [
            Positioned.fill(
              child: TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  MatchTab(autoStart: widget.autoStart),
                  const FriendTab(),
                  const TrainTab(),
                  const FreeTab(),
                ],
              ),
            ),
            _header(),
            Positioned(left: 0, right: 0, bottom: 0, child: _bottomTabs()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Stack(
      children: [
        Positioned(
          left: 16,
          top: 6,
          child: DuelHit(
            key: const ValueKey('create-room-back'),
            onTap: _back,
            borderRadius: BorderRadius.circular(2),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Text(
                '← 返回大厅',
                style: DuelType.sans(10, color: DuelColors.textMuted),
              ),
            ),
          ),
        ),
        Positioned(
          left: 100,
          top: 6,
          child: Text('对战', style: DuelType.sans(16, height: 1.2)),
        ),
        Positioned(
          left: 100,
          top: 26,
          child: Text(
            '选择模式后开始匹配',
            style: DuelType.sans(8.5, color: DuelColors.textFaint),
          ),
        ),
        Positioned(
          right: 18,
          top: 11,
          child: Text(
            '白金 III · 1,842',
            style: DuelType.latin(10, color: DuelColors.gold),
          ),
        ),
      ],
    );
  }


  /// 底部页签：Flutter TabBar（样式对齐设计稿：文字 + 短下划线）。
  Widget _bottomTabs() {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0xFF070D16),
        border: Border(top: BorderSide(color: DuelColors.divider)),
      ),
      child: TabBar(
        controller: _tabs,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: DuelColors.accent, width: 2),
          insets: EdgeInsets.symmetric(horizontal: 2),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        indicatorPadding: const EdgeInsets.only(bottom: 10),
        labelColor: DuelColors.accent,
        unselectedLabelColor: DuelColors.textMuted,
        labelStyle: DuelType.sans(12, weight: FontWeight.w500),
        unselectedLabelStyle: DuelType.sans(12),
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        tabs: [
          for (var i = 0; i < _labels.length; i++)
            Tab(
              key: ValueKey('create-room-tab-$i'),
              height: 57,
              text: _labels[i],
            ),
        ],
      ),
    );
  }
}
