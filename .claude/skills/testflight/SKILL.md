---
name: testflight
description: Use when the user asks to upload, ship, or push a new build to TestFlight / App Store Connect for this Flutter iOS app, or asks whether the last upload succeeded. Covers "TestFlight 올려", "빌드 올려", "테플 업로드", "ipa 배포".
---

# TestFlight upload

## Overview

One script does the whole thing: bump build number → commit → push → `flutter build ipa` (which **already uploads**) → verify from Xcode's local delivery log.

```bash
.claude/skills/testflight/scripts/testflight.sh            # bump +1, commit, push, build+upload, verify
.claude/skills/testflight/scripts/testflight.sh --dry-run  # prerequisites + plan only
```
Flags: `--no-push`, `--no-bump`, `--version 1.3.0` (see script header).

## Facts this project relies on

| Fact | Consequence |
|---|---|
| `ios/ExportOptions.plist` has `method=app-store-connect`, `destination=upload` | `flutter build ipa --export-options-plist=ios/ExportOptions.plist` archives **and uploads**. No `altool`, no `notarytool`, no API key needed. Xcode's signed-in Apple ID session does the auth. |
| `manageAppVersionAndBuildNumber=false` | Build number comes from `pubspec.yaml` `version: X.Y.Z+N`. ASC rejects a reused N, so bump **before** building. |
| Upload mode leaves no IPA on disk | Flutter ends with `Flutter failed to list directory ... build/ios/ipa` / `PathNotFoundException`. **Harmless.** Not a failure signal. |
| Xcode writes `/var/folders/.../T/Runner_<date>.xcdistributionlogs/ContentDelivery.log` | Success = the line `UPLOAD SUCCEEDED with no errors`. `Delivery UUID: …` is the receipt. The script greps this; do not rely on the ASC website or email. |
| iOS deployment target 15.0 | Build 6 was rejected with ITMS-90068 for 13.0. Do not lower it. |
| Signing is automatic, team `T583WJWNAK` | Nothing to configure. |

## Procedure (if running by hand)

1. `git status` clean. Bump `version:` in `pubspec.yaml` (+1 build), commit `chore: bump version to X.Y.Z+N`, push.
2. `flutter build ipa --release --export-options-plist=ios/ExportOptions.plist` (≈2–3 min: archive ~30 s, upload ~100 s).
3. Verify: newest `Runner_*.xcdistributionlogs/ContentDelivery.log` contains `UPLOAD SUCCEEDED`.
4. Report: version+build, Delivery UUID, and that ASC processing takes a few more minutes before the build is installable.

## Common mistakes

- Adding an `xcrun altool --upload-app` step → fails (no API key) and is redundant.
- Reading the `build/ios/ipa` listing error as a failed build.
- Verifying only via App Store Connect web / email → can't confirm from the terminal; use the log.
- `flutter clean` first → unnecessary, costs minutes. Only if the previous build was broken.
- Bumping the version after the build → the uploaded binary carries the old number and ASC rejects the duplicate.
- Running `git commit` on the same shell line as a command containing `-n` (e.g. `grep -n`) → the repo's block-no-verify hook rejects it. Keep the commit on its own line (the script does).
