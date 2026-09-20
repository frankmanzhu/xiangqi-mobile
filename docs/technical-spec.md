# Xiangqi Mobile — technical specification

Status: proposed architecture for MVP  
Client: native SwiftUI iOS application  
Engine: Pikafish C++ embedded in-process  
Primary quality attribute: correct, cancellable, recoverable game state

## 1. Architectural decision

Compile a pinned Pikafish revision and its NNUE network into the app distribution, expose a narrow C-compatible bridge, and call it from Swift through an isolated engine actor.

Do not launch Pikafish as a child process. iOS apps should not depend on a shell/`Process` workflow, and Apple distribution rules prohibit downloading or installing executable code outside the permitted model. Bundling and compiling the engine also makes startup, cancellation, resource control, and version reporting deterministic.

Although current Xcode supports direct Swift/C++ interoperability, the MVP should prefer a small C ABI or Objective-C++ facade because it:

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
    └── engine/network version reporting
              │
              ▼
Pinned Pikafish C++ sources + pinned pikafish.nnue
```

The app is a local client, not a client/server system. No network service is required for MVP.

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
enum Side: String, Codable, Sendable { case red, black }

enum PieceKind: String, Codable, Sendable {
    case general, advisor, elephant, horse, chariot, cannon, soldier
}

enum PlayerController: Codable, Sendable {
    case localHuman
    case computer(DifficultyPolicyID)
    case remoteHuman(RemotePlayerID) // reserved for the online release
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

struct Position: Equatable, Codable, Sendable {
    let fen: String
    let sideToMove: Side
    let pieces: [PlacedPiece]
}

struct GameRecord: Codable, Sendable {
    let id: UUID
    let schemaVersion: Int
    let rulesPolicy: RulesPolicyID
    let engineBuild: EngineBuildID
    let startingFEN: String
    let mode: GameMode
    var moves: [RecordedMove]
    var status: GameStatus
    var clocks: ClockState?
    var settings: GameSettingsSnapshot
    var updatedAt: Date
}
```

Primary persisted truth is `startingFEN + ordered UCI moves + rules policy/version`. A cached current FEN and board snapshot may speed launch but must be validated/reconstructable from the primary truth.

### Position version

Every committed position has a monotonically increasing `PositionVersion` scoped to a game session. Engine searches and hint requests capture it. A result is accepted only if:

- Game ID matches.
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
- Callbacks for iteration, full analysis updates, search start, best move, and network verification.
- Options including Threads, Hash, Ponder, MultiPV, Move Overhead, UCI_ShowWDL, and EvalFile.
- UCI coordinate moves using files `a...i` and ranks `0...9`.

