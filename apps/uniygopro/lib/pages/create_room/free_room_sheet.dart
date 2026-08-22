// ────────────────────────────────────────────────────────────
// Free Room Sheet (环境选择 + 加入/创建 Tab)
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'package:duelink/duelink.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:uniygopro/config/servers.dart';
import '../../models/mercury233_room_spec.dart';
import 'package:biz/service_singleton.dart';
import '../../widgets/create_room/room_dialog.dart';
import '../../widgets/create_room/create_room_form.dart';
import '../../widgets/create_room/env_selector.dart';
import '../../widgets/create_room/join_room_form.dart';
import 'match_store.dart';
import 'room_history_store.dart';

class FreeRoomSheet extends StatefulWidget {
  final GameServer server;
  const FreeRoomSheet({super.key, required this.server});

  @override
  State<FreeRoomSheet> createState() => _FreeRoomSheetState();
}

class _FreeRoomSheetState extends State<FreeRoomSheet>
    with TickerProviderStateMixin {
  TabController? _tabCtrl;
  DuelEnvironment _env = DuelEnvironment.koishi;

  void _initTabController() {
    _tabCtrl?.dispose();
    final length = _env.canCreate ? 2 : 1;
    _tabCtrl = TabController(length: length, vsync: this);
  }

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  /// 加入/创建成功后：写 MatchStore、关闭弹层并进入决斗房间。
  void _enterRoom({
    required String password,
    String? roomName,
    RoomOptions? roomOptions,
  }) {
    final matchStore = context.read<MatchStore>();
    if (roomOptions != null) {
      matchStore.configureCreatedRoom(
        roomOptions: roomOptions,
        roomName: roomName ?? '',
      );
    }
    matchStore.selectServer(widget.server, _env, password);

    final params = matchStore.toDuelRoomParams();
    Navigator.of(context).pop();
    if (context.mounted) context.go('/duel-room', extra: params);
    matchStore.reset();
  }

  Future<List<Mercury233BanlistOption>> _loadBanlistOptions() async {
    final tables = await ServiceSingleton.instance.dataService.getAllLfTable();
    return buildMercury233BanlistOptions(tables.values);
  }

  Widget _buildJoinForm() {
    return JoinRoomForm(
      env: _env,
      onTapFeedback: ServiceSingleton.instance.ygoSoundService.playButtonTap,
      onJoin: (password) => _enterRoom(password: password),
    );
  }

  Widget _buildCreateForm() {
    return CreateRoomForm(
      env: _env,
      historyLoader: RoomHistoryStore.load,
      onSaveRecord: RoomHistoryStore.add,
      onDeleteRecord: RoomHistoryStore.remove,
      banlistOptionsLoader: _loadBanlistOptions,
      onTapFeedback: ServiceSingleton.instance.ygoSoundService.playButtonTap,
      onEnterRoom: ({required options, required roomName, required password}) =>
          _enterRoom(
        password: password,
        roomName: roomName,
        roomOptions: options,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _env.canCreate;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: sheetContainer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final currentTab = _tabCtrl?.index ?? 0;

            // 表单主体用 Flexible 占据「头部之后的剩余高度」而非固定
            // 像素预算——头部实际高度（标题/描述/环境选择/TabBar）随时
            // 变化，硬编码扣减容易欠账导致 RenderFlex 溢出；表单内部
            // 自带 SingleChildScrollView，超出剩余空间时自行滚动。
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.server.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.server.description,
                  style: TextStyle(
                    color: Colors.blueGrey.shade400,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                EnvSelector(
                  value: _env,
                  onChanged: (v) {
                    _env = v;
                    _initTabController();
                    setState(() {});
                  },
                ),
                if (canCreate) ...[
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabCtrl,
                    indicatorColor: Colors.amber,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.blueGrey.shade400,
                    onTap: (_) {
                      ServiceSingleton.instance.ygoSoundService.playTabSwitch();
                      setState(() {});
                    },
                    tabs: const [
                      Tab(text: '加入房间'),
                      Tab(text: '创建房间'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: KeyedSubtree(
                        key: ValueKey('${_env.name}-$currentTab'),
                        child: currentTab == 0
                            ? _buildJoinForm()
                            : _buildCreateForm(),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Flexible(child: _buildJoinForm()),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
