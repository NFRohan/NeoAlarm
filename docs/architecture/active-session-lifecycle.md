# Active Session Lifecycle

## Purpose

This document explains the authoritative lifecycle for an alarm after it has fired.

It exists because the active alarm path is the most reliability-sensitive part of the system. Contributors should be able to answer all of these questions from the repository alone:

- what states an active alarm can be in
- which layer owns each transition
- when audio is expected to be playing
- how inactivity, snooze, dismissal, and recovery behave

## Ownership Model

The active alarm session is owned by native Android, not by Flutter.

Flutter renders the current state and sends user intents back to the Android alarm engine, but it is not the source of truth for:

- whether an alarm is actively ringing
- whether a mission is in progress
- whether the session has gone idle and should re-trigger
- whether the alarm is snoozed
- whether dismissal is allowed

The persisted session stack in `RingSessionStore` is authoritative.

Only the top active session is rendered or rung at a time, but interrupted sessions may remain preserved underneath it until they resurface.

## Session States

Each live session currently has three persisted states:

### `ringing`

Meaning:

- alarm audio is expected to be playing
- vibration is expected to be active
- the foreground ringing service is the active owner of the session
- the full-screen alarm UI should be available

This state is used for:

- direct-dismiss alarms
- mission alarms before the user explicitly starts the mission
- mission alarms that were re-triggered after inactivity
- snoozed alarms when the snooze timer expires and ringing restarts

### `mission_active`

Meaning:

- the user explicitly accepted the mission entry step
- alarm audio and vibration have been stopped
- the mission is still active and dismissal may still be blocked
- a native inactivity timeout is armed
- the current inactivity deadline is persisted with the session

This state exists to reduce user-hostile behavior while keeping the anti-cheat model intact. The alarm is silent only while the user is actively working through the mission.

### `snoozed`

Meaning:

- the session is paused until the next exact snooze trigger
- no audio should be playing
- no mission progress is currently active

This state is only used when snooze is allowed and the user chose snooze.

## State Transitions

### 1. Alarm Fires

1. `AlarmReceiver` receives the scheduled broadcast.
2. Native scheduling logic updates the stored alarm definition.
3. `AlarmRingingService` starts.
4. A new or restored `AlarmRingSession` enters `ringing`.
5. Audio, vibration, notification, and lock-screen/full-screen behavior begin.

### 2. User Sees A Mission Alarm

For a mission-backed alarm, the first UI is not the mission runner.

The user first sees a confirmation step while the session is still `ringing`.

Why:

- the user needs an explicit transition from "alarm is firing" to "mission work begins"
- this is the point where the app is allowed to silence the alarm
- the system can clearly distinguish between "alarm not yet engaged" and "mission in progress"

### 3. User Starts The Mission

1. Flutter sends `startMission`.
2. Native code validates that the session exists and actually requires a mission.
3. The session transitions from `ringing` to `mission_active`.
4. Audio and vibration stop.
5. A native 30-second inactivity re-trigger timer is scheduled.
6. The exact mission timeout deadline is persisted so Flutter can render the quiet timer from native state.

### 4. User Interacts During The Mission

While the session is `mission_active`, Flutter sends lightweight activity signals back to native code.

Current examples:

- focusing or editing the math answer field
- submitting a math answer
- accepted `TYPE_STEP_DETECTOR` events for the steps mission

Each activity signal refreshes the 30-second inactivity timer.

This means the alarm stays silent only while the user is genuinely interacting with the mission.

Important exclusions:

- generic taps on empty screen space do not count as mission activity
- permission-repair buttons do not count as mission activity
- steps missions are kept silent by accepted detector events, not by touch input

### 5. User Goes Idle During The Mission

If no activity is registered for 30 seconds:

1. the native inactivity timer fires through `AlarmReceiver`
2. `AlarmRingingService` starts again
3. the session transitions back to `ringing`
4. audio and vibration resume

Mission progress is preserved. Re-triggering is not a reset of the mission; it is a reset of the alarm noise.

### 5A. Another Alarm Fires While One Is Already Active

Overlapping alarms are handled as a preemptive stack, not as a single overwrite slot.

When a newly fired alarm arrives while another session is still `ringing` or `mission_active`:

