# Reliability, Security, And Quality Hardening Sprint

## Goal

Stabilize the location-alarm release path by fixing the audit findings that can cause missed alarms, stale native state, leaked resources, insecure release handling, or confusing maintenance work.

This sprint is not a feature expansion sprint. It is a hardening sprint.

## Release Position

Current verification:

- `flutter analyze` passes
- `flutter test` passes
- `android\gradlew.bat -p android :app:compileDebugKotlin` passes after the native refactor
- `flutter build apk --release --target-platform android-arm64` passes
- `flutter build apk --release --split-per-abi` passes
- `flutter build appbundle --analyze-size --target-platform android-arm64` passes
- release APK zip integrity check passes
- `android\gradlew.bat -p android :app:lintRelease` passes locally after fixing ignored `android/local.properties` path escaping
- real-device location alarm route test passed on Samsung with power saving enabled

Release posture:

- do not ship a location-alarm release until the blocking native reliability issues are fixed
- do not tag a public release until release signing, lint gates, and APK artifact generation are boringly deterministic
- keep real-device route testing in the loop after each location-trigger fix

## Non-Goals

Do not include these in this sprint:

- new location-alarm product features
- repeating location alarms
- route-aware or transit-stop intelligence
- foreground-service live tracking
- visual redesign of the map setup surface
- provider migration beyond hardening the existing MapLibre, Photon, OpenCage stack

## Phase 0: Baseline And Guardrails

Objective: make failures visible before changing behavior.

Tasks:

- preserve the current audit report in `docs/reviews/security-performance-code-quality-audit-2026-05-17.md`
- capture the current `lintRelease` report as the native release-gate baseline
- add a release checklist item that requires `flutter analyze`, `flutter test`, release APK build, and `:app:lintRelease`
- decide whether `lintRelease` enters CI immediately after fixes or after one local cleanup pass

Acceptance criteria:

- the team can name the exact command that blocks native release readiness
- future releases cannot claim verification without the Android lint gate being mentioned

## Phase 1: Release-Blocking Native Reliability

Objective: remove the alarm-miss and stale-native-state risks first.

Tasks:

- fix `LocationAlarmCoordinator` missing-permission lint errors with explicit permission checks or scoped `SecurityException` handling
- add bounded waits for geofence registration, passive listener registration, last-location lookup, and current-location lookup
- cancel current-location tokens on timeout
- split `AlarmRescheduleReceiver` into independent time-alarm and location-alarm recovery failure domains
- ensure location re-arm runs even if exact alarm permission blocks time-alarm rescheduling
- log geofence delivery errors in `LocationAlarmReceiver`
- map geofence delivery and removal failures to persisted location health
- unregister inner and outer geofences after one-shot location alarm trigger
- clear geofence, approach, and retry metadata after trigger, disable, and delete
- release ringing wake locks through the shared teardown path in `AlarmRingingService.onDestroy`

Acceptance criteria:

- `lintRelease` no longer reports missing location permission errors
- reboot/time-change/package-replace recovery cannot skip location sync because time-alarm scheduling failed
- triggering a one-shot location alarm removes its native geofences
- geofence errors become visible in logs and persisted health
- service destruction cannot leave playback or wake-lock state half-cleaned

Validation:

- run `android\gradlew.bat -p android :app:lintRelease`
- run `flutter test`
- run `flutter build apk --release --target-platform android-arm64`
- install release APK on device
- create, arm, trigger, and delete a location alarm
- check logs for geofence add/remove and passive listener cleanup
- reboot and verify location alarm re-arm behavior

Phase 1 progress on 2026-05-17:

- Added bounded Play Services waits for geofence registration/removal, passive listener registration/removal, last-location lookup, and active current-location lookup.
- Added scoped Android location-permission suppressions only around guarded Play Services calls so `lintRelease` no longer reports missing-location-permission errors.
- Added current-location cancellation on timeout.
- Split boot/time/package recovery so time-alarm reschedule failures are logged independently and cannot skip location-alarm sync.
- Added geofence broadcast error logging and repair-state persistence for armed location alarms.
- Added one-shot trigger cleanup that removes inner/outer geofences and clears geofence, approach, and retry metadata before disabling the triggered location alarm.
- Added stale passive-listener cleanup when location readiness becomes unhealthy.
- Routed `AlarmRingingService.onDestroy` through the shared playback and wake-lock teardown path.
- Cleared the CameraX release lint opt-in error and declared camera hardware optional in the manifest.
- Field-tested a location alarm on a Samsung device with power saving enabled; the alarm triggered successfully.
- Revoking location permission while a location alarm was active persisted the unhealthy state and surfaced it on the dashboard.

Remaining Phase 1 validation:

- Install the hardened APK on device.
- Reboot and verify location alarm re-arm behavior from logs.

