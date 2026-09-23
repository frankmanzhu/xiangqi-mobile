# Xiangqi Mobile

Xiangqi Mobile is a native, offline SwiftUI app for playing xiangqi locally. It supports Player vs Computer and two-player hot-seat games, full move replay, atomic save/resume, clocks, undo, hints, three visual themes, and portable game sharing.

The canonical game record is `starting FEN + ordered UCI moves + versioned rules policy`. Human-readable notation is derived from that record, so a game can be reconstructed independently of the UI and can form the payload for later online play.

## Build and test

- Open `XiangqiMobile.xcodeproj` in Xcode and run the `XiangqiMobile` scheme.
- Run domain tests with `swift test`.
- Run the real-engine bridge smoke test with `scripts/test_pikafish_bridge.sh`.
- Regenerate the checked-in Xcode project after adding source files with `ruby scripts/generate_project.rb`.
- Regenerate the typed string keys after editing a `Localizable.strings` file with `python3 scripts/l10n.py generate`.

## Localization

Each language has its own file: `Resources/Localizations/en.lproj/Localizable.strings`,
`zh-Hans.lproj/Localizable.strings`, and `zh-Hant.lproj/Localizable.strings`. A
contributor translating one language only ever touches their own file. `en.lproj`
is the source of truth for the key set — adding or renaming a key happens there
first, then the same key is added to the other two files.

`scripts/l10n.py generate` derives `XiangqiMobile/App/Localization/Strings+Generated.swift`
from the English file, giving each key a typed constant such as `L10n.Home.Hero.title`.
Views reference those constants, so a key can never drift from the source file.
`scripts/l10n.py check` fails when the generated file is stale, a translation is
missing from `zh-Hans`/`zh-Hant`, or a key is no longer referenced by any view —
run it in CI.

Views render strings through `\.l10n`, a `Localizer` that resolves against the
`.lproj` bundle for the selected language. SwiftUI's `\.locale` drives date and
number formatting but does not redirect string lookup, so the in-app language
picker needs this explicit bundle to take effect without restarting the app.

Because each view resolves its text while its body runs, changing that
environment value is enough to re-render everything — the language modifier
deliberately does *not* attach an `.id()`. Forcing a rebuild re-creates the
`NavigationStack`, which resets its content to the top while the existing
navigation bar keeps its collapsed state, leaving an inline title and an
expanded large title drawn over the first row.

Two things are deliberately *not* translated: `Side.recordName` and
`PieceKind.recordName`, which build the portable game record. A saved or shared
record must read the same in every language.

The project's `knownRegions` must list every shipped language. Xcode silently
drops translations for regions missing from it; `scripts/generate_project.rb`
sets them.

## Settings behaviour

Every toggle in Settings drives something:

- **Coordinates** labels the board's files (a–i) and ranks (0–9), matching the
  move record. `Red perspective` shows them only while the board is viewed from
  red's side; `Always` keeps them through a flip, where they run the other way.
  Showing them widens the board's leading margin so the digits sit clear of the
  edge pieces.
- **Sound effects** plays a cue for a move, a capture, check, the end of a game,
  and a wrong move in practice. The cues are synthesized at runtime from
  `GameSoundRecipe` rather than bundled as audio, which keeps the app asset-free
  and the sounds testable — see `SoundSynthesisTests`. To retune one, change the
  numbers in the recipe. The audio session is `.ambient`, so the game mixes with
  whatever is already playing and the ring switch silences it.
- **Haptics** pairs each of those events with a matching impact or notification.

Audio work runs on its own queue. Activating a session or building an
`AVAudioPlayer` blocks on the audio server, and on the main thread that trips
UIKit's hang-risk check and can stall the tap that caused the sound.

Failures reach the player as translated sentences, not Swift error dumps.
`UserFacingError` maps each thrown error to a catalog key and writes the
technical detail to the `com.frankzhu.xiangqi-mobile` log subsystem instead, so
the screen stays readable without losing anything to debugging.

Settings whose stored vocabulary changed are normalized once at launch by
`PreferenceMigration`, so a value written by an older build still selects the
right option instead of leaving the picker blank.

## Theming

