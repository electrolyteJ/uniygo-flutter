import 'dart:ui';
import 'package:flutter/material.dart';

class DuelLogDrawer extends StatelessWidget {
  final List<String> logs;

  const DuelLogDrawer({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    const goldGlow = Color(0xFFFFD700);
    const cyanGlow = Color(0xFF00F0FF);
    const panelDark = Color(0xE6080E18); // rgba(8, 14, 24, 0.9)

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: panelDark,
            border: Border.all(
              color: const Color(0x4D00F0FF),
            ), // rgba(0, 240, 255, 0.3)
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '❖ DUEL LOG',
                    style: TextStyle(
                      color: goldGlow,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: logs.isEmpty ? 1 : logs.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Colors.white12,
                    height: 4,
                    thickness: 0.5,
                  ),
                  itemBuilder: (context, index) {
                    if (logs.isEmpty) {
                      return const Text(
                        '等待决斗开始...',
                        style: TextStyle(color: Colors.white24, fontSize: 10),
                      );
                    }
                    final log = logs[logs.length - 1 - index];
                    final isHighlight =
                        log.contains('发动') || log.contains('攻击力');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: isHighlight
                              ? cyanGlow
                              : const Color(0xFF8B9BB4),
                          fontSize: 10,
                          height: 1.5,
                          fontFamily: 'Noto Sans SC',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
