// ── 创建房间 ──

import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_mycard/account_mycard.dart';

import '../../config/servers.dart';
import '../../models/created_room_record.dart';
import '../../services/mycard_gate.dart';
import '../../pages/create_room/match_store.dart';
import '../../models/mercury233_room_spec.dart';
import '../../models/mercury233_room_string_codec.dart';
import 'duel_room_params_fields.dart';
import 'room_params_form.dart';
import 'password_field.dart';
import 'mercury233_room_form_section.dart';
import 'room_history_list.dart';
import '../create_room/room_dialog.dart';

/// 创建成功后业务侧写 MatchStore + 跳转的回调。
typedef EnterRoomCallback = void Function({
  required RoomOptions options,
  required String roomName,
  required String password,
});

class CreateRoomForm extends StatefulWidget {
  final DuelEnvironment env;

  /// 加载历史记录（由业务侧提供持久化实现）。
  final Future<List<CreatedRoomRecord>> Function() historyLoader;

  /// 保存/置顶一条历史记录。
  final Future<void> Function(CreatedRoomRecord record) onSaveRecord;

  /// 删除一条历史记录。
  final Future<void> Function(CreatedRoomRecord record) onDeleteRecord;

  /// 创建成功后的业务动作（写 MatchStore + 导航）。
  final EnterRoomCallback onEnterRoom;

  /// 禁限卡表加载（由业务侧提供数据源）。
  final Future<List<Mercury233BanlistOption>> Function()? banlistOptionsLoader;

  /// 按钮点击反馈（如音效），由业务侧注入。
  final VoidCallback? onTapFeedback;

  const CreateRoomForm({
    super.key,
    required this.env,
    required this.historyLoader,
    required this.onSaveRecord,
    required this.onDeleteRecord,
    required this.onEnterRoom,
    this.banlistOptionsLoader,
    this.onTapFeedback,
  });

  @override
  State<CreateRoomForm> createState() => _CreateRoomFormState();
}

class _CreateRoomFormState extends State<CreateRoomForm> {
  final _nameCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _connecting = false;
  String? _error;

