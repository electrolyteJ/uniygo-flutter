// ────────────────────────────────────────────────────────────
// Free Room Sheet (环境选择 + 加入/创建 Tab)
// ────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../config/servers.dart';
import '../home_page.dart';
import '../../widgets/shared/create_room.dart';
import '../../widgets/create_room/create_room_form.dart';
import '../../widgets/create_room/env_selector.dart';
import '../../widgets/create_room/join_room_form.dart';

class FreeRoomSheet extends StatefulWidget {
  final GameServer server;
  const FreeRoomSheet({required this.server});

  @override
  State<FreeRoomSheet> createState() => _FreeRoomSheetState();
}

class _FreeRoomSheetState extends State<FreeRoomSheet> with TickerProviderStateMixin {
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
  void dispose() { _tabCtrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final canCreate = _env.canCreate;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: sheetContainer(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.server.displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(widget.server.description, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
        const SizedBox(height: 14),
        EnvSelector(value: _env, onChanged: (v) {
          _env = v;
          _initTabController();
          setState(() {});
        }),
        if (canCreate) ...[
          const SizedBox(height: 8),
          TabBar(
            controller: _tabCtrl, indicatorColor: Colors.amber,
            labelColor: Colors.white, unselectedLabelColor: Colors.blueGrey.shade400,
            tabs: const [Tab(text: '加入房间'), Tab(text: '创建房间')],
          ),
        ] else
          const SizedBox(height: 16),
        SizedBox(
          height: 444,
          child: canCreate
              ? TabBarView(
            controller: _tabCtrl,
            children: [
              JoinRoomForm(server: widget.server, env: _env),
              CreateRoomForm(server: widget.server, env: _env),
            ],
          )
              : JoinRoomForm(server: widget.server, env: _env),
        ),
      ])),
    );
  }
}