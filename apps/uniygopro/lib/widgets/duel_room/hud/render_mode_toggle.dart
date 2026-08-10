import 'package:flutter/material.dart';
import '../field/playmat_render_mode.dart';

/// 渲染模式切换器：Prototype / Flame 3D 双段胶囊。
///
/// 从 [PhaseBar] 中抽取，供 AppBar actions 使用。
class RenderModeToggle extends StatelessWidget {
  final PlaymatRenderMode mode;
  final ValueChanged<PlaymatRenderMode>? onChanged;

  const RenderModeToggle({
    super.key,
    required this.mode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
          _buildChip(
            label: 'Prototype',
            target: PlaymatRenderMode.prototype,
          ),
          _buildChip(
            label: 'Flame 3D',
            target: PlaymatRenderMode.flame,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required PlaymatRenderMode target,
  }) {
    final active = mode == target;
    final enabled = onChanged != null;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(target) : null,
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