A theme is a `Theme` value — semantic colours, shape metrics, and a preferred
colour scheme — not a case in a switch. `ThemeRegistry` holds the built-ins and
accepts more through `ThemeRegistry.register(_:)`, so adding a look means adding
one value and no view changes. Views read `\.theme` from the environment.

`ThemeID` is an open string identifier, so a saved game naming a theme this build
no longer ships still decodes; the registry substitutes its fallback.

## CCPD learning corpus

The `ccpd-import` Swift executable decodes and validates the pinned [Chinese Chess Practical Dataset](https://github.com/Yvonne761/Chinese-Chess-Practical-Dataset) before it is packaged for offline learning. It accepts the repository's Big5/HKSCS or UTF-8 PGN files, parses Chinese move notation against each position, emits canonical UCI records, and quarantines invalid or ambiguous source records with an audit report.

```sh
swift run -c release ccpd-import \
  /path/to/Chinese-Chess-Practical-Dataset/Dataset \
  /path/to/output \
  --source-revision 368a47a947773dd8692c026e286dd19b6277b993 \
  --database-only
```

Generated files are the indexed native library `ccpd.sqlite3`, `ccpd-quarantine.jsonl`, and `ccpd-audit.json`. Omit `--database-only` when a portable `ccpd-records.jsonl` export is also needed. Source identity, expected category counts, attribution, and modification notices are recorded in `Resources/Learning/CCPD-source.json`; the bundled license notice is under `Resources/Licenses`.

The original CCPD import was generated from pinned commit `368a47a947773dd8692c026e286dd19b6277b993` and contains 58,456 legality-validated records. The shipped database is now a merged, legality-validated corpus of 145,065 records. It retains the original CCPD records and adds unique games transformed from the public WXF and Dongping ICCS collections. The shipped database SHA-256 is `86779b0419a1bf058ab211046418333fb89cd0f5172681523016bd246f345358`.

### Validating ICCS game collections

`iccs-validate` is the batch checker for downloaded ICCS `.pgn`/`.pgns` collections. It replays every move from the tagged FEN, distributes games across worker processes/threads, canonicalizes each replayable game as `FEN + UCI moves`, and removes exact duplicates across all input files. It keeps the raw downloads unchanged and writes:

- `Processed/unique-games.jsonl` — replayable, unique games.
- `Duplicates/duplicate-games.jsonl` — replayable games whose canonical sequence already appeared.
- `Failed/invalid-games.jsonl` — games with malformed structure, unknown tokens, invalid FENs, or an illegal move, including the failing ply and position.
- `manifest.json` — counts, worker count, source names, and warning totals.

Run it against local downloads with:

```sh
swift run -c release iccs-validate tempData tempData/Validation --workers 8
```

The whole `tempData/` directory is ignored by Git, so downloaded source archives and generated validation output are not committed accidentally. The WXF and Dongping game files were downloaded from publicly available online locations, replay-validated, deduplicated, and transformed from ICCS into the normalized SQLite format for offline learning and replay. The source manifest records the known provenance and the remaining source-license uncertainty; public availability alone is not presented as a separate license grant.

To build a staged merged database without changing the bundled app resource:

```sh
swift run -c release ccpd-merge \
  Resources/Learning/ccpd.sqlite3 \
  tempData/Validation \
  tempData/Merge
```

The merger backs up the current database, skips canonical duplicates, preserves original ICCS notation alongside UCI moves, and writes the candidate database plus `merge-report.json`, `verification-report.json`, and `source-manifest.json` under `tempData/Merge`. The checked-in seed was produced from that candidate after replay, uniqueness, storage, and schema verification.

### Shipped library and user game library

`Resources/Learning/ccpd.sqlite3` is the read-only shipped seed. The app opens it without write access and replaces it only when a new app version is installed. On first use, the app creates a separate writable `user-games.sqlite3` in its Application Support directory. Learning screens read both databases as one library, while app updates leave user-imported games untouched. Future import tools should write only to the user database and use IDs in the `user:` namespace so they cannot collide with shipped records.

The shipped seed is for human learning, browsing, and replay. These game records are not used to train Pikafish or to generate engine hints.

In the Learning screen, the `對局` (Matches) category can be narrowed by collection: CCPD master matches, CCPD computer matches, WXF ICCS matches, or Dongping ICCS matches. The search field searches the imported metadata for player names, events or tournaments, ECCO/opening codes, dates or years, and results. The original CCPD master collection preserves its player-organized source paths; tournament, opening, and year discovery is provided through the searchable metadata.

The app performs no network requests and has no account or online-play code. Computer play uses Pikafish compiled in-process from submodule revision `6a59ee2f7b105bff64d9efc2692591107787e2b1`, plus the bundled `pikafish.nnue` network with SHA-256 `7d13d73569a9b571ba0eb20cf1596247bc2a42738967e61afef6482b231e900e`. There is no alternate or fallback computer player. The engine receives the canonical starting FEN and complete ordered UCI move history for every search.

## Licensing and source availability

Copyright (c) 2026 Frank Zhu

Xiangqi Mobile is licensed under the GNU General Public License, version 3 or any later version (GPL-3.0-or-later). The app embeds Pikafish in-process, so the distributed application and its corresponding source are provided under GPL-compatible terms. The root [`LICENSE`](LICENSE) file identifies the project license; the complete GPL text, Pikafish attribution, and authors list are bundled under `Resources/Licenses`.

For every distributed version, the complete corresponding source is available from the matching release tag or commit in the [Xiangqi Mobile repository](https://github.com/frankmanzhu/xiangqi-mobile). This includes the Swift application and GUI source, the Pikafish submodule at the exact revision used for the build, the C/C++ bridge, the Xcode project, build scripts, and required resources. Users may rebuild, modify, and sign the app with their own Apple Developer account. They do not need this project's signing credentials, and submitting a pull request is not required to exercise those rights.

To rebuild a modified iOS app, check out the matching source tag, open `XiangqiMobile.xcodeproj` in Xcode, select your own development team, change the bundle identifier if required by your provisioning profile, and build/sign/install the app on your device. The App Store binary is not the only permitted form of the software; GPL rights to modify and redistribute the source remain available.

### Rebuild and install a modified copy

The following procedure is the supported path for building a modified copy on a physical iPhone:

1. Install Xcode on a Mac and sign in with an Apple Developer account that can provision the target device. This project targets iOS 18.0 or later.
2. Clone the repository at the release tag or commit corresponding to the app version, then initialize the exact Pikafish source revision:

   ```sh
   git clone https://github.com/frankmanzhu/xiangqi-mobile.git
   cd xiangqi-mobile
   git checkout <release-tag-or-commit>
   git submodule update --init --recursive
   ```

3. Open `XiangqiMobile.xcodeproj` in Xcode and select the `XiangqiMobile` scheme.
4. In the target's **Signing & Capabilities** settings, select the user's own development team. If the bundle identifier is already registered to another team, replace `com.frankzhu.xiangqi-mobile` with a unique identifier owned by that team.
5. Connect the iPhone, select it as the run destination, and allow Xcode to register or provision the device. If iOS requests it, enable Developer Mode and trust the developer profile on the device.
6. Build and run. Xcode signs the modified app with the user's own account; no Xiangqi Mobile signing certificate or private key is required.

The source checkout must retain the bundled NNUE network, CCPD learning resources, license notices, and the Pikafish submodule revision used by the release. A modified build can use a different bundle identifier and can be installed separately from the App Store build.

Pikafish's GPL license cannot be removed by changing this README, changing the link mode, or changing the project's license label. Avoiding GPL obligations would require replacing Pikafish or obtaining relicensing permission from the relevant Pikafish copyright holders.

The learning corpus is separate data, not software. The original CCPD portion is available under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), with attribution and modification notices in `Resources/Learning/CCPD-source.json` and `Resources/Licenses/CCPD-CC-BY-4.0.txt`. The added public ICCS collections are described in [`Resources/Learning/CCPD-merged-sources.json`](Resources/Learning/CCPD-merged-sources.json); the app does not claim that GPL-3.0-or-later relicenses the underlying game data.

The product direction is documented in the [specification index](docs/README.md):

- [Product specification](docs/product-spec.md)
- [UX and visual specification](docs/ux-spec.md)
- [Technical specification](docs/technical-spec.md)

The implementation order and decision hierarchy are defined in the specification index. Do not add online controllers, services, schemas, dependencies, permissions, remote configuration, or placeholder UI to the 1.0 target.
