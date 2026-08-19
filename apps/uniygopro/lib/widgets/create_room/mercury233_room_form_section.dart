import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

import '../../models/mercury233_room_spec.dart';
import '../../models/mercury233_room_string_codec.dart';
import 'mercury233_room_params_form.dart';
import 'room_dialog.dart';

/// 233 服建房表单：房间名 / 对战模式 / 手动房间串为建房专属，
/// 其余参数（大师规则/卡片允许/禁限卡表/LP/手牌/抽卡/时间/
/// 卡组检查开关）统一由 [Mercury233RoomParamsForm] 渲染（与 AI 房
/// 面板共用同一套控件）。
class Mercury233RoomFormSection extends StatefulWidget {
  final Mercury233RoomSpec spec;
  final String? errorText;
  final ValueChanged<Mercury233RoomSpec> onSpecChanged;

  /// 禁限卡表选项加载（由业务侧提供数据源）；为空时使用内置默认选项。
  final Future<List<Mercury233BanlistOption>> Function()? banlistOptionsLoader;

  const Mercury233RoomFormSection({
    super.key,
    required this.spec,
    required this.errorText,
    required this.onSpecChanged,
    this.banlistOptionsLoader,
  });

  @override
  State<Mercury233RoomFormSection> createState() =>
      _Mercury233RoomFormSectionState();
}

class _Mercury233RoomFormSectionState extends State<Mercury233RoomFormSection> {
  late final TextEditingController _roomNameCtrl;
  late final TextEditingController _manualRoomStringCtrl;
  bool _hasInteracted = false;
  bool _hasSeededManualRoomString = false;

  @override
  void initState() {
    super.initState();
    _roomNameCtrl = TextEditingController(text: widget.spec.roomName);
    _manualRoomStringCtrl = TextEditingController(
      text: widget.spec.manualRoomString,
    );
    _hasSeededManualRoomString =
        widget.spec.manualRoomStringEnabled ||
        widget.spec.manualRoomString.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant Mercury233RoomFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(_roomNameCtrl, widget.spec.roomName);
    _syncController(_manualRoomStringCtrl, widget.spec.manualRoomString);
  }

  @override
  void dispose() {
    _roomNameCtrl.dispose();
    _manualRoomStringCtrl.dispose();
    super.dispose();
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text != value) controller.text = value;
  }

  void _update(Mercury233RoomSpec next) {
    _hasInteracted = true;
    widget.onSpecChanged(next);
  }

  void _setManualMode(bool enabled, String generatedRoomString) {
    final shouldSeedManualRoomString = enabled && !_hasSeededManualRoomString;
    if (enabled) {
      _hasSeededManualRoomString = true;
    }
    _update(
      widget.spec.copyWith(
        manualRoomStringEnabled: enabled,
        manualRoomString: shouldSeedManualRoomString
            ? generatedRoomString
            : widget.spec.manualRoomString,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = Mercury233RoomStringCodec.build(widget.spec);
    final errorText =
        widget.errorText ?? (_hasInteracted ? result.error : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _darkTextField(
          controller: _roomNameCtrl,
          label: '房间名称',
          icon: Icons.edit,
          onChanged: (value) => _update(widget.spec.copyWith(roomName: value)),
        ),
        const SizedBox(height: 10),
        Mercury233RoomParamsForm(
          spec: widget.spec,
          onSpecChanged: _update,
          banlistOptionsLoader: widget.banlistOptionsLoader,
        ),
        const SizedBox(height: 8),
        Material(
          color: const Color(0xFF1E2A38),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: Colors.amber,
            value: widget.spec.manualRoomStringEnabled,
            onChanged: (value) => _setManualMode(value, result.value),
            title: Text(
              '手动编辑最终房间串',
              style: TextStyle(color: Colors.blueGrey.shade100),
            ),
          ),
        ),
        if (widget.spec.manualRoomStringEnabled)
          _darkTextField(
            controller: _manualRoomStringCtrl,
            label: '最终房间串',
            icon: Icons.code,
            onChanged: (value) {
              _hasSeededManualRoomString = true;
              _update(widget.spec.copyWith(manualRoomString: value));
            },
          )
        else
          _roomStringPreview(result.value),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _darkTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.blueGrey.shade300),
        prefixIcon: Icon(icon, color: Colors.blueGrey.shade400),
        filled: true,
        fillColor: Colors.blueGrey.shade800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _roomStringPreview(String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '最终房间串: $value',
        style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
      ),
    );
  }
}
