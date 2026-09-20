# Xiangqi Mobile — themes, localization, and learning plan

Status: CCPD learning milestone implemented; broader theme/localization plan remains iterative
Last updated: 2026-09-21  
Scope: offline visual themes, English/Chinese localization, and an offline learning library

## Implemented CCPD milestone

The pinned CCPD corpus is now imported into a single read-only SQLite resource and exposed natively in the app. The delivered path includes strict UTF-8/Big5/Big5-HKSCS decoding, Chinese-notation-to-UCI normalization, per-ply legality validation, deterministic quarantine and audit output, category browsing, Traditional/Simplified Chinese-aware metadata search, annotated source-notation replay from arbitrary FENs, record practice with automatic source replies, bookmarks and durable progress, live English/Simplified Chinese/Traditional Chinese selection for learning flows, offline attribution, and regression coverage.

The validated import accepts 58,456 of 58,468 source records. Six malformed FENs and six illegal continuations are quarantined. The database checksum, accepted category totals, and quarantine totals are pinned in `Resources/Learning/CCPD-source.json`; the complete machine-readable audit and quarantine files ship beside the database.

## 1. Outcome

Add three complete product capabilities without changing the rules engine or weakening save compatibility:

1. **Theme packs** that visibly change the board, pieces, surrounding surfaces, state markers, sound, and restrained motion while sharing one board geometry and interaction model.
2. **In-app language selection** for System Default, English, Simplified Chinese, and Traditional Chinese, including accessible board descriptions and move notation.
3. **Learn and Practice** experiences containing rules lessons, guided positions, tactics, annotated games, and later opening study, all bundled for offline use and validated against the same rules engine as normal play.

Recommended release order is localization foundation, theme completion, learning framework with original starter content, then licensed third-party content. Localization and reusable board rendering are prerequisites for a maintainable learning feature.

This respects the existing scope lock by splitting delivery into two releases: finish the already-promised themes and localizations for 1.0, then treat Learn and Practice as the first post-1.0 feature. If product intentionally reopens 1.0 scope, the same dependency order still applies.

## 2. Current-state findings

The current app is a strong gameplay base, but the existing settings are ahead of their implementation:

- `ThemeID` and three color palettes exist. The themes currently change colors only; all themes use the same procedural board and circular text pieces.
- The global theme choice is copied into a new `GameRecord`. Changing the setting does not update an already active game.
- `pieceLabels` and `coordinates` are stored in `UserDefaults`, but `BoardView` does not read them. Piece glyphs are hard-coded Traditional Chinese and coordinates are not drawn.
- `confirmMoves` works. Sound and haptic preferences exist in Settings but have no feedback service behind them.
- User-facing English is embedded across views and `GameSession`; there is no String Catalog or localization resource.
- `RecordedMove.notation` stores an English presentation string. This prevents old moves from changing language when the user changes the app language, despite UCI already being the canonical record.
- `BoardView` is coupled directly to `GameSession`. A lesson, puzzle, or annotated-game screen cannot reuse it cleanly yet.
- The product and UX specifications already name Classic, Tournament, and Calm and already require English, Simplified Chinese, and Traditional Chinese. This plan completes those promises rather than adding unrelated scope.

## 3. Product decisions

### 3.1 Preferences

Use typed global preferences instead of independent stringly typed `@AppStorage` properties in views.

```swift
enum AppLanguage: String, CaseIterable, Codable {
    case system, english, simplifiedChinese, traditionalChinese
}

enum PieceLabelStyle: String, CaseIterable, Codable {
    case traditionalChinese, simplifiedChinese
}

enum CoordinateMode: String, CaseIterable, Codable {
    case off, redPerspective, always
}
```

Create one `@MainActor` `AppPreferences` observable object backed by `UserDefaults`. Inject it at the app root. Views consume typed values; they do not read raw keys directly.

- App language, piece labels, coordinates, sounds, haptics, and move confirmation are global preferences.
- A theme change applies immediately, including during a game. The active record's existing `theme` field is updated and persisted so resume looks the same.
- Language does not become game state and does not change the portable game format.
- Piece label style defaults from the selected language on first launch but remains independently selectable. This allows an English UI with Chinese pieces.

### 3.2 Localization behavior