The upstream UCI lifecycle is documented in [Pikafish UCI & Commands](https://github.com/official-pikafish/Pikafish/wiki/UCI-%26-Commands). The app may use the in-process API but should preserve the same conceptual lifecycle in tests.

### 6.2 Bridge API sketch

Names are illustrative; ownership and behavior are normative.

```c
typedef struct PFSession PFSession;

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
                                 PFMoveBuffer *buffer,
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
- Returned strings have documented ownership and UTF-8 encoding.
- Callback payloads are copied before the callback returns.
- Destroy blocks until engine workers finish.
- Calls that mutate/search a session must arrive serially.
- Legal move enumeration reuses Pikafish `MoveList<LEGAL>` and the engine's coordinate conversion so the UI does not maintain a second move generator.
- The bridge validates NNUE availability and returns a recoverable typed error instead of terminating the app.

The current UCI wrapper calls `std::exit` on critical errors. The embedded bridge must not use that path; adapt errors into results so malformed restore data or a missing network cannot terminate the iOS process.

### 6.3 Build integration

- Pin Pikafish by commit or submodule revision; never build from a moving branch in release CI.
- Maintain iOS-specific build patches as small, reviewable commits in the fork.
- Compile arm64 device and arm64/x86_64 simulator slices as required by the supported toolchain.
- Use Apple Clang and libc++; enable C++ hardening/assertions in Debug and appropriate optimization in Release.
- Disable command-line `main.cpp` for the library target.
- Bundle a known-compatible `pikafish.nnue`; record SHA-256 in generated build metadata.
- Verify the engine source commit and network checksum at startup in Debug and in release CI.
- Do not download a replacement engine or executable at runtime. Network/model updates ship through an app update unless a later legal/security review approves a signed data-only NNUE update mechanism.

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

| Option | Play | Hint | Review |
| --- | --- | --- | --- |
| Threads | 1–2, device policy | 1–2 | 1–2 |
| Hash | 32–64 MB | shared setting | 64 MB if memory allows |
| Ponder | false | false | false |
| MultiPV | difficulty policy; 1 at strong levels | 3 | 1 initially; 3 in Study release |
| UCI_ShowWDL | false | false | true when advanced evaluation needs it |
| Move Overhead | 50–150 ms after calibration | N/A | N/A |

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
- Cache engine/network initialization across games when safe, but clear search state for a new game.

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

Use a seeded weighted choice for Levels 1–2; Levels 4–5 select the best completed line. Record policy version, candidate set summary, seed, and selected move in debug/TestFlight diagnostics. Production records need only policy version and seed unless diagnostics consent is enabled.

Do not simulate weakness by inserting arbitrary illegal-looking moves or blocking the main thread. Verify mate scores and side-to-move score normalization before applying loss envelopes.

## 10. Rules session

Define a protocol even if the first implementation is Pikafish-backed:

```swift
protocol RulesSession: Sendable {
    func position(startingFEN: String, moves: [Move]) async throws -> Position
    func legalMoves(from square: Square?, in position: PositionID) async throws -> [Move]
    func outcome(in position: PositionID, history: PositionHistory) async throws -> GameOutcome?
    func notation(for move: Move, locale: Locale) async throws -> String
}
```

The engine bridge is authoritative for legal move generation in MVP. Repetition/chase adjudication must be implemented against the selected Computer Rule policy with explicit history fixtures; do not infer it only from absence of a best move.

For responsive touch, cache legal moves for the current position on entering the human turn. Selecting a piece filters the cache locally. Invalidate the cache on every committed state change.

## 11. Persistence

Recommended MVP storage:

- Atomic JSON or SQLite/SwiftData repository behind `GameRepository`.
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

Clock persistence stores remaining durations plus a monotonic/absolute checkpoint sufficient to reconstruct foreground elapsed time. Since MVP does not allow background play, suspend the game clock when the scene becomes inactive unless product later specifies real-time clocks.

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
    case networkMissing(expectedPath: String)
    case networkIncompatible(expectedHash: String, actualHash: String?)
    case invalidPosition(fen: String, reason: String)
    case illegalMove(String)
    case searchAlreadyRunning
    case initializationFailed(String)
    case cancelled
}
```

Fatal-to-session errors stop play, preserve the record, and offer Retry/Home/Copy diagnostics. They must not call `abort`, `exit`, or crash intentionally in Release. Programmer invariants may assert in Debug.

## 15. Security and privacy

- No network entitlement is required for core gameplay.
- Treat imported FEN/game data in later releases as untrusted: length-limit and validate before the native boundary.
- Never pass user-controlled paths to `EvalFile` in production.
- Bundle resources read-only; write saves only inside the app container.
- Strip or gate debug engine logs because they may contain user positions.
- Do not expose a generic UCI command console in production.
- Do not download executable engines. Apple's current program terms state that apps generally may not download or install executable code; see [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/).

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

CI should produce:

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
- Measure binary size, initialization, memory, NPS, cancellation, and thermal behavior on one old and one current iPhone.

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
| NNUE size/startup cost | Large app and slow first game | Measure current network; lazy prepare from Home; checksum and compatible fallback strategy |
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
- [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/).
- [XiangqiAI](https://xiangqiai.com), inspected as interaction and layout guidance on 2026-09-20.
