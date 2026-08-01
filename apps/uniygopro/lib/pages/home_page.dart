import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:duelink/duelink.dart';
import '../config/servers.dart';
import '../services/match_service.dart';
import '../stores/match_store.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final matchStore = context.watch<MatchStore>();

    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.casino, color: Colors.amber),
            SizedBox(width: 8),
            Text('uniygopro'),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.card_membership),
            tooltip: '卡组',
            onPressed: () => context.go('/deck-editor'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: gameServers.length,
                itemBuilder: (context, index) {
                  return _ServerCard(
                    server: gameServers[index],
                    onTap: () => _onServerTap(context, gameServers[index]),
                  );
                },
              ),
            ),
            if (matchStore.isSearching) _buildSearchingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 16),
            Text('正在搜索对手...', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _onServerTap(BuildContext context, GameServer server) {
    if (server.requiresMatchApi) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _MatchJoinSheet(server: server),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _FreeRoomSheet(server: server),
      );
    }
  }
}

// ────────────────────────────────────────────────────────────
// Server Card (3 items: 竞技, 娱乐, 自由)
// ────────────────────────────────────────────────────────────

class _ServerCard extends StatelessWidget {
  final GameServer server;
  final VoidCallback onTap;

  const _ServerCard({required this.server, required this.onTap});

  IconData get _icon {
    switch (server.type) {
      case ServerType.matchAthletic:
        return Icons.emoji_events;
      case ServerType.matchEntertain:
        return Icons.sports_esports;
      case ServerType.freeRoom:
        return Icons.meeting_room;
    }
  }

  Color get _accentColor {
    switch (server.type) {
      case ServerType.matchAthletic:
        return Colors.amber;
      case ServerType.matchEntertain:
        return Colors.lightBlue;
      case ServerType.freeRoom:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.shade800,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: _accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(server.displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(server.description,
                        style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.blueGrey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Shared UI helpers
// ────────────────────────────────────────────────────────────

Widget _sheetContainer({required Widget child}) {
  return Container(
    decoration: const BoxDecoration(
      color: Color(0xFF1E2A38),
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.blueGrey.shade600, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

Widget _darkTextField({
  required TextEditingController controller,
  required String label,
  String? hintText,
  IconData? icon,
  TextInputType? keyboardType,
  bool obscureText = false,
  ValueChanged<String>? onSubmitted,
}) {
  return TextField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label, hintText: hintText,
      hintStyle: TextStyle(color: Colors.blueGrey.shade500),
      labelStyle: TextStyle(color: Colors.blueGrey.shade300),
      prefixIcon: icon != null ? Icon(icon, color: Colors.blueGrey.shade400) : null,
      filled: true, fillColor: Colors.blueGrey.shade800,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    ),
    onSubmitted: onSubmitted,
  );
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? icon;
  final ValueChanged<String>? onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.label,
    this.hintText,
    this.icon,
    this.onSubmitted,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        hintStyle: TextStyle(color: Colors.blueGrey.shade500),
        labelStyle: TextStyle(color: Colors.blueGrey.shade300),
        prefixIcon: widget.icon != null ? Icon(widget.icon, color: Colors.blueGrey.shade400) : null,
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.blueGrey.shade400),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: Colors.blueGrey.shade800,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      onSubmitted: widget.onSubmitted,
    );
  }
}

Widget _connectButton({required String label, required bool connecting, required VoidCallback onPressed}) {
  return SizedBox(
    height: 48,
    child: FilledButton.icon(
      onPressed: connecting ? null : onPressed,
      icon: connecting
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.play_arrow),
      label: Text(connecting ? '连接中...' : label),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

Widget _numberRow(String label, int value, ValueChanged<int> onChanged) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 14))),
      IconButton(icon: Icon(Icons.remove_circle_outline, color: Colors.blueGrey.shade300, size: 22),
          onPressed: value > 0 ? () => onChanged(value - 1) : null, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32)),
      SizedBox(width: 48, child: Text('$value', textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
      IconButton(icon: Icon(Icons.add_circle_outline, color: Colors.amber, size: 22),
          onPressed: () => onChanged(value + 1), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32)),
    ]),
  );
}

Widget _dropdownRow<T>({required String label, required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 14))),
      const SizedBox(width: 12),
      Expanded(
        child: DropdownButtonFormField<T>(
          isExpanded: true,
          value: value, items: items, onChanged: onChanged,
          dropdownColor: Colors.blueGrey.shade800,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            filled: true, fillColor: Colors.blueGrey.shade800,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ),
    ]),
  );
}

Widget _checkRow(String label, bool value, ValueChanged<bool?> onChanged) {
  return Expanded(
    child: Row(children: [
      SizedBox(width: 24, height: 24, child: Checkbox(value: value, onChanged: onChanged,
          activeColor: Colors.amber, checkColor: Colors.blueGrey.shade900, side: BorderSide(color: Colors.blueGrey.shade400))),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 13)),
    ]),
  );
}

