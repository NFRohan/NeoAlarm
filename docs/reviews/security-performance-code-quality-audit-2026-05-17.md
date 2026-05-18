# Security, Performance, And Code Quality Audit

Date: 2026-05-17

## Purpose

This review captures the security, performance, reliability, and maintainability findings from the comprehensive post-location-alarm audit.

The immediate goal is to convert the audit into actionable engineering work before location alarms move from field-testing into a stable release.

## Scope

Reviewed surfaces:

- native Android alarm engine
- location alarm geofence and passive-assist implementation
- custom tone import and storage
- Flutter location setup, dashboard, and settings flows
- release and CI workflows
- Android manifest, Gradle config, and dependency footprint
- documentation and planning state

Verification performed:

- `flutter analyze` passed
- `flutter test` passed
- `flutter build apk --release` passed
- `android\gradlew.bat -p android :app:lintRelease` failed with `8 errors / 44 warnings`
- release APK size: `107,274,067` bytes, about `102.3 MiB`

## Release-Blocking Findings

### 1. Android Lint Release Gate Fails

Severity: High

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:170`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:661`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:728`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:738`
- `android/app/src/main/kotlin/dev/neoalarm/app/vision/VisionSessionManager.kt:219`
- `android/app/src/main/AndroidManifest.xml:5`

Impact:

Release builds compile, but Android's native lint gate is catching permission-sensitive calls and CameraX opt-in usage. This is exactly the class of issue that can differ between debug confidence and shipped Android behavior.

Expected fix:

- Add explicit permission checks or tightly scoped `SecurityException` handling around Play Services location calls.
- Add the required CameraX experimental opt-in annotation.
- Add `<uses-feature android:name="android.hardware.camera" android:required="false" />`.
- Fix local `android/local.properties` escaping locally; this should not be committed.
- Add `:app:lintRelease` to CI once the current errors are cleared.

### 2. Location Alarms Can Leave Geofences Registered After Trigger

Severity: High

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:348`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/AlarmScheduler.kt:76`

Impact:

One-shot location alarms are disabled after firing, but inner and outer geofences are not clearly removed as part of the trigger path. This can keep waking `LocationAlarmReceiver`, waste quota, and leave stale system state after the alarm is no longer active.

Expected fix:

- After a location alarm triggers successfully, remove both inner and outer geofences.
- Clear persisted `geofenceId`, `registeredAtEpochMillis`, approach metadata, and retry metadata.
- Add a regression test or native logging assertion for trigger cleanup.

### 3. Boot Or Retry Reschedule Can Skip Location Re-Arming

Severity: High

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/AlarmRescheduleReceiver.kt:15`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/AlarmScheduler.kt:116`

Impact:

`AlarmRescheduleReceiver` currently runs time-alarm rescheduling and location-alarm sync inside one swallowed `runCatching`. If exact alarm rescheduling throws, location alarms may never re-arm after reboot, package replacement, time change, timezone change, or deferred retry.

Expected fix:

- Split time-alarm and location-alarm recovery into independent failure domains.
- Log each failure path.
- Always run `LocationAlarmCoordinator.syncAll()` even if time-alarm rescheduling fails.
- Persist a visible unhealthy state if re-arm fails.

### 4. Geofence Errors Are Dropped Silently

Severity: High

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmReceiver.kt:19`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:479`

Impact:

Play Services can deliver geofence errors or fail to remove geofences. The current paths drop or swallow these failures, which can create either unarmed alarms or stale geofences without user-visible health.

Expected fix:

- Log geofence error codes.
- Map recoverable errors to `rearm_pending`.
- Map hard failures to `geofence_not_registered` or a more specific health state.
- Surface these states on saved alarm cards and repair flows.

### 5. Location And Geofence Tasks Wait Without Timeouts

Severity: High

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:170`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:661`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:728`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:737`

Impact:

Broadcast and boot-adjacent work can block on Play Services tasks. That is risky for reliability, battery, and receiver lifetime behavior.

Expected fix:

- Use bounded `Tasks.await(task, timeout, TimeUnit.SECONDS)`.
- Cancel `getCurrentLocation` tokens on timeout.
- Prefer `goAsync` plus a bounded executor for broadcast-driven work.
- Persist retry state on timeout instead of blocking indefinitely.

### 6. Alarm Service Does Not Release Wake Lock On All Teardown Paths

