# Sprint Plan

## Cadence

Assume 2-week sprints. That is long enough to finish meaningful slices of alarm behavior, short enough to expose bad architecture quickly, and realistic for a small team or a solo maintainer with open source overhead.

If the project is effectively solo, keep the sprint goals but treat dates as flexible. Scope discipline matters more than the calendar.

## Sprint 1: Project Bootstrap And Quality Bar

### Goal

Create a runnable Flutter project with the intended Android/Kotlin ownership boundaries and engineering guardrails.

### Scope

- bootstrap the Flutter app and Android package structure
- add initial package boundaries for alarm domain, Android bridge, missions, and vision
- set up linting, formatting, test scaffolding, and CI
- add a basic shell screen and placeholder navigation
- document code ownership boundaries that are now visible in the repo

### Done Criteria

- the app builds locally
- automated checks run in CI
- package structure reflects the documented architecture
- contributors can find roadmap, architecture docs, and ADRs from the repo root

## Sprint 2: Alarm Domain, Persistence, And Scheduling

### Goal

Make alarms real data with deterministic next-fire behavior and exact scheduling.

### Scope

- define `AlarmSpec`, recurrence rules, and timezone-aware next-fire logic
- implement local persistence for alarms
- implement bridge methods for create, update, delete, enable, and disable
- schedule alarms natively with `AlarmManager.setAlarmClock()`
- handle reboot, app update, time change, and timezone change rescheduling

### Done Criteria

- alarms can be created and toggled from the app
- the next scheduled fire time is visible and testable
- recurrence and DST rules have unit coverage
- rescheduling behavior works after reboot and time changes

## Sprint 3: Ringing Service And Recovery

### Goal

Own the active alarm lifecycle natively so the ring path is trustworthy.

### Scope

- implement the native foreground ringing service
- add looping audio, vibration, and active session persistence
- launch the full-screen alarm activity from the ring path
- add wake handling and lock-screen behavior
- recover the active session after app process death

### Done Criteria

- an alarm rings from a cold app state
- ring audio starts before Flutter mission UI loads
- the lock-screen/full-screen experience works on at least one reference device
- the active session is recoverable after force-closing the app during ringing

## Sprint 4: Dashboard, Editor, And Device Diagnostics

### Goal

Make the app usable end-to-end for alarm configuration and capability checks.

### Scope

- build the dashboard with alarm list and quick toggles
- build the alarm editor for time, repeat rules, ringtone, snooze policy, and mission selection
- add diagnostics for exact alarms, notifications, battery optimization, camera, and activity recognition
- surface unsupported-device states clearly in the UI

### Done Criteria

- a user can configure alarms end-to-end without manual native setup
- permission and capability problems are explained from inside the app
- the editor prevents invalid configurations

## Sprint 5: Mission Platform, Snooze Enforcement, And Math

### Goal

Prove the mission architecture with one fully working mission and native snooze enforcement.

### Scope

- implement `MissionSpec`, `MissionDriver`, and mission registry plumbing
- persist mission state as part of `RingSession`
- implement configurable snooze duration and snooze cap
- enforce mission completion when the snooze cap is reached
- build the `Math` mission with configurable difficulty and problem count
- add the mission confirmation entry flow and native inactivity re-trigger behavior

### Done Criteria

- a configured math alarm can only be dismissed by completing the math mission
- mission-backed alarms can silence only after explicit mission start and re-trigger after inactivity
- snooze cap behavior is reliable and test-covered
- mission-specific code does not reach into scheduler internals

## Sprint 6: Steps Mission

### Goal

Add the first physical mission and prove sensor-capability handling without weakening mission enforcement.

### Scope

- integrate the hardware step sensor
- use `TYPE_STEP_DETECTOR` for live step progress
- implement `Steps` mission configuration and runner UI
- gate the mission on device capability
- handle unsupported devices and revoked permissions cleanly
- keep the repair path in settings while hiding impossible editor configurations
- add quiet-timer visibility and harden mission activity rules against meaningless taps or shake bursts

### Done Criteria

- the steps mission works on supported devices
- unsupported devices fail clearly in the editor and active mission flow
- the quiet timer reflects the real native re-trigger deadline
- only valid mission activity can keep a mission silent
- activity-recognition and sensor edge cases are documented and manually tested

## Sprint 7: Native Vision Pipeline And QR Mission

### Goal

Add the first camera mission using the reusable native analyzer pipeline.

### Scope

- implement CameraX preview plus image analysis ownership in the Android layer
- define `VisionMissionDriver` and `VisionAnalyzer`
- add the `BarcodeAnalyzer` implementation
- build the `QR` mission editor and runner UI
- connect analyzer results to mission completion without exposing raw frames to Dart

### Done Criteria

- a QR-backed alarm can only be dismissed after scanning the configured code
- camera permission denial and recovery flows are usable
- the vision pipeline is analyzer-driven and ready for future object detection

## Sprint 8: MVP Hardening And Release Candidate

### Goal

Turn the feature set into a trustworthy first release.

### Scope

- run the full manual reliability matrix across multiple OEMs
- verify Doze behavior, reboot recovery, timezone changes, overlapping alarms, and mission recovery
- fix reliability bugs and documentation gaps
- finalize packaging, release notes, and contribution guidance

### Done Criteria

- the MVP acceptance criteria from the overall plan are satisfied
- known device-specific limitations are documented
- a sideload-ready release candidate can be built and tested by outside contributors

## Immediate Post-MVP Backlog

Treat these as the next sprint candidates after MVP, not as part of the first release:

- skip-next alarm
- one-time override for repeating alarms
- backup and restore
- timezone/travel handling refinements
- alarm history
- gradual volume ramp
- holiday/date skip rules
