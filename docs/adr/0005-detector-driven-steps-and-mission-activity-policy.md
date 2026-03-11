# ADR 0005: Detector-Driven Steps And Mission Activity Policy

- Status: Accepted
- Date: 2026-03-11

## Context

The first sensor mission forced the project to answer several questions that are easy to postpone and hard to fix later:

- should a live steps mission use `TYPE_STEP_COUNTER` or `TYPE_STEP_DETECTOR`
- should a mission remain visible in the editor when the required permission is missing
- what kinds of interaction are allowed to keep a silent mission quiet
- how should Flutter show the remaining silent window before the alarm re-triggers

These questions are connected.

The project had already introduced a silent `mission_active` phase with a native 30-second inactivity re-trigger. Once that phase exists, weak definitions of "activity" become anti-cheat bugs rather than cosmetic issues.

The steps mission also exposed a UX constraint:

- a user watching the screen expects immediate progress feedback
- a batched cumulative step total is not a good fit for a live alarm challenge

Finally, the UI needed a way to show the user how close the alarm was to re-triggering. A local Flutter timer would be easy to add, but it would not be authoritative after refreshes, native timeout resets, or process recovery.

## Decision

The project adopts the following policy.

### 1. Steps Missions Use `TYPE_STEP_DETECTOR`

The steps mission uses Android's `TYPE_STEP_DETECTOR` as the primary hardware signal.

It does not use `TYPE_STEP_COUNTER` for active mission progress.

Rationale:

- detector events provide prompt progress updates
- detector events align naturally with inactivity-timer resets
- a cumulative reboot-total counter introduces unnecessary bookkeeping and weaker live UX

### 2. Impossible Steps Configurations Are Hidden In The Editor

The `Steps` mission is only shown in the alarm editor when:

- the device reports a usable live step detector
- `ACTIVITY_RECOGNITION` is granted

If those prerequisites are missing:

- the mission is hidden from the editor
- diagnostics and settings still expose the repair path

If Android stops presenting a runtime prompt because the permission was denied persistently, the repair action may deep-link to the app's system settings page.

### 3. Mission Activity Is Mission-Specific

Only mission-valid activity may refresh the silent mission timeout.

Current rules:

- math: answer-field interaction and answer submission may refresh the timeout
- steps: accepted detector events may refresh the timeout
- generic pointer taps on the mission surface do not refresh the timeout
- permission-repair actions do not refresh the timeout

### 4. Steps Silence Uses Native Detector Evidence

For steps missions, silence is sustained by accepted native step-detector events, not by Flutter touch input.

The implementation may reject obviously impossible cadence bursts to reduce trivial shaking exploits.

### 5. Quiet Timer Is Derived From Native Session State

The active ring session persists the current mission-timeout deadline.

Flutter may display a quiet timer, but the countdown must be derived from that persisted native deadline rather than from a separate local timer that pretends to be authoritative.

## Consequences

### Positive

- the steps mission feels responsive enough for live alarm use
- the editor no longer advertises broken mission configurations
- silence enforcement is harder to exploit with meaningless taps
- revoked-permission recovery remains usable without becoming a loophole
- the quiet timer reflects the actual native re-trigger deadline

### Negative

- the activity policy is more complex than "any touch counts"
- contributors must think explicitly about what evidence a mission provides
- some devices may still misclassify motion, so the steps mission is not a perfect proof of walking
- Flutter countdown UI now depends on an additional persisted session field

## Alternatives Considered

- Use `TYPE_STEP_COUNTER`.

Rejected because batched cumulative totals are a worse fit for live mission UX and for inactivity enforcement.

- Leave `Steps` visible but disabled in the editor when permission is missing.

Rejected because it advertises an impossible configuration path instead of describing the current valid surface.

- Allow any pointer activity to refresh the silent mission timeout.

Rejected because it creates obvious exploits for both math and steps missions.

- Use a Flutter-only countdown for the quiet timer.

Rejected because the authoritative timeout is native and must survive refreshes and recovery.
