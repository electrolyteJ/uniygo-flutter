import 'package:biz/widgets/banlist_detail_dialog.dart';
import 'package:flutter/material.dart';
import 'package:ygo_data/ygo_data.dart';
import '../models/deck_model.dart';

class CardSearchBar extends StatefulWidget {
  final void Function(String query) onSearch;
  final bool isGridView;
  final VoidCallback onToggleViewMode;
  final List<LfTable> availableBanlists;
  final LfTable? selectedBanlist;
  final int? selectedBanlistHash;
  final void Function(int? hash) onSelectBanlist;
  final bool isLoadingBanlists;
  final int currentEnvironmentCode;
  final void Function(int env) onSetEnvironment;
  final CardFilter filter;
  final void Function(CardFilter filter) onUpdateFilter;
  final VoidCallback onResetFilters;
  final Future<CardInfo?> Function(int code) cardLoader;

  const CardSearchBar({
    super.key,
    required this.onSearch,
    required this.isGridView,
    required this.onToggleViewMode,
    required this.availableBanlists,
    required this.selectedBanlist,
    required this.selectedBanlistHash,
    required this.onSelectBanlist,
    required this.isLoadingBanlists,
    required this.currentEnvironmentCode,
    required this.onSetEnvironment,
    required this.filter,
    required this.onUpdateFilter,
    required this.onResetFilters,
    required this.cardLoader,
  });

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
    

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2A3A4A),
        border: Border(bottom: BorderSide(color: Color(0xFF455A64))),
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
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
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
                    widget.onSearch(value);
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
                      isActive: widget.isGridView,
                      onPressed: () {
                        if (!widget.isGridView) {
                          widget.onToggleViewMode();
                        }
                      },
                    ),
                    _ViewToggleButton(
                      icon: Icons.view_list,
                      isActive: !widget.isGridView,
                      onPressed: () {
                        if (widget.isGridView) {
                          widget.onToggleViewMode();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEnvironmentAndBanlist(),
          const SizedBox(height: 12),
          // 筛选器
          _buildFilterChips(),
        ],
      ),
    );
  }

  Widget _buildEnvironmentAndBanlist() {
    final selectedBanlist = widget.selectedBanlist;
    final selectedBanlistHash =
        widget.availableBanlists.any(
          (table) => table.hash == widget.selectedBanlistHash,
        )
        ? widget.selectedBanlistHash
        : null;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment<int>(value: 0, label: Text('OCG')),
            ButtonSegment<int>(value: 1, label: Text('408')),
          ],
          selected: {widget.currentEnvironmentCode},
          showSelectedIcon: false,
          onSelectionChanged: (values) {
            if (values.isNotEmpty) {
              widget.onSetEnvironment(values.first);
            }
          },
        ),
        SizedBox(
          width: 260,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF344555),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF455A64)),
            ),
            child: DropdownButton<int>(
              value: selectedBanlistHash,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: Text(widget.isLoadingBanlists ? '加载禁限卡表中...' : '禁限卡表'),
              items: widget.availableBanlists
                  .map(
                    (table) => DropdownMenuItem<int>(
                      value: table.hash,
                      child: Text(table.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: widget.isLoadingBanlists ? null : widget.onSelectBanlist,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: selectedBanlist == null
              ? null
              : () => BanlistDetailDialog.show(
                  context,
                  lfTable: selectedBanlist,
                  cardLoader: widget.cardLoader,
                ),
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('查看禁限'),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filter = widget.filter;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // 全部
        _FilterChip(
          label: '全部',
          isSelected:
              filter.cardType == null &&
              filter.race == null &&
              filter.attribute == null,
          onTap: () {
            widget.onResetFilters();
          },
        ),
        // 怪兽
        _FilterChip(
          label: '怪兽',
          isSelected: filter.cardType == 0x1,
          color: const Color(0xFFFF7043),
          onTap: () {
            widget.onUpdateFilter(
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
            widget.onUpdateFilter(
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
            widget.onUpdateFilter(
              filter.copyWith(
                cardType: filter.cardType == 0x4 ? null : 0x4,
                clearCardType: filter.cardType == 0x4,
              ),
            );
          },
        ),
        // 种族筛选
        _FilterChip(
          label: '战士',
          isSelected: filter.race == 0x1,
          onTap: () {
            widget.onUpdateFilter(
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
            widget.onUpdateFilter(
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
            widget.onUpdateFilter(
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
        backgroundColor: isActive
            ? const Color(0xFF546E7A)
            : Colors.transparent,
        foregroundColor: isActive
            ? Colors.white
            : Colors.white.withValues(alpha: 0.5),
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