## Phase 2: Location Setup Correctness

Objective: prevent stale async UI state from lying about the selected destination.

Tasks:

- add sequence tokens for location search requests
- add sequence tokens for setup diagnostics requests
- add coordinate matching before applying reverse-geocode labels
- catch `PlatformException` and generic reverse-geocode failures in setup
- replace the garbled map attribution string with clean text
- add tests for stale search and stale reverse-geocode responses if practical

Acceptance criteria:

- old search results cannot overwrite newer query results
- old reverse-geocode labels cannot overwrite a newer dropped pin
- diagnostics cannot flash stale or irrelevant state into the setup UI
- map attribution text renders without encoding artifacts

Validation:

- run fast repeated search queries
- tap multiple map points quickly and confirm final label belongs to the final pin
- create a destination with and without an OpenCage key
- run `flutter test`

Phase 2 progress on 2026-05-17:

- Added request sequence guards for destination search, setup diagnostics, and pinned-location reverse geocoding.
- Added coordinate/radius matching before applying diagnostics or reverse-geocode labels to the current draft.
- Search query edits now cancel stale spinner/results state instead of letting old results reopen later.
- Search-result selection and map pinning clear stale search result UI.
- Reverse geocode failures now keep the fallback pin label across repository, platform-channel, and unexpected failures.
- Replaced the garbled map attribution copy with ASCII-safe provider attribution.
- Added tests for stale search result suppression and query-edit search-state cleanup.

Remaining Phase 2 validation:

- Manually tap multiple map points quickly with an OpenCage key and confirm only the final pin receives the reverse-geocode label.
- Manually run repeated slow/fast searches on device and confirm old result panels do not reopen.

## Phase 3: Fail-Closed Health And Repair Semantics

Objective: make location alarm health safe under native/Dart contract drift.

Tasks:

- add an explicit `unknown` or `unavailable` location health state
- make Dart health parsing fail closed instead of defaulting to `healthy`
- make Kotlin health parsing fail closed instead of defaulting to `HEALTHY`
- update setup diagnostics and dashboard rendering for unknown health
- add a contract test or shared fixture for native/Dart health IDs
- add a geofence quota warning or health state if the hybrid model approaches Android's geofence limit

Acceptance criteria:

- unknown native health IDs never show as `Ready`
- repair UI can display a safe fallback message
- tests cover health ID parity
- docs note that the hybrid model uses two geofences per armed location alarm

Validation:

- deserialize an intentionally unknown health ID in Dart and Kotlin tests
- manually force an unrecognized health string in stored data and verify the card is not marked ready

Phase 3 progress on 2026-05-17:

- Added explicit `unknown` location health state in Dart and Kotlin.
- Changed Dart and Kotlin health parsing so unrecognized health IDs fail closed to `unknown` instead of `healthy`.
- Updated setup diagnostics copy so unknown readiness is blocking and asks the user to recheck instead of showing `Ready`.
- Updated dashboard repair handling so unknown location health triggers a readiness refresh.
- Added a dashboard repair prompt for enabled location alarms that enter actionable unhealthy states, while keeping the passive card health text as the durable status surface.
- Added Dart coverage for unknown location health IDs across trigger parsing and setup diagnostics parsing.
- Made `lintRelease` deterministic by disabling `PropertyEscape` for Flutter-regenerated, ignored `android/local.properties`.

Remaining Phase 3 validation:

- Manually force an unknown health string in stored alarm data and confirm the dashboard shows `Readiness unknown` instead of `Ready`.
- Revoke location permission with an enabled location alarm and confirm the dashboard shows one active repair prompt plus the passive unhealthy card status.
- Add a Kotlin/JVM contract test if native unit test infrastructure is introduced.

## Phase 4: Security Hardening

Objective: close the concrete release and storage security gaps.

Tasks:

- remove release signing materialization from pull-request CI paths
- keep production signing only in the release workflow
- require tag checkout and tag/SHA verification in manual release dispatch
- consider a protected GitHub environment for release publishing
- split app-private location retry broadcasts into a non-exported receiver
- enforce the 15 MB tone cap during stream copy, not only via provider metadata
- copy imported tones to a temp file and atomically rename on success
- release unused persistable URI grants after local copy and on tone deletion
- remove or round exact destination coordinates from production logs
- add OpenCage privacy copy in settings: dropped-pin reverse geocoding sends coordinates to OpenCage
- hide OpenCage key text by default or add a simple reveal affordance

Acceptance criteria:

- PR CI cannot access production signing secrets
- manual releases publish the requested tag, not the incidental workflow ref
- malicious or broken document providers cannot import oversized tones
- app-private retry work cannot be triggered through an exported receiver
- location logs no longer contain exact destination coordinates in production

Validation:

