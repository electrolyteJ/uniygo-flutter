import 'package:flutter/material.dart';
import '../models/duel_card.dart';
import '../models/duel_state.dart';
import '../theme/duel_theme.dart';
import 'card_face.dart';

class PopupsLayer extends StatelessWidget {
  final DuelState state;

  const PopupsLayer({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final p in state.popups) _PopupItem(state: state, popup: p),
      ],
    );
  }
}

class _PopupItem extends StatefulWidget {
  final DuelState state;
  final Popup popup;

  const _PopupItem({required this.state, required this.popup});

  @override
  State<_PopupItem> createState() => _PopupItemState();
}

class _PopupItemState extends State<_PopupItem> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..forward().then((_) {
        if (mounted) widget.state.removePopup(widget.popup.id);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.popup;
    Alignment align;
    if (p.side == Side.own) {
      align = const Alignment(-0.7, 0.78);
    } else if (p.side == Side.foe) {
      align = const Alignment(0, -0.72);
    } else {
      align = const Alignment(0, -0.24);
    }
    final color = p.good ? const Color(0xFF5CFFB0) : const Color(0xFFFF5C7A);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          final scale = t < .15 ? .4 + (t / .15) * .9 : t < .3 ? 1.3 - ((t - .15) / .15) * .3 : 1.0;
          final opacity = t > .7 ? ((1 - t) / .3).clamp(0.0, 1.0) : 1.0;
          return Align(
            alignment: align,
            child: Transform.translate(
              offset: Offset(0, -t * 70),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Text(
                    p.text,
                    style: DuelTheme.tech(p.side == null ? 24 : 32,
                            color: color, w: FontWeight.w800)
                        .copyWith(shadows: [
                      Shadow(color: color.withValues(alpha: .9), blurRadius: 18),
                      const Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 2)),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TrapPromptOverlay extends StatefulWidget {
  final DuelState state;

  const TrapPromptOverlay({super.key, required this.state});

  @override
  State<TrapPromptOverlay> createState() => _TrapPromptOverlayState();
}

class _TrapPromptOverlayState extends State<TrapPromptOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timer;
  TrapPromptData? _bound;

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(vsync: this, duration: const Duration(milliseconds: 8000));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = widget.state.trapPrompt;
    if (p != null && !identical(p, _bound)) {
      _bound = p;
      _timer.forward(from: 0).then((_) {
        if (mounted && identical(widget.state.trapPrompt, _bound) && !p.completer.isCompleted) {
          p.completer.complete(false);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.state.trapPrompt;
    if (p == null) return const SizedBox.shrink();
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: () {},
          child: Container(color: const Color(0x8C03040A)),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(36, 22, 36, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFA141836), Color(0xFA080A1A)],
            ),
            border: Border.all(color: DuelTheme.trap),
            boxShadow: [BoxShadow(color: DuelTheme.trap.withValues(alpha: .35), blurRadius: 50)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('发动陷阱 ?',
                  style: DuelTheme.body(22, color: const Color(0xFFFFB6EF), w: FontWeight.w900, ls: 6)),
              const SizedBox(height: 4),
              Text('TRAP ACTIVATE', style: DuelTheme.tech(9, color: const Color(0xFFC98ABD), ls: 5)),
              const SizedBox(height: 14),
              CardFace(card: p.card, width: 118),
              const SizedBox(height: 10),
              Text('${p.card.name} · ${p.card.enName}',
                  style: DuelTheme.body(13, color: const Color(0xFFE8ECFF), ls: 1.5)),
              const SizedBox(height: 14),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _btn('发动 ACTIVATE', true, () {
                    if (!p.completer.isCompleted) p.completer.complete(true);
                  }),
                  const SizedBox(width: 14),
                  _btn('跳过 SKIP', false, () {
                    if (!p.completer.isCompleted) p.completer.complete(false);
                  }),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 260,
                height: 4,
                child: AnimatedBuilder(
                  animation: _timer,
                  builder: (context, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (1 - _timer.value).clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [DuelTheme.trap, Color(0xFFFFB6EF)]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _btn(String label, bool primary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [Color(0xFFFFB6EF), DuelTheme.trap, Color(0xFFA03490)])
              : null,
          color: primary ? null : Colors.white.withValues(alpha: .07),
          border: primary ? null : Border.all(color: const Color(0x4D9AA6D8)),
          boxShadow: [
            if (primary) BoxShadow(color: DuelTheme.trap.withValues(alpha: .4), blurRadius: 18),
          ],
        ),
        child: Text(label,
            style: DuelTheme.body(13,
                color: primary ? const Color(0xFF2A0622) : DuelTheme.textDim,
                w: FontWeight.w700,
                ls: 2)),
      ),
    );
  }
}

class RebirthOverlay extends StatelessWidget {
  final DuelState state;

  const RebirthOverlay({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final req = state.rebirthRequest;
    if (req == null) return const SizedBox.shrink();
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(color: const Color(0xA803040A)),
        ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.88),
          child: Container(
            padding: const EdgeInsets.fromLTRB(32, 22, 32, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFA141836), Color(0xFA080A1A)]),
              border: Border.all(color: DuelTheme.cyan.withValues(alpha: .4)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .8), blurRadius: 60)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('选择复活的怪兽',
                    style: DuelTheme.body(19, color: DuelTheme.cyan, w: FontWeight.w900, ls: 5)),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < req.candidates.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _Choice(
                            card: req.candidates[i],
                            onTap: () {
                              if (!req.completer.isCompleted) req.completer.complete(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    if (!req.completer.isCompleted) req.completer.complete(-1);
                  },
                  child: Text('取 消',
                      style: DuelTheme.body(12, color: DuelTheme.textFaint, ls: 4)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Choice extends StatefulWidget {
  final DuelCard card;
  final VoidCallback onTap;

  const _Choice({required this.card, required this.onTap});

  @override
  State<_Choice> createState() => _ChoiceState();
}

class _ChoiceState extends State<_Choice> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0.0, _hover ? -10.0 : 0.0, 0.0)
          ..multiply(Matrix4.diagonal3Values(
              _hover ? 1.08 : 1.0, _hover ? 1.08 : 1.0, 1.0)),
        child: CardFace(card: widget.card, width: 100, onHover: (h) => setState(() => _hover = h)),
      ),
    );
  }
}

class HandoffOverlay extends StatelessWidget {
  final DuelState state;

  const HandoffOverlay({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final side = state.handoffSide;
    if (side == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => state.confirmHandoff(),
      child: Container(
        color: const Color(0xFB0A0D2B),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FloatingAnkh(),
              const SizedBox(height: 16),
              Text('${state.nameOf(side)} 的回合',
                  style: DuelTheme.body(40, color: DuelTheme.goldHi, w: FontWeight.w900, ls: 8)
                      .copyWith(shadows: [
                    Shadow(color: DuelTheme.gold.withValues(alpha: .7), blurRadius: 30),
                  ])),
              const SizedBox(height: 18),
              _Blink(text: '请将设备交给对方 · 点击继续'),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingAnkh extends StatefulWidget {
  @override
  State<_FloatingAnkh> createState() => _FloatingAnkhState();
}

class _FloatingAnkhState extends State<_FloatingAnkh> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, -12 * _c.value),
        child: Text('☥',
            style: TextStyle(
                fontSize: 50,
                color: DuelTheme.goldHi,
                shadows: [Shadow(color: DuelTheme.gold.withValues(alpha: .9), blurRadius: 28)])),
      ),
    );
  }
}

class _Blink extends StatefulWidget {
  final String text;
  const _Blink({required this.text});

  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Opacity(
        opacity: .4 + .6 * _c.value,
        child: Text(widget.text, style: DuelTheme.tech(12, color: DuelTheme.textDim, ls: 5)),
      ),
    );
  }
}

class PreviewPanel extends StatelessWidget {
  final DuelState state;

  const PreviewPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final card = state.previewCard;
    return IgnorePointer(
      ignoring: card == null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: card == null ? 0 : 1,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 250),
          offset: card == null ? const Offset(-0.06, 0) : Offset.zero,
          child: Align(
            alignment: const Alignment(-0.96, -0.1),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xF50F122A), Color(0xF5070918)]),
                border: Border.all(color: DuelTheme.gold.withValues(alpha: .4)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .7), blurRadius: 40)],
              ),
              child: card == null
                  ? const SizedBox(width: 330, height: 250)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CardFace(card: card, width: 150),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 165,
                          height: 150 * DuelTheme.cardRatio,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card.name,
                                  style: DuelTheme.body(18, color: DuelTheme.goldHi, w: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(card.enName,
                                  style: DuelTheme.tech(9, color: DuelTheme.cyan, ls: 2.5)),
                              const SizedBox(height: 10),
                              if (card.isMonster) ...[
                                _row('属性 ATTR', card.attr),
                                _row('等级 LEVEL', '${card.level}'),
                                _row('攻击 ATK', '${card.atk}'),
                                _row('守备 DEF', '${card.def}'),
                              ] else
                                _row('种类 TYPE', card.type == CardType.spell ? '魔法' : '陷阱'),
                              const Spacer(),
                              Text(card.flavor,
                                  style: DuelTheme.body(11,
                                      color: DuelTheme.textDim, w: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: DuelTheme.body(11, color: const Color(0xFF9AA6D8), ls: 1.5)),
            Text(v, style: DuelTheme.tech(12, color: const Color(0xFFE8ECFF))),
          ],
        ),
      );
}
