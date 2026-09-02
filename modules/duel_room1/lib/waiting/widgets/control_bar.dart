import 'package:flutter/material.dart';
import 'package:duelink/duelink.dart';
import 'automation_switch.dart';

class ControlBar extends StatelessWidget {
  final bool isHost;
  final PlayerType selfType;
  final bool isSelfReady;
  final bool isAllReady;
  final bool autoHandEnabled;
  final bool autoTurnOrderEnabled;
  final bool autoDuelEnabled;
  final ValueChanged<BuildContext> toggleReady;
  final ValueChanged<bool> onToggleAutoHand;
  final ValueChanged<bool> onToggleAutoTurnOrder;
  final ValueChanged<bool> onToggleAutoDuel;
  final VoidCallback onStartDuel;
  final VoidCallback onBecomeDuelist;
  final VoidCallback onBecomeObserver;

  const ControlBar({
    super.key,
    required this.isHost,
    required this.selfType,
    required this.isSelfReady,
    required this.isAllReady,
    required this.autoHandEnabled,
    required this.autoTurnOrderEnabled,
    required this.autoDuelEnabled,
    required this.toggleReady,
    required this.onToggleAutoHand,
    required this.onToggleAutoTurnOrder,
    required this.onToggleAutoDuel,
    required this.onStartDuel,
    required this.onBecomeDuelist,
    required this.onBecomeObserver,
  });

  /// godot RoomOverlay 按钮的强调色。
  static const _accentReady = Color(0xFF1A8C4C); // 准备：绿
  static const _accentStart = Color(0xFF996600); // 开始决斗：橙

  @override
  Widget build(BuildContext context) {
    // tag 模式 2/3 号位（player3/player4）同样是决斗者。
    final isPlayer = selfType.isDuelist;
    // 不设底色：等待室已改为半透明弹窗，面板背景由弹窗容器提供。
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.blueGrey.shade700)),
      ),
      child: SafeArea(
        top: false,
        // 两行布局：第一行自动化开关，第二行操作按钮。
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                if (isHost)
                  buildAutomationSwitch(
                    label: '自动加入决斗',
                    value: autoDuelEnabled,
                    enabled: !isSelfReady,
                    onChanged: (value) => onToggleAutoDuel(value),
                  ),
                buildAutomationSwitch(
                  label: '自动猜拳',
                  value: autoHandEnabled,
                  enabled: !isSelfReady,
                  onChanged: (value) => onToggleAutoHand(value),
                ),
                buildAutomationSwitch(
                  label: '自动随机先后手',
                  value: autoTurnOrderEnabled,
                  enabled: !isSelfReady,
                  onChanged: (value) => onToggleAutoTurnOrder(value),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (isPlayer)
                    _roomButton(
                      key: const ValueKey('waiting-room-ready'),
                      maxWidth: constraints.maxWidth,
                      // 自动开局只在房主端生效（notifier 内按 isHost
                      // 门控），非房主即使开过偏好也不会自动开始，
                      // 标签同步隐藏避免误导。
                      label: isSelfReady
                          ? '取消准备'
                          : (isHost && autoDuelEnabled ? '准备&决斗' : '准备'),
                      icon: isSelfReady ? Icons.cancel : Icons.check_circle,
                      accent: _accentReady,
                      active: isSelfReady,
                      onPressed: () => toggleReady(context),
                    ),
                  if (isPlayer)
                    _roomButton(
                      maxWidth: constraints.maxWidth,
                      label: '观战',
                      icon: Icons.visibility,
                      accent: const Color(0xFF8CA6C4),
                      onPressed: onBecomeObserver,
                    ),
                  if (selfType == PlayerType.observer)
                    _roomButton(
                      maxWidth: constraints.maxWidth,
                      label: '加入对战',
                      icon: Icons.person_add,
                      accent: Colors.amber,
                      onPressed: onBecomeDuelist,
                    ),
                  if (isHost && !autoDuelEnabled)
                    _roomButton(
                      maxWidth: constraints.maxWidth,
                      label: '开始决斗',
                      icon: Icons.play_arrow,
                      accent: _accentStart,
                      onPressed: isAllReady ? onStartDuel : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// godot RoomOverlay 风格按钮：深色底 Color(0.04,0.07,0.13,0.95) +
  /// 彩色描边 + 圆角 6，最小 120×44；[active] 时用 godot hover 的
  /// accent.darkened(0.55) 底色表达「已准备」等激活态。
  Widget _roomButton({
    Key? key,
    required double maxWidth,
    required String label,
    required IconData icon,
    required Color accent,
    required VoidCallback? onPressed,
    bool active = false,
  }) {
    final bg = active
        ? Color.lerp(accent, Colors.black, 0.55)!
        : const Color(0xF20A1221);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: OutlinedButton(
        key: key,
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(bg),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? Colors.blueGrey.shade500
                : Colors.white,
          ),
          overlayColor: WidgetStatePropertyAll(accent.withValues(alpha: 0.2)),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? Colors.blueGrey.shade700
                  : accent,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          minimumSize: WidgetStatePropertyAll(
            Size(maxWidth < 120 ? maxWidth : 120, 44),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: maxWidth < 120 ? 4 : 16),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
