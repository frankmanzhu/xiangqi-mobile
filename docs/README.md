# Xiangqi Mobile specifications

Status: product and technical specification for implementation  
Last updated: 2026-09-20

## Product decision

The first release is a fully offline, native iPhone xiangqi app with two complete experiences: **Player vs Computer** and **local two-player hot-seat**. It must feel like a polished board game rather than an engine console.

The UI is board-first and themeable. A theme can change the board, pieces, surfaces, typography accents, sound, and motion, but it cannot change board geometry, game state, rules, controls, accessibility labels, or engine behavior.

“Offline” is a hard 1.0 boundary: a fresh install contains every gameplay resource, makes no network request, needs no account, and completes every release journey in airplane mode. Online play is roadmap context only and must not add production code, schema cases, permissions, dependencies, settings, or placeholder controls to 1.0.

## Release 1.0 scope lock

- Two modes: Player vs Computer and local two-player hot-seat.
- Three time choices: Casual, 10 minutes, and 15 minutes per side.
- One active saved game, read-only move replay, staged hints, five strengths, and three themes.
- Bundled Pikafish source build and bundled NNUE; no downloads or remote configuration.
- English, Traditional Chinese, and Simplified Chinese localizations.
- iPhone on iOS 18 or newer; iPad compatibility is welcome but not a release gate.
- No “coming soon” controls for local or online modes.

Feature-complete means the release acceptance criteria in `product-spec.md` pass. Engine budgets are calibration work rather than unresolved product behavior; iPhone XR is the performance/thermal baseline and iPhone SE (2nd generation) is the smallest-screen layout baseline.

## Documents

- [Product specification](product-spec.md) — goals, release scope, player stories, functional requirements, acceptance criteria, and roadmap.
- [UX and visual specification](ux-spec.md) — navigation, screens, board interactions, hints, themes, accessibility, and localization.
- [Technical specification](technical-spec.md) — native architecture, Pikafish bridge, data models, concurrency, performance, persistence, licensing, and test strategy.

## Decision hierarchy

If the documents appear to conflict, use this order:

1. Game correctness and saved-game integrity.
2. Product scope in `product-spec.md`.
3. Interaction behavior in `ux-spec.md`.
4. Suggested implementation in `technical-spec.md`.
5. Concept images in `assets/`.

The concept images are moodboards, not pixel-perfect specifications. Their generated board positions, labels, and spacing are not authoritative. Board geometry and behavior are defined in the written specifications.

## Recommended implementation sequence

1. Build the rules/session bridge and validate legal moves against Pikafish.
2. Implement a deterministic headless game coordinator with Player vs Computer tests.
3. Build the accessible board and game screen with the Classic theme.
4. Add save/resume, hints, results, and read-only move replay.
5. Add Tournament and Calm themes using the same view model and controls.
6. Performance/thermal-test on iPhone XR and layout-test on iPhone SE (2nd generation) before App Store work.
