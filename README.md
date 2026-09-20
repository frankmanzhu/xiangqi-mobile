# Xiangqi Mobile

Xiangqi Mobile is a native, offline SwiftUI app for playing xiangqi locally. It supports Player vs Computer and two-player hot-seat games, full move replay, atomic save/resume, clocks, undo, hints, three visual themes, and portable game sharing.

The canonical game record is `starting FEN + ordered UCI moves + versioned rules policy`. Human-readable notation is derived from that record, so a game can be reconstructed independently of the UI and can form the payload for later online play.

## Build and test

- Open `XiangqiMobile.xcodeproj` in Xcode and run the `XiangqiMobile` scheme.
- Run domain tests with `swift test`.
- Run the real-engine bridge smoke test with `scripts/test_pikafish_bridge.sh`.
- Regenerate the checked-in Xcode project after adding source files with `ruby scripts/generate_project.rb`.

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

Pikafish is licensed under GPL-3.0. Its license and attribution are bundled in `Resources/Licenses`.

The product direction is documented in the [specification index](docs/README.md):

- [Product specification](docs/product-spec.md)
- [UX and visual specification](docs/ux-spec.md)
- [Technical specification](docs/technical-spec.md)

The implementation order and decision hierarchy are defined in the specification index. Do not add online controllers, services, schemas, dependencies, permissions, remote configuration, or placeholder UI to the 1.0 target.
