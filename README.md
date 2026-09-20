# Xiangqi Mobile

Xiangqi Mobile is a native, offline SwiftUI app for playing xiangqi locally. It supports Player vs Computer and two-player hot-seat games, full move replay, atomic save/resume, clocks, undo, hints, three visual themes, and portable game sharing.

The canonical game record is `starting FEN + ordered UCI moves + versioned rules policy`. Human-readable notation is derived from that record, so a game can be reconstructed independently of the UI and can form the payload for later online play.

## Build and test

- Open `XiangqiMobile.xcodeproj` in Xcode and run the `XiangqiMobile` scheme.
- Run domain tests with `swift test`.
- Run the real-engine bridge smoke test with `scripts/test_pikafish_bridge.sh`.
- Regenerate the checked-in Xcode project after adding source files with `ruby scripts/generate_project.rb`.

The app performs no network requests and has no account or online-play code. Computer play uses Pikafish compiled in-process from submodule revision `6a59ee2f7b105bff64d9efc2692591107787e2b1`, plus the bundled `pikafish.nnue` network with SHA-256 `7d13d73569a9b571ba0eb20cf1596247bc2a42738967e61afef6482b231e900e`. There is no alternate or fallback computer player. The engine receives the canonical starting FEN and complete ordered UCI move history for every search.

Pikafish is licensed under GPL-3.0. Its license and attribution are bundled in `Resources/Licenses`.

The product direction is documented in the [specification index](docs/README.md):

- [Product specification](docs/product-spec.md)
- [UX and visual specification](docs/ux-spec.md)
- [Technical specification](docs/technical-spec.md)

The implementation order and decision hierarchy are defined in the specification index. Do not add online controllers, services, schemas, dependencies, permissions, remote configuration, or placeholder UI to the 1.0 target.
