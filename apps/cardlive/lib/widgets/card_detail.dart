import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ygo_data/card_info.dart';
import '../service/script_service.dart';
import '../summon/summon_overlay.dart'; // 导入新的召唤叠加层

class CardDetail extends StatelessWidget {
  final CardInfo card;
  final String imageUrl;
  final String limitText;
  final List<EffectType>? effects;
  final VoidCallback onClose;

  const CardDetail({
    super.key,
    required this.card,
    required this.imageUrl,
    required this.limitText,
    this.effects,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCloseButton(),
              const SizedBox(height: 20),
              _buildCardImage(),
              const SizedBox(height: 20),
              _buildCardInfo(),
              const SizedBox(height: 20),
              _buildCardStats(),
              const SizedBox(height: 20),
              _buildSummonButton(context), // 插入召唤按钮
              const SizedBox(height: 10),
              _buildCardDesc(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummonButton(BuildContext context) {
    // 只有怪兽卡可以发动召唤动效
    if (!card.isMonster) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, _, __) => SummonOverlay(
                card: card,
                imageUrl: imageUrl,
                onBack: () => Navigator.of(context).pop(),
              ),
              transitionsBuilder: (context, animation, _, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        },
        icon: const Icon(Icons.flash_on, color: Colors.cyanAccent),
        label: const Text(
          '发动召唤',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent.withOpacity(0.2),
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          shadowColor: Colors.cyanAccent.withOpacity(0.5),
          elevation: 10,
        ),
      ),
    ).animate().fadeIn(delay: 600.ms).scale();
  }

  Widget _buildCloseButton() {
    return Align(
      alignment: Alignment.topRight,
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: onClose,
      ),
    );
  }

  Widget _buildCardImage() {
    return Container(
      width: 300,
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor(),
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: _getBorderColor().withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildPlaceholder(),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(duration: 500.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0))
        .rotate(duration: 500.ms, begin: -5 * 3.14159 / 180, end: 0);
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 300,
      height: 420,
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 12),
            Text(
              card.name,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardInfo() {
    return Column(
      children: [
        Text(
          card.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getLimitColor(),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            limitText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: _getAttributeColor()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                card.attributeText,
                style: TextStyle(
                  color: _getAttributeColor(),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              card.raceText,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              card.typeText,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildCardStats() {
    if (!card.isMonster) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('等级', card.level.toString(), Icons.star),
          _buildStatItem('攻击', card.attack.toString(), Icons.favorite),
          _buildStatItem('防御', card.attack.toString(), Icons.shield),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slide(begin: const Offset(0, 20), end: Offset.zero);
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[400], size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCardDesc() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '卡片效果',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.desc.isNotEmpty ? card.desc : '暂无效果描述',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.justify,
          ),
          if (effects != null && effects!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.grey[600]),
            const SizedBox(height: 12),
            const Text(
              '脚本效果解析',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: effects!.asMap().entries.map((entry) {
                final index = entry.key;
                final effect = entry.value;
                return _buildEffectItem(effect, index);
              }).toList(),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slide(begin: const Offset(0, 20), end: Offset.zero);
  }

  Widget _buildEffectItem(EffectType effect, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getEffectBgColor(effect.animationType),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  effect.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                if (effect.description.isNotEmpty)
                  Text(
                    effect.description,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              effect.animationType,
              style: TextStyle(color: Colors.grey[400], fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Color _getEffectBgColor(String type) {
    switch (type) {
      case 'destroy': return Colors.red.withValues(alpha: 0.2);
      case 'spsummon': return Colors.amber.withValues(alpha: 0.2);
      case 'negate': return Colors.purple.withValues(alpha: 0.2);
      case 'atkchange': return Colors.orange.withValues(alpha: 0.2);
      case 'defchange': return Colors.blue.withValues(alpha: 0.2);
      case 'draw': return Colors.cyan.withValues(alpha: 0.2);
      case 'remove': return Colors.grey.withValues(alpha: 0.2);
      case 'field': return Colors.green.withValues(alpha: 0.2);
      case 'ignition': return Colors.yellow.withValues(alpha: 0.2);
      case 'trigger': return Colors.pink.withValues(alpha: 0.2);
      case 'damage': return Colors.redAccent.withValues(alpha: 0.2);
      case 'recover': return Colors.greenAccent.withValues(alpha: 0.2);
      case 'search': return Colors.blueAccent.withValues(alpha: 0.2);
      default: return Colors.white.withValues(alpha: 0.1);
    }
  }

  Color _getBorderColor() {
    if (card.isSpell) return Colors.blue;
    if (card.isTrap) return Colors.purple;
    switch (card.attribute) {
      case 0x01: return Colors.brown;
      case 0x02: return Colors.blue;
      case 0x04: return Colors.red;
      case 0x08: return Colors.green;
      case 0x10: return Colors.yellow;
      case 0x20: return Colors.grey;
      case 0x40: return Colors.amber;
      default: return Colors.white;
    }
  }

  Color _getAttributeColor() {
    switch (card.attribute) {
      case 0x01: return Colors.brown;
      case 0x02: return Colors.blue;
      case 0x04: return Colors.red;
      case 0x08: return Colors.green;
      case 0x10: return Colors.yellow;
      case 0x20: return Colors.grey;
      case 0x40: return Colors.amber;
      default: return Colors.white;
    }
  }

  Color _getLimitColor() {
    switch (limitText) {
      case '禁止': return Colors.red;
      case '限制': return Colors.orange;
      case '准限制': return Colors.yellow;
      default: return Colors.green;
    }
  }
}
