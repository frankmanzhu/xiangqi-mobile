# Xiangqi Mobile

Xiangqi Mobile is a native, offline SwiftUI app for playing xiangqi locally. It supports Player vs Computer and two-player hot-seat games, full move replay, atomic save/resume, clocks, undo, hints, three visual themes, and portable game sharing.

The canonical game record is `starting FEN + ordered UCI moves + versioned rules policy`. Human-readable notation is derived from that record, so a game can be reconstructed independently of the UI and can form the payload for later online play.

## Build and test

- Open `XiangqiMobile.xcodeproj` in Xcode and run the `XiangqiMobile` scheme.
- Run domain tests with `swift test`.
- Run the real-engine bridge smoke test with `scripts/test_pikafish_bridge.sh`.
- Regenerate the checked-in Xcode project after adding source files with `ruby scripts/generate_project.rb`.
- Regenerate the typed string keys after editing the String Catalog with `python3 scripts/l10n.py generate`.

## Localization

`Resources/Localizations/Localizable.xcstrings` is the single source of truth for
every user-facing string, in English, Simplified Chinese, and Traditional Chinese.
It is editable in Xcode's String Catalog editor.

`scripts/l10n.py generate` derives `XiangqiMobile/App/Localization/Strings+Generated.swift`
from it, giving each key a typed constant such as `L10n.Home.Hero.title`. Views
reference those constants, so a key can never drift from the catalog.
`scripts/l10n.py check` fails when the generated file is stale, a translation is
missing, or a key is no longer referenced by any view — run it in CI.

Views render strings through `\.l10n`, a `Localizer` that resolves against the
`.lproj` bundle for the selected language. SwiftUI's `\.locale` drives date and
number formatting but does not redirect string lookup, so the in-app language
picker needs this explicit bundle to take effect without restarting the app.

Two things are deliberately *not* translated: `Side.recordName` and
`PieceKind.recordName`, which build the portable game record. A saved or shared
record must read the same in every language.

The project's `knownRegions` must list every shipped language. Xcode silently
drops translations for regions missing from it; `scripts/generate_project.rb`
sets them.

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

The bundled database was generated from pinned commit `368a47a947773dd8692c026e286dd19b6277b993`. It contains 58,456 legality-validated records; 12 source files are excluded in the bundled quarantine report (6 invalid FENs and 6 illegal move sequences). Its SHA-256 is `7d258a7a4d3572c1c183ef39637af9fe879a193aec70bad86006e8c23c858fc8`.

The app performs no network requests and has no account or online-play code. Computer play uses Pikafish compiled in-process from submodule revision `6a59ee2f7b105bff64d9efc2692591107787e2b1`, plus the bundled `pikafish.nnue` network with SHA-256 `7d13d73569a9b571ba0eb20cf1596247bc2a42738967e61afef6482b231e900e`. There is no alternate or fallback computer player. The engine receives the canonical starting FEN and complete ordered UCI move history for every search.

## Licensing and source availability

Xiangqi Mobile is licensed under the GNU General Public License, version 3 or any later version (GPL-3.0-or-later). The app embeds Pikafish in-process, so the distributed application and its corresponding source are provided under GPL-compatible terms. The root [`LICENSE`](LICENSE) file identifies the project license; the complete GPL text, Pikafish attribution, and authors list are bundled under `Resources/Licenses`.

For every distributed version, the complete corresponding source is available from the matching release tag or commit in the [Xiangqi Mobile repository](https://github.com/frankmanzhu/xiangqi-mobile). This includes the Swift application and GUI source, the Pikafish submodule at the exact revision used for the build, the C/C++ bridge, the Xcode project, build scripts, and required resources. Users may rebuild, modify, and sign the app with their own Apple Developer account. They do not need this project's signing credentials, and submitting a pull request is not required to exercise those rights.

To rebuild a modified iOS app, check out the matching source tag, open `XiangqiMobile.xcodeproj` in Xcode, select your own development team, change the bundle identifier if required by your provisioning profile, and build/sign/install the app on your device. The App Store binary is not the only permitted form of the software; GPL rights to modify and redistribute the source remain available.

Pikafish's GPL license cannot be removed by changing this README, changing the link mode, or changing the project's license label. Avoiding GPL obligations would require replacing Pikafish or obtaining relicensing permission from the relevant Pikafish copyright holders.

The bundled CCPD learning corpus is separate data, not software. The database and CCPD-derived exports remain available under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), with attribution and modification notices in `Resources/Learning/CCPD-source.json` and `Resources/Licenses/CCPD-CC-BY-4.0.txt`.

The product direction is documented in the [specification index](docs/README.md):

- [Product specification](docs/product-spec.md)
- [UX and visual specification](docs/ux-spec.md)
- [Technical specification](docs/technical-spec.md)

The implementation order and decision hierarchy are defined in the specification index. Do not add online controllers, services, schemas, dependencies, permissions, remote configuration, or placeholder UI to the 1.0 target.