- inspect GitHub Actions workflow conditions
- run a release workflow dry-run or manual workflow review before tagging
- import a valid small MP3/WAV
- test an oversized or fake-sized tone provider case where possible
- delete an externally referenced tone and verify URI grant release path runs

Phase 4 progress on 2026-05-17:

- Removed release signing materialization from the general Android CI workflow; production signing now stays in the release workflow.
- Added `lintRelease` to Android CI so native release blockers are checked alongside analyze/tests.
- Added release-tag checkout and tag-to-commit verification for manual release dispatches; release metadata and GitHub release target now use the checked-out tag commit.
- Split private location re-arm retries into `LocationRearmRetryReceiver`, a non-exported receiver, instead of accepting the private retry action through the exported boot/time receiver.
- Enforced the 15 MB tone cap during stream copy, not only via provider metadata.
- Switched imported tone copies to temp-file copy plus atomic rename.
- Released persistable URI grants after successful local tone copy and when deleting externally referenced tones.
- Removed exact destination latitude/longitude from location-arm registration logs.
- Added OpenCage privacy copy explaining that dropped-pin coordinates are sent to OpenCage for readable labels.
- Hid the OpenCage key by default with a reveal toggle.

Remaining Phase 4 validation:

- Manually import a valid small MP3/WAV and verify local copy playback.
- Manually test an oversized tone import, ideally from a provider with misleading metadata.
- Manually delete an externally referenced tone and verify the app continues cleanly.
- Review the release workflow in GitHub before the next tag to confirm manual dispatch builds the requested tag.

## Phase 5: Performance And Battery Cleanup

Objective: reduce redundant background work without weakening trigger recovery.

Tasks:

- choose a single app-resume owner for location alarm foreground checks
- debounce resume-triggered location health refreshes
- avoid full `syncAll()` unless boot, package replace, permission return, explicit repair, or startup requires it
- remove stale passive location updates before returning on blocking health
- batch location sync so store scans and passive/retry scheduling happen once
- skip geofence unregister/register churn when alarm trigger parameters did not change
- memoize direct-boot storage migration checks
- add timeouts and response-size caps to Photon and OpenCage HTTP calls
- consider a shared injectable JSON HTTP client for location providers

Acceptance criteria:

- one foreground resume produces one intentional location check path
- passive listener registration and removal are visible in logs
- network calls fail quickly and cleanly under timeout conditions
- repeated dashboard resumes do not churn location alarm storage or Play Services calls unnecessarily

Validation:

- foreground/background the app repeatedly and inspect logs
- revoke background location and confirm passive listener cleanup
- simulate network timeout for search and reverse geocode
- run `flutter test`

Phase 5 progress on 2026-05-17:

- Centralized app-resume location recovery in the app shell and removed the dashboard's duplicate `refreshLocationAlarms()` resume path.
- Added a 30 second debounce and in-flight guard around resume-triggered location foreground checks.
- Kept app startup, alarm list, and engine status invalidation on resume while avoiding duplicate native location sync calls.
- Added connection/request/response timeouts to Photon search and OpenCage reverse geocoding.
- Added response-size caps to Photon and OpenCage JSON reads.
- Added passive-listener cleanup on unhealthy readiness in Phase 1; Phase 5 keeps that behavior as the cleanup path.
- Added native geofence registration reuse so normal sync passes can refresh health without unregistering and re-adding already armed geofences.

Remaining Phase 5 validation:

- Foreground/background the app repeatedly on device and confirm logs show one intentional foreground check path.
- Simulate slow or oversized provider responses if practical.
- Confirm explicit location repair still forces a re-arm instead of using the registration reuse path.

## Phase 6: Maintainability Cleanup

Objective: make the codebase easier to continue changing after the hardening work lands.

Tasks:

- extract `LocationReadinessProbe`
- extract `GeofenceRegistrar`
- extract `LocationApproachMonitor`
- extract `LocationRearmScheduler`
- keep `LocationAlarmCoordinator` as orchestration glue
- split `AlarmEngineMethodCallHandler` into smaller command handlers
- add lifecycle disposal for handler-owned executors
- centralize app metadata and HTTP user-agent version
- rename OpenCage settings toward reverse-geocode settings if no provider switcher exists
- keep `docs/README.md` as a short redirect to `docs/Doc Index.md` so it no longer drifts into a duplicate overview
- update `analysis_options.yaml` with stricter Dart checks after the release blockers are fixed

Acceptance criteria:

- location reliability code has clear single-purpose native classes
- method-channel dispatch is easier to review without a 600-line central file
- HTTP user-agent version matches `pubspec.yaml`
- documentation entry points no longer disagree

Validation:

- run `flutter analyze`
- run `flutter test`
- run `android\gradlew.bat -p android :app:lintRelease`
- run targeted manual location-alarm smoke tests after refactor

