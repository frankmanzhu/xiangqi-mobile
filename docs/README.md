# Xiangqi Mobile specifications

Status: product and technical specification for implementation  
Last updated: 2026-09-20

## Product decision

The first release is an offline, native iPhone xiangqi app focused on one complete experience: **Player vs Computer**, powered by a bundled Pikafish engine. It must feel like a polished board game rather than an engine console.

The UI is board-first and themeable. A theme can change the board, pieces, surfaces, typography accents, sound, and motion, but it cannot change board geometry, game state, rules, controls, accessibility labels, or engine behavior.

Local two-player is the next mode after the Player vs Computer MVP. Online play is intentionally deferred until the offline rules, persistence, clocks, and game-state model are proven.

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
4. Add save/resume, hints, results, and review.
5. Add Tournament and Calm themes using the same view model and controls.
6. Performance-test on the oldest supported iPhone before App Store work.

