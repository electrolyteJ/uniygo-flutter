import 'package:biz/duel/models/duel_menu.dart';
import 'package:duelink/duelink.dart';
import 'package:flutter/material.dart';

import 'hud_theme.dart';

/// 右侧竖排阶段轨道（MDPro3 风格圆形按钮：DP/SP/M1/BP/M2/EP）。
///
/// 当前阶段发光高亮；有可执行阶段动作时点击弹出操作菜单
/// （条目来自 biz phaseActionMenuProvider）。
class PhaseRail extends StatelessWidget {
  const PhaseRail({
    super.key,
    required this.current,
    required this.isMyTurn,
    required this.phaseActions,
    required this.onActionTap,
  });

  final DuelPhase current;
  final bool isMyTurn;
  final List<ActionMenuEntry> phaseActions;
  final void Function(ActionMenuEntry entry) onActionTap;

  static const _phases = [
    DuelPhase.dp,
    DuelPhase.sp,
    DuelPhase.m1,
    DuelPhase.bp,
    DuelPhase.m2,
    DuelPhase.ep,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: HudTheme.panel(radius: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final phase in _phases) ...[
            _PhaseDot(
              label: phase.name.toUpperCase(),
              active: phase == current,
              isMyTurn: isMyTurn,
            ),
            if (phase != _phases.last)
              Container(width: 2, height: 10, color: HudTheme.panelBorder),
          ],
          if (phaseActions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PhaseActionButton(
              onTap: () => _showPhaseMenu(context),
            ),
          ],
        ],
      ),
    );
  }

  void _showPhaseMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: HudTheme.glowPanel(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('阶段操作', style: HudTheme.title),
              ),
              for (final entry in phaseActions)
                ListTile(
                  title: Text(entry.label, style: HudTheme.body),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onActionTap(entry);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseDot extends StatelessWidget {
  const _PhaseDot({
    required this.label,
    required this.active,
    required this.isMyTurn,
  });

  final String label;
  final bool active;
  final bool isMyTurn;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (isMyTurn ? HudTheme.cyan : HudTheme.gold)
        : HudTheme.panelBorder;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
        border: Border.all(color: color, width: active ? 2 : 1),
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? color : HudTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PhaseActionButton extends StatelessWidget {
  const _PhaseActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [HudTheme.cyanDim, HudTheme.cyan],
          ),
          boxShadow: [
            BoxShadow(
              color: HudTheme.cyan.withValues(alpha: 0.5),
              blurRadius: 12,
            ),
          ],
        ),
        child: const Icon(Icons.bolt, color: Colors.black, size: 20),
      ),
    );
  }
}