  /// 创建房间参数（mycard/koishi 共用；由 RoomParamsForm 驱动）。
  RoomOptions _options = const RoomOptions();
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
    final records = await widget.historyLoader();
    if (mounted) setState(() => _history = records);
  }

  Future<void> _saveRecord(CreatedRoomRecord record) async {
    await widget.onSaveRecord(record);
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
        // MyCard 记录的 password 是私密房 ID（自动派生，不回填密码框）。
        _pwCtrl.text = widget.env.useEncodedPassword ? '' : record.password;
        _options = options;
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
    // MyCard 私密房：u16Secret 时间轮换，历史回填必须重新获取密钥编码；
    // 记录的 password（私密房 ID）不参与编码，房间 ID 由账号派生。
    if (widget.env.useEncodedPassword) {
      setState(() {
        _connecting = true;
        _error = null;
      });
      try {
        final encoded = await _encodeMyCardCreate(context, options);
        if (encoded == null) {
          if (mounted) setState(() => _connecting = false);
          return;
        }
        final (password, roomId) = encoded;
        await _saveRecord(record.touch());
        if (!mounted) return;
        _enterRoom(
          options: options,
          roomName: record.roomName.isEmpty
              ? 'MyCard 私密房 $roomId'
              : record.roomName,
          password: password,
        );
      } on MyCardAuthException catch (e) {
        if (mounted) {
          setState(() {
            _connecting = false;
            _error = e.message;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _connecting = false;
            _error = '创建房间失败：$e';
          });
        }
      }
      return;
    }
    final password = _encodePassword(options, record.password);
    await _saveRecord(record.touch());
    if (!mounted) return;
    _enterRoom(options: options, roomName: record.roomName, password: password);
  }

  Future<void> _deleteFromHistory(CreatedRoomRecord record) async {
    await widget.onDeleteRecord(record);
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

    // MyCard 环境：私密房流程（登录门禁 + u16Secret + 派生房间 ID），
    // 不需要用户输入房间密码。
    if (widget.env.useEncodedPassword) {
      return _createMyCard(context);
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

    final options = _options;

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

  /// MyCard 私密房创建流程：登录门禁 → 重新获取 u16Secret → 派生房间 ID
  /// → 编码（createPrivate）。
  ///
  /// 对齐 neos-ts Match/index.tsx onCreateMCRoom：MyCard 建房是私密房
  /// （isPrivate=true），房间 ID 固定由房主 external_id 派生
  /// （external_id ^ 0x54321），朋友输入该数字 ID 即可加入。
  Future<void> _createMyCard(BuildContext context) async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final options = _options;
      final encoded = await _encodeMyCardCreate(context, options);
      if (encoded == null) {
        // 用户取消登录（门禁返回 null）
        if (mounted) setState(() => _connecting = false);
        return;
      }
      final (password, roomId) = encoded;
      final roomName = _nameCtrl.text.trim();
      // 历史记录的 password 字段语义 = 私密房 ID（派生自房主 external_id，
      // 同一用户恒定），展示/分享给朋友用；房间名称仅作本地标记。
      await _saveRecord(
        CreatedRoomRecord(
          env: widget.env,
          roomName: roomName,
          password: roomId,
          options: options,
        ),
      );
      if (!context.mounted) return;
      _enterRoom(
        options: options,
        roomName: roomName.isEmpty ? 'MyCard 私密房 $roomId' : roomName,
        password: password,
      );
    } on MyCardAuthException catch (e) {
      // u16Secret 获取失败（如登录过期），消息可直接展示
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = '创建房间失败：$e';
        });
      }
    }
  }

  /// MyCard 私密房编码：登录门禁 → 每次操作前重新获取 u16Secret →
  /// encodeCreate(isPrivate: true)。返回 (编码密码, 私密房 ID)；
  /// 用户取消登录返回 null；失败抛异常由调用方处理。
  Future<(String, String)?> _encodeMyCardCreate(
    BuildContext context,
    RoomOptions options,
  ) async {
    final account = await requireMyCardAccount(
      context,
      reason: '创建 MyCard 私密房间',
    );
    if (account == null || !context.mounted) return null;
    // 对决服用 MyCard 用户名标识玩家：进房前写入 MatchStore，否则
    // DuelRoomPage 会用默认 'Guest' 发 CTOS_PLAYER_INFO，服查无此用户。
    context.read<MatchStore>().setUsername(account.username);
    // u16Secret 是时间轮换密钥，必须每次操作前重新获取。
    final u16Secret = await context.read<MyCardAccountApi>().fetchU16Secret();
    // 私密房 ID 派生自房主 external_id。注意：API 直登响应只有
    // id/username，external_id 可能缺失（为 0），此时回退 id 派生——
    // 待真实网络验证 external_id 可得性。
    final externalId = account.externalId != 0 ? account.externalId : account.id;
    final roomId = '${RoomPassword.privateRoomId(externalId)}';
    final password = RoomPassword.encodeCreate(
      options: options,
      roomId: roomId,
      secret: u16Secret,
      isPrivate: true,
    );
    return (password, roomId);
  }

  /// 非编码环境的密码直通（koishi 等）。
  String _encodePassword(RoomOptions options, String pw) => pw;

  /// 通知业务侧进入房间（写 MatchStore + 导航由调用方负责）。
  void _enterRoom({
    required RoomOptions options,
    required String roomName,
    required String password,
  }) {
    widget.onEnterRoom(
      options: options,
      roomName: roomName,
      password: password,
    );
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
              banlistOptionsLoader: widget.banlistOptionsLoader,
              onSpecChanged: (next) => setState(() {
                _mercury233Spec = next;
                _error = null;
              }),
            )
          else ...[
            darkTextField(
              controller: _nameCtrl,
              label: widget.env.useEncodedPassword ? '房间名称（本地标记）' : '房间名称',
              icon: Icons.edit,
            ),
            const SizedBox(height: 10),
            // MyCard 私密房：房间 ID 由账号自动派生，无需设置房间密码。
            if (widget.env.useEncodedPassword)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Colors.blueGrey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'MyCard 私密房间：房间 ID 由账号自动派生，创建后分享给朋友即可',
                        style: TextStyle(
                          color: Colors.blueGrey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              PasswordField(
                controller: _pwCtrl,
                label: '房间密码',
                icon: Icons.lock,
              ),
            const SizedBox(height: 14),
            RoomParamsForm(
              options: _options,
              cardRuleItems: cardRuleItems,
              onChanged: (o) => setState(() => _options = o),
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
            onTapFeedback: widget.onTapFeedback,
            onPressed: () => _create(context),
          ),
        ],
      ),
    );
  }
}
