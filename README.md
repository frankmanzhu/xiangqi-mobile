# Xiangqi Mobile

Xiangqi Mobile is a native, offline SwiftUI app for playing xiangqi locally. It supports Player vs Computer and two-player hot-seat games, full move replay, atomic save/resume, clocks, undo, hints, three visual themes, and portable game sharing.

The canonical game record is `starting FEN + ordered UCI moves + versioned rules policy`. Human-readable notation is derived from that record, so a game can be reconstructed independently of the UI and can form the payload for later online play.

## Build and test

- Open `XiangqiMobile.xcodeproj` in Xcode and run the `XiangqiMobile` scheme.
- Run domain tests with `swift test`.
- Regenerate the checked-in Xcode project after adding source files with `ruby scripts/generate_project.rb`.

The app performs no network requests and has no account or online-play code. The current computer player is a deterministic native search implementation behind an isolated interface; the pinned Pikafish source and NNUE described in the technical specification are not present in this repository and remain an engine-integration milestone.

The product direction is documented in the [specification index](docs/README.md):

- [Product specification](docs/product-spec.md)
- [UX and visual specification](docs/ux-spec.md)
- [Technical specification](docs/technical-spec.md)

The implementation order and decision hierarchy are defined in the specification index. Do not add online controllers, services, schemas, dependencies, permissions, remote configuration, or placeholder UI to the 1.0 target.
