import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../stores/deck_editor_store.dart';
import '../../models/deck_model.dart';

class CardSearchBar extends StatefulWidget {
  const CardSearchBar({super.key});

  @override
  State<CardSearchBar> createState() => _CardSearchBarState();
}

class _CardSearchBarState extends State<CardSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DeckEditorStore>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2A3A4A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF455A64)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 搜索框 + 视图切换
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '搜索卡牌名称、效果文本...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF344555),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF455A64)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF455A64)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFFFB300)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    store.searchCards(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // 视图切换按钮
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF344555),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ViewToggleButton(
                      icon: Icons.grid_view,
                      isActive: store.isGridView,
                      onPressed: () {
                        if (!store.isGridView) {
                          store.toggleViewMode();
                        }
                      },
                    ),
                    _ViewToggleButton(
                      icon: Icons.view_list,
                      isActive: !store.isGridView,
                      onPressed: () {
                        if (store.isGridView) {
                          store.toggleViewMode();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 筛选器
          _buildFilterChips(store),
        ],
      ),
    );
  }

  Widget _buildFilterChips(DeckEditorStore store) {
    final filter = store.filter;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // 全部
        _FilterChip(
          label: '全部',
          isSelected: filter.isDefault,
          onTap: () {
            store.updateFilter(const CardFilter());
          },
        ),
        // 怪兽
        _FilterChip(
          label: '怪兽',
          isSelected: filter.cardType == 0x1,
          color: const Color(0xFFFF7043),
          onTap: () {
            store.updateFilter(
              filter.copyWith(
                cardType: filter.cardType == 0x1 ? null : 0x1,
                clearCardType: filter.cardType == 0x1,
              ),
            );
          },
        ),
        // 魔法
        _FilterChip(
          label: '魔法',
          isSelected: filter.cardType == 0x2,
          color: const Color(0xFF42A5F5),
          onTap: () {
            store.updateFilter(
              filter.copyWith(
                cardType: filter.cardType == 0x2 ? null : 0x2,
                clearCardType: filter.cardType == 0x2,
              ),
            );
          },
        ),
        // 陷阱
        _FilterChip(
          label: '陷阱',
          isSelected: filter.cardType == 0x4,
          color: const Color(0xFFAB47BC),
          onTap: () {
            store.updateFilter(
              filter.copyWith(
                cardType: filter.cardType == 0x4 ? null : 0x4,
                clearCardType: filter.cardType == 0x4,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        // 环境筛选
        _FilterChip(
          label: 'OCG',
          isSelected: filter.env == 0,
          onTap: () {
            store.updateFilter(
              filter.copyWith(
                env: filter.env == 0 ? null : 0,
                clearEnv: filter.env == 0,
              ),
            );
          },
        ),
        _FilterChip(
          label: '408',
          isSelected: filter.env == 1,
          onTap: () {
            store.updateFilter(
              filter.copyWith(
                env: filter.env == 1 ? null : 1,
                clearEnv: filter.env == 1,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        // 种族筛选
        _FilterChip(
          label: '战士',
          isSelected: filter.race == 0x1,
          onTap: () {
            store.updateFilter(
              filter.copyWith(
                race: filter.race == 0x1 ? null : 0x1,
                clearRace: filter.race == 0x1,
              ),
            );
          },
        ),
        _FilterChip(
          label: '魔法师',
          isSelected: filter.race == 0x2,
          onTap: () {
            store.updateFilter(
              filter.copyWith(
                race: filter.race == 0x2 ? null : 0x2,
                clearRace: filter.race == 0x2,
              ),
            );
          },
        ),
        _FilterChip(
          label: '龙',
          isSelected: filter.race == 0x2000,
          onTap: () {
            store.updateFilter(
              filter.copyWith(
                race: filter.race == 0x2000 ? null : 0x2000,
                clearRace: filter.race == 0x2000,
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── 视图切换按钮 ──
class _ViewToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  const _ViewToggleButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: isActive ? const Color(0xFF546E7A) : Colors.transparent,
        foregroundColor: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
      ),
    );
  }
}

// ── 筛选芯片 ──
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFFFFB300);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.2)
              : const Color(0xFF344555),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? chipColor : const Color(0xFF455A64),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? chipColor : Colors.white.withValues(alpha: 0.7),
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
