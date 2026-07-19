import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../model/card_model.dart';
import '../service/script_service.dart';
import '../service/ocgcore_service.dart';
import 'card_effect_animation.dart';
import 'summon_animation.dart';

class CardAnimation extends StatefulWidget {
  final CardData card;
  final String imageUrl;
  final double width;
  final double height;
  final List<EffectType>? effects;
  final VoidCallback? onTap;
  final OcgcoreService? ocgcoreService;

  const CardAnimation({
    super.key,
    required this.card,
    required this.imageUrl,
    this.width = 200,
    this.height = 280,
    this.effects,
    this.onTap,
    this.ocgcoreService,
  });

  @override
  State<CardAnimation> createState() => _CardAnimationState();
}

class _CardAnimationState extends State<CardAnimation> {
  bool _isHovered = false;
  bool _isAnimating = false;
  int _animationIndex = 0;
  bool _isExecutingScript = false;
  String _scriptResult = '';

  void _triggerEffectAnimation() {
    setState(() {
      _isAnimating = true;
      _animationIndex = 0;
    });

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SummonAnimation(
          card: widget.card,
          imageUrl: widget.imageUrl,
          onComplete: () {
            Navigator.pop(context);
            setState(() {
              _isAnimating = false;
            });
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
      ),
    );
  }

  Future<void> _executeCardScript() async {
    if (_isExecutingScript || widget.ocgcoreService == null) return;

    setState(() {
      _isExecutingScript = true;
      _scriptResult = '正在执行脚本...';
    });

    try {
      widget.ocgcoreService!.cacheCard(widget.card);
      final result = await widget.ocgcoreService!.executeCardScript(widget.card.code);
      setState(() {
        _scriptResult = result;
      });

      Future.delayed(const Duration(milliseconds: 3000)).then((_) {
        setState(() {
          _scriptResult = '';
        });
      });
    } catch (e) {
      setState(() {
        _scriptResult = '执行失败: $e';
      });
    } finally {
      setState(() {
        _isExecutingScript = false;
      });
    }
  }

  EffectType? get _currentEffect {
    if (widget.effects == null || widget.effects!.isEmpty) return null;
    return widget.effects![_animationIndex % widget.effects!.length];
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          _triggerEffectAnimation();
          widget.onTap?.call();
        },
        onDoubleTap: () {
          _executeCardScript();
        },
        child: Stack(
          children: [
            _buildCardContainer(),
            CardEffectAnimation(
              animationType: _currentEffect?.animationType ?? 'default',
              child: _buildCardImage(),
            ),
            _buildCardGlow(),
            _buildCardInfo(),
            EffectNameAnimation(
              effect: _currentEffect ??
                  const EffectType(
                    name: '效果',
                    description: '',
                    animationType: 'default',
                  ),
              visible: _isAnimating && _currentEffect != null,
            ),
            _buildScriptResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildScriptResult() {
    if (_scriptResult.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _scriptResult.contains('失败') ? Colors.red : Colors.green),
        ),
        child: Text(
          _scriptResult,
          style: TextStyle(
            color: _scriptResult.contains('失败') ? Colors.red : Colors.green,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCardContainer() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: _isHovered ? 20 : 10,
            offset: Offset(0, _isHovered ? 10 : 5),
          ),
        ],
      ),
      transform: _isHovered
          ? Matrix4.translationValues(0, -10, 0)
          : Matrix4.identity(),
    );
  }

  Widget _buildCardImage() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(),
          width: _isAnimating ? 4 : 3,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildPlaceholder(),
        ),
      ),
    )
        .animate()
        .scale(
          duration: 300.ms,
          begin: const Offset(1.0, 1.0),
          end: _isHovered ? const Offset(1.05, 1.05) : const Offset(1.0, 1.0),
        )
        .rotate(
          duration: 300.ms,
          begin: 0,
          end: _isHovered ? 2 * 3.14159 / 180 : 0,
        )
        .shimmer(
          duration: _isAnimating ? 500.ms : 0.ms,
          color: _isAnimating ? Colors.white.withValues(alpha: 0.5) : Colors.transparent,
        );
  }

  Widget _buildCardGlow() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: _isHovered ? 0.1 : 0),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardInfo() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.card.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  widget.card.attributeText,
                  style: TextStyle(
                    color: _getAttributeColor(),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.card.raceText,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            if (widget.effects != null && widget.effects!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 10,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.effects!.length}个效果',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              widget.card.name,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getBorderColor() {
    if (_isAnimating) {
      return _currentEffect?.animationType == 'destroy'
          ? Colors.red
          : _currentEffect?.animationType == 'spsummon'
              ? Colors.amber
              : _currentEffect?.animationType == 'negate'
                  ? Colors.purple
                  : Colors.white;
    }

    if (widget.card.isSpell) return Colors.blue;
    if (widget.card.isTrap) return Colors.purple;
    switch (widget.card.attribute) {
      case 0x01:
        return Colors.brown;
      case 0x02:
        return Colors.blue;
      case 0x04:
        return Colors.red;
      case 0x08:
        return Colors.green;
      case 0x10:
        return Colors.yellow;
      case 0x20:
        return Colors.grey;
      case 0x40:
        return Colors.amber;
      default:
        return Colors.white;
    }
  }

  Color _getAttributeColor() {
    switch (widget.card.attribute) {
      case 0x01:
        return Colors.brown;
      case 0x02:
        return Colors.blue;
      case 0x04:
        return Colors.red;
      case 0x08:
        return Colors.green;
      case 0x10:
        return Colors.yellow;
      case 0x20:
        return Colors.grey;
      case 0x40:
        return Colors.amber;
      default:
        return Colors.white;
    }
  }
}

class CardAttackAnimation extends StatelessWidget {
  final int attack;

  const CardAttackAnimation({
    super.key,
    required this.attack,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: attack),
      duration: 1000.ms,
      builder: (context, value, child) {
        return Text(
          '$value',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }
}

class CardLevelAnimation extends StatelessWidget {
  final int level;

  const CardLevelAnimation({
    super.key,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: level),
      duration: 500.ms,
      builder: (context, value, child) {
        return Row(
          children: List.generate(value, (index) {
            return const Icon(
              Icons.star,
              size: 12,
              color: Colors.yellow,
            )
                .animate()
                .fadeIn(duration: 100.ms)
                .slide(begin: const Offset(0, 5), end: Offset.zero);
          }),
        );
      },
    );
  }
}