- System Default follows the device's preferred supported language.
- An explicit selection updates the UI without requiring an app restart by setting the root SwiftUI locale.
- Use `Localizable.xcstrings` with `en`, `zh-Hans`, and `zh-Hant` variants.
- Use stable semantic keys such as `home.play_computer`, not English sentences as program identifiers.
- Keep domain values locale-neutral. `Side`, `PieceKind`, `GameMode`, result reasons, and strength levels receive localized presentation formatters outside the core rules package.
- Keep FEN and UCI ASCII and unchanged in exports, diagnostics, and persistence.
- Localize accessibility labels, hints, errors, menus, pluralized move counts, and dynamic status text—not only visible button labels.

### 3.3 Move notation

UCI remains the canonical move. Display notation is derived whenever it is shown.

- Migrate saved games to schema version 2 using explicit versioned DTOs. The v1 migration reads but discards the stored English `notation`; it preserves UCI, captured piece, hint use, timestamps, and engine seed.
- Add `MoveNotationFormatter` with an unambiguous English long form and standard Chinese forms.
- Chinese notation must cover side-relative file numbering, `进/退/平` and `進/退/平`, destination semantics, and `前/中/后` / `前/中/後` disambiguation for same-file pieces.
- Reconstruct the position before each ply when formatting history so notation remains correct after a language change.
- Continue to show UCI as a secondary value and use it in accessibility where it removes ambiguity.

### 3.4 Theme model

Keep the three already specified theme names. Make each a complete built-in pack rather than adding a marketplace or downloads.

| Theme | Board treatment | Piece treatment | State treatment |
| --- | --- | --- | --- |
| Classic | warm paper/wood, dark brown grid, localized river text | warm ivory discs, serif/calligraphic glyphs, restrained depth | seal-red last move and selection marks |
| Tournament | graphite, low glare, thin high-contrast grid | flat high-contrast outlined discs, crisp glyphs | strong geometric markers with minimal motion |
| Calm | pale stone, jade accent, open visual rhythm | matte ceramic discs, softer shadow | jade hints and gentler motion |

Implement a real `BoardTheme` contract containing semantic colors, board decoration, piece rendering style, typography, effects, sounds, and motion intensity. `GameSession` and rules code never see these values.

Prefer vector/procedural SwiftUI rendering for the first release. It scales cleanly, avoids asset-rights uncertainty, and supports contrast settings. Any later texture, sound, or font must have an entry in the asset attribution manifest.

Piece identity is always resolved from `side + kind + PieceLabelStyle`; it is never inferred from its FEN character or displayed glyph. River text follows the piece-label style (`楚河漢界` or `楚河汉界`).

### 3.5 Learning product

Add one **Learn** entry on Home. Do not mix lessons into the New Game flow.

The first useful release contains:

- **Learn the board:** goal, turn order, palace, river, check, checkmate, stalemate, and every piece's movement.
- **Practice fundamentals:** legal-move exercises and small tactics such as checks, captures, cannon screens, horse-leg blocks, pins, forks, and basic mating patterns.
- **Study a game:** a small set of annotated public-domain or explicitly licensed games with move-by-move replay.
- **Progress:** completed lessons, puzzle attempts, solves, and best hint level, stored locally.

Opening encyclopedias and large historical databases are a later content pack. A small, reviewed curriculum is more useful and safer than shipping thousands of unexplained positions.

## 4. Technical design

### 4.1 Proposed modules and files

```text
XiangqiMobile/
├── App/
│   ├── AppPreferences.swift
│   └── LocalizationController.swift
├── Presentation/
│   ├── LocalizedDomainText.swift
│   └── MoveNotationFormatter.swift
├── BoardUI/
│   ├── BoardRenderer.swift
│   ├── BoardPresentation.swift
│   ├── BoardTheme.swift
│   ├── ThemeCatalog.swift
│   └── PieceGlyphProvider.swift
├── Learning/
│   ├── LearningLibrary.swift
│   ├── LearningModels.swift
│   ├── LearningProgressStore.swift
│   ├── LessonView.swift
│   ├── PuzzleSession.swift
│   └── StudyGameSession.swift
└── Resources/
    ├── Localizable.xcstrings
    ├── Learning/
    │   ├── manifest.json
    │   ├── lessons.json
    │   ├── puzzles.json
    │   └── study-games.json
    └── Licenses/
        └── ContentAttributions.json
```

The exact folders may be introduced incrementally; boundaries matter more than moving every file at once.

### 4.2 Reusable board presentation

Extract rendering inputs from `GameSession` into a value model:

```swift
struct BoardPresentation {
    let position: Position
    let orientation: Side
    let selectedSquare: Square?
    let legalDestinations: Set<Square>
    let lastMove: Move?
    let hint: Move?
    let interaction: BoardInteraction
}
```

