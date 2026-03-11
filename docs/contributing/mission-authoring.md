# Mission Authoring Guide

## Purpose

This guide explains how to add or extend dismissal missions without weakening alarm reliability or creating hidden coupling between the Flutter UI and the Android alarm engine.

Read this after:

- [../architecture/overview.md](../architecture/overview.md)
- [../architecture/active-session-lifecycle.md](../architecture/active-session-lifecycle.md)

## Design Intent

Missions are not mini-apps bolted onto the alarm screen.

They are part of a constrained platform with three hard requirements:

- alarm scheduling must remain independent of mission code
- dismissal authority must remain native
- mission progress must survive process death and re-entry

If a new mission shape breaks one of those requirements, the platform contract has changed and the change needs architecture documentation and probably an ADR.

## Current Mission Layers

### Flutter Domain Configuration

Mission configuration is represented in Dart by `MissionSpec`.

This owns:

- mission type
- mission-specific editor configuration
- user-facing mission summary

Current mission-specific config includes:

- math difficulty
- math problem count
- step goal

### Native Mission Configuration

Mission configuration is mirrored in Kotlin by the native `MissionSpec`.

This exists because the native ring session must be able to:

- construct mission runtime state without Flutter
- persist mission progress
- decide whether dismissal is allowed

The Dart and Kotlin mission config models are a compatibility boundary. If you change one, you almost certainly need to change the other in the same patch.

### Runtime Mission State

Runtime state is not the same as editor configuration.

Runtime state is owned by native code through `AlarmMissionRuntime`.

This owns:

- completion status
- mission progress
- per-problem or per-challenge state
- dismissal authorization

Flutter reads this state through `ActiveMissionSnapshot`.

### Mission UI Driver

Flutter mission rendering is organized through `MissionDriver`.

A mission driver is responsible for:

- building the runner UI
- consuming the current active session
- sending mission actions back through the shared callbacks

Mission drivers should not:

- reschedule alarms
- edit alarm definitions
- decide dismissal rules locally
- own alarm audio behavior

## Current User Flow For Mission Alarms

Mission alarms are intentionally split into two phases:

### 1. Confirmation Phase

State:

- session is `ringing`
- alarm audio is still playing

UI expectation:

- show the current alarm
- show a `Start mission` action
- allow snooze if snooze is still permitted

Purpose:

- the user explicitly transitions from alarm firing into mission solving

### 2. Mission Active Phase

State:

- session is `mission_active`
- alarm audio is silent
- native inactivity timeout is armed

UI expectation:

- show the mission runner
- send activity signals while the user interacts
- preserve mission progress across refresh and recovery

Purpose:

- make solving tolerable without losing anti-cheat pressure

## Required Integration Points

When adding a mission, check each layer below.

### 1. Add Mission Configuration

Update:

- Dart `MissionSpec`
- Kotlin `MissionSpec`
- editor UI
- serialization tests

Requirements:

- configuration must have deterministic defaults
- unsupported devices must fail clearly in the editor

### 2. Add Native Runtime State

Update:

- `AlarmMissionRuntime`
- native serialization
- native completion rules

Requirements:

- runtime state must be reconstructable from persisted JSON
- completion must be computed natively

### 3. Add Flutter Snapshot Support

Update:

- `ActiveMissionSnapshot`
- any mission-specific snapshot parsing

Requirements:

- Flutter must be able to render mission progress after app restart

### 4. Add Driver Registration

Update:

- `MissionRegistry`
- mission runner widget

Requirements:

- drivers should remain thin UI adapters over platform state

### 5. Wire Activity Signaling

If the mission can take time, it must signal activity while the user interacts.

Examples:

- text entry
- taps on mission controls that are actually part of solving the mission
- camera scan interactions
- accepted sensor mission checkpoints

Without activity signaling, the native inactivity timeout will re-trigger ringing even while the mission UI is visible.

Important rule:

- do not treat generic screen taps as activity unless they are genuinely meaningful to the mission
- do not let permission-repair actions count as mission progress or quiet-time extension
- if the mission is hardware-driven, prefer native-origin evidence over Dart-side guesses

### 5A. Define Capability Gating And Recovery

Be explicit about:

- what hardware is required
- what runtime permission is required
- whether the mission should be hidden or disabled when prerequisites are missing
- where the repair path lives

Current policy:

- impossible mission configs should be hidden from the editor instead of being saved in a broken state
- diagnostics or settings may still expose a repair action to make the mission available later

### 6. Define Dismiss Semantics

Be explicit about:

- what counts as progress
- what counts as completion
- whether progress is incremental or all-or-nothing
- whether the mission can be resumed after inactivity re-triggering

Write these rules down in docs if they are not obvious.

### 7. Define Quiet-Timer Behavior

If the mission can enter a silent `mission_active` state, define:

- what resets the quiet timer
- what must never reset it
- whether Flutter needs to display the remaining silent window

Current policy:

- native code owns the timeout deadline
- Flutter may display that deadline but must not invent its own authoritative timer
- the displayed countdown should refresh from session state after valid mission activity

## Rules For Mission Authors

- Keep mission-specific persistence inside the mission runtime, not in ad hoc UI state.
- Treat Flutter as a rendering layer and intent sender, not as the dismissal authority.
- Prefer explicit runtime fields over deriving critical state from UI assumptions.
- Preserve progress across temporary UI loss and process death unless a reset is deliberate and documented.
- Gate unsupported hardware and permission states in the editor before an alarm is saved in a broken configuration.
- Prefer native-origin sensor, analyzer, or permission state over client-side approximations when anti-cheat matters.

## Math And Steps As Reference Implementations

The current math mission demonstrates:

- mission config mirrored across Dart and Kotlin
- native-generated runtime challenges
- configurable difficulty
- configurable problem count
- incremental mission progress
- silent mission solving with inactivity re-trigger

The current steps mission demonstrates:

- permission and hardware gating before configuration
- native detector-driven progress
- mission-specific activity signals from hardware rather than generic touch input
- quiet-time enforcement that is visible in Flutter but owned by native state

Use math and steps as the reference shapes before adding `QR` or future missions.

## Testing Expectations For New Missions

At minimum, add coverage for:

- config serialization round-trips
- native runtime state serialization
- correct completion rules
- incorrect input handling
- recovery after session reload
- inactivity re-trigger behavior if the mission can remain active for extended time
- permission-revoked behavior if the mission depends on a runtime permission
- quiet-timer refresh behavior when valid activity occurs
- exploit cases where invalid taps or gestures should not keep the mission silent

Also add manual-device validation notes if the mission depends on:

- sensors
- camera
- permissions
- lock-screen behavior
- OEM-specific background limits

## When To Write An ADR

Write an ADR if the mission requires changing:

- the active session state machine
- dismissal authority boundaries
- mission/plugin contract shape
- inactivity policy
- camera ownership or analyzer flow

If a contributor cannot understand why the mission platform behaves the way it does from the repository alone, the documentation is incomplete.
