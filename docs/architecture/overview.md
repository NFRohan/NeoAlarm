# Architecture Overview

## System Shape

The app is intentionally split into two execution domains:

- Flutter: user interface, alarm editing, mission configuration, non-critical state presentation
- Native Android: exact scheduling, alarm firing, ringing lifecycle, recovery, and camera analysis

This split exists because alarm correctness cannot depend on the Flutter isolate being alive when the device wakes from Doze or when the app process has been reclaimed.

## Core Subsystems

### Alarm Domain

Owns alarm definitions, repeat rules, snooze policy, mission configuration, and next-fire computation semantics.

### Android Alarm Engine

Owns:

- exact scheduling via `AlarmManager.setAlarmClock()`
- boot/time/timezone reschedule handling
- active ring session state
- foreground ringing service
- wake handling and lock-screen launch

### Mission Platform

Owns a stable mission contract so dismissal challenges can be added without rewriting the scheduler or alarm service.

Initial mission types:

- Math, implemented
- Steps, implemented
- QR, planned

Current note:

- Math progress is native-authored and Flutter-rendered
- Steps progress is driven by native `TYPE_STEP_DETECTOR` events

### Vision Pipeline

Owns camera preview and frame analysis for vision-based missions.

The pipeline is native-first:

- CameraX provides preview and image analysis
- analyzers consume frames
- Flutter receives analyzer results and mission-state updates

This keeps the QR mission fast today and makes future on-device object detection a swap of analyzer implementation rather than a rebuild of the camera stack.

## Runtime Flows

### Alarm Scheduling

1. User creates or updates an alarm in Flutter.
2. Flutter sends a normalized `AlarmSpec` to the native bridge.
3. Native persistence stores the alarm and schedules the next exact fire time.

### Alarm Firing

1. Android receives the alarm broadcast at the scheduled time.
2. A native foreground service starts immediately.
3. Audio, vibration, wakelock, and session persistence begin before Flutter UI is required.
4. A full-screen alarm activity launches over the lock screen.

### Mission Completion

1. A mission alarm first enters the `ringing` state and shows a confirmation step.
2. The user explicitly starts the mission, which transitions the session into `mission_active`.
3. Native code persists the current mission timeout deadline and exposes it to Flutter for the quiet-timer UI.
4. The mission driver reports only mission-valid activity back to the native layer.
5. Native session logic validates progress, dismissal, snooze rules, and inactivity re-triggering.
5. The service stops only after a successful dismiss path.

For current missions, the activity contract is mission-specific:

- Math: answer-field interaction and answer submission can refresh the timeout
- Steps: accepted `TYPE_STEP_DETECTOR` events refresh the timeout
- Generic screen taps do not buy silence by themselves

### Recovery

If the app process dies while an alarm is ringing, the native session state remains authoritative. Relaunch should restore the user directly into the active mission flow.

If the process dies while a mission is active, the session should still restore into the mission flow. The alarm engine, not Flutter route state, decides whether the app should show a ringing alarm, a mission in progress, or the dashboard.

## Active Session State Machine

The current active session has three persisted states:

- `ringing`: alarm audio and vibration are expected to be active
- `mission_active`: the user explicitly started the mission, the alarm is silent, and inactivity is enforced by a native timer
- `snoozed`: the session is paused until the exact snooze alarm fires

Mission inactivity is enforced natively. If a `mission_active` session goes idle for 30 seconds, the alarm re-enters `ringing` while preserving mission progress.

The session also persists the current mission-timeout deadline so Flutter can render a quiet timer from native state instead of inventing a separate client-side countdown.

See [active-session-lifecycle.md](active-session-lifecycle.md) for the full state machine and invariants.

## Key Invariants

- Alarm delivery must not depend on a live Flutter isolate.
- Ring audio must start before any mission UI dependency is satisfied.
- Persisted alarm state and persisted ring-session state must be recoverable independently.
- Mission silence must not depend on a Flutter-only timer.
- Mission silence must depend on mission-valid activity, not generic taps anywhere on the screen.
- A mission may be silent only while the native session is actively enforcing user engagement.
- If Flutter shows a quiet timer, it must be derived from the persisted native deadline.
- Mission implementations must not mutate scheduler behavior directly.
- Vision missions must depend on analyzer results, not raw cross-platform frame transport.

## Non-Goals For V1

- Cloud sync
- iOS support
- Guaranteed blocking of the stock Android power-off menu
- Server-side analytics or telemetry
