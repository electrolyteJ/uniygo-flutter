# Playmat Review Handoff

Date: 2026-08-06
Scope: `apps/uniygopro/lib/widgets/playmat`, `apps/uniygopro/lib/pages/duel_room/field`

## Review Goal

This handoff is for agent/code review of the immersive duel playmat pass.

Review should focus on:

- UI structure consistency between `prototype` and `flame`
- protocol-correct interaction behavior
- action-source correctness for hand, field, grave, removed, and extra
- overlay positioning and anchor behavior

## Design Sources

Primary design/spec docs:

- `docs/superpowers/specs/2026-08-06-playmat-immersive-design.md`
- `docs/superpowers/specs/2026-08-02-playmat-interactions-design.md`
- `docs/superpowers/plans/2026-08-06-playmat-immersive.md`

Approved static UI prototype:

- `docs/duel_ui_prototype.html`

## UI Entry Points

Runtime page entry:

- `apps/uniygopro/lib/pages/duel_room/field/duel_field_page.dart`

Top-level playmat coordinator:

- `apps/uniygopro/lib/widgets/playmat/playmat.dart`

Field renderers:

- `apps/uniygopro/lib/widgets/playmat/prototype_playmat_field.dart`
- `apps/uniygopro/lib/widgets/playmat/flame_playmat_field.dart`
- `apps/uniygopro/lib/widgets/playmat/flame/duel_flame_game.dart`

## Current UI Contract

- The playmat fills the page and stays visually dominant.
- The left card inspector is large and vertically centered.
- The opponent HUD is top-left.
- The self HUD is bottom-left.
- The duel log is top-right.
- The opponent hand fan is top-center and non-interactive.
- The self hand rail is bottom-center and is the main action entry.
- Only the current phase is shown; it appears as an in-field phase lamp on the self side.
- Hand action menus are anchored above the selected self-hand card.
- Field action menus are anchored near the selected actionable field card.
- Graveyard, removed, and extra deck open a shared zone browser and may expose direct actions for legal cards.

## Key Implementation Files

Interaction and local UI orchestration:

- `apps/uniygopro/lib/widgets/playmat/playmat.dart`
- `apps/uniygopro/lib/widgets/playmat/playmat_action_resolver.dart`

Protocol-backed selection state:

- `apps/uniygopro/lib/pages/duel_room/field/duel_selection_store.dart`
- `apps/uniygopro/lib/pages/duel_room/field/duel_board_store.dart`

Overlay and browse UI:

- `apps/uniygopro/lib/widgets/playmat/card_detail_drawer.dart`
- `apps/uniygopro/lib/widgets/playmat/zone_browser_modal.dart`
- `apps/uniygopro/lib/widgets/playmat/hand_action_popover.dart`
- `apps/uniygopro/lib/widgets/playmat/field_action_popover.dart`
- `apps/uniygopro/lib/widgets/playmat/phase_action_menu.dart`
- `apps/uniygopro/lib/widgets/playmat/phase_lamp.dart`

Shared renderer contract:

- `apps/uniygopro/lib/widgets/playmat/playmat_render_mode.dart`
- `apps/uniygopro/lib/widgets/playmat/playmat_field_view_data.dart`
- `apps/uniygopro/lib/widgets/playmat/playmat_anchor_data.dart`

HUD and supporting widgets:

- `apps/uniygopro/lib/widgets/playmat/phase_bar.dart`
- `apps/uniygopro/lib/widgets/playmat/player_status_card.dart`
- `apps/uniygopro/lib/widgets/playmat/hand_cards_bar.dart`
- `apps/uniygopro/lib/widgets/playmat/opponent_hand_fan.dart`
- `apps/uniygopro/lib/widgets/playmat/duel_log_drawer.dart`
- `apps/uniygopro/lib/widgets/playmat/chain_stack_overlay.dart`

## Behavior To Review

### Hand

- Single click updates inspector and opens contextual actions.
- Double click executes a safe default action when one exists.
- Action labels come from protocol-backed legality, not client-side guessing.

### Field

- Clicking a field card updates inspector.
- Actionable field cards show local contextual actions near that card.

### Grave / Removed / Extra

- Clicking zone entry opens the browser.
- Clicking a card updates inspector.
- If the selected card is currently legal, direct actions are shown and dispatched from the browser.

### Phase

- Only the current phase lamp is shown.
- Clicking the lamp opens only currently legal phase actions.
- No optimistic local phase mutation is allowed.

### Render Mode Parity

- `prototype` and `flame` should expose the same visible slot topology and interaction semantics.
- Overlay anchors should stay usable after switching render modes.

## Not In Scope For This Pass

- unit tests
- commit/merge preparation
- broader repository lint cleanup outside touched playmat flow
- a separate UI state machine refactor

## Validation Status

Targeted analyzer pass for touched playmat/field files has been run and passed.

Broader `flutter analyze` on larger app/package ranges still reports pre-existing warnings and infos outside the core playmat delivery scope.
