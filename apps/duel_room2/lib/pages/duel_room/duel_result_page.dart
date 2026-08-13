import 'package:flutter/material.dart';

import '../../models/duel_result_summary.dart';
import 'duel_room_exit.dart';

/// 决斗结算页：由房间页退出时经 `/duel-result` 路由展示。
///
/// 此时房间页的 ProviderScope 已销毁，页面不读写任何房间 provider，
/// 只展示经路由 extra 传入的 [DuelResultSummary]。
class DuelResultPage extends StatelessWidget {
  final DuelResultSummary result;

  const DuelResultPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final accent = result.didWin
        ? const Color(0xFFD7B65A)
        : const Color(0xFF7BA7D9);
    final title = result.didWin ? '胜利' : '失败';
    final subtitle = result.didWin ? '你赢下了这场决斗' : '这场决斗落败';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF151821), Color(0xFF090B10)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                decoration: BoxDecoration(
                  color: const Color(0xEE10141C),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accent.withValues(alpha: 0.75)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accent,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _ResultRow(
                      label: result.selfName,
                      value: '${result.selfLp}',
                      highlight: result.didWin,
                    ),
                    const SizedBox(height: 12),
                    _ResultRow(
                      label: result.opponentName,
                      value: '${result.opponentLp}',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '结束原因代码 ${result.reason}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => backHomeAfterDuel(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('返回首页'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _ResultRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: highlight ? const Color(0x1FD7B65A) : const Color(0xFF171C27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? const Color(0x80D7B65A)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            'LP $value',
            style: TextStyle(
              color: highlight ? const Color(0xFFD7B65A) : Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
