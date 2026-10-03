# App Store submission package

Prepared 4 October 2026 for version 1.0, build 1.

## Listing draft

- Name: Xiangqi Mobile (availability must be checked in App Store Connect).
- Subtitle: Play and study Chinese chess
- Primary category: Games / Board
- Price: Free; no advertising or in-app purchases.
- Copyright: © 2026 Frank Zhu
- Keywords: xiangqi,chinese chess,board game,offline,pikafish,strategy,puzzles,tactics
- Languages: English, Simplified Chinese, Traditional Chinese.
- Devices: iPhone and iPad; minimum iOS/iPadOS 18.

### Description

Play Chinese chess wherever you are. Challenge the bundled Pikafish engine, share a device with a friend, or explore a library of more than 145,000 recorded games and practice lines.

• Play offline against five computer strengths.
• Play two-player games on one device.
• Choose casual play or 10- and 15-minute clocks.
• Save and resume your active game, review moves, and share portable game records.
• Use staged hints and undo in casual games.
• Browse openings, endgames, tactics, matches, and mating exercises.
• Choose Classic, Tournament, or Calm themes.
• Use English, Simplified Chinese, or Traditional Chinese.

No account, ads, or in-app purchases. Games and settings stay on your device. New games use the pinned Pikafish Computer Rule, including repetition, perpetual checking and chasing, and draw adjudication.

### Review notes

The app works fully offline and does not require a reviewer account. On the home screen, Play Computer starts a game against the bundled engine. Two Players starts a shared-device game. Learn and practice opens the bundled library. Settings contains the privacy policy, rules explanation, license notices, source-code link, and support link. No executable code, neural-network weights, or learning data are downloaded at runtime.

### Privacy and support URLs

The following pages were published with owner approval on 4 October 2026 and their contents were verified without authentication:

- Privacy: https://github.com/frankmanzhu/xiangqi-mobile/blob/main/docs/privacy-policy.md
- Support: https://github.com/frankmanzhu/xiangqi-mobile/blob/main/docs/support.md

The repository’s default branch is `main`. Privacy-policy publication commit: `ade35b6d4ff69977c9b7e021e30f66311a667b34`; support-page publication commit: `8d77c637f45b1a454b5036f6e7382d3ff7044688`. The in-app privacy policy is bundled and readable offline.

### App privacy and age rating

The current app contains no tracking, analytics, advertisements, account service, or developer-hosted data collection. The expected App Privacy answer is Data Not Collected; review the final binary and Apple’s definitions before submitting. User-initiated sharing and GitHub support follow the selected service’s policies. Do not confuse Apple’s own crash reporting with an embedded analytics SDK.

Complete every current age-rating question accurately. There is no app-provided chat, ads, gambling, simulated gambling, web browsing, or paid randomized rewards. The historical game corpus can contain names and event metadata. Do not declare the Kids Category merely because the game is suitable for children. Check the generated rating in App Store Connect.

Export-compliance questions remain to be answered for the final binary. CryptoKit verifies a bundled file hash; no app-provided encrypted communication or custom cryptographic protocol exists. Do not set an export-compliance exemption flag without confirming the applicable Apple questionnaire.

## Licensing evidence

The learning database contains 145,065 records: 58,456 CCPD records under CC BY 4.0, 14,386 WXF records, and 72,223 Dongping records. CCPD attribution, modification notices, source revision, and checksum are recorded. The owner requested retaining WXF and Dongping because the collections are publicly available online. Their redistribution rights remain undocumented; this owner preference is not a license grant or a legal clearance.

Pikafish source is GPL-3.0-or-later. The application is GPL-3.0-or-later, includes its notices and authors, and provides rebuild instructions. A source tag matching the distributed binary, including submodule revision and actual Git LFS resources, must be publicly available before release. A public repository and bundled notices alone do not establish that App Store distribution terms satisfy every GPL obligation; review that distribution route before treating licensing as closed.

Pikafish publishes separate NNUE weight terms restricting commercial use without permission. The intended release is free without ads or purchases. The checksum identifies the current weights, but the original download/version provenance is not recorded in this repository. Record that provenance and applicable terms before signing off the weight licensing gate. Published terms: https://www.pikafish.com/list.html?lang=zh-CN

## Verification

Run from the repository root:

```sh
python3 scripts/check_release.py
swift test
bash scripts/test_pikafish_bridge.sh
bash scripts/test_rules_differential.sh
```

Use the shared Xcode scheme to run UI tests on a large iPhone, a small iPhone, and an iPad. Archive in Release with a generic iOS destination; signing can be disabled to check compilation before enrollment. That archive cannot be uploaded.

Current test outcomes and open gates are recorded in `release-readiness.md`. Passing these checks is evidence for a release candidate, not a promise of App Review acceptance.