// ────────────────────────────────────────────────────────────
// Environment selector (used inside free room sheet)
// ────────────────────────────────────────────────────────────

/// Shared env selector row for both join and create forms.
class EnvSelector extends StatelessWidget {
  final DuelEnvironment value;
  final ValueChanged<DuelEnvironment> onChanged;

  const EnvSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _dropdownRow<DuelEnvironment>(
      label: '对战环境',
      value: value,
      items: DuelEnvironment.values.map((e) => DropdownMenuItem(value: e, child: Text(e.displayName))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}

// ────────────────────────────────────────────────────────────
// Match Join Sheet
// ────────────────────────────────────────────────────────────

class _MatchJoinSheet extends StatefulWidget {
  final GameServer server;
  const _MatchJoinSheet({required this.server});

  @override
  State<_MatchJoinSheet> createState() => _MatchJoinSheetState();
}

class _MatchJoinSheetState extends State<_MatchJoinSheet> {
  final _usernameCtrl = TextEditingController(text: 'Guest');
  final _passwordCtrl = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void dispose() { _usernameCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }

  Future<void> _join(BuildContext context) async {
    setState(() { _connecting = true; _error = null; });
    final matchStore = context.read<MatchStore>();
    final arena = widget.server.type == ServerType.matchAthletic ? 'athletic' : 'entertain';
    matchStore.startSearching(arena);
    Navigator.of(context).pop();

    try {
      final result = await MatchService().match(
        arena: arena, username: _usernameCtrl.text.trim(), secret: _passwordCtrl.text.trim(),
      );
      matchStore.setMatchResult(result.address, result.port, result.password);
      matchStore.username = _usernameCtrl.text.trim();
      if (context.mounted) context.go('/duel-room');
    } catch (e) {
      if (mounted) { setState(() { _connecting = false; _error = '匹配失败: $e'; }); matchStore.stopSearching(); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _sheetContainer(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.server.displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${widget.server.wsUrl}  ·  ${widget.server.description}',
            style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
        const SizedBox(height: 20),
        _darkTextField(controller: _usernameCtrl, label: '用户名', icon: Icons.person),
        const SizedBox(height: 12),
        _PasswordField(controller: _passwordCtrl, label: '密码 (选填)', hintText: '留空使用默认密码', icon: Icons.lock, onSubmitted: (_) => _join(context)),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        const SizedBox(height: 20),
        _connectButton(label: '开始匹配', connecting: _connecting, onPressed: () => _join(context)),
      ])),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Free Room Sheet (环境选择 + 加入/创建 Tab)
// ────────────────────────────────────────────────────────────

class _FreeRoomSheet extends StatefulWidget {
  final GameServer server;
  const _FreeRoomSheet({required this.server});

  @override
  State<_FreeRoomSheet> createState() => _FreeRoomSheetState();
}

class _FreeRoomSheetState extends State<_FreeRoomSheet> with TickerProviderStateMixin {
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
      child: _sheetContainer(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                    _JoinRoomForm(server: widget.server, env: _env),
                    _CreateRoomForm(server: widget.server, env: _env),
                  ],
                )
              : _JoinRoomForm(server: widget.server, env: _env),
        ),
      ])),
    );
  }
}

// ── 加入房间 ──

class _JoinRoomForm extends StatefulWidget {
  final GameServer server;
  final DuelEnvironment env;
  const _JoinRoomForm({required this.server, required this.env});

  @override
  State<_JoinRoomForm> createState() => _JoinRoomFormState();
}

class _JoinRoomFormState extends State<_JoinRoomForm> {
  final _pwCtrl = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void dispose() { _pwCtrl.dispose(); super.dispose(); }

  Future<void> _join(BuildContext context) async {
    final pw = _pwCtrl.text.trim();
    if (pw.isEmpty) { setState(() => _error = '请输入房间密码'); return; }
    setState(() { _connecting = true; _error = null; });

    final matchStore = context.read<MatchStore>();
    final server = widget.server;
    final env = widget.env;

    final password = env.useEncodedPassword
        ? RoomPassword.encodeJoin(roomId: pw, secret: 0)
        : pw;
    matchStore.selectServer(server, env, password);
    Navigator.of(context).pop();
    if (context.mounted) context.go('/duel-room');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        _PasswordField(controller: _pwCtrl, label: '房间密码', icon: Icons.lock, onSubmitted: (_) => _join(context)),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        const SizedBox(height: 16),
        _connectButton(label: '加入房间', connecting: _connecting, onPressed: () => _join(context)),
      ]),
    );
  }
}

// ── 创建房间 ──

