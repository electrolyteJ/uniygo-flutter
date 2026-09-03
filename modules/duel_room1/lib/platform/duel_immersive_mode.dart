import 'package:duel_room1/platform/platform_adaptive.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

typedef DuelSystemUiModeSetter = Future<void> Function(SystemUiMode mode);

class DuelSystemUiController {
  DuelSystemUiController({DuelSystemUiModeSetter? setter})
    : _setter = setter ?? SystemChrome.setEnabledSystemUIMode;

  final DuelSystemUiModeSetter _setter;
  Future<void> _pending = Future<void>.value();
  int _activePages = 0;
  SystemUiMode? _appliedMode;

  void enter() {
    _activePages++;
    _enqueueDesiredState();
  }

  void exit() {
    if (_activePages == 0) return;
    _activePages--;
    if (_activePages == 0) _enqueueDesiredState();
  }

  void _enqueueDesiredState() {
    _pending = _pending
        .then((_) async {
          final desired = _activePages > 0
              ? SystemUiMode.immersiveSticky
              : SystemUiMode.edgeToEdge;
          if (_appliedMode == desired) return;
          await _setter(desired);
          _appliedMode = desired;
        })
        .catchError((Object _) {});
  }
}

final DuelSystemUiController duelSystemUiController = DuelSystemUiController();

class DuelImmersiveMode extends StatefulWidget {
  const DuelImmersiveMode({
    super.key,
    required this.child,
    this.platform,
    this.controller,
  });

  final Widget child;
  final DuelPlatform? platform;
  final DuelSystemUiController? controller;

  @override
  State<DuelImmersiveMode> createState() => _DuelImmersiveModeState();
}

class _DuelImmersiveModeState extends State<DuelImmersiveMode> {
  DuelSystemUiController? _leaseController;

  bool _isMobile(DuelPlatform platform) =>
      platform == DuelPlatform.android || platform == DuelPlatform.ios;

  DuelPlatform get _platform =>
      widget.platform ?? PlatformAdaptive.of(context).platform;

  DuelSystemUiController get _controller =>
      widget.controller ?? duelSystemUiController;

  @override
  void initState() {
    super.initState();
    _syncLease();
  }

  @override
  void didUpdateWidget(covariant DuelImmersiveMode oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLease();
  }

  void _syncLease() {
    final next = _isMobile(_platform) ? _controller : null;
    if (identical(next, _leaseController)) return;
    _leaseController?.exit();
    _leaseController = next;
    next?.enter();
  }

  @override
  void dispose() {
    _leaseController?.exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
