// ── 创建房间 ──

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:uniygopro/widgets/create_room/password_field.dart';
import 'package:uniygopro/widgets/create_room/mercury233_room_form_section.dart';
import 'package:uniygopro/widgets/create_room/mercury233_room_spec.dart';
import 'package:uniygopro/widgets/create_room/mercury233_room_string_codec.dart';
import 'package:uniygopro/widgets/create_room/room_history_list.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/servers.dart';
import '../../pages/create_room/match_store.dart';
import '../../pages/create_room/room_history.dart';
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

  /// 全部创建记录（展示时按当前环境过滤）。
  List<CreatedRoomRecord> _history = [];

  List<CreatedRoomRecord> get _envHistory =>
      _history.where((r) => r.env == widget.env).toList();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final records = await RoomHistoryStore.load();
    if (mounted) setState(() => _history = records);
  }

  Future<void> _saveRecord(CreatedRoomRecord record) async {
    await RoomHistoryStore.add(record);
    await _loadHistory();
  }

  /// 点击历史卡片：把记录回填到表单。
  void _fillFromHistory(CreatedRoomRecord record) {
    setState(() {
      final spec = record.mercurySpec;
      final options = record.options;
      if (spec != null) {
        _mercury233Spec = spec;
      } else if (options != null) {
        _nameCtrl.text = record.roomName;
        _pwCtrl.text = record.password;
        _startLp = options.startLp;
        _startHand = options.startHand;
        _drawCount = options.drawCount;
        _rule = options.rule;
        _duelRule = options.duelRule;
        _mode = options.mode;
        _noCheckDeck = options.noCheckDeck;
        _noShuffleDeck = options.noShuffleDeck;
        _timeLimit = options.timeLimit;
      }
      _error = null;
    });
  }

  /// 点击历史卡片的播放按钮：跳过表单直接创建并进入房间。
  Future<void> _enterFromHistory(CreatedRoomRecord record) async {
    final spec = record.mercurySpec;
    if (spec != null) {
      final result = Mercury233RoomStringCodec.build(spec);
      if (result.error != null) {
        setState(() => _error = result.error);
        return;
      }
      await _saveRecord(record.touch());
      if (!mounted) return;
      _enterRoom(
        options: spec.toRoomOptions(),
        roomName: spec.roomName.trim(),
        password: result.value,
      );
      return;
    }
    final options = record.options;
    if (options == null) return;
    final password = _encodePassword(options, record.password);
    await _saveRecord(record.touch());
    if (!mounted) return;
    _enterRoom(options: options, roomName: record.roomName, password: password);
  }

  Future<void> _deleteFromHistory(CreatedRoomRecord record) async {
    await RoomHistoryStore.remove(record);
    await _loadHistory();
  }

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
      final spec = _mercury233Spec;
      await _saveRecord(
        CreatedRoomRecord(
          env: widget.env,
          roomName: spec.roomName.trim(),
          mercurySpec: spec,
        ),
      );
      if (!context.mounted) return;
      _enterRoom(
        options: spec.toRoomOptions(),
        roomName: spec.roomName.trim(),
        password: result.value,
      );
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

    final roomName = _nameCtrl.text.trim();
    final password = _encodePassword(options, pw);
    await _saveRecord(
      CreatedRoomRecord(
        env: widget.env,
        roomName: roomName,
        password: pw,
        options: options,
      ),
    );
    if (!context.mounted) return;
    _enterRoom(options: options, roomName: roomName, password: password);
  }

  /// 按环境编码创建房间密码（mycard 需要 RoomPassword 编码）。
  String _encodePassword(RoomOptions options, String pw) {
    if (widget.env.useEncodedPassword) {
      // 每次操作前都要重新获取 u16Secret
      // const u16Secret = await getUserU16Secret(user.token);
      //todo: 这里的 u16Secret 需要从服务器获取，暂时使用 0 作为占位符
      return RoomPassword.encodeCreate(options: options, roomId: pw, secret: 0);
    }
    return pw;
  }

  /// 写入 MatchStore 并跳转到决斗房间页。
  void _enterRoom({
    required RoomOptions options,
    required String roomName,
    required String password,
  }) {
    final matchStore = context.read<MatchStore>();
    matchStore.configureCreatedRoom(roomOptions: options, roomName: roomName);
    matchStore.selectServer(widget.server, widget.env, password);

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
          if (_envHistory.isNotEmpty)
            RoomHistoryList(
              records: _envHistory,
              onFill: _fillFromHistory,
              onEnter: (r) => _enterFromHistory(r),
              onDelete: (r) => _deleteFromHistory(r),
            ),
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
            numberRow(
              '初始 LP',
              _startLp,
              (v) => setState(() => _startLp = v),
              max: 65535,
            ),
            numberRow(
              '初始手牌',
              _startHand,
              (v) => setState(() => _startHand = v),
              max: 15,
            ),
            numberRow(
              '每回合抽卡',
              _drawCount,
              (v) => setState(() => _drawCount = v),
              max: 15,
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
