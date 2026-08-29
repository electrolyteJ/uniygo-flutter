import 'package:flutter/material.dart';
import 'package:resource_data/card_info.dart';

/// 卡牌详情弹窗
/// 支持显示卡牌完整信息、禁限状态、添加到卡组
class CardDetailDialog extends StatelessWidget {
  final CardInfo card;
  final bool showAddButton;
  final String? defaultZone;
  final String? banlistStatus;
  final String? imageUrl;

  const CardDetailDialog({
    super.key,
    required this.card,
    this.showAddButton = true,
    this.defaultZone,
    this.banlistStatus,
    this.imageUrl,
  });

  /// 显示卡牌详情弹窗
  static Future<void> show(
    BuildContext context, {
    required CardInfo card,
    bool showAddButton = true,
    String? defaultZone,
    String? banlistStatus,
    String? imageUrl,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CardDetailDialog(
        card: card,
        showAddButton: showAddButton,
        defaultZone: defaultZone,
        banlistStatus: banlistStatus,
        imageUrl: imageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final banlistStatus = this.banlistStatus;
    final imageUrl =
        this.imageUrl ??
        'https://cdn02.moecube.com:444/images/ygopro-images-zh-CN/${card.code}.jpg';
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isSmallScreen ? screenSize.width * 0.9 : 700,
          maxHeight: screenSize.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            _buildHeader(context, theme, banlistStatus),
            // 内容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: isSmallScreen
                    ? _buildVerticalLayout(theme, banlistStatus, imageUrl)
                    : _buildHorizontalLayout(theme, banlistStatus, imageUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    String? banlistStatus,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (banlistStatus != null) ...[
                  const SizedBox(height: 4),
                  _BanlistBadge(status: banlistStatus),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalLayout(
    ThemeData theme,
    String? banlistStatus,
    String imageUrl,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 卡图
        _buildCardImage(theme, imageUrl),
        const SizedBox(width: 16),
        // 信息
        Expanded(child: _buildCardInfo(theme, banlistStatus)),
      ],
    );
  }

  Widget _buildVerticalLayout(
    ThemeData theme,
    String? banlistStatus,
    String imageUrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 卡图
        _buildCardImage(theme, imageUrl),
        const SizedBox(height: 16),
        // 信息
        _buildCardInfo(theme, banlistStatus),
      ],
    );
  }

  Widget _buildCardImage(ThemeData theme, String imageUrl) {
    return Container(
      width: 400,
      height: 580,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.name,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardInfo(ThemeData theme, String? banlistStatus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 类型信息
        _InfoSection(label: '类型', value: card.typeText),
        if (card.isMonster) ...[
          _InfoSection(label: '属性', value: card.attributeText),
          _InfoSection(label: '种族', value: card.raceText),
          if (card.attack >= 0 || card.defense >= 0)
            _InfoSection(
              label: '攻/守',
              value:
                  '${card.attack >= 0 ? card.attack : "?"} / ${card.defense >= 0 ? card.defense : "?"}',
            ),
          if (card.isPendulum) ...[
            _InfoSection(
              label: '灵摆刻度',
              value: '${card.lscale} / ${card.rscale}',
            ),
          ],
          if (card.isLink) ...[
            _InfoSection(
              label: '连接标记',
              value: _getLinkMarkerText(card.linkMarker),
            ),
          ],
          // 等级/阶级
          if (!card.isLink) ...[
            _InfoSection(
              label: card.isXyz ? '阶级' : '等级',
              value: '${card.level.abs()}',
            ),
          ],
        ],
        const SizedBox(height: 12),
        // 效果文本
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(card.desc, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }

  String _getLinkMarkerText(int linkMarker) {
    if (linkMarker == 0) return '无';
    final markers = <String>[];
    if (linkMarker & 0x1 != 0) markers.add('下');
    if (linkMarker & 0x2 != 0) markers.add('左下');
    if (linkMarker & 0x4 != 0) markers.add('左');
    if (linkMarker & 0x8 != 0) markers.add('左上');
    if (linkMarker & 0x10 != 0) markers.add('上');
    if (linkMarker & 0x20 != 0) markers.add('右上');
    if (linkMarker & 0x40 != 0) markers.add('右');
    if (linkMarker & 0x80 != 0) markers.add('右下');
    return markers.join(' ');
  }
}

class _InfoSection extends StatelessWidget {
  final String label;
  final String value;

  const _InfoSection({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BanlistBadge extends StatelessWidget {
  final String status;

  const _BanlistBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    String text;

    switch (status) {
      case '禁止':
        color = theme.colorScheme.error;
        text = '禁止';
        break;
      case '限制':
        color = Colors.orange;
        text = '限制 (最多1张)';
        break;
      case '准限制':
        color = Colors.yellow.shade700;
        text = '准限制 (最多2张)';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
