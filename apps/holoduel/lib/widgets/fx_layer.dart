import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../fx/fx_engine.dart';

class FxLayer extends StatefulWidget {
  final FxEngine engine;

  const FxLayer({super.key, required this.engine});

  @override
  State<FxLayer> createState() => _FxLayerState();
}

class _FxLayerState extends State<FxLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.engine.addListener(_onEngine);
  }

  void _onEngine() {
    if (widget.engine.active && !_running) {
      _running = true;
      _ticker.start();
    }
  }

  void _onTick(Duration _) {
    widget.engine.tick();
    if (!widget.engine.active) {
      _running = false;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngine);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.engine,
      builder: (context, _) => IgnorePointer(
        child: CustomPaint(
          painter: _FxPainter(widget.engine),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _FxPainter extends CustomPainter {
  final FxEngine engine;

  _FxPainter(this.engine);

  @override
  void paint(Canvas canvas, Size size) {
    engine.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_FxPainter old) => true;
}
