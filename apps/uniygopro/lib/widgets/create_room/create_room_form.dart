// ── 创建房间 ──

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:uniygopro/widgets/create_room/password_field.dart';
import 'package:uniygopro/widgets/create_room/mercury233_room_form_section.dart';
import 'package:uniygopro/widgets/create_room/mercury233_room_spec.dart';
import 'package:uniygopro/widgets/create_room/mercury233_room_string_codec.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/servers.dart';
import '../../pages/create_room/match_store.dart';
import '../shared/create_room.dart';

class CreateRoomForm extends StatefulWidget {
  final GameServer server;
  final DuelEnvironment env;
  const CreateRoomForm({super.key, required this.server, required this.env});

  @override
  State<CreateRoomForm> createState() => _CreateRoomFormState();
}

class _CreateRoomFormState extends State<CreateRoomForm> {
  final _nameCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _connecting = false;
  String? _error;

  int _startLp = 8000;
  int _startHand = 5;
  int _drawCount = 1;
  int _rule = 0;
  DuelRule _duelRule = DuelRule.mr2020;
  RoomMode _mode = RoomMode.match;
  bool _noCheckDeck = false;
  bool _noShuffleDeck = false;
  int _timeLimit = 180;
  Mercury233RoomSpec _mercury233Spec = const Mercury233RoomSpec();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CreateRoomForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.env.usesRoomStringDsl != widget.env.usesRoomStringDsl) {
      _error = null;
    }
  }

  Future<void> _create(BuildContext context) async {
    if (widget.env.usesRoomStringDsl) {
      final result = Mercury233RoomStringCodec.build(_mercury233Spec);
      if (result.error != null) {
        setState(() => _error = result.error);
        return;
      }

      setState(() {
        _connecting = true;
        _error = null;
      });
      final matchStore = context.read<MatchStore>();
      matchStore.configureCreatedRoom(
        roomOptions: _mercury233Spec.toRoomOptions(),
        roomName: _mercury233Spec.roomName.trim(),
      );
      matchStore.selectServer(widget.server, widget.env, result.value);

      Navigator.of(context).pop();
      if (context.mounted) context.go('/duel-room');
      return;
    }

    final pw = _pwCtrl.text.trim();
    if (pw.isEmpty) {
      setState(() => _error = '请设置房间密码');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });

    final options = RoomOptions(
      rule: _rule,
      startLp: _startLp,
      startHand: _startHand,
      drawCount: _drawCount,
      duelRule: _duelRule,
      mode: _mode,
      noCheckDeck: _noCheckDeck,
      noShuffleDeck: _noShuffleDeck,
      timeLimit: _timeLimit,
    );

    final matchStore = context.read<MatchStore>();
    matchStore.configureCreatedRoom(
      roomOptions: options,
      roomName: _nameCtrl.text.trim(),
    );

    final env = widget.env;
    String password;
    if (env.useEncodedPassword) {
      // 每次操作前都要重新获取 u16Secret
      // const u16Secret = await getUserU16Secret(user.token);
      const u16Secret = 0;
      //todo: 这里的 u16Secret 需要从服务器获取，暂时使用 0 作为占位符
      password = RoomPassword.encodeCreate(
        options: options,
        roomId: pw,
        secret: u16Secret,
      );
    } else {
      password = pw;
    }
    matchStore.selectServer(widget.server, env, password);

    Navigator.of(context).pop();
    if (context.mounted) context.go('/duel-room');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          if (widget.env.usesRoomStringDsl)
            Mercury233RoomFormSection(
              spec: _mercury233Spec,
              errorText: _error,
              onSpecChanged: (next) => setState(() {
                _mercury233Spec = next;
                _error = null;
              }),
            )
          else ...[
            darkTextField(
              controller: _nameCtrl,
              label: '房间名称',
              icon: Icons.edit,
            ),
            const SizedBox(height: 10),
            PasswordField(controller: _pwCtrl, label: '房间密码', icon: Icons.lock),
            const SizedBox(height: 14),
            numberRow('初始 LP', _startLp, (v) => setState(() => _startLp = v)),
            numberRow(
              '初始手牌',
              _startHand,
              (v) => setState(() => _startHand = v),
            ),
            numberRow(
              '每回合抽卡',
              _drawCount,
              (v) => setState(() => _drawCount = v),
            ),
            const SizedBox(height: 6),
            dropdownRow<int>(
              label: '卡片允许',
              value: _rule,
              items: const [
                DropdownMenuItem(value: 0, child: Text('OCG')),
                DropdownMenuItem(value: 1, child: Text('TCG')),
                DropdownMenuItem(value: 2, child: Text('OT 混')),
                DropdownMenuItem(value: 3, child: Text('自制卡')),
                DropdownMenuItem(value: 4, child: Text('专有卡禁止')),
                DropdownMenuItem(value: 5, child: Text('所有卡片')),
              ],
              onChanged: (v) => setState(() => _rule = v!),
            ),
            dropdownRow<DuelRule>(
              label: '决斗规则',
              value: _duelRule,
              items: const [
                DropdownMenuItem(
                  value: DuelRule.mr3,
                  child: Text('大师规则 3 (2014)'),
                ),
                DropdownMenuItem(
                  value: DuelRule.mr4,
                  child: Text('新大师规则 (2017)'),
                ),
                DropdownMenuItem(
                  value: DuelRule.mr2020,
                  child: Text('大师规则 2020'),
                ),
              ],
              onChanged: (v) => setState(() => _duelRule = v!),
            ),
            dropdownRow<RoomMode>(
              label: '对战模式',
              value: _mode,
              items: const [
                DropdownMenuItem(value: RoomMode.single, child: Text('单局')),
                DropdownMenuItem(
                  value: RoomMode.match,
                  child: Text('三局两胜 (Match)'),
                ),
                DropdownMenuItem(value: RoomMode.tag, child: Text('双打 (Tag)')),
              ],
              onChanged: (v) => setState(() => _mode = v!),
            ),
            dropdownRow<int>(
              label: '时间限制',
              value: _timeLimit,
              items: const [
                DropdownMenuItem(value: 0, child: Text('无限制')),
                DropdownMenuItem(value: 180, child: Text('3 分钟')),
                DropdownMenuItem(value: 240, child: Text('4 分钟')),
                DropdownMenuItem(value: 300, child: Text('5 分钟')),
                DropdownMenuItem(value: 600, child: Text('10 分钟')),
              ],
              onChanged: (v) => setState(() => _timeLimit = v!),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                checkRow(
                  '不检查卡组',
                  _noCheckDeck,
                  (v) => setState(() => _noCheckDeck = v ?? false),
                ),
                const SizedBox(width: 16),
                checkRow(
                  '不切洗卡组',
                  _noShuffleDeck,
                  (v) => setState(() => _noShuffleDeck = v ?? false),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
          ],
          const SizedBox(height: 10),
          connectButton(
            label: '创建房间',
            connecting: _connecting,
            onPressed: () => _create(context),
          ),
        ],
      ),
    );
  }
}
