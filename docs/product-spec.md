# Xiangqi Mobile — product specification

Status: implementation-ready MVP specification  
Owner: product and engineering  
Target: native iPhone app; iPad layout is compatible but not an MVP release gate  
Primary mode: Player vs Computer  
Engine: Pikafish, pinned from the user's fork

## 1. Product summary

Xiangqi Mobile is a fully offline iOS app for playing a strong, configurable computer opponent without needing to understand engine terminology. A player can start a game in a few taps, choose a side and strength, ask for a useful hint, leave at any time, and resume exactly where they stopped.

The product combines three qualities:

- **Trustworthy:** legal moves, end conditions, clocks, saves, and engine turns are correct and deterministic.
- **Approachable:** the default experience uses plain language and reveals engine detail only when requested.
- **Beautiful:** the board is the visual center, interactions feel tactile, and themes can alter presentation without altering behavior.

## 2. Goals and non-goals

### MVP goals

1. Deliver a complete Player vs Computer game from setup through result.
2. Make every legal board action comfortable with one hand on a small iPhone.
3. Use Pikafish locally, with no account or network connection required.
4. Provide hints that help a player decide, rather than automatically taking over.
5. Save and restore an unfinished game safely after app termination.
6. Support multiple visual themes through tokens and assets, not duplicated screens.
7. Meet a practical accessibility baseline for VoiceOver, Dynamic Type outside the fixed board, color contrast, reduced motion, and non-color state indicators.

### Not in MVP

- Online matchmaking, ratings, spectators, chat, clubs, or tournaments.
- User accounts, cloud sync, subscriptions, ads, or in-app purchases.
- Opening-book browser, puzzle catalog, lessons, or generated prose explanations.
- External engine installation or downloadable executable code.
- Editing arbitrary positions, importing game files, or full database analysis.
- A desktop-style engine console with raw UCI controls.
- Any production networking code, remote configuration, account schema, or placeholder control for a future mode.

### Immediately after MVP

- Local two-player (hot-seat) using the same board and rules session.
- Post-game analysis with a move-quality timeline.
- Position setup and FEN import/export.
- iPad-specific two-column analysis layout.

The data model and coordinator represent Red and Black independently with `localHuman` and `computer` controllers. MVP exposes exactly one human and one computer. Local two-player can reuse the model in 1.1. A remote controller is added later through an explicit schema migration; it is not present in the 1.0 code or persisted data.

## 3. Intended players

### Primary: improving casual player

Knows the rules and wants a good offline opponent. Values fast setup, understandable strength levels, a helpful hint, and a polished board more than engine statistics.

### Secondary: experienced player

Wants a stronger opponent, reliable clocks, move history, and board flipping. Will notice rule, notation, or latency errors immediately.

## 4. Product principles

1. **Board before chrome.** The board gets the largest stable area on the game screen.
2. **Play language before engine language.** Say “Computer is thinking” rather than “search depth 18.”
3. **One source of truth.** Themes and screens observe the same authoritative game session.
4. **Hints preserve agency.** A hint shows a recommendation; it does not move a piece until the player confirms a move.
5. **Offline, always.** New game, play, hints, save/resume, replay, settings, help, and results work in airplane mode without attempting a connection.
6. **Fast cancellation.** Leaving, undoing, suspending, or starting a new game stops the current engine search before state changes.
7. **No engine-console leakage.** Evaluation, principal variations, raw limits, and engine logs are not player UI in 1.0.

## 5. MVP scope

### 5.1 New game setup

Required choices:

- Side: Red, Black, or Random. Red moves first.
- Computer strength: five human-readable levels.
- Time: Casual (no clock), 10 minutes, or 15 minutes per side.
- Theme: uses the current global preference, with a preview and change link.

Defaults:

- Side: Red.
- Strength: Level 2, “Club learner.”
- Time: Casual.
- Theme: Classic.

Starting a game creates and persists the game record before the first engine search. If the player chooses Black, the computer begins only after the game screen is fully visible.

The canonical starting FEN is `rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1`, matching the pinned Pikafish `StartFEN`. From Red's unflipped perspective, `a0` is Red's left chariot and `i9` is Black's left chariot as seen by Black. Checked-in fixtures must assert all 32 starting pieces and both orientations.

### 5.2 Player vs Computer game

The player can:

- Tap a piece to select it and see legal destinations.
- Tap a legal destination to move.
- Drag a piece to a legal destination as an equivalent gesture.
- Tap the selected piece or empty board space to cancel selection.
- Ask for a hint when it is their turn and the game is active.
- Undo to the position before the player's most recent move in a casual game. If the computer reply is already committed, remove both plies; if the computer is still searching, cancel it and remove only the pending human ply.
- Timed games do not offer undo in 1.0.
- Flip the board without changing sides or game state.
- Open move history.
- Pause/leave, resign, or start a new game through an overflow menu.

