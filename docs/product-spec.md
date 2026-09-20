# Xiangqi Mobile — product specification

Status: implementation-ready MVP specification  
Owner: product and engineering  
Target: native iPhone app; iPad layout is compatible but not an MVP release gate  
Primary mode: Player vs Computer  
Engine: Pikafish, pinned from the user's fork

## 1. Product summary

Xiangqi Mobile is an offline-first iOS app for playing a strong, configurable computer opponent without needing to understand engine terminology. A player can start a game in a few taps, choose a side and strength, ask for a useful hint, leave at any time, and resume exactly where they stopped.

The product should combine three qualities:

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

### Immediately after MVP

- Local two-player (hot-seat) using the same board and rules session.
- Post-game analysis with a move-quality timeline.
- Position setup and FEN import/export.
- iPad-specific two-column analysis layout.

The data model and coordinator must understand that Red and Black each have a controller (`localHuman`, `computer`, or later `remoteHuman`). MVP only exposes the combinations needed for Player vs Computer. This prevents the first release from hard-coding “Red is the user” or “Black is the engine” and keeps local/online modes additive.

## 3. Intended players

### Primary: improving casual player

Knows the rules and wants a good offline opponent. Values fast setup, understandable strength levels, a helpful hint, and a polished board more than engine statistics.

### Secondary: experienced player

Wants a stronger opponent, reliable clocks, move history, board flipping, and an optional compact evaluation view. Will notice rule, notation, or latency errors immediately.

### Future: competitive online player

Needs identity, ratings, fair-play controls, authoritative server clocks, reconnection, and moderation. This persona informs the state model but does not expand MVP scope.

## 4. Product principles

1. **Board before chrome.** The board gets the largest stable area on the game screen.
2. **Play language before engine language.** Say “Computer is thinking” rather than “search depth 18.”
3. **One source of truth.** Themes and screens observe the same authoritative game session.
4. **Hints preserve agency.** A hint shows a recommendation; it does not move a piece until the player confirms a move.
5. **Offline by default.** New game, play, hints, save/resume, and results work in airplane mode.
6. **Fast cancellation.** Leaving, undoing, suspending, or starting a new game stops the current engine search before state changes.
7. **Progressive disclosure.** Advanced evaluation, principal variation, and engine details remain optional.

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

### 5.2 Player vs Computer game

The player can:

- Tap a piece to select it and see legal destinations.
- Tap a legal destination to move.
- Drag a piece to a legal destination as an equivalent gesture.
- Tap the selected piece or empty board space to cancel selection.
- Ask for a hint when it is their turn and the game is active.
- Undo the last full turn in a casual game: the player's move and the computer reply.
- Offer no undo in timed games by default; this may become a setup option later.
- Flip the board without changing sides or game state.
- Open move history.
- Pause/leave, resign, or start a new game through an overflow menu.

The computer:

- Searches only when it is the computer's turn, during a requested hint, or during explicit review.
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
- The hint action shows a spinner if no result is ready after 150 ms.
- A repeated tap does not launch a duplicate search.
- Changing the position cancels and invalidates the hint.
- Hints do not expose centipawn scores in the default playing UI.
- The game record stores whether a hint was used for that ply, enabling later review.
- Casual MVP places no hard limit on hints. A future challenge mode may limit them.

### 5.4 Game completion

The app recognizes and presents at least:

- Checkmate.
- Stalemate/no legal move according to the selected xiangqi rule policy.
- Resignation.
- Draw by supported repetition/adjudication rule.
- Draw by mutual agreement only after local or online two-player exists.
- Time loss in timed games.

The result sheet shows outcome, reason, player color, difficulty, move count, elapsed time, hints used, and actions for Rematch, Review game (initially move-by-move without full analysis), and Home.

### 5.5 Save and resume

- Maintain one active game in MVP.
- Persist after every committed move and every clock transition.
- On launch, Home shows “Continue game” when a valid unfinished record exists.
- Restore board orientation, move list, clocks, hint usage, selected theme, and whose turn it is.
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
- Show advanced evaluation: Off by default.
- Rules and notation help.
- Open-source licenses and exact Pikafish source link/commit.

## 6. Strength model

The product exposes five stable labels and does not expose raw depth, node, thread, or hash controls in normal settings.

| Level | Label | Intended experience | Search policy target |
| --- | --- | --- | --- |
| 1 | Beginner | Makes understandable mistakes and responds quickly | Small node/time budget; select among safe MultiPV candidates within a wide evaluation-loss budget |
| 2 | Club learner | Forgiving but tactically credible | Moderate budget; narrower candidate loss budget |
| 3 | Club player | Consistent intermediate opponent | Larger budget; usually first or second line |
| 4 | Expert | Strong play with longer thought time | High budget; best line, capped for device comfort |
| 5 | Pikafish | Strongest practical on-device setting | Best line with adaptive time and thermal limits |

Implementation requirements:

- Difficulty is a versioned policy, not just a UI label.
- A lower level may choose a suboptimal move only from legal engine candidates.
- Candidate selection is seeded and recorded so a saved game is reproducible.
- Never create obviously illegal, self-checking, or random non-engine moves.
- Device thermal and battery safeguards may reduce compute time but must not silently change the selected level's identity; the UI may say “Reduced analysis to keep your device cool.”

Exact budgets must be calibrated on physical devices before release and live in configuration, not hard-coded across views.

