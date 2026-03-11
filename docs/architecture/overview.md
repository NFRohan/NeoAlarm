# Architecture Overview

## System Shape

The app is intentionally split into two execution domains:

- Flutter: user interface, alarm editing, mission configuration, non-critical state presentation
- Native Android: exact scheduling, alarm firing, ringing lifecycle, recovery, camera analysis, and performance-critical session timing

This split exists because alarm correctness cannot depend on the Flutter isolate being alive when the device wakes from Doze or when the app process has been reclaimed.

Direct-boot note:

- Flutter startup is treated as a conditional shell, not an always-safe initialization environment
- native code decides whether the device is unlocked
- before first unlock, Flutter may show active alarm UI but otherwise stays on a minimal direct-boot-safe screen instead of loading the full dashboard

## Core Subsystems

### Alarm Domain

Owns alarm definitions, repeat rules, snooze policy, mission configuration, and next-fire computation semantics.

### Android Alarm Engine

Owns:

- exact scheduling via `AlarmManager.setAlarmClock()`
- boot/time/timezone reschedule handling, including `LOCKED_BOOT_COMPLETED`
- active ring session state
- foreground ringing service
- wake handling and lock-screen launch

Security note:

- lock-screen/full-screen alarm window flags are authorized by persisted active-session state, not by a forgeable incoming activity action
- exported reschedule entry points are constrained to expected system actions and treated defensively
- local persistence is device-protected for alarm/session recovery and Android auto-backup is disabled for MVP
- shell-driven profiling is exposed only through the dedicated `benchmark` target, not through the shipped app manifest

### Mission Platform

Owns a stable mission contract so dismissal challenges can be added without rewriting the scheduler or alarm service.

Initial mission types:

- Math, implemented
- Steps, implemented
- QR, implemented

Current note:

- Math progress is native-authored and Flutter-rendered
- Steps progress is driven by native `TYPE_STEP_DETECTOR` events
- Active-session UI updates are streamed from the native session store instead of being polled from Flutter on a short interval

### Vision Pipeline

Owns camera preview and frame analysis for vision-based missions.

The pipeline is native-first:

- CameraX provides preview and image analysis
- analyzers consume frames
- Flutter receives analyzer results and mission-state updates
- identical vision-session restarts are treated idempotently instead of forcing unnecessary camera rebinds
- camera analysis resources are disposed explicitly when the host activity is destroyed

This keeps the QR mission fast today and makes future on-device object detection a swap of analyzer implementation rather than a rebuild of the camera stack.

Dependency note:

- the current QR implementation depends on ML Kit barcode scanning
- that dependency chain pulls in `com.google.android.datatransport.runtime`
- the resulting small background job activity is currently accepted and tracked rather than treated as app-authored alarm work

## Runtime Flows

### Alarm Scheduling

1. User creates or updates an alarm in Flutter.
2. Flutter sends a normalized `AlarmSpec` to the native bridge.
3. Native persistence stores the alarm and schedules the next exact fire time.

### Alarm Firing

1. Android receives the alarm broadcast at the scheduled time.
2. A native foreground service starts immediately.
3. If another alarm session is already active, native code preserves it beneath the incoming session instead of overwriting it.
4. Audio, vibration, wakelock, and session persistence begin before Flutter UI is required.
5. A full-screen alarm activity launches over the lock screen only when native session state confirms that an alarm is active.

### Mission Completion

1. A mission alarm first enters the `ringing` state and shows a confirmation step.
2. The user explicitly starts the mission, which transitions the session into `mission_active`.
3. Native code persists the current mission timeout deadline and exposes it to Flutter for the quiet-timer UI.
4. The mission driver reports only mission-valid activity back to the native layer.
5. Native session changes are streamed back to Flutter so mission UI can react without high-frequency polling.
6. Native session logic validates progress, dismissal, snooze rules, and inactivity re-triggering.
7. The service stops only after a successful dismiss path.

For current missions, the activity contract is mission-specific:

- Math: answer-field interaction and answer submission can refresh the timeout
- Steps: accepted `TYPE_STEP_DETECTOR` events refresh the timeout
- Generic screen taps do not buy silence by themselves

### Recovery

If the app process dies while an alarm is ringing, the native session state remains authoritative. Relaunch should restore the user directly into the active mission flow.

If the process dies while a mission is active, the session should still restore into the mission flow. The alarm engine, not Flutter route state, decides whether the app should show a ringing alarm, a mission in progress, or the dashboard.

If the device reboots before first unlock, direct-boot-aware components can still read persisted alarm and session state from device-protected storage, rebuild the exact schedules, and preserve alarm behavior across restart.

## Active Session State Machine

NeoAlarm persists a stack of live ring sessions, not a single mutable slot.

Only the top active session is rendered into Flutter or owned by the foreground ringing service at any given time. Older interrupted sessions remain persisted underneath it until they are resumed, snoozed, or dismissed.

Each session still has three persisted states:

- `ringing`: alarm audio and vibration are expected to be active
- `mission_active`: the user explicitly started the mission, the alarm is silent, and inactivity is enforced by a native timer
- `snoozed`: the session is paused until the exact snooze alarm fires

Mission inactivity is enforced natively. If a `mission_active` session goes idle for 30 seconds, the alarm re-enters `ringing` while preserving mission progress.

The session also persists the current mission-timeout deadline so Flutter can render a quiet timer from native state instead of inventing a separate client-side countdown.

If a second alarm fires while another is already active:

- the newly fired alarm preempts the current top session
- the interrupted session is normalized back to `ringing` and kept beneath the new one
- its mission inactivity timeout is canceled so stale timers cannot resurrect it incorrectly
- once the top alarm is dismissed or snoozed, the next preserved session resumes ringing

See [active-session-lifecycle.md](active-session-lifecycle.md) for the full state machine and invariants.

## Key Invariants

- Alarm delivery must not depend on a live Flutter isolate.
- Reboot recovery before first unlock must depend on device-protected alarm/session persistence, not credential-protected defaults.
- Flutter startup before first unlock must stay minimal and must not assume arbitrary plugin initialization is safe.
- Ring audio must start before any mission UI dependency is satisfied.
- Alarm-only lock-screen/full-screen UI must depend on native active-session state, not on incoming intent claims alone.
- Persisted alarm state and persisted ring-session state must be recoverable independently.
- Overlapping alarms must preempt by preserving the interrupted session, never by overwriting it.
- Local alarm and mission persistence must not be silently exported through Android auto-backup defaults in MVP.
- Mission silence must not depend on a Flutter-only timer.
- Live active-session UI must not depend on high-frequency polling of the full native session.
- Mission silence must depend on mission-valid activity, not generic taps anywhere on the screen.
- A mission may be silent only while the native session is actively enforcing user engagement.
- If Flutter shows a quiet timer, it must be derived from the persisted native deadline.
- Mission implementations must not mutate scheduler behavior directly.
- Vision missions must depend on analyzer results, not raw cross-platform frame transport.
- Vision resources must have an explicit lifecycle end instead of relying on process teardown.
- Performance investigation should prefer Macrobenchmark and Perfetto over ad hoc frame summaries once runtime behavior is in question.

## Non-Goals For V1

- Cloud sync
- iOS support
- Guaranteed blocking of the stock Android power-off menu
- Server-side analytics or telemetry