The computer:

- Searches only when it is the computer's turn or during a requested hint. Read-only move replay never starts the engine.
- Shows a thinking state without blocking navigation.
- Applies only a legal move to the position version it searched.
- Never applies a stale result after undo, restore, new game, or app suspension.

### 5.3 Hint

The MVP hint is a staged interaction:

1. First tap: highlight one recommended source piece and show “Consider this piece.”
2. Second tap, or tapping the highlighted piece: show the recommended destination and arrow.
3. The player still performs or confirms the move.

Rules:

- Hint is available only on the human turn in an active game.
- In a timed game, the human clock continues while a hint is searching or displayed.
- The hint action shows a spinner if no result is ready after 150 ms.
- A repeated tap does not launch a duplicate search.
- Changing the position cancels and invalidates the hint.
- Hints do not expose centipawn scores in the default playing UI.
- The game record stores whether a hint was used for that ply, enabling later review.
- Casual MVP places no hard limit on hints. A future challenge mode may limit them.

### 5.4 Game completion

The app recognizes and presents at least:

- Checkmate.
- No legal move: the side to move loses; present “checkmate” when in check and “stalemate” otherwise.
- Resignation.
- Draw by supported repetition/adjudication rule.
- Time loss in timed games.

The result sheet shows outcome, reason, player color, difficulty, move count, elapsed time, hints used, and actions for Rematch, Review game (move-by-move without engine analysis), and Home. Rematch starts a new record with the same resolved human side, difficulty, time control, and current theme; clocks, moves, hints, result, and elapsed time reset.

### 5.5 Save and resume

- Maintain one active game in MVP.
- Persist atomically after every committed move and whenever the game screen pauses, resumes, enters the background, or becomes terminal. Do not write once per displayed clock tick.
- On launch, Home shows “Continue game” when a valid unfinished record exists.
- Restore board orientation, move list, clocks, hint usage, selected theme, and whose turn it is.
- Timed clocks run only while the game screen is visible and the scene is active. Leaving the game screen or making the scene inactive pauses both clocks; returning resumes the side-to-move clock from its persisted checkpoint.
- Do not persist an in-flight search result. Recreate the engine session from start FEN plus the committed move list and launch a new search if necessary.
- If recovery validation fails, keep the record, show a non-destructive recovery message, and offer export/copy of diagnostic FEN and moves before discarding it.

### 5.6 Settings

MVP settings:

- Theme: Classic, Tournament, Calm.
- Piece labels: Traditional Chinese by default; Simplified Chinese as a localization/display option.
- Coordinates: Off, Red perspective, or Always.
- Move confirmation: Off by default; when on, moving requires a Confirm action.
- Sound effects: On/off.
- Haptics: On/off.
- Rules and notation help.
- Open-source licenses and exact Pikafish source link/commit.

## 6. Strength model

The product exposes five stable labels and does not expose raw depth, node, thread, or hash controls in normal settings.

| Level | Label | Intended experience | Search policy target |
| --- | --- | --- | --- |
| 1 | Beginner | Makes understandable mistakes and responds quickly | Small node/time budget; select among safe MultiPV candidates within a wide evaluation-loss budget |
| 2 | Club learner | Forgiving but tactically credible | Moderate budget; narrower candidate loss budget |
| 3 | Club player | Consistent intermediate opponent | Larger budget; best completed line |
| 4 | Expert | Strong play with longer thought time | High budget; best line, capped for device comfort |
| 5 | Pikafish | Strongest practical on-device setting | Best line with adaptive time and thermal limits |

Implementation requirements:

- Difficulty is a versioned policy, not just a UI label.
- A lower level may choose a suboptimal move only from legal engine candidates.
- Candidate selection for Levels 1–2 is seeded and the policy version is recorded so the choice can be diagnosed. Restoring a game replays committed moves; it never tries to regenerate past engine choices.
- Never create obviously illegal, self-checking, or random non-engine moves.
- Device thermal and battery safeguards may reduce compute time but must not silently change the selected level's identity; the UI may say “Reduced analysis to keep your device cool.”

Exact budgets must be calibrated on physical devices before release and live in configuration, not hard-coded across views.

## 7. Rules policy

Xiangqi repetition and chasing rules vary by federation and platform. MVP must ship with one named, testable policy rather than an unspecified approximation.

Decision for implementation:

- Use **Pikafish Computer Rule**, identified in records as `pikafish-computer-rule@6a59ee2f7b105bff64d9efc2692591107787e2b1`.
- Display the policy name and a concise explanation under Settings → Rules.
- Keep the rules policy behind an interface so a future WXF/CCA policy can be added without changing board UI or persistence format.
- Store the policy identifier and version in each game record.
- Derive adjudication from Pikafish `Position::rule_judge` at the pinned revision and validate it against a checked-in snapshot of the [Pikafish Computer Rule](https://pikafish.org/rule.html). Updating Pikafish does not silently update saved games: a new engine revision requires a new policy version and migration decision.

Before release, engineering must convert the chosen policy into fixture-based tests covering perpetual check, perpetual chase, mixed sequences, threefold/repeated positions, checkmate, stalemate, and insufficient/unsupported draw claims. “Engine returned a move” is not sufficient adjudication testing.

## 8. Core user journeys

### 8.1 First game

1. Launch.
2. Home presents Play computer as the primary action.
3. Setup uses sensible defaults; player taps Start game.
4. Game screen explains tap or drag in one dismissible coach mark.
5. Player selects a piece, sees legal destinations, and moves.
6. Computer thinking indicator appears; move animates when ready.
7. Game continues to result.
8. Result sheet offers rematch or home.

### 8.2 Ask for a hint

1. On human turn, tap Hint.
2. If needed, engine performs a short cancellable search.
3. Source piece receives a pulse/ring and VoiceOver announcement.
4. Tap Hint again to reveal destination and arrow.
5. Player chooses that move or another legal move.

### 8.3 Resume after termination

1. App launches and validates the active record.
2. Home shows current side, opponent level, and last-move time.
3. Tap Continue game.
4. Board restores without animation from the initial position.
5. If it is the computer turn, a fresh search begins after restoration.

### 8.4 Undo in a casual game

1. Tap Undo.
2. If the computer is searching, cancel and await cancellation.
3. Revert to the position before the player's most recent move, removing its committed computer reply when one exists.
4. Truncate the active move array at that position and atomically persist it. Discarded plies are not retained in the production game record.
5. Clear hint and evaluation state.

## 9. Functional requirements

Identifiers are stable and should be referenced by tests and issues.

| ID | Requirement |
| --- | --- |
| GAME-001 | The app starts a standard xiangqi game with Red to move. |
| GAME-002 | Selection exposes only legal destinations for the selected piece. |
| GAME-003 | The app rejects moves that leave the moving side's general in check. |
| GAME-004 | The app detects terminal positions under the selected rules policy. |
| GAME-005 | Undo in Casual mode returns to before the latest human move, removes any committed reply, and cancels stale search. |
| GAME-006 | Board flip changes presentation only. |
| CLOCK-001 | Timed clocks run only while the game screen and app scene are active, and resume from a durable checkpoint. |
| CPU-001 | The computer returns and commits a legal move for the searched position version. |
| CPU-002 | Engine search is cancellable for undo, navigation, suspension, and new game. |
| CPU-003 | Five difficulty policies are configurable and versioned. |
| CPU-004 | The computer cannot move while it is the human turn. |
| HINT-001 | Hint never commits a move automatically. |
| HINT-002 | Hint is invalidated by any position change. |
| HINT-003 | Hint exposes source first, destination second. |
| SAVE-001 | A committed move is durable before the opponent starts thinking. |
| SAVE-002 | Restore reconstructs and validates the position from start FEN and moves. |
| SAVE-003 | Corrupt saves are preserved until the user chooses to discard them. |
| THEME-001 | Changing theme cannot recreate or mutate the game session. |
| THEME-002 | Every theme uses identical hit targets and accessibility semantics. |
| A11Y-001 | Every piece and legal destination is operable with VoiceOver. |
| A11Y-002 | No required state is conveyed by color alone. |
| PRIV-001 | MVP gameplay requires no account, network request, or personal data. |
| PRIV-002 | A fresh install completes all MVP journeys in airplane mode without downloading assets, configuration, an engine, or an NNUE. |
| LIC-001 | The app exposes Pikafish attribution, GPLv3 text, exact source revision, and corresponding source offer/link. |

## 10. Non-functional targets

Performance and thermal targets are measured on a physical iPhone XR in Release configuration. Small-screen layout and interaction targets are also tested on iPhone SE (2nd generation). Both support iOS 18; newer devices must meet or exceed the same functional targets.

| Area | Target |
| --- | --- |
| Board input | Selection feedback begins within 100 ms; legal destinations are available within one 16.7 ms frame after cached state is ready |
| Resume | Saved board visible within 500 ms of entering the game screen |
| Engine ready | Bundled NNUE integrity verification and engine readiness within 1.5 s at p75 |
| Computer turn | Levels 1–3 normally respond within 0.3–1.5 s; levels 4–5 may think longer according to clock policy |
| Hint | First useful hint within 1.0 s at p75; progress state after 150 ms |
| Cancellation | Search acknowledges cancellation within 250 ms at p95 |
| Reliability | No legal-state divergence across 10,000 automated random legal playouts |
| Accessibility | Full game can be completed with VoiceOver and without drag gestures |
| Offline | All MVP user journeys pass in airplane mode |

Performance targets may be revised after the first on-device benchmark, but a revision must document device, build, engine commit, NNUE checksum, threads, hash, and search budget.

## 11. Analytics and privacy

MVP ships without analytics or automatic diagnostic upload. Diagnostics are stored on-device and leave the device only when the player explicitly uses Copy or Share diagnostics.

Permitted diagnostic fields:

- App version and build.
- Device class and OS major version.
- Pikafish commit and NNUE checksum.
- Search duration, cancellation duration, and crash category.
- Game outcome and difficulty only when the player explicitly exports a diagnostic report.

Do not collect move histories, imported positions, names, contacts, advertising identifiers, or precise device identifiers. If analytics are introduced later, update the privacy specification and App Store disclosures first.

## 12. Release acceptance criteria

MVP is releasable only when all are true:

- A player can complete, resign, save, resume, rematch, and review the moves of a Player vs Computer game.
- Legal move, check, terminal-state, repetition, and undo suites pass against fixtures.
- Ten thousand random legal playouts show no divergence between UI/session state and the engine bridge.
- Search cancellation tests show no stale move applied after undo, new game, or backgrounding.
- App launch and game play succeed with network disabled.
- A clean install contains the engine, NNUE, themes, localizations, rules help, and licenses; runtime inspection shows no attempted network connection during any MVP journey.
- All three themes pass screenshot, contrast, clipping, and identical-hit-target checks.
- VoiceOver can select a piece, enumerate destinations, make a move, request a hint, hear check, and resign.
- Restore succeeds after forced termination during human turn, computer turn, hint search, and result presentation.
- Performance and thermal soak tests pass on the oldest supported device.
- GPLv3 compliance artifacts and corresponding-source link are present in the app and release checklist.
- Every release-blocking correctness, data-loss, accessibility, or thermal issue found through TestFlight is fixed and regression-tested before release.

## 13. Roadmap

### Release 1.0 — Play Pikafish

Player vs Computer, five strengths, Casual/10/15 minute games, hints, undo for Casual, three themes, save/resume, move history, result sheet, and basic replay.

### Release 1.1 — Play together

Local two-player, per-side names, board auto-rotate option, mutual draw, takeback request, shared clock presets, and game export.

Local two-player reuses the same Game screen. Hint is off by default because showing an engine answer to both people changes the nature of the game; a casual setup switch may enable shared hints. Between turns, optional auto-rotate animates the board while keeping piece labels upright. Both sides can pause, and destructive actions require confirmation from the current device user.

### Release 1.2 — Study

Post-game MultiPV analysis, evaluation graph, blunder review, position setup, FEN import/export, and richer notation.

### Release 2.0 — Online competition

Accounts, matchmaking, ratings, authoritative game server, reconnection, server clocks, anti-cheat/fair-play controls, reporting and moderation, push notifications, privacy/retention policy, and operational monitoring. Online engine assistance is prohibited during rated games and must be technically disabled, not merely hidden.

## 14. Locked decisions and calibration gates

Locked for implementation:

- Working product name: Xiangqi Mobile. The final icon is a release asset, not a behavior decision.
- Launch localizations: English, Traditional Chinese, and Simplified Chinese.
- Minimum deployment target: iOS 18; performance/thermal baseline: iPhone XR; smallest-screen layout baseline: iPhone SE (2nd generation).
- Rules: the versioned Pikafish Computer Rule identifier in section 7.
- Timed games: no undo.
- NNUE: a read-only bundled resource, located through `Bundle`; it is never downloaded or copied to a user-writable location.

The only remaining values are empirical calibration gates: final engine budgets per measured device tier and binary/memory limits. M0 records these values on iPhone XR and one current iPhone before M1 begins; they must not remain magic numbers in view code.

## 15. Source grounding

- [Pikafish repository](https://github.com/frankmanzhu/Pikafish) — fork reviewed at commit `6a59ee2f7b105bff64d9efc2692591107787e2b1` on 2026-09-20 (commit date 2026-09-19).
- [Official Pikafish UCI and commands](https://github.com/official-pikafish/Pikafish/wiki/UCI-%26-Commands) — command lifecycle, options, FEN/move format, MultiPV, WDL, and search output.
- [XiangqiAI](https://xiangqiai.com) — reference for board-first hierarchy, explicit engine-side controls, move navigation, and separation of engine and move-list workspaces; adapted for a simpler native mobile play flow.
- [Apple: Designing for games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games) — touch-first interaction and accessible personalization.
- [Apple: Adapting a game interface for smaller screens](https://developer.apple.com/documentation/Metal/adapting-your-game-interface-for-smaller-screens) — legibility, responsive layout, and accessible input guidance.
- [Apple: iOS 18 compatible iPhone models](https://support.apple.com/en-au/104985) — confirms iPhone XR and iPhone SE (2nd generation) support the deployment target.
