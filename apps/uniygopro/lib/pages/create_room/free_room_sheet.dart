// ────────────────────────────────────────────────────────────
// Free Room Sheet (环境选择 + 加入/创建 Tab)
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../config/servers.dart';
import '../../widgets/shared/create_room.dart';
import '../../widgets/create_room/create_room_form.dart';
import '../../widgets/create_room/env_selector.dart';
import '../../widgets/create_room/join_room_form.dart';

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
            final hasBoundedHeight = constraints.maxHeight.isFinite;
            final availableBodyHeight = hasBoundedHeight
                ? math.max(
                    220.0,
                    constraints.maxHeight - (canCreate ? 126.0 : 96.0),
                  )
                : 520.0;
            final currentTab = _tabCtrl?.index ?? 0;

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
                    onTap: (_) => setState(() {}),
                    tabs: const [
                      Tab(text: '加入房间'),
                      Tab(text: '创建房间'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: availableBodyHeight),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: KeyedSubtree(
                        key: ValueKey('${_env.name}-$currentTab'),
                        child: currentTab == 0
                            ? JoinRoomForm(server: widget.server, env: _env)
                            : CreateRoomForm(server: widget.server, env: _env),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  JoinRoomForm(server: widget.server, env: _env),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