1. native code preserves the interrupted top session in the session store instead of deleting it
2. the interrupted session is normalized back to `ringing`
3. any mission inactivity timeout for the interrupted session is canceled
4. the newly fired alarm becomes the new top session and starts ringing

Why the interrupted session is normalized back to `ringing`:

- mission silence belongs only to the session that is currently on top and actively enforced
- if an interrupted mission resurfaces later, it should make noise again rather than quietly resuming in the background
- canceling its old inactivity timeout avoids stale timeout broadcasts reviving outdated session state

### Quiet Timer Visibility

Flutter may show a quiet timer while the session is `mission_active`.

That timer must be derived from the persisted native deadline rather than from a local guessed countdown. If the timeout is refreshed by native code, the UI must refresh from the session model instead of assuming its own timer is still authoritative.

### 6. User Answers Correctly

Mission handling is native-authoritative.

For the current math mission:

- a wrong answer keeps the session active and increments attempt count
- a correct answer may either advance to the next generated problem or complete the mission
- dismissal is allowed only when the native mission runtime reports completion

### 7. User Snoozes

If snooze is available:

1. native code increments the snooze count
2. the session enters `snoozed`
3. an exact snooze alarm is scheduled
4. audio and vibration stop

When the snooze alarm fires, the session returns to `ringing`.

### 8. User Dismisses

Dismissal is native-validated.

- direct-dismiss alarms can dismiss immediately
- mission alarms can dismiss only when the mission runtime reports that dismissal is allowed

On dismiss:

- notification, audio, and vibration stop
- snooze and inactivity timers for the dismissed top session are canceled
- only the dismissed top session is removed from the persisted session stack
- if another active session remains underneath, it resumes ringing

## Recovery Model

Recovery is based on the persisted session state, not on the last Flutter route.

### Process Death While Ringing

Expected behavior:

- native session remains persisted
- reopening the app restores the full-screen active alarm flow
- audio ownership remains native

### Process Death While Mission Is Active

Expected behavior:

- native session remains persisted as `mission_active`
- reopening the app should return the user to the mission flow
- the mission inactivity timer remains the native enforcement mechanism

If multiple sessions are preserved, recovery restores only the current top active session into Flutter. Lower stacked sessions remain native-persisted until they surface.

### Device Time Events

The active session is separate from alarm definition rescheduling.

Alarm definitions are rescheduled through the scheduler. Active sessions remain in the session store until dismiss, snooze, or mission-triggered re-entry clears or advances them.

## Lock-Screen And UI Behavior

The app should surface the active alarm UI for both `ringing` and `mission_active` sessions.

That is why the Android activity checks whether a session is active, not only whether it is currently ringing. A mission in progress is still an active alarm session and should not silently drop the user back to the dashboard.

## Current Invariants

- Flutter must not become the authority for active alarm state.
- `ringing` means the service is expected to be responsible for audio and vibration.
- `mission_active` means the alarm is silent but still enforceable.
- inactivity re-triggering must be driven by native timers, not Flutter timers.
- any quiet timer shown in Flutter must reflect the persisted native timeout deadline.
- re-triggering must preserve mission progress.
- overlapping alarms must preserve interrupted sessions instead of overwriting them.
- resurfacing interrupted sessions must return to `ringing`, not silently re-enter `mission_active`.
- mission activity must be mission-specific and must not be reducible to random pointer taps.
- dismissing or snoozing the top session must cancel its own snooze and mission inactivity timers without destroying preserved lower sessions.
- active-session recovery must work even if the app route stack is lost.

## Contributor Rules

- Do not add mission logic that bypasses the session store.
- Do not make silence during a mission depend on a Dart-only timer.
- Do not treat "user opened the mission screen" as equivalent to "user actively engaged the mission".
- Do not let permission-repair actions or generic mission-surface taps extend silence unless that is intentionally part of the mission definition.
- Do not reset mission progress when inactivity re-triggering happens unless that behavior is intentionally redesigned and documented.

## Known Scope Limits

The current inactivity model is intentionally simple:

- one fixed timeout window of 30 seconds
- activity is signaled from explicit mission-valid interactions
- steps rely on a native step detector rather than generic motion inference
- no attempt is made to infer attention from foreground state or accessibility events beyond the defined mission signals

If this behavior changes, update this document and write an ADR if the state machine or ownership model changes with it.
