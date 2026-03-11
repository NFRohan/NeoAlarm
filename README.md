# NeoAlarm

Android-first, local-first, open source alarm app built with Flutter and a native Android core.

## Documentation

- Project docs index: [docs/README.md](docs/README.md)
- Overall implementation plan: [docs/planning/overall-plan.md](docs/planning/overall-plan.md)
- Sprint plan: [docs/planning/sprint-plan.md](docs/planning/sprint-plan.md)
- Test strategy: [docs/testing/test-strategy.md](docs/testing/test-strategy.md)
- Architecture overview: [docs/architecture/overview.md](docs/architecture/overview.md)
- Engineering story: [docs/architecture/engineering-story.md](docs/architecture/engineering-story.md)
- Active session lifecycle: [docs/architecture/active-session-lifecycle.md](docs/architecture/active-session-lifecycle.md)
- Mission authoring guide: [docs/contributing/mission-authoring.md](docs/contributing/mission-authoring.md)

## Current Status

The project currently has:

- exact alarm scheduling and native alarm persistence
- direct-boot-aware alarm/session persistence for reboot recovery before first unlock
- a native foreground ringing service with full-screen recovery
- dashboard, editor, diagnostics, and settings flows
- math mission enforcement with configurable difficulty and problem count
- mission confirmation plus native inactivity re-trigger behavior
- steps mission enforcement with native `TYPE_STEP_DETECTOR` tracking
- activity-recognition gating in the editor plus settings-based repair/re-enable flow
- quiet-timer countdown UI sourced from the persisted native mission timeout
- exploit hardening so only mission-valid activity can keep a mission silent
- event-driven active-session updates from native Android into Flutter
- idempotent QR camera session startup with explicit native vision cleanup

## Release Signing

- Local release signing is read from [android/key.properties.example](android/key.properties.example).
- Copy it to `android/key.properties` and provide a local keystore file when you want a real signed release build.
- If `android/key.properties` does not exist, Gradle falls back to the debug signing config so CI and local verification builds still work.

## CI

GitHub Actions now includes:

- `Android CI` for `flutter analyze`, tests, debug APK builds, and artifact upload
- `CodeQL` for SAST on Android code and workflow code
- `Dependency Review` on pull requests for dependency-risk/CVE changes
- `Release APK` on `v*` tags to build a release APK and attach it to a GitHub release

Release verification note:

- release builds run with R8 minification and resource shrinking enabled
- a passing debug build is not sufficient release evidence
- install and smoke-test the minified release APK on a real device before treating a release candidate as verified

Optional release-signing secrets for the release workflow:

- `ANDROID_SIGNING_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

