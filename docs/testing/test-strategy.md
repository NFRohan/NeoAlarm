# Test Strategy

## Summary

This project is a reliability-sensitive Android app. The test strategy must prove more than UI correctness. It has to validate scheduling semantics, ringing behavior, recovery behavior, mission enforcement, and device-specific failure modes.

The correct model is a layered test ladder:

- fast unit tests for rules and serialization
- integration tests for Flutter/native boundaries
- emulator-based smoke tests in CI
- cloud device testing for Android instrumentation on real hardware
- manual reliability testing on a small but intentional device matrix

## Goals

- catch logic regressions before they reach devices
- validate Flutter-to-native bridge behavior without relying only on manual testing
- build APKs and test artifacts even when local Android tooling is incomplete
- catch release-only regressions introduced by minification and resource shrinking
- prove the MVP on actual Android hardware before release
- keep reliability claims grounded in repeatable checks

## What GitHub Actions Can Do

GitHub Actions is sufficient for:

- building debug and release APKs
- running Dart unit tests and Flutter widget tests
- running Kotlin/JVM unit tests
- running emulator-based Android instrumentation tests
- publishing build artifacts for download and review
- orchestrating cloud device tests such as Firebase Test Lab runs
- running repository security automation such as SAST and dependency-risk checks

That means the lack of a full local Android toolchain is not a blocker for setting up CI, building APKs, or getting early automated feedback.

## What GitHub Actions Cannot Do By Itself

GitHub Actions does not give you a built-in farm of physical Android phones. If you want real-device testing from CI, use one of these approaches:

- trigger Firebase Test Lab from a GitHub Actions workflow
- use a third-party mobile device cloud
- run a self-hosted runner attached to one or more Android devices

For this project, Firebase Test Lab is the cleanest first choice. It gives us real-device execution without maintaining our own device farm.

## Recommended Test Layers

### Layer 1: Pure Logic Tests

Run on every pull request.

Cover:

- recurrence rules
- timezone and DST behavior
- snooze cap logic
- mission configuration validation
- mission problem-count validation
- step-goal validation and detector-progress serialization
- alarm serialization and persistence mapping
- analyzer result mapping for vision missions

These tests should be fast and independent of Android UI.

### Layer 2: Flutter Integration Boundary Tests

Run on every pull request.

Cover:

- bridge contracts between Flutter and native Android
- create, update, enable, disable, and delete alarm flows
- active `RingSession` query and recovery handoff
- active-session event streaming from native persistence into Flutter
- mission state transitions that cross the Flutter/native boundary
- mission activity signaling and inactivity re-trigger contract
- quiet-timer deadline propagation from native session state into Flutter UI
- mission-availability gating when sensors or permissions are missing

These tests should prove that the app shell and the native core agree on state shape and lifecycle.

### Layer 3: Emulator Smoke Tests

Run on `main` and optionally on pull requests if runtime is acceptable.

Cover:

- app boot and basic navigation
- creating an alarm and confirming the schedule path succeeds
- foreground ringing service startup
- math mission flow including multi-problem completion
- mission confirmation flow and 30-second inactivity re-trigger
- quiet-timer UI countdown and refresh after valid mission activity
- steps mission progress on supported emulators or test doubles where available
- QR mission permission flow

Use emulator tests for confidence, not for final reliability claims. Emulator behavior is useful, but it does not fully represent Doze, OEM battery policies, or lock-screen quirks on real devices.

### Layer 4: Cloud Physical-Device Tests

Run nightly and on release candidates.

Cover:

- Android instrumentation tests on real hardware via Firebase Test Lab
- permission handling
- camera-based QR mission path
- step mission on supported device types
- recovery after process death where automation is practical
- mission-active recovery and idle re-trigger behavior where automation is practical
- activity-recognition revocation while a steps mission is active where automation is practical
- cadence-filter behavior and obvious anti-cheat regression cases where automation is practical

Use this layer to catch issues that emulators miss, but do not assume cloud devices replace the entire manual matrix.

### Layer 5: Manual Reliability Matrix

Run before beta and release candidates.

Cover:

- overnight Doze behavior
- reboot recovery
- reboot recovery before first unlock
- manual time and timezone changes
- overlapping alarms
- full-screen launch from lock screen
- app swipe-away and process reclaim during ringing
- mission confirmation behavior
- mission-active silence while interacting
- re-trigger after 30 seconds of no mission activity
- quiet-timer accuracy during math input and step activity
- random taps not extending math mission silence
- activity-recognition revoked during an active steps mission
- repeated QR permission recovery or app resume not causing scanner churn or camera-session breakage
- OEM-specific battery optimization problems

Target at least:

- one Pixel-class reference device
- one Samsung device
- one aggressive OEM device family

