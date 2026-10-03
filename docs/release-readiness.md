# Release readiness — 4 October 2026

Version 1.0, build 1 is a tested release candidate. It is **not yet certified ready for App Store submission**. Apple Developer enrollment is not needed to finish the remaining local testing; distribution signing, TestFlight, and App Store Connect validation require enrollment.

## Completed preparation

- Offline privacy policy in Settings, translated into English, Simplified Chinese, and Traditional Chinese.
- Public [privacy policy](https://github.com/frankmanzhu/xiangqi-mobile/blob/main/docs/privacy-policy.md) and [support page](https://github.com/frankmanzhu/xiangqi-mobile/blob/main/docs/support.md), published with owner approval and verified without authentication. Only those two pages were published; application changes remain local.
- [Submission draft](app-store-submission.md): free pricing with no advertising or purchases, description, keywords, review notes, and questionnaire guidance.
- [Screenshots](app-store-screenshots/README.md) for the large iPhone and 13-inch iPad slots.
- GPL and authors notices, separate NNUE notice, learning-source attribution, and rules explanation accessible inside the app.
- New games use pinned Pikafish Computer Rule adjudication; existing saves retain their recorded legacy policy. Save loading rejects unsupported policy IDs.
- Learning exercises accurately ask for the next recorded move. iPad learning rows have tappable full-row areas.
- Pikafish uses its existing process-local allocation fallback on iOS. The corresponding source includes `EngineBridge/Patches/pikafish-ios-local-memory.patch`; follow the README's rebuild instructions to apply it. This removes the unused shared-memory directory probe and its `lstat` reference from the iOS release executable.

## Verified

| Check | Evidence |
| --- | --- |
| Core unit tests | All 29 pass |
| Native bridge | Real engine search and hint pass; repetition, perpetual check/chase, mixed checking, mate, stalemate, insufficient material, 60-move rule and illegal-history fixtures pass |
| Rules agreement | Exact legal move sets agree across 9,825 positions in 100 deterministic playouts capped at 100 plies |
| Large iPhone UI | All 7 smoke tests pass; learning/screenshot tests pass again after the row fix |
| Small iPhone SE simulator UI | All 7 smoke tests pass after test scrolling/capitalization repairs |
| iPad UI | All 7 smoke tests pass after the row hit-target repair |
| Resources | SQLite integrity, all 145,065 records, source totals, database/NNUE hashes, bundled notices and opaque 1024px icon pass |
| Localization | All 269 keys translated and synchronized |
| Release archive | Unsigned generic-iOS Release archive succeeds with Xcode 27 / iOS 27 SDK |
| Free development signing | Release build succeeds with the configured Personal Team; provisioning profile permits development only and lasts 7 days |
| iOS memory patch regression | Computer reply and staged-hint UI tests both pass; final archive executable has no `lstat` reference |
| Physical installation | Final development-signed Release build installed and launched successfully on Frank 17 Pro Max, iOS 27.0.1 |
| Physical interaction smoke | Through Apple's Device Hub: existing four-ply game resumes, level-5 Pikafish replies to `i0h0` with `i9h9`, hint source/destination reveal, undo returns to four plies, save survives process termination/relaunch, learning collection and practice board open, bundled Chinese privacy policy renders |

The UI checks cover game creation, real computer reply and staged hint, two-player moves, save/relaunch, learning navigation, privacy-policy access, and screenshot capture. They run on iOS/iPadOS 27 simulators and do not establish behavior on physical iOS 18 hardware. The differential run does **not** meet the original specification's 10,000 complete playout target.

The additional physical interaction smoke used the real iPhone 17 Pro Max through Device Hub. XCTest's separate QA app/runner could not install because the phone already occupies all three free-profile application slots; this is a provisioning limit, not a test assertion failure. The manual physical smoke is distinct from the seven-test simulator suite. Wi-Fi remained connected for Device Hub, so this did not establish airplane-mode behavior. Original Application Support game/progress files were backed up locally before move testing and restored afterward.

Local evidence is retained under `/tmp/xiangqi-release-*.log` and corresponding `.xcresult` bundles. The archive is `/tmp/xiangqi-release-tested.xcarchive`. These paths are local build artifacts, not durable published release evidence.

## Remaining gates before submission

1. **Physical-device acceptance:** play in airplane mode; finish games and check resign, undo, clocks, background/resume and restoration across modes; check audio/haptics, VoiceOver navigation, all supported languages and themes. Measure long engine sessions for responsiveness, memory and thermal behavior, including baseline older hardware. Simulator checks cannot replace these observations.
2. **Licensing evidence:** the owner requested keeping the full public-online corpus. CCPD's 58,456 records have documented CC BY 4.0 terms. WXF's 14,386 and Dongping's 72,223 records still lack documented redistribution permission. Record the original NNUE download/version and applicable separate terms. Review GPL obligations against the intended App Store distribution route. Public availability alone does not close these gates.
3. **Corresponding source:** publish a release tag matching the final binary, including the exact submodule revision, iOS patch, rebuild instructions, and actual resources. Only the privacy/support documents have been published during this preparation.
4. **After enrollment:** configure distribution signing, validate/upload the final archive, exercise TestFlight, complete accurate privacy/age-rating/export-compliance answers, enter live URLs and listing assets, and submit for review. Apple's acceptance is a separate decision.

Apple's [required-reason API documentation](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) explains the privacy-manifest requirement. Current [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) govern privacy and rights to third-party content.

## Re-run local checks

```sh
python3 scripts/check_release.py
swift test
bash scripts/test_pikafish_bridge.sh
bash scripts/test_rules_differential.sh
```

Run the shared Xcode scheme's UI tests and build a Release archive after material changes. The resource checker validates files and declarations; it does not prove licensing rights, hosted-page availability, complete privacy API coverage, or App Store acceptance.
