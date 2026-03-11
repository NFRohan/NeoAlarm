# 0011: Overlapping Alarm Session Stack

## Status

Accepted

## Context

NeoAlarm originally persisted only one active ring session.

That was sufficient for the first end-to-end alarm flow, but it broke down as soon as overlapping alarms were considered. If one alarm was already active and a second alarm fired before the first one had been dismissed, snoozed, or completed, the second alarm overwrote the only stored session.

That produced incorrect behavior:

- the interrupted alarm lost first-class session ownership
- in-progress missions could be stomped by the later alarm
- stale mission-timeout or snooze timers could still fire later for the older alarm
- the system had no explicit policy for simultaneous alarms beyond "last writer wins"

For an alarm engine, that is not an acceptable invariant.

## Decision

NeoAlarm persists a stack of live ring sessions instead of a single mutable slot.

The runtime policy is:

- a newly fired alarm preempts the current top active session
- the interrupted session is preserved underneath it
- interrupted `mission_active` sessions are normalized back to `ringing`
- the interrupted session's mission timeout is canceled when it is preempted
- only the top active session is rendered into Flutter or owned by the foreground ringing service
- when the top session is dismissed or snoozed, the next preserved active session resumes ringing

Snoozed sessions remain in the same persisted stack so mission progress and snooze counts survive until that alarm resurfaces.

## Consequences

Positive:

- overlapping alarms now have explicit, deterministic behavior
- an interrupted mission is preserved instead of destroyed
- stale mission timeout broadcasts are less likely to revive outdated session state
- Flutter can keep a simple "current active session" UI contract because native code still exposes only the top active session

Tradeoffs:

- the ring-session persistence model is more complex than a single-slot store
- dismiss and snooze operations must mutate only the top session instead of clearing the whole store
- service restore logic must distinguish between the currently ringing session and preserved lower sessions

## Alternatives Considered

### Keep the single active-session slot

Rejected.

This was the buggy behavior that allowed the later alarm to overwrite the earlier one with no defensible concurrency policy.

### Queue new alarms behind the current one

Rejected for now.

Queueing would delay a newly fired alarm instead of surfacing it immediately. For an alarm product, "alarm fired on time but waited behind another mission" is a harder behavior to justify than immediate preemption.

### Preserve interrupted sessions exactly as `mission_active`

Rejected.

If an interrupted mission resurfaced silently, the user could be returned to a quiet mission screen without renewed alarm noise. That is unsafe and easier to exploit. Returning resurfaced sessions to `ringing` is the stricter and more defensible rule.