Phase 6 progress on 2026-05-18:

- Extracted `LocationReadinessProbe` for permission, service, Play Services, battery-warning, and location snapshot checks.
- Extracted `LocationGeofenceRegistrar` for inner/outer geofence request construction, registration, reuse checks, and removal.
- Extracted `LocationApproachMonitor` for passive fused-location listener registration/removal and unhealthy approach cleanup.
- Extracted `LocationRearmScheduler` for deferred location re-arm retry alarms.
- Added `LocationAlarmConfig` for geofence IDs, radius multiplier, retry timing, task timeouts, and shared distance/registration helpers.
- Kept `LocationAlarmCoordinator` as orchestration glue for sync, trigger conversion, duplicate suppression, and state transitions.
- Split `AlarmEngineMethodCallHandler` into `AlarmPermissionCommandHandler` and `ToneCommandHandler` for status/permission and tone-import command ownership.
- Added explicit disposal for handler-owned tone import state and the worker executor from `MainActivity.onDestroy`.
- Centralized app metadata and HTTP user-agent copy in `AppMetadata`; added a test that keeps the user-agent version aligned with `pubspec.yaml`.
- Renamed settings copy toward reverse-geocode behavior rather than presenting OpenCage as a general map provider switch.
- Enabled strict Dart analyzer language checks for casts, inference, and raw types.

Remaining Phase 6 validation:

- Run a real-device smoke test after installing the refactored release build.
- Recheck tone import after the command-handler extraction.
- Recheck permission repair prompts after the permission-command extraction.

## Phase 7: Size And Release Packaging Review

Objective: understand whether the new map/location dependencies change distribution strategy.

Tasks:

- run `flutter build appbundle --analyze-size`
- identify dominant APK contributors after MapLibre, Play Services Location, CameraX, and ML Kit
- decide whether GitHub release should include ABI split APKs
- document the preferred artifact set for location-alarm releases

Acceptance criteria:

- APK size increase is explained and tracked
- release artifacts are intentional instead of accidental universal APK bloat

Phase 7 progress on 2026-05-18:

- `flutter build appbundle --analyze-size` requires a single ABI; the successful size baseline used `--target-platform android-arm64`.
- `app-release.aab` compressed size is `38.1 MB`.
- AAB dominant contributors are native `base/lib` at `26 MB`, debug symbols metadata at `6 MB`, obfuscation metadata at `2 MB`, assets at `735 KB`, dex at about `1 MB`, and Android resources at about `1 MB`.
- Dart AOT decompressed symbols account for about `6 MB`; the app's own Dart code is about `336 KB`, while Flutter framework code is about `3 MB`.
- Local APK outputs are zip-valid.
- Universal release APK is `70.5 MB`.
- Split APKs are smaller: `armeabi-v7a` is `32.5 MB`, `arm64-v8a` is `39.9 MB`, and `x86_64` is `42.4 MB`.
- Release workflow now keeps the universal APK for simple sideloading, adds signed ABI split APKs for smaller downloads, and still publishes the signed app bundle for store-style distribution.

Preferred release artifact set:

- signed universal APK for users who do not know their device ABI
- signed `arm64-v8a`, `armeabi-v7a`, and `x86_64` split APKs for smaller GitHub downloads
- signed app bundle for Play/App Bundle distribution paths
- checksum manifest
- build metadata
- ProGuard/R8 mapping file when available

## Suggested Commit Slices

1. `docs: record security performance quality audit`
2. `fix(android): clear release lint blockers`
3. `fix(location): harden geofence trigger cleanup and rearm recovery`
4. `fix(alarm): release ringing resources on service teardown`
5. `fix(location): prevent stale setup async state`
6. `fix(location): fail closed on unknown health state`
7. `fix(security): harden release workflows and private retry receiver`
8. `fix(tones): enforce import size while streaming`
9. `perf(location): debounce resume checks and cleanup passive listeners`
10. `refactor(location): split coordinator responsibilities`
11. `docs: reconcile documentation index and release checklist`

## Definition Of Done

This sprint is complete when:

- `flutter analyze` passes
- `flutter test` passes
- `flutter build apk --release --target-platform android-arm64` passes
- `android\gradlew.bat -p android :app:lintRelease` passes
- release workflow signing behavior is reviewed and documented
- location alarm trigger, cleanup, reboot re-arm, and passive listener cleanup are verified on a physical device
- the audit report findings are either fixed, deliberately deferred, or tracked in a follow-up plan

## Follow-Up Backlog

Items that can reasonably wait until after the hardening sprint:

- split device-protected and credential-protected alarm metadata
- Android Keystore-backed storage for user-provided provider keys
- broader strict analyzer rollout if it creates too much churn
- deeper dashboard rebuild optimization
- location-alarm quota UX beyond basic warning/state support