## 7. Rules policy

Xiangqi repetition and chasing rules vary by federation and platform. MVP must ship with one named, testable policy rather than an unspecified approximation.

Decision for implementation:

- Use the Pikafish-compatible **Computer Rule** as the initial adjudication policy.
- Display the policy name and a concise explanation under Settings → Rules.
- Keep the rules policy behind an interface so a future WXF/CCA policy can be added without changing board UI or persistence format.
- Store the policy identifier and version in each game record.

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
3. Revert to the position before the player's most recent move.
4. Persist the new main line and mark discarded plies as removed from the active line.
5. Clear hint and evaluation state.

## 9. Functional requirements

Identifiers are stable and should be referenced by tests and issues.

| ID | Requirement |
| --- | --- |
| GAME-001 | The app starts a standard xiangqi game with Red to move. |
| GAME-002 | Selection exposes only legal destinations for the selected piece. |
| GAME-003 | The app rejects moves that leave the moving side's general in check. |
| GAME-004 | The app detects terminal positions under the selected rules policy. |
| GAME-005 | Undo in Casual mode reverts one full human/computer turn and cancels stale search. |
| GAME-006 | Board flip changes presentation only. |
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
| LIC-001 | The app exposes Pikafish attribution, GPLv3 text, exact source revision, and corresponding source offer/link. |

## 10. Non-functional targets

Targets are measured on the oldest supported physical iPhone in Release configuration.

| Area | Target |
| --- | --- |
| Board input | Selection feedback begins within 100 ms; legal destinations are available within one 16.7 ms frame after cached state is ready |
| Resume | Saved board visible within 500 ms of entering the game screen |
| Engine ready | Initial network verification and engine readiness within 1.5 s at p75 |
| Computer turn | Levels 1–3 normally respond within 0.3–1.5 s; levels 4–5 may think longer according to clock policy |
| Hint | First useful hint within 1.0 s at p75; progress state after 150 ms |
| Cancellation | Search acknowledges cancellation within 250 ms at p95 |
| Reliability | No legal-state divergence across 10,000 automated random legal playouts |
| Accessibility | Full game can be completed with VoiceOver and without drag gestures |
| Offline | All MVP user journeys pass in airplane mode |

Performance targets may be revised after the first on-device benchmark, but a revision must document device, build, engine commit, NNUE checksum, threads, hash, and search budget.

## 11. Analytics and privacy

MVP should launch without third-party analytics. Use local, opt-in diagnostics only if needed during TestFlight.

Permitted diagnostic fields:

- App version and build.
- Device class and OS major version.
- Pikafish commit and NNUE checksum.
- Search duration, cancellation duration, and crash category.
- Anonymous aggregate game outcome and difficulty only after explicit diagnostic consent.

Do not collect move histories, imported positions, names, contacts, advertising identifiers, or precise device identifiers. If analytics are introduced later, update the privacy specification and App Store disclosures first.

## 12. Release acceptance criteria

MVP is releasable only when all are true:

- A player can complete, resign, save, resume, rematch, and review the moves of a Player vs Computer game.
- Legal move, check, terminal-state, repetition, and undo suites pass against fixtures.
- Ten thousand random legal playouts show no divergence between UI/session state and the engine bridge.
- Search cancellation tests show no stale move applied after undo, new game, or backgrounding.
- App launch and game play succeed with network disabled.
- All three themes pass screenshot, contrast, clipping, and identical-hit-target checks.
- VoiceOver can select a piece, enumerate destinations, make a move, request a hint, hear check, and resign.
- Restore succeeds after forced termination during human turn, computer turn, hint search, and result presentation.
- Performance and thermal soak tests pass on the oldest supported device.
- GPLv3 compliance artifacts and corresponding-source link are present in the app and release checklist.
- TestFlight feedback contains no release-blocking correctness, data-loss, accessibility, or thermal issue.

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

## 14. Open decisions before implementation freeze

These do not block initial architecture work but must be resolved before feature-complete:

- App name and icon.
- Exact Traditional/Simplified Chinese and English launch languages.
- Minimum iOS version; technical recommendation is iOS 18 or newer unless market requirements require broader support.
- Final calibrated engine budgets per supported device tier.
- Exact Computer Rule version and user-facing rules wording.
- Whether timed games permit undo as an explicit non-ranked setup option.
- Whether the bundled NNUE is embedded in the app binary or copied into Application Support on first run.

## 15. Source grounding

- [Pikafish repository](https://github.com/frankmanzhu/Pikafish) — fork reviewed at commit `6a59ee2f7b105bff64d9efc2692591107787e2b1` (2026-09-18).
- [Official Pikafish UCI and commands](https://github.com/official-pikafish/Pikafish/wiki/UCI-%26-Commands) — command lifecycle, options, FEN/move format, MultiPV, WDL, and search output.
- [XiangqiAI](https://xiangqiai.com) — reference for board-first hierarchy, explicit engine-side controls, move navigation, and separation of engine and move-list workspaces; adapted for a simpler native mobile play flow.
- [Apple: Designing for games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games) — touch-first interaction and accessible personalization.
- [Apple: Adapting a game interface for smaller screens](https://developer.apple.com/documentation/Metal/adapting-your-game-interface-for-smaller-screens) — legibility, responsive layout, and accessible input guidance.
