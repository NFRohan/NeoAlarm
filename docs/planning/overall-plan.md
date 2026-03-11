# Overall Implementation Plan

## Summary

Build an Android-first, local-first, open source alarm app with a Flutter UI shell and a native Android execution core. The app should be trustworthy as an alarm first, extensible as a mission platform second, and well-documented enough that experienced contributors can extend it without reverse-engineering hidden assumptions.

The first release should optimize for:

- exact alarm delivery on Android 10+
- ringing that survives Flutter isolate death and process reclaim
- mission-enforced dismissal
- clean local-only operation with no ads, subscriptions, or backend
- a codebase and documentation set that can support strong outside contributors

## Product Direction

### Platform And Release Strategy

- Android only for the initial product line
- Sideload-first distribution for MVP
- Flutter for UI and editor flows
- Kotlin-native Android components for alarm-critical behavior

### MVP Feature Set

- Alarm CRUD with multiple alarms
- Repeat scheduling by weekday
- Exact scheduling with `AlarmManager.setAlarmClock()`
- Foreground ringing service with looping audio and vibration
- Full-screen alarm launch over the lock screen
- Configurable snooze duration and maximum snooze count
- Mission-enforced dismissal with `Math`, `Steps`, and `QR`
- Mission confirmation flow that silences the alarm only after explicit mission start
- Native inactivity re-trigger while a mission is active
- A quiet-timer indicator sourced from the persisted native mission timeout
- Local storage for alarms, sessions, and mission configuration
- Recovery into the active mission screen after process death or forced app relaunch
- Permissions and device-health diagnostics for exact alarms, notifications, camera, sensors, and battery optimization status
- Steps mission gating and repair flow for missing `ACTIVITY_RECOGNITION`
- Mission-specific activity enforcement so silence cannot be prolonged by meaningless taps

### Early Post-MVP Feature Pack

Prioritize practical reliability features before novelty features:

- skip-next alarm
- one-time override for repeating alarms
- backup and restore via local import/export
- timezone and travel handling
- alarm history
- gradual volume ramp
- holiday/date skip rules from local config or imported calendar data

## Engineering Plan

### Phase 1: Foundation And Bootstrap

- Create the Flutter app and Android module structure
- Establish package boundaries for alarm domain, Android bridge, missions, and vision
- Set up linting, formatting, test scaffolding, and CI
- Lock the initial core types and bridge surface
- Keep docs and ADRs ahead of implementation changes

### Phase 2: Alarm Domain And Exact Scheduling

- Implement `AlarmSpec`, recurrence rules, timezone-aware next-fire computation, and local persistence
- Build the Flutter-to-native bridge for create, update, delete, enable, and disable flows
- Implement native scheduling with boot, app update, time change, and timezone change rescheduling
- Define DST handling explicitly and test it

### Phase 3: Ringing Lifecycle And Recovery

- Add the native foreground service for audio, vibration, and active session ownership
- Persist `RingSession` independently of alarm definitions
- Launch a full-screen alarm activity from the ringing path
- Add wake handling and recovery logic so the active alarm survives process death

### Phase 4: Mission Platform

- Define a stable mission contract and mission registry
- Implement mission state tracking as part of the active ring session
- Add the `Math` mission first to prove the contract
- Make math configurable enough to prove mission-specific runtime state, not just one-shot completion
- Enforce snooze limits through native session logic
- Define how long-running missions stay enforceable without continuous audio

### Phase 5: Sensor And Vision Missions

- Add `Steps` using `TYPE_STEP_DETECTOR` where available
- Gate the mission on sensor support and `ACTIVITY_RECOGNITION`, with a repair path in settings
- Filter impossible cadence bursts and keep silent mission time tied to accepted native step events
- Build the native CameraX-based `VisionMissionDriver`
- Implement `QR` as the first `VisionAnalyzer`
- Keep camera ownership native so future object-detection analyzers can be swapped in without redesign

### Phase 6: Flutter Shell And Diagnostics

- Build the dashboard, alarm editor, and active alarm screen
- Add permission and device-health diagnostics into editor and settings flows
- Make failure states explicit so users know why a feature or mission is unavailable

### Phase 7: Hardening And Release Readiness

- Build a manual device matrix across Pixel, Samsung, and at least one aggressive OEM
- Validate Doze, reboot recovery, clock/timezone changes, overlapping alarms, and lock-screen launch
- Add release notes, contributor guidance, and missing ADRs for final MVP behavior
- Publish a sideload-ready release candidate

## Architecture Commitments

- Alarm delivery and ringing are native responsibilities
- Flutter does not own the authoritative active-ring lifecycle
- Mission implementations extend through stable interfaces and do not mutate scheduling internals
- Vision missions consume native analyzer results, not raw frames pushed through Dart
- Documentation changes ship with behavior changes

## Core Types And Interfaces

- `AlarmSpec`: alarm identity, label, time, timezone, repeat rule, enabled flag, ringtone, volume policy, snooze policy, mission spec
- `MissionSpec`: mission type plus mission-specific configuration
- `RingSession`: active alarm session state machine, snooze count, start time, mission progress, and mission inactivity enforcement
- `AlarmEngineApi`: bridge contract for alarm CRUD, scheduling actions, active session queries, and diagnostics
- `MissionDriver`: extension contract for editor UI, runner UI, validation, and completion reporting
- `VisionMissionDriver` and `VisionAnalyzer`: native camera mission contracts for QR now and object recognition later

## Quality Bar

The project should read like it was built by engineers who expect outside scrutiny.

That means:

- architecture choices are documented, not implied
- invariants are written down before they become bugs
- tests cover rule-heavy logic and integration boundaries
- unsupported device states fail clearly instead of silently
- mission activity definitions are explicit and enforceable
- contributor-facing extension seams are named and stable

## Success Criteria For MVP

The MVP is complete when:

- an enabled alarm reliably fires on time from a cold app state
- ringing starts without requiring Flutter to be alive first
- a full-screen alarm experience launches from the lock screen
- snooze limits are enforced consistently
- a mission can move from ringing to silent solving without losing enforcement
- the quiet timer shown in Flutter reflects the native re-trigger deadline
- `Math`, `Steps`, and `QR` can each gate dismissal
- active missions recover correctly after app process death
- impossible mission configs are hidden or blocked before they can be saved
- contributors can identify the alarm engine, mission platform, and vision pipeline boundaries from docs alone

## Deferred For Later

- iOS support
- stock-Android power-menu blocking guarantees
- cloud sync
- telemetry and analytics
- memory game
- shake mission
- TFLite object recognition
- NFC mission
- wearable integrations
- home-screen widgets