This is the only layer that can honestly support reliability claims for an alarm product.

Direct-boot note:

- after adding `LOCKED_BOOT_COMPLETED` support, manual testing should include at least one alarm configured before reboot, then a restart without first unlocking the device, to confirm that schedules are rebuilt from device-protected storage rather than only after unlock
- direct-boot testing should also confirm that the Flutter shell does not load the full dashboard before unlock and that no startup-time plugin initialization crashes the app during a pre-unlock launch

## Post-Minification Verification

Release confidence for this project cannot stop at a passing debug APK.

The release build enables R8 minification and resource shrinking. That means the repository must explicitly verify the installed release artifact after shrinking, not just assume that a successful `flutter build apk --release` is enough.

Why this matters:

- method-channel and native bridge failures can appear only in release builds
- manifest-driven entry points can behave differently once the app is optimized
- resource shrinking can remove assets or references that debug builds still carry
- alarm apps are unusually sensitive to release-only regressions because the failure often appears only when the phone is idle, locked, or waking up

When to run it:

- before every tagged release
- after changes to native bridge code, manifest wiring, mission runtime code, startup/bootstrap logic, or QR/vision code
- after enabling or changing shrinker rules

Minimum post-minification checklist:

- build the release APK with `flutter build apk --release`
- install the release APK on a real device
- launch the app and confirm the dashboard or direct-boot-safe shell loads correctly
- create, edit, enable, and disable alarms
- let an alarm fire and confirm the ringing service, notification, and full-screen alarm UI still work
- complete at least one mission flow for each implemented mission type
- verify that steps progress and active mission-state updates still arrive in real time without visible polling lag
- verify that valid mission activity does not leave a restarted foreground service behind just to refresh the quiet timer
- confirm service teardown after mission completion or dismiss
- inspect `adb logcat` for release-only failures such as `ClassNotFoundException`, `NoSuchMethodError`, plugin registration failures, or unexpected permission/security exceptions
- inspect `dumpsys activity services` or equivalent state to confirm no ringing service is left behind after completion

If a release-only regression is found, do not guess at broad keep rules first. Narrow the failure to the affected class, entry point, or resource path, then add the smallest defensible shrinker rule needed to protect it.

## CI Recommendation

### Pull Request Workflow

- set up Flutter and Java
- restore dependencies
- run formatting and static analysis
- run Dart and Kotlin unit tests
- build a debug APK
- upload the APK as a workflow artifact
- run dependency review on dependency changes
- run CodeQL on the repository's scheduled or mainline cadence

### Main Branch Workflow

- run the pull request workflow checks
- run emulator smoke tests
- publish a debug or internal QA APK artifact
- publish CodeQL results to GitHub code scanning

### Nightly Or Release Workflow

- build a release-mode APK or AAB
- run post-minification verification against the installed release artifact
- run the Firebase Test Lab suite
- collect screenshots, logs, and test artifacts
- fail the workflow on device-test regressions
- publish signed or fallback-signed release artifacts in a controlled workflow

## Current Repository Automation

The repository now includes these GitHub Actions workflows:

- `Android CI`: `flutter analyze`, `flutter test`, debug APK build, and artifact upload
- `CodeQL`: SAST for Android code and workflow code
- `Dependency Review`: pull-request dependency-risk review
- `Release APK`: release APK build and GitHub release publishing on `v*` tags

This does not eliminate the manual device matrix, but it does move security and artifact discipline into the default engineering loop instead of leaving them as release-week tasks.

Current release note:

- release builds are now minified and shrink resources
- release verification is not complete until the minified APK has been installed and smoke-tested on a real device

## Practical Answer For This Repo

Yes, GitHub Actions can build the APK for us.

Yes, GitHub Actions can also run Android tests.

Yes, GitHub Actions can be the control plane for real-device testing, but not by itself. The workflow should trigger Firebase Test Lab or another device cloud for physical-device execution.

So the sensible setup is:

- GitHub Actions for builds, lint, unit tests, widget tests, and emulator tests
- GitHub Actions CodeQL and dependency review for baseline security automation
- Firebase Test Lab for real-device instrumentation runs
- a small manual device matrix before release for alarm-specific reliability behavior

## Local Environment Guidance

We can begin with CI-first Android builds while the local machine setup is incomplete. That is good enough for early repository bootstrapping, APK generation, and a first round of automated testing.

It is not good enough forever.

Before release work, we still need at least one local Android device and a usable local `adb` setup for fast debugging of wake behavior, services, notifications, and OEM-specific issues.

## References

- GitHub Actions: https://docs.github.com/actions
- Self-hosted runners: https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners
- Firebase Test Lab: https://firebase.google.com/docs/test-lab
- Android instrumented tests: https://developer.android.com/training/testing/instrumented-tests
