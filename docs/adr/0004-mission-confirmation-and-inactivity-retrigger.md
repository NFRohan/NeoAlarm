# ADR 0004: Mission Confirmation And Inactivity Re-Trigger

- Status: Accepted
- Date: 2026-03-11
- Related: [0005-detector-driven-steps-and-mission-activity-policy.md](0005-detector-driven-steps-and-mission-activity-policy.md)

## Context

The first mission implementation kept the alarm ringing continuously while the user solved the mission.

That behavior was simple to implement, but it was too hostile for missions that take meaningful time. The math mission already showed the problem:

- the user could be actively engaging with the challenge
- the alarm sound still continued at full intensity
- the result was irritating rather than productively coercive

At the same time, silencing the alarm too early would weaken enforcement if the user could simply open the mission screen and walk away.

We also could not rely on Flutter-only timers or route state for enforcement because:

- the app process may be reclaimed
- the Flutter isolate is not the authority for alarm state
- inactivity policy is part of the anti-cheat model and must survive UI loss

## Decision

Mission alarms will use a two-phase flow:

1. The alarm first enters a ringing confirmation phase.
2. The user must explicitly choose `Start mission`.
3. Only after that action does the session become silent and transition into a persisted `mission_active` state.

While the session is `mission_active`:

- the alarm audio and vibration are stopped
- native code schedules a 30-second inactivity timeout
- Flutter sends lightweight activity signals while the user interacts with the mission UI
- later ADRs may narrow which interactions are considered valid mission activity
- each activity signal refreshes the native timeout
- if the timeout expires, the alarm re-enters `ringing`

Mission progress is preserved across this re-trigger.

The session remains native-authoritative throughout:

- Flutter renders the current state
- native code persists the session
- native code decides dismissal eligibility
- native code owns the inactivity timer and re-trigger path

## Consequences

### Positive

- Mission-solving is materially less hostile for the user.
- The system distinguishes clearly between "alarm is firing" and "user is actively solving."
- Inactivity enforcement remains reliable even across process death.
- Re-triggering no longer requires the mission runtime to restart from scratch.
- This creates a reusable pattern for future long-running missions such as steps or QR.

### Negative

- The active session state machine is more complex.
- Flutter mission UIs now have an additional requirement: they must signal interaction activity.
- New missions must be designed with a silent-active phase in mind instead of assuming continuous ringing.
- More native timer paths now exist and must be canceled correctly on dismiss or snooze.

## Alternatives Considered

- Keep the alarm ringing continuously during mission solving.

Rejected because it makes slower missions frustrating enough that the UX degrades into noise rather than enforcement.

- Silence the alarm immediately when the mission screen opens.

Rejected because simply opening the mission screen is not a trustworthy indication of real engagement.

- Use a Flutter timer to re-trigger if the user goes idle.

Rejected because Flutter is not the authoritative execution environment for active alarm enforcement and cannot be trusted across process death or reclaim.

- Pause the alarm indefinitely once the mission begins.

Rejected because it weakens the anti-cheat model and lets a user stall without consequence.