Normal games, puzzles, lesson demonstrations, and annotated replay each create a `BoardPresentation`. `BoardRenderer` owns geometry, drawing, hit testing, accessibility elements, and theme application. Feature sessions own rules and state transitions.

This extraction must not rewrite working rules or engine coordination. First wrap the existing behavior with characterization tests, then move rendering behind the new input model.

### 4.3 Learning content schema

Use bundled, versioned JSON rather than hard-coded Swift arrays.

```text
LearningManifest
├── schemaVersion
├── contentVersion
├── attributions[]
├── lessons[]
├── puzzles[]
└── studyGames[]

Puzzle
├── stable ID, title key, tags, difficulty
├── starting FEN and side to move
├── solution tree of UCI moves
├── localized prompt/explanation keys
├── allowed hint stages
└── source attribution ID

StudyGame
├── stable ID and metadata
├── starting FEN and ordered UCI moves
├── annotations keyed by ply
└── source attribution ID
```

Keep localized prose in String Catalogs or locale-specific content files and structural chess data in shared JSON. Progress keys use stable content IDs, not array positions.

Add a deterministic validation tool that fails the build/test suite when:

- JSON or a localization key is missing;
- a FEN cannot be parsed;
- a solution or study move is illegal at its ply;
- the declared side to move is wrong;
- a claimed mate/result is false;
- IDs are duplicated;
- attribution or license metadata is missing.

Optionally run Pikafish offline during content authoring to score alternate puzzle moves. Runtime lessons remain deterministic and do not require engine search unless a feature explicitly offers analysis.

### 4.4 Progress persistence

Learning progress is separate from `active-game.json`:

- store a versioned `learning-progress.json` atomically in Application Support;
- key records by stable content ID;
- retain attempts, solves, completion date, and highest hint stage used;
- tolerate removed content IDs and migrate renamed IDs explicitly;
- do not create accounts, analytics, cloud sync, or networking.

## 5. Source and licensing plan

“Free to read” is not the same as reusable. Every imported item needs source URL, author, license, retrieval date, and modification notes in `ContentAttributions.json`.