Severity: High

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/AlarmRingingService.kt:80`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/AlarmRingingService.kt:223`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/AlarmRingingService.kt:338`

Impact:

`onDestroy` stops playback directly but does not call the shared `stopRingingFeedback()` cleanup path that releases the partial wake lock. The timeout limits worst-case impact to 30 minutes, but this is still a battery and correctness issue.

Expected fix:

- Call `stopRingingFeedback()` in `onDestroy()`.
- Keep playback and wake-lock cleanup unified in one path.
- Add a service lifecycle test or manual verification checklist entry.

### 7. Location Setup Async Responses Can Overwrite Newer State

Severity: High

Evidence:

- `lib/src/features/location_alarms/presentation/location_alarm_setup_screen.dart:323`
- `lib/src/features/location_alarms/presentation/location_alarm_setup_screen.dart:338`
- `lib/src/features/location_alarms/presentation/location_alarm_setup_screen.dart:425`

Impact:

Search, diagnostics, and reverse-geocode requests can complete out of order. An older request may overwrite a newer destination, label, or diagnostics state.

Expected fix:

- Add request sequence tokens for search, diagnostics, and reverse-geocode.
- Before applying a reverse-geocode label, verify that the current pinned coordinates still match the request coordinates.
- Catch platform and generic reverse-geocode failures without leaving the setup flow in a stale state.

### 8. Location Health Parsing Fails Open

Severity: High

Evidence:

- `lib/src/features/alarms/domain/alarm_location_trigger.dart:56`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmHealth.kt:16`
- `lib/src/features/location_alarms/domain/location_alarm_setup_diagnostics.dart:10`

Impact:

Unknown health IDs currently default to `healthy`. That is the wrong failure mode for location alarms because it can hide native/Dart contract drift.

Expected fix:

- Add an explicit `unknown` or `unavailable` health state.
- Fail closed for unknown IDs.
- Add a Dart/Kotlin health ID contract test or generated fixture.

## Security Findings

### 9. CI Materializes Signing Secrets In The General Android Workflow

Severity: High

Evidence:

- `.github/workflows/android.yml:3`
- `.github/workflows/android.yml:48`
- `.github/workflows/android.yml:69`

Impact:

The general Android CI workflow materializes release signing files before running repo-controlled build and test commands when secrets are present. Same-repo PRs or compromised workflow code could read signing material.

Expected fix:

- Never load production release signing secrets on `pull_request`.
- Keep release signing only in the dedicated release workflow.
- Use a protected environment for release signing.
- If CI needs release-like signing, use a throwaway CI keystore.

### 10. Manual Release Dispatch Does Not Prove The Checked-Out Ref Is The Requested Tag

Severity: Medium

Evidence:

- `.github/workflows/release.yml:7`
- `.github/workflows/release.yml:48`
- `.github/workflows/release.yml:187`

Impact:

Manual release dispatch accepts a tag name but can publish from the workflow's current ref unless checkout and verification are tightened.

Expected fix:

- Resolve and checkout `refs/tags/$tag_name`.
- Verify the tag exists.
- Verify `GITHUB_SHA` matches the intended tag commit.
- Require environment approval for manual production release.

### 11. Custom Tone Import Trusts Provider-Reported Size

Severity: Medium

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/ToneLibraryManager.kt:31`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/ToneLibraryManager.kt:137`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/ToneLibraryManager.kt:139`

Impact:

A document provider can report a file under 15 MB and then stream more data during copy. This can exhaust app storage or create oversized internal files.

Expected fix:

- Copy through a counted stream.
- Abort once `MAX_IMPORT_BYTES` is exceeded.
- Copy to a temp file first, then atomically rename.
- Delete temp files on failure.

### 12. Sensitive Alarm Data Lives In Device-Protected Storage

Severity: Medium

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/AlarmStorageContext.kt:8`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/ToneLibraryStore.kt:8`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/AlarmRecord.kt`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmRecord.kt`

Impact:

Device-protected storage is required for direct-boot alarm recovery, but not every field needs to be available before first unlock. Precise destination coordinates, labels, QR targets, tone metadata, source URIs, and custom tone files are more sensitive than schedule-critical fields.

Expected fix:

- Split direct-boot-critical state from richer credential-protected metadata.
- Keep only what is needed for alarm delivery in device-protected storage.
- Document any intentionally pre-unlock-readable data.

### 13. Exported Receiver Accepts App-Private Retry Action

Severity: Medium

Evidence:

- `android/app/src/main/AndroidManifest.xml:70`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/AlarmRescheduleReceiver.kt:31`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:621`

Impact:

The boot/time receiver must be exported for system broadcasts, but it also accepts the private location re-arm retry action. Another app can explicitly target the exported receiver and force reschedule or geofence work.

Expected fix:

- Split app-private retry into a separate non-exported receiver, or
- Reject app-private actions on exported receiver instances.

### 14. OpenCage Key And Exact Coordinates Need Stronger Privacy Posture

Severity: Medium

Evidence:

- `lib/src/features/settings/application/location_provider_settings_controller.dart:23`
- `lib/src/features/settings/application/location_provider_settings_controller.dart:47`
- `lib/src/features/location_alarms/data/opencage_reverse_geocode_repository.dart:20`

Impact:

The OpenCage key is a user-provided API token, stored in plaintext shared preferences and sent as a URL query parameter. Reverse geocoding also sends exact dropped-pin coordinates to OpenCage.

Expected fix:

- Consider Android Keystore-backed storage later.
- Hide the key by default in the UI.
- Add clear copy that dropped-pin reverse geocoding sends coordinates to OpenCage.
- Keep OpenCage optional and never required for alarm triggering.

### 15. Precise Coordinates Are Logged During Geofence Arming

Severity: Low

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:162`

