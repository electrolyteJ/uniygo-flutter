# Playmat Interactions Design

Date: 2026-08-02
Scope: `apps/uniygopro/lib/widgets/playmat`

## Goal

Bring the `playmat` UI up to the interaction model expected for in-duel play:

- Clicking a hand card keeps the left card inspector open and also shows a contextual action menu near the top-right of the battlefield.
- Double-clicking a hand card performs a safe default action when the server has exposed one for that card.
- Clicking extra deck or graveyard entry points opens a shared zone browser modal for both players.
- Clicking `MAIN 1`, `BATTLE`, `MAIN 2`, and `END` in `PhaseBar` advances phase only when the local player currently owns the response window; otherwise the bar is display-only and follows server state.

The design must preserve protocol correctness: UI may request an action, but duel state only changes after server messages are received.

## Current Context

Current `playmat` behavior already provides:

- Left-side card inspector via `CardDetailDrawer`
- Hand card single-tap inspection via `HandCardsBar`
- Extra/grave/removed count taps on `PlayerStatusCard`
- Protocol-backed idle/battle action data in `DuelRoomState.selectedIdleActions`, `selectedBattleActions`, `enableBp`, `enableM2`, and `enableEp`
- A display-only `PhaseBar`

Current gaps:

- No contextual menu on hand-card selection
- No double-click behavior for hand cards
- Extra deck taps inspect a zone through the left drawer instead of opening a browseable list
- Graveyard is not browseable in a dedicated modal
- `PhaseBar` does not send any protocol responses

## User-Visible Design

### 1. Hand card click and double-click

Single click on a self hand card does all of the following:

- Marks the card as selected in the hand rail
- Updates the left card inspector with that card
- Opens a contextual action stack anchored in the battlefield top-right area

The contextual stack only shows actions that are valid for the selected card in the current response window:

- Monster cards: prefer labels like `召唤`, `盖放`, `特殊召唤`, `改变表示形式`
- Spell/trap cards: prefer labels like `发动`, `盖放`
- Generic fallback: use the protocol-derived action label if no simplified label exists

Double click on a self hand card attempts a default action:

- Monster priority: `召唤`, then `特殊召唤`, then `盖放`
- Spell/trap priority: `发动`, then `盖放`
- If no valid default action exists, fall back to the same result as single click

The default action is chosen only from current server-provided actions for that specific card. No client-only assumptions are allowed.

### 2. Shared zone browser modal

A shared modal component will handle browsing zone contents for:

- `self_extra`
- `opp_extra`
- `self_grave`
- `opp_grave`

The modal presents:

- A title describing the zone, for example `己方额外`, `对手墓地`
- A scrollable card list or grid optimized for rapid inspection
- Card artwork and card name for each entry
- Selection state for the currently inspected card

Clicking a card inside the modal:

- Updates the left card inspector
- Keeps the modal open so the user can continue browsing

The zone browser is intentionally read-only for this pass. It does not trigger summon, activation, or graveyard effects directly.

### 3. Phase bar behavior

`PhaseBar` remains the visible stage tracker, but `MAIN 1`, `BATTLE`, `MAIN 2`, and `END` become interactive only when the local client is the one allowed to respond.

Rules:

- If the current response window belongs to the local player, phase buttons that are protocol-valid become clickable.
- If the current response window belongs to the opponent, all phase transition buttons are non-interactive.
- Active phase highlighting still comes from `duel.phase`, which is updated by server `s2c` messages.

Expected transitions:

- From idle/main response window: `BATTLE` and `END` may be enabled based on `enableBp` and `enableEp`
- From battle response window: `MAIN 2` and `END` may be enabled based on `enableM2` and `enableEp`
- `MAIN 1` is display-only in practice because there is no forward transition into it from current protocol windows

Client clicks do not mutate `duel.phase` directly. They only send the correct `c2s` response and wait for the resulting `MSG_NEW_PHASE` or `MSG_NEW_TURN`.

## Interaction Model

### Action menu source of truth

The top-right action menu is derived from existing protocol-backed state:

- `selectedIdleActions`
- `selectedBattleActions`
- `currentSelect`

Filtering rules:

- Only actions that match the currently selected hand card code are shown
- Only actions from the active selection type are shown
- If there is no matching action, the menu is hidden

This keeps the new `playmat` UI aligned with existing duel-room behavior without duplicating server-side game rules.