| Candidate | Useful for | Current recommendation |
| --- | --- | --- |
| [English Wikibooks Xiangqi book](https://en.wikibooks.org/wiki/Xiangqi) | terminology, rules, introductory strategy | Usable under [Wikibooks' CC BY-SA 4.0/GFDL terms](https://en.wikibooks.org/wiki/Wikibooks:Copyrights) with attribution and share-alike compliance. Prefer it as research and write original app lessons unless verbatim reuse is valuable. |
| Chinese Wikisource historical manuals, including [《梅花谱》](https://zh.wikisource.org/wiki/%E6%A2%85%E8%8A%B1%E8%AD%9C) | classic openings, historical annotated lines | Underlying old works are public domain, but a copied transcription may carry site terms. Re-transcribe from a verified public-domain scan or comply with the transcription's license; write new modern explanations. |
| [Chinese Chess Practical Dataset (CCPD)](https://github.com/Yvonne761/Chinese-Chess-Practical-Dataset) | master games, middlegames, endgames, tactical exercises, and openings | **Adopt as the primary external learning corpus.** The repository declares CC BY 4.0. Pin an audited commit, preserve attribution and modification notices, normalize every record, and expose the successfully validated corpus through native browsing, replay, and practice flows. |
| [Wikimedia Commons xiangqi art](https://commons.wikimedia.org/wiki/Category:Xiangqi_pieces) | optional board/piece references | Some relevant files are CC0/public domain, but verify each file page individually. Procedural original art remains preferred. |
| Community databases without an explicit data license | large game/puzzle collections | Do not bundle. A public repository or a “free” download is insufficient permission. |
| Free federation PDFs or modern commercial books | learning reference | Link or cite only where permitted; do not copy text, diagrams, or annotations without an explicit compatible license. |

For the initial learning release, author original bilingual lessons and 24–40 small puzzles, or derive them from clearly public-domain positions, then validate every line with the local rules implementation and Pikafish. This produces a coherent curriculum and a clean rights trail.

Add an in-app **Content sources and licenses** screen. It must remain available offline and identify modified material. Keep software licenses and learning-content licenses as separate sections.

### 5.1 CCPD native-support contract

CCPD is a committed product source, not merely a future candidate. The first audit of repository commit `368a47a947773dd8692c026e286dd19b6277b993` found:

- six top-level categories: middlegames, full-game tactics, games, endgames, mating/tactical exercises, and openings;
- 58,468 `.pgn` files in the Git tree at that commit;
- a 60-record mismatch with the README's stated total of 58,528, caused by the README reporting 53,953 games while the tree contains 53,893 under `Dataset/對局`;
- Big5-encoded source text in sampled files, not UTF-8;
- PGN-like headers including `Game`, `Event`, `Round`, `Date`, `Site`, `Red`, `Black`, `Result`, `ECCO`, and `FEN`;
- Traditional Chinese, position-dependent move notation rather than UCI moves.

The import pipeline must therefore support the source on its own terms:

1. Fetch only a pinned commit and record its commit SHA, retrieval date, source URL, license, and unmodified archive hash.
2. Preserve original source bytes and per-file hashes outside the app bundle so every normalized item is traceable.
3. Decode strict UTF-8 when valid, otherwise decode the documented/sampled Big5 family explicitly. Never use lossy replacement characters.
4. Parse tags, results, starting FEN, main-line moves, comments, and variations where present. Preserve unknown tags instead of discarding them.
5. Convert Chinese notation to canonical UCI by resolving each move against the current position. Support Traditional/Simplified piece characters, Chinese and full-width Arabic file numbers, `進/进`, `退`, `平`, and `前/中/後/后` disambiguation.
6. Validate every converted ply with `XiangqiCore` and, for disagreements, the pinned Pikafish bridge. Quarantine invalid or ambiguous records with a machine-readable reason; never repair them silently.
7. Generate an audit report containing discovered counts, imported counts, quarantined counts by reason, duplicates, tag coverage, result mismatches, and source-statistic discrepancies.
8. Normalize accepted records into one compact, indexed, read-only database. Do not add tens of thousands of individual files to the Xcode resource phase.
9. Include original Chinese notation alongside canonical UCI so the study UI can display source notation, localized derived notation, or both.
10. Generate the in-app attribution and change notice from the same import manifest used to build the database.

Native app support means:

- browse all successfully imported records by dataset category;
- filter games by player, event, year, result, and ECCO/opening code when metadata exists;
- open arbitrary records at their supplied FEN and replay every validated move;
- practice middlegame, endgame, mating, tactical, and opening records through category-appropriate flows;
- search Traditional and Simplified Chinese metadata using normalized search fields;
- show source metadata and attribution for every item;
- persist bookmarks, recent items, puzzle attempts, and completion independently of active games;
- remain fully functional offline with no runtime dependency on GitHub.

Use a reusable `XiangqiPGN` module for source decoding and parsing. The build-time importer and any future on-device file importer must share the same parser and fixtures. The shipped app reads only the normalized database, keeping startup and browsing predictable.

The full validated corpus should be shipped if its generated database meets the release size and performance budgets. If it does not, ship a deterministic curated database in the app and make the full corpus a separately built distribution variant; do not introduce runtime downloading without a separate product decision.

## 6. Implementation sequence

### Phase 0 — protect the baseline

1. Add characterization UI tests for Home, Settings, New Game, game controls, move history, and save/resume.
2. Add checked-in schema-v1 save fixtures before changing persistence.
3. Add screenshots for the same board state in all three existing palettes.
4. Add a source/asset attribution manifest and policy before importing content or art.

Exit gate: current gameplay and a v1 saved game behave identically after the test harness is added.

### Phase 1 — typed preferences and localization

1. Introduce `AppPreferences` and migrate existing `UserDefaults` keys without losing choices.
2. Add the String Catalog and root locale override.
3. Replace all visible and accessibility strings in views, sessions, alerts, and engine-facing error presentation.
4. Move domain display names out of `XiangqiCore`.
5. Implement Simplified/Traditional piece glyph resolution and coordinate display.
6. Implement schema-v1-to-v2 game migration and derived move notation.

Exit gate: a user can switch among System, English, Simplified Chinese, and Traditional Chinese without relaunching; the entire current game flow changes language; old saves load; exports remain byte-for-byte compatible except for intentionally versioned metadata.

### Phase 2 — complete theme packs

1. Replace `BoardPalette` with semantic `BoardTheme` tokens and a theme catalog.
2. Extract `BoardRenderer` and preserve the existing touch transform with exhaustive 90-square orientation tests.
3. Implement the three board treatments, piece treatments, coordinates, and river text.
4. Apply theme surfaces consistently to Home, setup, game, history, result, and learning screens.
5. Add sound/haptic services that respect preferences, Reduce Motion, Reduce Transparency, and Increased Contrast.
6. Make an in-game theme change immediate and durable.

Exit gate: all three themes render the same legal position and state overlays with identical hit targets, legal moves, accessibility order, and saved game; screenshot and contrast QA pass on the smallest supported iPhone.

### Phase 3 — learning framework and original starter pack

1. Add Learn routes and library browsing by Basics, Tactics, and Study Games.
2. Add schema, loader, validator, attribution model, and progress store.
3. Build lesson demonstration, puzzle, and annotated replay sessions on `BoardRenderer`.
4. Ship original localized starter content: all piece rules, core board concepts, 24–40 progressive puzzles, and 2–4 annotated games or miniature demonstrations.
5. Add staged hints: concept hint, source square, destination square, then explanation. Record hint use in learning progress only.

Exit gate: all content works in airplane mode, every line passes legality validation, progress survives termination, and switching language or theme preserves the current lesson/puzzle position.

### Phase 4 — CCPD import and native library

1. Pin the audited CCPD commit and check in its source manifest, CC BY 4.0 notice, citation, and archive checksum.
2. Build the reusable Big5/UTF-8 Xiangqi PGN parser and Chinese-notation-to-UCI converter from representative fixtures.
3. Run the full corpus through normalization, legality validation, deduplication, and quarantine reporting.
4. Generate a compact indexed database plus deterministic manifest; regenerate it reproducibly in CI rather than hand-editing output.
5. Build native category browsing, metadata filtering/search, bookmarks, replay, and category-appropriate practice flows.
6. Curate guided learning collections on top of stable imported IDs while retaining access to all successfully validated records.
7. Include exact attribution, modification notice, license text, pinned revision, and per-item source identity in the app and repository.

Exit gate: every shipped item can be traced to the pinned source and reproduced by the importer; all accepted plies are legal; every rejection is explained in the audit report; corpus counts reconcile with the pinned Git tree; library search, replay, and practice meet size and performance budgets on the baseline device.

### Phase 5 — release QA

1. Test all language × theme × orientation combinations for representative screens.
2. Run VoiceOver, Dynamic Type, grayscale, Increased Contrast, and Reduce Motion checks.
3. Test v1 save migration, corrupted content recovery, and content progress migration.
4. Run memory and scrolling checks for the learning library and long annotated games.
5. Review every attribution and third-party license before distribution.

## 7. Suggested pull-request slices

Keep changes reviewable and vertically testable:

1. Preferences model and compatibility migration.
2. String Catalog plus English key conversion.
3. Simplified and Traditional Chinese translations.
4. Derived English and Chinese move notation plus v2 save migration.
5. `BoardPresentation` extraction with no visual change.
6. Theme protocol and Classic parity.
7. Tournament and Calm piece/board implementations plus screenshot tests.
8. Learning schema, validator, and attribution screen.
9. Basics lessons and demonstration board.
10. Puzzle session, progress store, and starter tactics.
11. CCPD parser, encoding fixtures, Chinese notation conversion, and corpus audit CLI.
12. CCPD normalized database generator, native library browsing, search, replay, and practice.
13. Accessibility, device matrix, license, size/performance, and release QA.

## 8. Acceptance checklist

- No user-facing string is hard-coded outside approved diagnostic/developer output.
- English, Simplified Chinese, and Traditional Chinese cover visible UI and accessibility UI.
- Language changes never alter FEN, UCI, legal moves, engine inputs, or saved-game truth.
- A schema-v1 fixture loads and is migrated without losing gameplay metadata.
- Theme changes never alter board geometry, square mapping, legal moves, or interaction order.
- Every theme supports selected, legal, capture, last move, hint, check, disabled, and terminal states.
- Piece-label and coordinate settings visibly work in every theme and orientation.
- Every lesson, puzzle, and study game works offline and passes deterministic content validation.
- Every accepted CCPD record replays legally from its declared FEN; rejected records appear in a reproducible quarantine report.
- CCPD category and total counts are reconciled against the pinned source tree, including documented upstream discrepancies.
- The app browses and searches the normalized corpus without loading the complete database into memory.
- Every imported text, image, sound, font, game collection, or transcription has traceable license metadata.
- Learning progress is independent of the single active game and survives app termination.

## 9. Deliberately deferred

- Downloadable themes or content packs.
- Accounts, cloud progress, leaderboards, daily online puzzles, and analytics.
- User-authored positions or arbitrary database import.
- Live engine evaluation inside lessons.
- A comprehensive opening encyclopedia.
- Machine-translated lessons shipped without native-speaker review.

These can be added later without changing the proposed preference, theme, board-presentation, or learning-content boundaries.
