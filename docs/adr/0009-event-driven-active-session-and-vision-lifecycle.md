# ADR 0009: Event-Driven Active Session And Vision Lifecycle

- Status: Accepted
- Date: March 11, 2026

## Context

By the end of Sprint 7, NeoAlarm had working math, steps, and QR mission flows, but several runtime paths were still carrying bootstrap-era inefficiencies:

- the steps mission refreshed the full active session from Flutter on a 250 ms timer
- valid mission activity extended the quiet timer by starting the ringing service only to rewrite session state and stop again
- the quiet-timer countdown rebuilt the full active-alarm screen several times per second
- QR mission startup retried camera binding too aggressively on resume and widget updates
- the native vision manager did not yet have an explicit disposal path for its executor and scanner resources

None of these issues made the product incorrect, but together they weakened the architecture in three ways:

- they made the Flutter/native boundary noisier than it needed to be
- they treated service lifecycle work as a general-purpose state update mechanism
- they left native camera resources without a clean ownership end

## Decision

NeoAlarm will use an event-driven active-session propagation model and a tighter native lifecycle model for mission runtime work.

That means:

1. Persisted active ring-session changes are streamed from native Android to Flutter through a dedicated event channel.
2. Flutter uses that stream as the primary source for active-session UI updates instead of polling the full session on a short interval.
3. Mission-activity timeout extension is handled by a dedicated native coordinator that persists the updated session and reschedules the timeout alarm without spinning up the foreground ringing service.
4. The active-alarm quiet timer is repainted locally inside the timer widget instead of rebuilding the full active-alarm screen on each countdown tick.
5. The vision session manager must treat camera startup as idempotent for identical session configuration and must dispose scanner/executor resources explicitly when the activity is destroyed.

## Consequences

### Positive

- Steps progress and active-session changes now move across the Flutter/native boundary only when state actually changes.
- Mission-valid activity remains authoritative in native code without paying foreground-service churn for simple timeout refreshes.
- The active-alarm screen repaints less work during silent-mission countdowns.
- QR mission resume and permission recovery paths incur less unnecessary camera rebinding.
- The native vision pipeline now has a defensible ownership lifecycle instead of relying on process death to clean up resources.

### Negative

- The active-session model now depends on a second bridge shape in addition to point-in-time method calls.
- Contributors need to understand that event-driven session updates are the preferred path for live runtime state and should not casually reintroduce polling.
- Vision lifecycle code is slightly stricter and more stateful because it now tracks when a session is already bound and when resources have been disposed.

## Alternatives Considered

### Keep the polling model and simply slow it down

Rejected. Lower-frequency polling would reduce some churn, but it would still preserve the wrong shape: Flutter repeatedly asking for the whole active session even though native code already knows exactly when the session changes.

### Keep using the ringing service for mission timeout refreshes

Rejected. That kept a convenient entry point, but it mixed "alarm is actively ringing" concerns with "mission deadline changed" concerns and paid unnecessary service lifecycle cost for a small state update.

### Leave the vision manager mostly as-is and rely on process teardown

Rejected. Camera analyzers, scanner clients, and executors are long-lived enough that explicit disposal is part of correctness, not an optional cleanup task.

## Related

- [0002-native-vision-mission-pipeline.md](0002-native-vision-mission-pipeline.md)
- [0004-mission-confirmation-and-inactivity-retrigger.md](0004-mission-confirmation-and-inactivity-retrigger.md)
- [0005-detector-driven-steps-and-mission-activity-policy.md](0005-detector-driven-steps-and-mission-activity-policy.md)
