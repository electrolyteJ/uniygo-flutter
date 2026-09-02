import 'package:duel_room1/layout/duel_room_layout.dart';
import 'package:flutter/material.dart';

import 'overlay_panel.dart';

class InteractionIsolation extends StatelessWidget {
  const InteractionIsolation({
    super.key,
    required this.active,
    required this.child,
    this.excludeSemantics = false,
  });

  final bool active;
  final bool excludeSemantics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      excluding: !active && excludeSemantics,
      child: ExcludeFocus(
        excluding: !active,
        child: IgnorePointer(ignoring: !active, child: child),
      ),
    );
  }
}

class StageSelectionPanelHost extends StatelessWidget {
  const StageSelectionPanelHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spec = DuelRoomLayout.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(spec.pagePadding),
        child: Center(
          child: ConstrainedBox(
            key: const ValueKey('stage-selection-panel-constraints'),
            constraints: BoxConstraints(
              maxWidth: spec.dialogMaxSize.width.clamp(0, 520),
              maxHeight: spec.dialogMaxSize.height,
            ),
            child: OverlayPanel(child: SingleChildScrollView(child: child)),
          ),
        ),
      ),
    );
  }
}
