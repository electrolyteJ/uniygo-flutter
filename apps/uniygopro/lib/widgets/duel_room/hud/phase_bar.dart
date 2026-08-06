import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniygopro/widgets/duel_room/field/playmat_render_mode.dart';
import '../../../pages/duel_room/duel/duel_field_store.dart';

class PhaseBar extends StatelessWidget {
  final PlaymatRenderMode renderMode;
  final ValueChanged<PlaymatRenderMode>? onRenderModeChanged;

  const PhaseBar({
    super.key,
    this.renderMode = PlaymatRenderMode.prototype,
    this.onRenderModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final duelStore = context.watch<DuelFieldStore>();
    final isMyTurn = duelStore.currentPlayer == duelStore.myController;

    // v10: .turn-chip —— 顶部居中悬浮胶囊（回合徽章 + 计时），
    // 渲染模式切换作为开发工具钉在右缘。
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Center(child: _buildTurnChip(duelStore, isMyTurn)),
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(child: _buildRenderModeToggle()),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnChip(DuelFieldStore duelStore, bool isMyTurn) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [Color(0xB8060B14), Color(0xB30F192A), Color(0xB8060B14)],
            ),
            border: Border.all(color: const Color(0x3300F0FF)),
            boxShadow: const [
              BoxShadow(color: Color(0x1A00F0FF), blurRadius: 18),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1A00F0FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x7000F0FF)),
                ),
                child: Text(
                  'TURN ${duelStore.turnCount} · ${isMyTurn ? 'YOUR TURN' : 'OPPONENT'}',
                  style: const TextStyle(
                    color: Color(0xFF00F0FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '⏱ 118s',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRenderModeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x3300F0FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRenderModeChip(
            label: 'Prototype',
            mode: PlaymatRenderMode.prototype,
          ),
          _buildRenderModeChip(
            label: 'Flame 3D',
            mode: PlaymatRenderMode.flame,
          ),
        ],
      ),
    );
  }

  Widget _buildRenderModeChip({
    required String label,
    required PlaymatRenderMode mode,
  }) {
    final active = renderMode == mode;
    final enabled = onRenderModeChanged != null;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onRenderModeChanged == null
            ? null
            : () => onRenderModeChanged!(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF00F0FF), Color(0xFF0077FF)],
                  )
                : null,
            color: active ? null : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF8B9BB4),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFamily: 'Orbitron',
            ),
          ),
        ),
      ),
    );
  }
}