Impact:

Logs can leak through bug reports, adb, or privileged collectors. Exact destination logs are more sensitive than general alarm state logs.

Expected fix:

- Remove lat/lng from production logs, or
- Round coordinates heavily, or
- Gate exact coordinate logs behind debug builds.

### 16. Persistable Tone URI Grants Are Not Released

Severity: Low

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/ToneLibraryManager.kt:39`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/ToneLibraryStore.kt:40`

Impact:

The app can keep unnecessary document permissions after a tone was copied locally or deleted.

Expected fix:

- Take persistable URI permission only when storing an external reference.
- Release grants after successful local copy.
- Release grants when deleting externally referenced tones.

## Performance And Battery Findings

### 17. App Resume Duplicates Location Alarm Work

Severity: High

Evidence:

- `lib/src/app/app.dart:53`
- `lib/src/features/dashboard/presentation/dashboard_screen.dart:55`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:226`

Impact:

Foreground resume can run multiple location checks and full alarm refreshes. This increases Play Services calls, storage writes, and UI churn.

Expected fix:

- Keep one debounced resume owner.
- Prefer last-known location for non-repair refreshes.
- Reserve full `syncAll()` for boot, package replace, permission return, explicit repair, and app startup.

### 18. Passive Listener Cleanup Can Return Early On Blocking Health

Severity: Medium

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:641`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:649`

Impact:

If permissions or location services become blocked while an approach listener was registered, the function can return without removing existing passive updates.

Expected fix:

- Always call `removeLocationUpdates(pendingIntent)` before returning on blocking health.
- Add log coverage for passive listener register/remove.

### 19. Location Sync Repeats Store Scans And Work

Severity: Medium

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:226`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:667`

Impact:

`syncAll()` and nested sync helpers repeatedly scan alarms and can re-run Play Services operations. This is acceptable for small user counts, but it is the wrong shape for reliability code that may run on boot or resume.

Expected fix:

- Add a batch sync mode that caches `store.getAll()`.
- Defer passive listener and retry scheduling until the end of the batch.
- Skip unregister/register churn when trigger parameters are unchanged.

### 20. Network Calls Have No Timeout Or Response-Size Cap

Severity: Medium

Evidence:

- `lib/src/features/location_alarms/data/photon_location_search_repository.dart:19`
- `lib/src/features/location_alarms/data/opencage_reverse_geocode_repository.dart:17`

Impact:

Search and reverse geocode requests can hang UI state or decode unexpectedly large responses.

Expected fix:

- Use a shared injectable JSON HTTP client.
- Set connection and response timeouts.
- Cap decoded JSON body size before `jsonDecode`.
- Add tests for timeout, non-2xx, socket failure, malformed JSON, and oversized response.

### 21. APK Size Is Now Large

Severity: Low

Evidence:

- release APK size: `107,274,067` bytes
- `pubspec.yaml:14`
- `android/app/build.gradle.kts:78`
- `android/app/build.gradle.kts:83`
- `android/app/build.gradle.kts:84`

Impact:

MapLibre, Flutter, CameraX, Play Services Location, and ML Kit all contribute to the universal APK footprint. This may not matter for internal testing, but it matters for public GitHub releases and slow networks.

Expected fix:

- Produce ABI split APKs or prefer AAB distribution where applicable.
- Run `flutter build appbundle --analyze-size`.
- Track size as a release note item when adding native-heavy dependencies.

## Maintainability Findings

### 22. Location Coordinator Crosses Too Many Responsibilities

Severity: Medium

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt`

