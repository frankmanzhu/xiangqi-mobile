# Xiangqi Mobile — UX and visual specification

Status: implementation-ready MVP UX specification  
Reference product: [XiangqiAI](https://xiangqiai.com)  
Primary viewport: portrait iPhone, 390 × 844 points reference frame

## 1. Experience direction

The app should feel like a beautifully made physical game interpreted through native iOS controls. The board is always the hero. Engine capability is present but quiet: the player sees “thinking” and “hint,” not a wall of diagnostics.

XiangqiAI provides useful interaction guidance:

- The board receives the most prominent, stable area.
- Playing Red, playing Black, and analysis are explicit modes.
- Flip and move navigation are always easy to find.
- The move record, notes, engine output, and external database results are separate concepts.
- Advanced controls such as “move now,” excluding a line, import, edit, and sharing belong outside the basic play path.

The mobile app adapts these lessons rather than reproducing XiangqiAI's desktop workspace. In MVP, Play Red/Black moves into New Game setup; engine output and advanced analysis controls are deferred.

### Reference boundary

Borrow concepts, not expression.

May inform this app:

- Board-first hierarchy.
- Explicit choice of which side the engine plays.
- One-tap board flip.
- Previous/next move navigation.
- Separation between the move record and engine analysis.

Must be original to this app:

- Board and piece artwork, materials, colors, typography, icon treatment, and animation.
- Mobile layout, information hierarchy, control placement, sheets, and navigation.
- App name, icon, wording, sound, haptics, and brand voice.
- Theme system and every shipped theme asset.

Do not copy or scrape XiangqiAI assets, CSS, textures, icons, wording, or exact panel composition. Before release, review the game screen side-by-side with the reference: it should share recognizable xiangqi workflows while remaining visually and compositionally distinct.

## 2. Information architecture

```text
Home
├── Continue game (conditional)
├── Play computer
│   └── New game setup
│       └── Game
│           ├── Hint states
│           ├── Move history sheet
│           ├── Game menu
│           └── Result sheet
└── Settings
    ├── Appearance and theme
    ├── Board and notation
    ├── Sound and haptics
    ├── Rules and help
    └── About and licenses
```

Do not use a persistent tab bar in MVP. The product has one primary activity, and a tab bar would consume board space without improving navigation.

## 3. Navigation model

- Home → setup uses a standard push transition.
- Setup → game uses a short scale/fade that settles the board without moving pieces.
- Game → move history and game menu use bottom sheets.
- Game → result uses a non-dismissible-at-first result sheet; after presentation finishes, swipe-to-dismiss may return to the completed board.
- Leaving an active game returns Home, pauses a timed game, and keeps Continue game.
- Starting a new game while one is active requires a confirmation sheet that explains the current game will be replaced. This is the only destructive game action in normal navigation.

## 4. Screen specifications

### 4.1 Home

Purpose: resume immediately or start a game with minimal cognitive load.

Layout, top to bottom:

1. Compact wordmark/app name and Settings button.
2. Continue game panel when an active game exists:
   - Mini board snapshot or last-move motif.
   - “Your turn” or “Computer to move.” Search is stopped while Home is visible.
   - Opponent level, player side, and elapsed/remaining time.
   - Primary action: Continue.
3. Primary action: Play computer.
4. Theme preview strip with three selectable swatches; this is a shortcut to Appearance.

Empty-state copy should be brief. Avoid news, daily challenges, streaks, accounts, and promotional carousels in MVP.
Do not show disabled or “coming soon” controls for local or online play.

### 4.2 New game setup

Title: New game / 新對局.

Controls:

- Side segmented choice: Red, Black, Random.
- Strength five-position picker with label and one-sentence description.
- Time segmented choice: Casual, 10 min, 15 min.
- Theme preview row: Classic, Tournament, Calm.
- Primary button: Start game.

Changing strength updates descriptive copy, not raw engine metrics. Side selection includes “Red moves first.” If Black is selected, the primary button remains “Start game,” not “Let computer move.”

### 4.3 Game screen

The game screen has four vertical regions:

1. **Game header, 48–56 pt**
   - Back/close.
   - Opponent label and compact turn status.
   - Overflow menu.
2. **Opponent rail, 44–56 pt**
   - Side marker, “Pikafish · Level 2,” clock if enabled.
   - Thinking activity appears here without changing row height.
3. **Board, largest stable square-like region**
   - Correct 9-file × 10-rank intersection geometry.
   - Maintains aspect ratio; never stretches.
   - On shorter screens, controls condense before the board shrinks below the minimum playable size.
4. **Player rail and action dock**
   - Player side and clock.
   - Undo, Hint, Flip, Moves.

The board should not jump when a thinking indicator, check warning, hint, or clock digit appears. Reserve layout space for those states.

#### Game header states

- Human turn: “Your move.”
- Computer turn: “Pikafish is thinking…” with subtle indeterminate activity.
- Check: “Check” plus a distinct symbol and haptic; do not rely only on red.
- Paused/restored: “Game restored.” displayed as a temporary announcement, not a persistent banner.
- Terminal: outcome replaces turn text.

#### Action dock

| Action | Availability | Behavior |
| --- | --- | --- |
| Undo | Casual game, after at least one human move | Cancels search and returns to before the latest human move |
| Hint | Human turn, active game | Starts/reveals staged hint |
| Flip | Always | Rotates presentation only |
| Moves | After first move | Opens move history sheet |

When space is constrained, keep Hint labeled and allow the other actions to use icon plus VoiceOver label. No critical action may become gesture-only.

### 4.4 Move history sheet

Detents: medium and large.

Contents:

- Header with move count and Close.
- Two-column paired moves, Red then Black.
- Current ply highlighted by shape and weight, not color alone.
- Tap a past move to enter replay preview.
- Previous/next controls remain visible near the sheet bottom.
- “Return to live position” exits preview.

In MVP replay preview is read-only. It must never change the committed game or launch the computer.

### 4.5 Game menu

Actions:

- Resume.
- Rules and controls.
- Sound and haptics toggles.
- Resign (destructive styling and confirmation).
- Leave game (saves and returns Home).
- New game (replaces the active game after confirmation).

### 4.6 Result sheet

Order:

1. Result and cause: “You won — checkmate,” “Pikafish won — resignation,” or draw reason.
2. Compact summary: side, strength, moves, duration, hints.
3. Primary action: Rematch.
4. Secondary: Review moves.
5. Tertiary: Home.

Avoid confetti by default. A restrained piece-settle animation and success haptic are sufficient. Respect Reduce Motion.

### 4.7 Settings

Use native grouped settings with previews where useful. Changing theme while a game is open should crossfade visual assets without reconstructing the board or losing selection. If a theme asset is unavailable, fall back to Classic and preserve the preference for a future retry.

## 5. Board interaction specification

### 5.1 Coordinate model

- Files are `a` through `i` and ranks are `0` through `9` according to Pikafish's UCI conversion. Checked-in start-position fixtures define the screen mapping; do not infer it from localized Chinese notation.
- Ranks are `0` through `9`.
- The view maps model coordinates to screen coordinates according to orientation; the model never rotates.
- Hit testing is centered on the 90 intersections, not visual piece bounds alone.
- The hit target for an intersection may overlap its visual cell but must resolve to the nearest intersection deterministically.

### 5.2 Tap interaction

1. Tap a movable friendly piece: select it, announce it, show legal destinations.
2. Tap another movable friendly piece: transfer selection.
3. Tap a legal destination: commit or enter confirmation state, depending on setting.
4. Tap an illegal destination: keep selection, play a soft rejection haptic, and do not show an error toast.
5. Tap selected piece or non-actionable empty area: clear selection.

When move confirmation is enabled, step 3 enters a fixed-height pending state that shows the proposed move and Confirm/Cancel buttons. Confirm commits the move; Cancel restores the prior selection. The clock continues to run while confirmation is pending.

### 5.3 Drag interaction

- A 150 ms hold or movement beyond the system slop begins drag.
- The original piece remains visible at reduced emphasis; a lifted piece follows the finger.
- Legal intersections enlarge subtly as the finger approaches.
- Release on legal destination commits; elsewhere springs the piece back.
- Drag is an enhancement. Every action must work by tap and VoiceOver.

### 5.4 Visual states

Every theme must define tokens for:

- Selected source: ring plus slight scale/elevation.
- Legal quiet move: small filled dot with contrast outline.
- Legal capture: open ring around destination piece.
- Last move: source and destination corner marks or soft tiles.
- Hint source: lightbulb badge/ring and one gentle pulse.
- Hint destination: arrow plus destination ring.
- Check: general ring plus check icon/message.
- Move preview: translucent source/destination treatment distinct from live position.

Animations:

- Normal move: 160–220 ms ease-out.
- Capture: destination piece fades/scales before mover settles; total ≤260 ms.
- Computer move: same motion as human move after a 100 ms state-settle pause.
- Board flip: 250 ms crossfade/rotation illusion; piece labels remain upright. Under Reduce Motion, crossfade only.
- Never delay state commitment until animation completion.

### 5.5 Haptics and sound

- Selection: light impact.
- Move: selection/change feedback.
- Capture: medium impact.
- Check: warning notification.
- Game win/loss/draw: success/error/warning respectively, used sparingly.
- Illegal release: soft rigid impact.

Sound mirrors these events and can be disabled independently. Haptics and sound are presentation side effects; they never drive logic.

## 6. Hint UX states

```text
available → searching → source revealed → destination revealed
     ↑           │              │                 │
     └────────── invalidated by any committed position change ──┘
```

- Available: standard Hint button.
- Searching: button retains width, shows progress, label “Finding hint.”
- Source revealed: highlight source; button label “Show square.”
- Destination revealed: arrow and destination ring; button label “Hint shown.”
- Error: return to available and show “Hint unavailable. Try again.” in an accessible transient message.

VoiceOver announcements:

- “Hint: consider the red horse on file two, rank zero.”
- “Suggested move: horse from b0 to c2.”

Localized notation may be presented visually, but the accessibility description must be unambiguous and coordinate-based.

## 7. Theme system

### 7.1 Theme contract

A theme provides only presentation values:

```text
BoardTheme
├── board background/material
├── line, river, palace, coordinate styles
├── red/black piece assets and label style
├── selection, legal move, last move, hint, check tokens
├── surrounding surfaces and accent colors
├── typography accents
├── move/capture sounds
└── motion intensity within global accessibility limits
```

A theme cannot provide game rules, legal-move logic, view-model behavior, action visibility, accessibility wording, persistence rules, or engine configuration.

### 7.2 Theme A — Classic (default)

- Warm ivory and restrained wood grain.
- Charcoal black pieces, cinnabar red pieces.
- Contemporary Chinese editorial tone; avoid decorative dragons or imitation-antique clutter.
- Signature detail: fine paper fibers and offset seal-red state marks, not the reference site's lacquered board treatment.
- Best for general play.

Concept reference: [Classic theme](assets/theme-classic-concept.png).

### 7.3 Theme B — Tournament

- Deep graphite surfaces and a low-glare neutral board.
- Controlled coral/red and cool secondary accent.
- Signature detail: hairline grid, high-contrast outlined pieces, and restrained telemetry styling.
- Best for focused, high-contrast play and later analysis.

Concept reference: [Tournament theme](assets/theme-tournament-concept.png).

### 7.4 Theme C — Calm

- Warm white, pale stone board, jade secondary accent, coral red pieces.
- More generous coaching copy and softer motion.
- Signature detail: matte ceramic pieces, open spacing, and jade hint markers.
- Best for hints, lessons, and future puzzles.

Concept reference: [Calm theme](assets/theme-calm-concept.png).

### 7.5 Theme QA matrix

Every theme must pass:

- Standard, selected, legal move, capture, last move, hint, check, disabled, and terminal states.
- Red/Black and flipped orientations.
- Light/Dark system appearance where supported; a self-contained theme may declare one appearance but must keep system sheets legible.
- Increased Contrast, Reduce Transparency, Reduce Motion, and grayscale checks.
- Smallest and largest supported iPhone screenshots.
- VoiceOver focus and hit targets identical to Classic.
- Originality review confirming no shipped image, texture, icon, sound, or layout was copied from a reference product.

## 8. Visual tokens

Use semantic tokens. Suggested starting values are guidance, not a replacement for device review.

### Spacing

- `space.1`: 4 pt
- `space.2`: 8 pt
- `space.3`: 12 pt
- `space.4`: 16 pt
- `space.5`: 24 pt
- `space.6`: 32 pt

### Shape

- Control corner radius: 12–14 pt.
- Sheet/card radius: 20–24 pt.
- Piece shape: circular; no theme may alter its hit area.
- Use borders and shadows sparingly; group primarily with spacing and surface tone.

### Typography

- App chrome: system sans-serif.
- Piece glyphs may use one curated CJK display face with verified glyph coverage and licensing.
- Body text: 15–17 pt default.
- Button text: 16–17 pt semibold.
- Status: 13–15 pt medium.
- Clocks/evaluation: tabular numerals.
- No UI view should use more than two font families.

### Touch targets

- Non-board controls: minimum 44 × 44 pt.
- Board intersections: use the maximum non-ambiguous target supported by board geometry.
- On small screens, do not shrink toolbar targets; reduce labels or move secondary actions into sheets.

## 9. Accessibility

### VoiceOver board model

The visual board lines may use `Canvas`, but each occupied square and relevant empty legal destination must have a separate accessibility element.

Piece label structure:

`{side} {piece}, {coordinate}, {state}`

Examples:

- “Red cannon, b2, selectable.”
- “Empty c2, legal destination for red horse.”
- “Black general, e9, in check.”

Custom actions on a selected piece:

- List legal destinations.
- Move to each legal destination, grouped if too numerous.
- Cancel selection.

Additional requirements:

- Announce turn changes, checks, captures, hint results, and game result.
- Do not announce continuously updating engine depth.
- Provide a non-drag path for all moves.
- Dynamic Type applies to all chrome and sheets. The board preserves geometry; at accessibility sizes, supporting controls may flow into a sheet.
- Selected, legal, last-move, hint, and check states use shape/symbol plus color.
- Respect Reduce Motion and Reduce Transparency.
- Support Switch Control focus order: header → opponent → board in reading order → player → actions.

## 10. Localization and notation

Launch localizations:

- Traditional Chinese.
- Simplified Chinese.
- English.

Requirements:

- Do not encode piece identity from the displayed glyph; identity is a model enum.
- Piece glyph mapping is locale/theme data.
- UCI coordinate notation is always available for diagnostics and accessibility.
- Human-readable Chinese notation should be produced by a tested notation formatter, not stored as primary move data.
- Layout must tolerate English labels 30% longer than source Chinese labels.
- Use locale-aware digits in ordinary UI, but keep FEN and UCI import/export ASCII.

## 11. Empty, loading, and error states

- Engine startup: setup remains visible; Start game changes to “Preparing opponent” and is disabled until the bundled engine and NNUE are ready. No playable board is created before readiness succeeds.
- Computer search longer than expected: keep the reserved thinking state and change its label to “Still thinking…”. There is no “Move now” action in 1.0.
- Engine initialization failure: explain that the bundled engine could not start, offer Retry, and keep diagnostics copyable. Never begin a game without a functioning opponent.
- Save failure: keep the game in memory, show persistent “Game not saved,” retry on the next state change, and make Leave game confirm that unsaved progress may be lost. The app cannot prevent force-quit or termination.
- Invalid restored game: preserve record and provide recovery/export path as specified in the product document.

## 12. Concept-image disclaimer

The three images under `docs/assets/` establish mood, density, and hierarchy only. They contain generated details that may be invalid, including piece arrangements, board labeling, text, and dimensions. Implementation must follow the model-driven 9 × 10 intersection board, the token system, and the interaction requirements in this document.
