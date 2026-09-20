# Xiangqi Mobile — technical specification

Status: proposed architecture for MVP  
Client: native SwiftUI iOS application  
Engine: Pikafish C++ embedded in-process  
Primary quality attribute: correct, cancellable, recoverable game state

## 1. Architectural decision

Compile a pinned Pikafish revision and its NNUE network into the app distribution, expose a narrow C-compatible bridge, and call it from Swift through an isolated engine actor.

Do not launch Pikafish as a child process. iOS apps should not depend on a shell/`Process` workflow, and Apple distribution rules prohibit downloading or installing executable code outside the permitted model. Bundling and compiling the engine also makes startup, cancellation, resource control, and version reporting deterministic.

Although current Xcode supports direct Swift/C++ interoperability, the MVP uses a small C ABI implemented by a C++/Objective-C++ facade because it:

- Hides Pikafish templates and internal types from application code.
- Provides explicit ownership and error boundaries.
- Prevents C++ exceptions from crossing into Swift.
- Keeps future engine updates localized.
- Is straightforward to unit-test from both C++ and Swift.

Apple documents both [mixing Swift and C++ in an Xcode project](https://developer.apple.com/documentation/swift/mixinglanguagesinanxcodeproject) and current [C++ language support](https://developer.apple.com/xcode/cpp/). The bridge recommendation is an application-maintainability choice, not a platform limitation.

## 2. System overview

```text
SwiftUI views
    │ user intents / rendered state
    ▼
GameFeature / GameCoordinator (@MainActor)
    ├── RulesSession protocol
    ├── EngineClient protocol
    ├── GameRepository protocol
    ├── ClockService protocol
    └── FeedbackService protocol
              │
              ▼
PikafishEngineActor (serial executor)
              │ C ABI / Objective-C++
              ▼
PikafishBridge
    ├── position and legal moves
    ├── search lifecycle and callbacks
    ├── options/resource policy
    └── engine/NNUE version reporting
              │
              ▼
Pinned Pikafish C++ sources + pinned pikafish.nnue
```

The app is a local process, not a client/server system. The 1.0 production target contains no networking feature code, remote configuration, account model, or runtime download path. Build and release tooling may access source hosts, but the installed app does not.

## 3. Proposed repository layout

```text
xiangqi-mobile/
├── App/
│   ├── XiangqiMobileApp.swift
│   ├── AppEnvironment.swift
│   └── RootView.swift
├── Features/
│   ├── Home/
│   ├── NewGame/
│   ├── Game/
│   ├── Review/
│   └── Settings/
├── Packages/
│   ├── XiangqiDomain/
│   ├── XiangqiPersistence/
│   ├── XiangqiEngine/
│   ├── XiangqiBoardUI/
│   └── XiangqiTestSupport/
├── Vendor/
│   └── Pikafish/
├── Resources/
│   ├── Engine/pikafish.nnue
│   ├── Themes/
│   ├── Localizations/
│   └── Licenses/
├── Tests/
│   ├── DomainTests/
│   ├── EngineIntegrationTests/
│   ├── PersistenceTests/
│   ├── FeatureTests/
│   ├── SnapshotTests/
│   └── UITests/
└── docs/
```

The exact Xcode project generator is not prescribed. If the team uses Swift Package Manager for internal packages, keep app resources and the C++ build reproducible in CI.

## 4. Domain model

Use immutable value types in the Swift domain layer.

```swift
import Foundation

enum Side: String, Codable, Sendable { case red, black }

enum PieceKind: String, Codable, Sendable {
    case general, advisor, elephant, horse, chariot, cannon, soldier
}

enum PlayerController: Codable, Sendable {
    case localHuman
    case computer(policyID: String)
}

struct GameMode: Codable, Sendable {
    let red: PlayerController
    let black: PlayerController
}

struct Square: Hashable, Codable, Sendable {
    let file: Int // 0...8
    let rank: Int // 0...9
}

struct Move: Hashable, Codable, Sendable {
    let from: Square
    let to: Square
}

struct PlacedPiece: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let side: Side
    let kind: PieceKind
    let square: Square
}

struct Position: Equatable, Codable, Sendable {
    let fen: String
    let sideToMove: Side
    let pieces: [PlacedPiece]
}

struct RecordedMove: Codable, Sendable {
    let move: Move
    let uci: String
    let side: Side
    let hintUsed: Bool
    let engineSelectionSeed: UInt64? // non-nil only for a computer move
    let committedAt: Date
}

enum OutcomeReason: String, Codable, Sendable {
    case checkmate, stalemate, resignation, timeLoss
    case repetition, perpetualCheck, perpetualChase, rule60, insufficientMaterial
}

enum GameOutcome: Codable, Sendable {
    case win(winner: Side, reason: OutcomeReason)
    case draw(reason: OutcomeReason)
}

enum GameStatus: Codable, Sendable {
    case active
    case suspended
    case completed(GameOutcome)
}

struct ClockState: Codable, Sendable {
    var redRemainingMilliseconds: Int64
    var blackRemainingMilliseconds: Int64
}

struct GameSettingsSnapshot: Codable, Sendable {
    var orientation: Side
    var themeID: String
    var pieceLabels: String
    var coordinateMode: String
    var requiresMoveConfirmation: Bool
}

struct GameRecord: Codable, Sendable {
    let id: UUID
    let schemaVersion: Int
    let rulesPolicyID: String
    let engineRevision: String
    let nnueSHA256: String
    let startingFEN: String
    let mode: GameMode
    let createdAt: Date
    var moves: [RecordedMove]
    var status: GameStatus
    var clocks: ClockState?
    var activeElapsedMilliseconds: Int64
    var settings: GameSettingsSnapshot
    var updatedAt: Date
}
```

Primary persisted truth is `startingFEN + ordered UCI moves + rules policy/version`. A cached current FEN and board snapshot may speed launch but must be validated/reconstructable from the primary truth.

For a standard game, `startingFEN` is exactly `rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1`, the pinned engine's `StartFEN`. The coordinate transform is model-level test data: from Red's unflipped perspective, files run `a...i` left-to-right, Red's home rank is `0`, and Black's home rank is `9`.

### Position version

Each coordinator runtime creates a fresh `sessionEpoch: UUID` and starts `positionVersion: UInt64` at zero. The version increments on every committed move, undo, replacement, or recovery transition. Neither value is persisted game truth; restore creates a new epoch after the old search is stopped. Every engine request also has a unique request UUID and captures the epoch and version. A result is accepted only if:

- Game ID matches.
- Session epoch and request UUID match the current pending request.
- Position version matches.
- Side to move matches.
- Search purpose matches the current pending request.
- Move is legal in the current rules session.

This is the primary defense against stale callbacks.

## 5. Game state machine

```text
loading
  ├── ready.humanTurn
  │     ├── selected(piece, legalMoves)
  │     ├── hintSearching(requestID)
  │     ├── hintShown(stage)
  │     └── committingHumanMove
  ├── ready.computerTurn
  │     ├── computerSearching(requestID)
  │     └── committingComputerMove
  ├── replaying(ply)
  ├── suspended
  ├── terminal(result)
  └── recoveryError(record, reason)
```

Only the coordinator transitions state. Views send intents such as `pieceTapped`, `destinationTapped`, `hintTapped`, `undoTapped`, and `scenePhaseChanged`. Views do not call the engine or repository directly.

Invariant examples:

- At most one engine search exists per engine instance.
- A committed move is persisted before starting the next turn's search.
- Replay state cannot commit moves.
- Theme changes cannot transition game state.
- The engine can return many analysis updates but at most one accepted `bestMove` per request.

## 6. Pikafish integration

### 6.1 Reviewed engine surface

The fork at commit `6a59ee2f7b105bff64d9efc2692591107787e2b1` exposes:

- `Engine::set_position(fen, moves)` for validated state setup.
- Non-blocking `Engine::go(limits)` plus `stop()` and `wait_for_search_finished()`.
- Callbacks for iteration, full analysis updates, search start, best move, and NNUE verification.
- Options including Threads, Hash, Ponder, MultiPV, Move Overhead, UCI_ShowWDL, and EvalFile.
- UCI coordinate moves using files `a...i` and ranks `0...9`.

`Engine` does not expose public root legal-move enumeration or adjudication. The custom bridge must add those operations using `MoveList<LEGAL>`, `UCIEngine::move`, and `Position::rule_judge` at the pinned revision. The upstream UCI lifecycle is documented in [Pikafish UCI & Commands](https://github.com/official-pikafish/Pikafish/wiki/UCI-%26-Commands). The app uses the in-process API but preserves the same conceptual lifecycle in tests.

### 6.2 Bridge API sketch

Names are illustrative; the represented operations, ownership, and behavior are normative. The checked-in header must compile as C11 and be exercised by a C smoke test.

```c
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct PFSession PFSession;

typedef struct {
  int32_t code;                 // zero when no error
  char message_utf8[512];       // always NUL-terminated
} PFError;

typedef struct {
  int32_t move_time_ms;         // zero means unset
  int32_t depth;                // zero means unset
  uint64_t nodes;               // zero means unset
} PFSearchLimits;

typedef struct {
  char **items_utf8;            // bridge-owned copies
  size_t count;
} PFMoveList;

typedef enum {
  PF_OUTCOME_ACTIVE = 0,
  PF_OUTCOME_RED_WIN,
  PF_OUTCOME_BLACK_WIN,
  PF_OUTCOME_DRAW
} PFOutcomeKind;

typedef enum {
  PF_REASON_NONE = 0,
  PF_REASON_CHECKMATE,
  PF_REASON_STALEMATE,
  PF_REASON_REPETITION,
  PF_REASON_PERPETUAL_CHECK,
  PF_REASON_PERPETUAL_CHASE,
  PF_REASON_RULE_60,
  PF_REASON_INSUFFICIENT_MATERIAL
} PFOutcomeReason;

typedef struct {
  PFOutcomeKind kind;
  PFOutcomeReason reason;
} PFOutcome;

typedef struct {
  char engine_revision_utf8[41];
  char nnue_sha256_utf8[65];
} PFBuildInfo;

typedef struct {
  int depth;
  int sel_depth;
  int multipv;
  int score_cp;
  int mate_in;
  uint64_t nodes;
  uint64_t nps;
  int time_ms;
  const char *pv_utf8;
} PFAnalysis;

typedef void (*PFAnalysisCallback)(void *context, const PFAnalysis *analysis);
typedef void (*PFBestMoveCallback)(void *context,
                                   const char *best_move_utf8,
                                   const char *ponder_utf8);

PFSession *pf_session_create(const char *nnue_path_utf8,
                             PFError *error);
void pf_session_destroy(PFSession *session);

bool pf_session_set_position(PFSession *session,
                             const char *fen_utf8,
                             const char *const *moves_utf8,
                             size_t move_count,
                             PFError *error);

bool pf_session_copy_legal_moves(PFSession *session,
                                 PFMoveList *moves,
                                 PFError *error);
void pf_move_list_destroy(PFMoveList *moves);

bool pf_session_copy_outcome(PFSession *session,
                             PFOutcome *outcome,
                             PFError *error);

bool pf_session_start_search(PFSession *session,
                             const PFSearchLimits *limits,
                             int multipv,
                             void *context,
                             PFAnalysisCallback analysis,
                             PFBestMoveCallback best_move,
                             PFError *error);

void pf_session_stop(PFSession *session);
void pf_session_wait_until_idle(PFSession *session);
PFBuildInfo pf_copy_build_info(void);
```

Bridge requirements:

- No C++ exception crosses the boundary.
- Error strings are copied into fixed caller-owned storage. Move strings are bridge-owned copies released only by `pf_move_list_destroy`. Callback strings and analysis payloads are borrowed only for the duration of the callback.
- The Swift callback trampoline copies every borrowed payload before the callback returns, then hops to Swift concurrency.
- Destroy blocks until engine workers finish.
- Calls that mutate/search a session must arrive serially.
- Legal move enumeration reuses Pikafish `MoveList<LEGAL>` and the engine's coordinate conversion so the UI does not maintain a second move generator.
- `pf_session_copy_outcome` classifies no-legal-move as a loss for the side to move and maps the pinned `rule_judge` result to a stable, tested app reason.
- The bridge validates NNUE availability and returns a recoverable typed error instead of terminating the app.

Several upstream fatal paths call `exit`/`std::exit`, including NNUE, memory, thread, transposition-table, and UCI paths. M0 must enumerate every path reachable by the iOS target and either exclude it from the target, pre-validate its inputs, or patch it to return a typed error. Malformed restore data, resource exhaustion, or a missing/incompatible NNUE must not terminate the iOS process.

### 6.3 Build integration

- Pin Pikafish by commit or submodule revision; never build from a moving branch in release CI.
- Maintain iOS-specific build patches as small, reviewable commits in the fork.
- Compile arm64 device and arm64/x86_64 simulator slices as required by the supported toolchain.
- Use Apple Clang and libc++; enable C++ hardening/assertions in Debug and appropriate optimization in Release.
- Disable command-line `main.cpp` for the library target.
- Bundle a known-compatible `pikafish.nnue` as a read-only app resource located through `Bundle`; record its SHA-256 in generated build metadata.
- Verify the engine source commit and NNUE checksum at startup in Debug and in release CI.
- Do not copy the NNUE to a writable location and do not download a replacement engine, NNUE, or configuration at runtime. All engine and model updates ship through an app update.

The upstream Makefile has armv8, armv8-dotprod, arm64-universal, and Apple Silicon profiles but its Darwin path targets macOS. iOS requires a dedicated Xcode/CMake build configuration with the iPhoneOS SDK, deployment target, and simulator slices; using the macOS `apple-silicon` target unchanged is not sufficient.

## 7. Engine actor and search lifecycle

`PikafishEngineActor` owns exactly one session for MVP.

```swift
actor PikafishEngineActor: EngineClient {
    func prepare(configuration: EngineConfiguration) async throws
    func setPosition(_ snapshot: SearchPosition) async throws
    func bestMove(request: SearchRequest) async throws -> EngineMove
    func hint(request: SearchRequest) -> AsyncThrowingStream<AnalysisUpdate, Error>
    func stop() async
}
```

Lifecycle for a computer move:

1. Coordinator commits/persists the human move.
2. Coordinator creates request with game ID and position version.
3. Actor waits until prior search is idle.
4. Actor sets position from start FEN plus moves.
5. Actor applies resource and difficulty options while idle.
6. Actor starts search and forwards throttled analysis updates.
7. Best move callback resumes the awaiting task exactly once.
8. Coordinator checks request identity and legality.
9. Coordinator commits and persists the computer move.

Cancellation:

- Swift task cancellation calls `stop`, then waits for search completion on the actor executor.
- The continuation is completed once with `CancellationError` if no accepted best move is needed.
- Late native callbacks are ignored through request tokens but still released safely.
- App suspension, undo, new game, and deinit follow the same cancellation path.

Never hold the main actor while waiting for native search completion.

## 8. Engine configuration

Initial safe defaults for measurement, not final tuning:

| Option | Play | Hint |
| --- | --- | --- |
| Threads | 1–2, device policy | 1–2 |
| Hash | 32–64 MB | shared setting |
| Ponder | false | false |
| MultiPV | difficulty policy; 1 at strong levels | 3 |
| UCI_ShowWDL | false | false |
| Move Overhead | 50–150 ms after calibration | N/A |

Read-only move replay does not start a search. Engine-backed post-game review belongs to the Study release.

Resource policy observes:

- `ProcessInfo.processInfo.thermalState`.
- Low Power Mode.
- App scene activity.
- Device memory class if a measured distinction is necessary.

Rules:

- Stop all search when the app is inactive/backgrounded.
- Do not claim background engine computation.
- Reduce time/nodes before increasing threads.
- Never allocate a user-configurable unbounded hash.
- Cache engine/NNUE initialization across games when safe, but clear search state for a new game.

## 9. Difficulty implementation

Difficulty uses two layers:

1. Search budget: time, nodes, or depth ceiling calibrated per device tier.
2. Move policy: optionally select from completed MultiPV candidates within a maximum evaluation-loss envelope.

```text
candidate is eligible when:
  legal(candidate.move)
  and bestScore - candidateScore <= level.maxLoss
  and candidate.depth >= level.minCompletedDepth
```

Use a seeded weighted choice for Levels 1–2. Levels 3–5 select the best completed line; their strength difference comes from calibrated search budgets, not move randomization. Record policy version, candidate set summary, seed, and selected move in debug builds and user-exported TestFlight diagnostics. Production game records contain only policy version and seed; the app never uploads diagnostics automatically.

Do not simulate weakness by inserting arbitrary illegal-looking moves or blocking the main thread. Verify mate scores and side-to-move score normalization before applying loss envelopes.

## 10. Rules session

Define a protocol even though the first implementation is Pikafish-backed:

```swift
struct RulesSnapshot: Sendable {
    let position: Position
    let legalMoves: [Move]
    let outcome: GameOutcome?
}

protocol RulesSession: Sendable {
    func load(startingFEN: String, moves: [RecordedMove]) async throws -> RulesSnapshot
    func notation(for move: Move, locale: Locale) async throws -> String
}
```

The engine bridge is authoritative for legal move generation in MVP. The rules policy ID is `pikafish-computer-rule@6a59ee2f7b105bff64d9efc2692591107787e2b1`. Root adjudication calls the bridge operation backed by `Position::rule_judge`, distinguishes checkmate from stalemate when no legal move exists, and is verified with explicit history fixtures. Do not infer an outcome only from absence of a best move. A Pikafish upgrade creates a new policy ID until fixture comparison proves migration-safe behavior.

For responsive touch, cache legal moves for the current position on entering the human turn. Selecting a piece filters the cache locally. Invalidate the cache on every committed state change.

## 11. Persistence

MVP storage:

- Atomic JSON files behind `GameRepository`, stored in Application Support with `Data.WritingOptions.atomic` and `.completeFileProtection`. Use one active-game file and a separate completed-summary file; do not introduce SQLite/SwiftData for 1.0.
- One active record plus completed game summaries.
- User preferences in `UserDefaults`/AppStorage where appropriate.
- No iCloud dependency in MVP.

Write behavior:

1. Encode next record to a temporary location/transaction.
2. Flush/commit atomically.
3. Update in-memory “saved version.”
4. Only then start the next engine turn.

Migration:

- Every record has `schemaVersion`.
- Migrations are deterministic and tested with checked-in fixtures.
- Unknown future versions open in protected recovery mode and are never overwritten.

The durable `ClockState` stores remaining durations only. While the game screen and scene are active, an in-memory clock runtime holds the active side and a monotonic `ContinuousClock` instant. Before every durable write, compute the delta since that instant, update the active side's remaining duration, add the delta to `activeElapsedMilliseconds`, and reset the instant. Leaving the game screen or becoming inactive performs this write and then discards the instant. Resume creates a new instant; never persist a monotonic instant or subtract wall-clock time spent away or in the background. Result-sheet “duration” means this active elapsed time for both casual and timed games.

## 12. Theme implementation

`XiangqiBoardUI` renders from semantic tokens:

```swift
protocol BoardTheme: Sendable {
    var id: ThemeID { get }
    var colors: BoardColors { get }
    var metrics: BoardMetrics { get }
    var pieces: PieceAssetProvider { get }
    var effects: BoardEffects { get }
    var sounds: BoardSounds { get }
}
```

Architecture rules:

- `GameViewModel` contains no color, asset name, font, or sound file.
- Theme selection is an environment dependency.
- Board geometry/hit testing is one implementation shared by themes.
- Piece assets are resolved by `side + kind + locale/display style`, never by FEN character directly.
- Theme snapshot tests render the exact same fixture positions and state overlays.
- Missing theme resources fail validation in CI and fall back to Classic at runtime.

Use a Canvas/Shape layer for board lines and individual SwiftUI/accessibility elements for pieces and destinations. Keep model coordinates separate from rendered transforms so flip/rotation cannot affect move semantics.

## 13. Concurrency and thread safety

- UI feature state mutates on `@MainActor`.
- Native engine calls are isolated to `PikafishEngineActor`.
- Persistence uses its own actor or serial repository context.
- Bridge callbacks never mutate UI state directly; copy payload, hop into Swift concurrency, then validate request identity.
- Mark bridged types `Sendable` only when ownership is genuinely immutable or isolated.
- Use Thread Sanitizer on simulator bridge tests where supported and native sanitizers in dedicated C++ CI jobs.

Potential race cases that require tests:

- Undo during search.
- App inactive immediately before best move callback.
- Double-tap Hint.
- Start new game while old search stops.
- Restore a game whose turn is the computer.
- Theme change during move animation.
- Result detected while an analysis update is queued.

## 14. Error model

Use typed errors with a player-safe message and diagnostic payload.

```swift
enum EngineError: Error {
    case nnueMissing(expectedResource: String)
    case nnueIncompatible(expectedHash: String, actualHash: String?)
    case invalidPosition(fen: String, reason: String)
    case illegalMove(String)
    case searchAlreadyRunning
    case initializationFailed(String)
    case cancelled
}
```

Fatal-to-session errors stop play, preserve the record, and offer Retry/Home/Copy diagnostics. They must not call `abort`, `exit`, or crash intentionally in Release. Programmer invariants may assert in Debug.

## 15. Security and privacy

- The 1.0 production target contains no URL loading, socket, WebSocket, account, remote-config, push-notification, or cloud-sync dependency. A runtime network-attempt test is part of release acceptance.
- Treat imported FEN/game data in later releases as untrusted: length-limit and validate before the native boundary.
- Never pass user-controlled paths to `EvalFile` in production.
- Bundle resources read-only; write saves only inside the app container.
- Strip or gate debug engine logs because they may contain user positions.
- Do not expose a generic UCI command console in production.
- Do not download engines, NNUE files, or executable code. Apple's current program terms state that apps generally may not download or install executable code; see [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/).

## 16. Licensing and distribution

Pikafish is GPLv3. Distribution of an app containing it requires a deliberate compliance plan reviewed by the publisher's legal counsel.

Release requirements:

- Include the GPLv3 license text and Pikafish attribution in the app.
- Provide the complete corresponding source for the exact distributed engine binary, including iOS build scripts, bridge modifications, and relevant configuration.
- Link the exact tagged source from Settings → About → Open Source.
- Retain copyright notices and AUTHORS.
- Record engine commit, patch set, compiler/toolchain, build flags, NNUE source, and checksum in release artifacts.
- Review whether and how GPL obligations apply to the combined app, its Swift code, App Store distribution terms, and any proprietary assets. This specification does not replace legal advice.

The fork's README explicitly states the GPLv3 source-availability obligation. The product must not postpone compliance until submission.

## 17. Testing strategy

### 17.1 Native engine tests

- Build bridge for device and simulator architectures.
- Initialize/verify known NNUE.
- Starting FEN round-trip.
- Legal moves for checked-in tactical/rules fixtures.
- Search returns legal best move.
- Stop/wait and destroy under active search.
- Malformed FEN and illegal move return errors without process termination.
- Repeated create/destroy leak test.
- Fixed nodes test for repeatable CI where practical.

### 17.2 Domain/property tests

- UCI square and move encode/decode for every board square.
- Orientation transform is invertible for all 90 intersections.
- Applying and undoing a move restores identical record/position.
- Every legal generated move applied to a position remains internally valid.
- Random legal playout differential test against bridge position validation.
- Serialization round-trip and schema migration fixtures.
- Stale position versions never commit.

### 17.3 Feature tests

- Human move → persist → computer search → commit → persist.
- Hint stage transitions and invalidation.
- Undo while idle/searching/callback queued.
- Resume on human/computer turn.
- Clock expiry versus near-simultaneous move.
- Resign/new game confirmations.
- Theme change preserves identical game state.

### 17.4 UI and accessibility tests

- Tap and drag all piece types.
- Board flipped and unflipped.
- VoiceOver labels/actions and focus order.
- Dynamic Type, Reduce Motion, Increased Contrast.
- Smallest supported iPhone and common current sizes.
- Three themes across selection, legal move, capture, hint, check, and terminal fixtures.
- Screenshot comparisons use tolerances for antialiasing but zero tolerance for board geometry drift.

### 17.5 Performance tests

- Cold engine initialization.
- Legal-move cache latency.
- Time-to-first completed analysis iteration.
- Stop latency.
- Memory at idle, search, repeated games, and theme changes.
- 30-minute thermal soak at Level 5 on oldest supported device.
- Background/foreground loop and memory-warning response.

## 18. CI and release artifacts

CI produces:

- App build and tests.
- Native bridge unit tests.
- Engine commit and diff/patch manifest.
- NNUE SHA-256.
- Architecture/symbol check for the embedded library.
- Open-source notice bundle.
- Corresponding-source archive or verified public tag URL.
- Theme asset validation and snapshots.
- Performance baseline from scheduled physical-device CI when available.

Release build fails if engine revision, NNUE checksum, source link, or license bundle is missing.

## 19. Implementation milestones

### M0 — Feasibility spike

- Build Pikafish as an iOS static library for device and simulator.
- Load bundled NNUE.
- Set start position, enumerate legal moves, run a short search, stop it, and receive best move.
- Measure binary size, initialization, memory, NPS, cancellation, and thermal behavior on iPhone XR and one current iPhone.

Exit: results recorded and no process-exit/error-path blocker remains.

### M1 — Headless game

- Domain types, rules session, engine actor, state machine, persistence.
- Complete automated Player vs Computer games without UI.
- Undo, hint, terminal detection, and restore tests.

Exit: deterministic integration suite and random playout differential suite pass.

### M2 — Playable Classic UI

- Home, setup, game board, actions, result, settings.
- Tap/drag, sound/haptics, VoiceOver path.
- Physical-device performance tuning.

Exit: complete game meets correctness and latency targets.

### M3 — Product polish

- Tournament and Calm themes.
- Move history/replay.
- Localization, accessibility matrix, restore/recovery UX.
- TestFlight diagnostics and GPL release artifacts.

Exit: all product acceptance criteria pass.

## 20. Technical risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Upstream engine assumes desktop/process behavior | Crash or unsupported APIs on iOS | M0 library spike; remove CLI exit paths; isolate platform patch set |
| NNUE size/startup cost | Large app and slow first game | Measure the bundled NNUE; lazy prepare from Home; checksum and fail with a recoverable error if incompatible |
| Stale async best move | Corrupt game | Position versions, request IDs, serialized actor, legality recheck |
| Duplicate rules logic | UI/engine divergence | Pikafish-backed legal move enumeration; differential playout tests |
| Thermal/battery load | Poor reviews and throttling | No ponder, bounded threads/hash, adaptive budgets, soak tests |
| Complex repetition/chase rules | Incorrect result | Versioned rule policy and curated fixture suite before release |
| GPL/App Store obligations | Distribution risk | Compliance plan and corresponding-source artifacts from first build |
| Theme customization breaks play | Mis-taps/accessibility regressions | Shared geometry/semantics and cross-theme fixture snapshots |

## 21. Source grounding

- [User's Pikafish fork](https://github.com/frankmanzhu/Pikafish), inspected at commit `6a59ee2f7b105bff64d9efc2692591107787e2b1`.
- [Official Pikafish repository and GPL notice](https://github.com/official-pikafish/Pikafish).
- [Pikafish UCI & Commands](https://github.com/official-pikafish/Pikafish/wiki/UCI-%26-Commands).
- [Apple: Mixing Languages in an Xcode project](https://developer.apple.com/documentation/swift/mixinglanguagesinanxcodeproject).
- [Apple: C++ language support](https://developer.apple.com/xcode/cpp/).
- [Apple: Designing for games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games).
- [Apple: Encrypting your app's files](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files).
- [Apple: iOS 18 compatible iPhone models](https://support.apple.com/en-au/104985).
- [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/).
- [XiangqiAI](https://xiangqiai.com), inspected as interaction and layout guidance on 2026-09-20.