Impact:

The coordinator owns readiness probing, geofence registration, retry scheduling, passive approach monitoring, current-location lookup, and persistence. It is becoming hard to reason about failure boundaries.

Expected fix:

- Extract `LocationReadinessProbe`.
- Extract `GeofenceRegistrar`.
- Extract `LocationApproachMonitor`.
- Extract `LocationRearmScheduler`.
- Keep the coordinator as orchestration glue.

### 23. Method Channel Handler Is Too Large

Severity: Medium

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/AlarmEngineMethodCallHandler.kt`

Impact:

The method handler has become a broad dispatcher for alarm CRUD, permission repair, location operations, tone operations, and status reporting.

Expected fix:

- Extract method-specific handlers or command classes.
- Add lifecycle disposal for owned executors.
- Keep method-channel parsing close to each command instead of in one central file.

### 24. Readiness Logic Is Duplicated

Severity: Medium

Evidence:

- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/AlarmEngineMethodCallHandler.kt:533`
- `android/app/src/main/kotlin/dev/neoalarm/app/alarmengine/LocationAlarmCoordinator.kt:489`

Impact:

Settings readiness and arming readiness can drift, which would confuse repair UX.

Expected fix:

- Move global location readiness into a shared native probe.
- Use that probe from status reporting, setup diagnostics, and arming.

### 25. Provider Abstraction Is Too Thin

Severity: Medium

Evidence:

- `lib/src/features/location_alarms/data/location_search_repository.dart:2`
- `lib/src/features/location_alarms/data/photon_location_search_repository.dart:19`
- `lib/src/features/location_alarms/data/opencage_reverse_geocode_repository.dart:17`

Impact:

The search abstraction exists, but provider setup, network policy, user-agent handling, and error mapping are duplicated or hard-coded.

Expected fix:

- Introduce a small location-provider HTTP client wrapper.
- Keep Photon and OpenCage as replaceable implementations.
- Centralize app user-agent/version metadata.

### 26. Documentation Has Drift

Severity: Medium

Evidence:

- `README.md:316`
- `docs/README.md`
- `docs/Doc Index.md`

Impact:

The real documentation index is `docs/Doc Index.md`, but the README points at `docs/README.md`, which has drifted into an older duplicate project overview.

Expected fix:

- Replace `docs/README.md` with a short redirect to `Doc Index.md`, or
- Make `docs/README.md` the canonical index and remove the duplicate overview content.

### 27. Version Metadata Is Inconsistent

Severity: Low

Evidence:

- `pubspec.yaml:4`
- `lib/src/features/location_alarms/data/photon_location_search_repository.dart:30`
- `lib/src/features/location_alarms/data/opencage_reverse_geocode_repository.dart:30`

Impact:

The app version says `1.0.1+2`, while HTTP user agents hard-code `1.0.3`. This makes logs and provider attribution misleading.

Expected fix:

- Centralize app metadata.
- Generate or inject user-agent version from package metadata.

### 28. Analyzer Strictness Is Light

Severity: Low

Evidence:

- `analysis_options.yaml`

Impact:

Current linting does not strongly defend the method-channel-heavy Dart code from dynamic casts, fail-open parsing, and discarded futures.

Expected fix:

- Add `strict-casts`.
- Add `strict-inference`.
- Add targeted lints for discarded futures and dynamic usage.
- Fix resulting issues incrementally instead of broad-suppressing.

## Recommended Fix Order

1. Clear native lint errors and make `lintRelease` part of the release gate.
2. Fix location trigger cleanup, boot re-arm isolation, geofence error handling, Play Services timeouts, and wake-lock teardown.
3. Fix setup async races and health fail-closed parsing.
4. Harden tone import and release workflow security.
5. Reduce duplicate resume work and passive listener leakage.
6. Add network timeouts and response-size caps.
7. Decompose native location classes and method-channel dispatcher.
8. Clean up documentation drift, version metadata, and analyzer strictness.

## Follow-Up Sprint

The execution plan for this audit is tracked in:

- `docs/planning/reliability-security-quality-hardening-sprint.md`