class _CreateRoomForm extends StatefulWidget {
  final GameServer server;
  final DuelEnvironment env;
  const _CreateRoomForm({required this.server, required this.env});

  @override
  State<_CreateRoomForm> createState() => _CreateRoomFormState();
}

class _CreateRoomFormState extends State<_CreateRoomForm> {
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

  @override
  void dispose() { _nameCtrl.dispose(); _pwCtrl.dispose(); super.dispose(); }

  Future<void> _create(BuildContext context) async {
    final pw = _pwCtrl.text.trim();
    if (pw.isEmpty) { setState(() => _error = '请设置房间密码'); return; }
    setState(() { _connecting = true; _error = null; });

    final options = RoomOptions(
      rule: _rule, startLp: _startLp, startHand: _startHand, drawCount: _drawCount,
      duelRule: _duelRule, mode: _mode, noCheckDeck: _noCheckDeck, noShuffleDeck: _noShuffleDeck, timeLimit: _timeLimit,
    );

    final matchStore = context.read<MatchStore>();
    matchStore.roomOptions = options;
    matchStore.roomName = _nameCtrl.text.trim();
    matchStore.isHost = true;

    final env = widget.env;
    String password;
    if (env.useEncodedPassword) {
      // 每次操作前都要重新获取 u16Secret
      // const u16Secret = await getUserU16Secret(user.token);
      const u16Secret = 0;
      //todo: 这里的 u16Secret 需要从服务器获取，暂时使用 0 作为占位符
      password = RoomPassword.encodeCreate(
          options: options, roomId: pw, secret: u16Secret);
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 4),
        _darkTextField(controller: _nameCtrl, label: '房间名称', icon: Icons.edit),
        const SizedBox(height: 10),
        _PasswordField(controller: _pwCtrl, label: '房间密码', icon: Icons.lock),
        const SizedBox(height: 14),
        _numberRow('初始 LP', _startLp, (v) => setState(() => _startLp = v)),
        _numberRow('初始手牌', _startHand, (v) => setState(() => _startHand = v)),
        _numberRow('每回合抽卡', _drawCount, (v) => setState(() => _drawCount = v)),
        const SizedBox(height: 6),
        _dropdownRow<int>(
          label: '卡片允许', value: _rule,
          items: const [
            DropdownMenuItem(value: 0, child: Text('OCG')), DropdownMenuItem(value: 1, child: Text('TCG')),
            DropdownMenuItem(value: 2, child: Text('OT 混')), DropdownMenuItem(value: 3, child: Text('自制卡')),
            DropdownMenuItem(value: 4, child: Text('专有卡禁止')), DropdownMenuItem(value: 5, child: Text('所有卡片')),
          ],
          onChanged: (v) => setState(() => _rule = v!),
        ),
        _dropdownRow<DuelRule>(
          label: '决斗规则', value: _duelRule,
          items: const [
            DropdownMenuItem(value: DuelRule.mr3, child: Text('大师规则 3 (2014)')),
            DropdownMenuItem(value: DuelRule.mr4, child: Text('新大师规则 (2017)')),
            DropdownMenuItem(value: DuelRule.mr2020, child: Text('大师规则 2020')),
          ],
          onChanged: (v) => setState(() => _duelRule = v!),
        ),
        _dropdownRow<RoomMode>(
          label: '对战模式', value: _mode,
          items: const [
            DropdownMenuItem(value: RoomMode.single, child: Text('单局')),
            DropdownMenuItem(value: RoomMode.match, child: Text('三局两胜 (Match)')),
            DropdownMenuItem(value: RoomMode.tag, child: Text('双打 (Tag)')),
          ],
          onChanged: (v) => setState(() => _mode = v!),
        ),
        _dropdownRow<int>(
          label: '时间限制', value: _timeLimit,
          items: const [
            DropdownMenuItem(value: 0, child: Text('无限制')), DropdownMenuItem(value: 180, child: Text('3 分钟')),
            DropdownMenuItem(value: 240, child: Text('4 分钟')), DropdownMenuItem(value: 300, child: Text('5 分钟')),
            DropdownMenuItem(value: 600, child: Text('10 分钟')),
          ],
          onChanged: (v) => setState(() => _timeLimit = v!),
        ),
        const SizedBox(height: 6),
        Row(children: [
          _checkRow('不检查卡组', _noCheckDeck, (v) => setState(() => _noCheckDeck = v ?? false)),
          const SizedBox(width: 16),
          _checkRow('不切洗卡组', _noShuffleDeck, (v) => setState(() => _noShuffleDeck = v ?? false)),
        ]),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        const SizedBox(height: 10),
        _connectButton(label: '创建房间', connecting: _connecting, onPressed: () => _create(context)),
      ]),
    );
  }
}