### Phase transition source of truth

Phase clicks are mapped to existing response messages, not to local enums:

- Idle/main window uses `respondIdleCmd(...)`
- Battle window uses `respondBattleCmd(...)`

The mapping layer is UI-owned and explicit:

- `BATTLE` uses the idle response code for enter-battle
- `END` uses the idle or battle response code for end-phase depending on current window
- `MAIN 2` uses the battle response code for exit-to-main2

Because these values are protocol conventions rather than semantic phase IDs, the mapping must stay isolated in one place with narrow tests.

## Components and Responsibilities

### `Playmat`

Owns new top-level UI state:

- Currently selected hand card for contextual actions
- Whether the action menu is visible
- Which zone browser modal is open, if any
- Which zone card is currently selected inside the modal

Coordinates:

- Left inspector updates
- Hand click/double-click actions
- Zone browser open/close
- Phase action dispatch

### `HandCardsBar`

Adds:

- Distinct single-click callback
- Distinct double-click callback

It remains presentation-focused and does not contain duel logic.

### `PhaseBar`

Adds:

- Click callback per visible phase button
- Enabled/disabled visual state separate from active-phase visual state

`PhaseBar` does not know protocol response codes. It only renders the states it is given and emits phase taps upward.

### New `zone_browser_modal.dart`

New shared modal for browseable zones.

Inputs:

- Title
- List of card codes
- Currently selected code
- Card select callback
- Close callback

### New playmat action menu widget

New small widget dedicated to the top-right contextual action stack.

Responsibilities:

- Render action buttons with the cyber visual style already used in `playmat`
- Show simplified labels for supported hand-card actions
- Emit selected protocol-backed action upward

## Data Flow

### Hand single click

1. User clicks a self hand card.
2. `HandCardsBar` emits the card code.
3. `Playmat` updates inspector state.
4. `Playmat` filters current protocol actions for that card.
5. Matching actions render in the top-right action menu.

### Hand double click

1. User double-clicks a self hand card.
2. `Playmat` computes the default action from current protocol actions for that card.
3. If one exists, `Playmat` calls `respondIdleCmd` or `respondBattleCmd`.
4. UI waits for server updates before reflecting any duel-state change.

### Zone browser open

1. User taps self/opponent extra or grave entry point.
2. `Playmat` resolves the zone key into a title and card-code list.
3. Shared zone browser modal opens.
4. User selects a card in the modal.
5. Left inspector updates while the modal stays open.

### Phase click

1. User taps a clickable phase button.
2. `Playmat` verifies current response ownership and phase-button enablement.
3. `Playmat` sends the mapped `c2s` response.
4. Server sends `s2c` phase or turn update.
5. `DuelRoomState` updates `phase`, selection flags, and logs.
6. `PhaseBar` rerenders from store state.

## Error Handling and Guards

- If no valid action exists for a selected card, the action menu stays hidden.
- If a double-click has no valid default action, treat it as a single-click inspection.
- If a phase button is tapped while disabled, ignore the tap.
- If a browsed zone is empty, show an explicit empty-state message in the modal.
- If a card code is missing metadata, render fallback text such as `Card #12345`.

## Testing Strategy

Tests should be added before implementation changes where practical.

### Widget tests

- Hand single-click opens inspector and contextual menu for matching actions
- Hand double-click dispatches the preferred default action
- Extra deck tap opens the shared zone browser modal with expected cards
- Graveyard tap opens the shared zone browser modal with expected cards
- Clicking a zone-browser card updates the inspector and keeps the modal open
- Phase buttons are enabled only for the local response owner and only when the protocol flags allow the transition

### Logic/unit tests

- Idle-action label mapping for monster and spell/trap cards
- Default-action prioritization for hand double-click
- Phase-button-to-response-code mapping
- Zone-key-to-title-and-card-list resolution

## Non-Goals

- No direct zone-browser actions beyond inspection in this pass
- No browsing for removed zone in this pass
- No local optimistic phase changes
- No protocol changes

## Implementation Notes

- Reuse existing `DuelRoomState` response methods instead of creating new duel APIs.
- Prefer one explicit helper for phase response mapping so protocol assumptions stay easy to audit.
- Keep new interaction state inside `Playmat` unless it clearly belongs in shared store state.
- Preserve the existing left inspector as the single detailed card-information surface.
