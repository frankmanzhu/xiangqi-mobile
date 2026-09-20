# Xiangqi Mobile

Xiangqi Mobile is a planned native iPhone app for playing xiangqi against a bundled Pikafish engine. Release 1.0 is deliberately self-contained: it requires no account or network connection and includes its engine, NNUE, themes, help, localizations, and licenses in the app.

## Current status

The repository is in the specification phase; application source has not been scaffolded yet. The 1.0 scope is locked to Player vs Computer. Local two-player follows after the offline core is proven, and online play is roadmap-only.

Start with the [specification index](docs/README.md):

- [Product specification](docs/product-spec.md)
- [UX and visual specification](docs/ux-spec.md)
- [Technical specification](docs/technical-spec.md)

The implementation order and decision hierarchy are defined in the specification index. Do not add online controllers, services, schemas, dependencies, permissions, remote configuration, or placeholder UI to the 1.0 target.
