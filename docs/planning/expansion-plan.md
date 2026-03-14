# Expansion Plan

## Purpose

This document defines the product and engineering direction after the `v1.0.x` stabilization line.

NeoAlarm now has a trustworthy base:

- exact alarm scheduling is live
- ringing and dismissal enforcement are native
- `Math`, `Steps`, and `QR` missions are working
- onboarding exists for alarm-critical setup
- reboot and Doze resilience have been validated on-device
- release automation, signing, and security scanning are in place

That changes the next planning problem. The goal is no longer "make the alarm engine real." The goal is "expand user value without weakening the reliability model that the engine now provides."

## Expansion Principles

### Expand In Layers

Feature work should continue in this order:

1. daily usability improvements
2. power-user reliability features
3. new mission types
4. larger platform bets

That order is intentional. Users feel the day-to-day alarm experience before they care about novelty missions.

### Protect The Execution Boundary

Expansion work must keep the current authority split intact:

- Flutter owns product UX, setup flows, and mission rendering
- native Android owns scheduling, ringing, mission enforcement, and dismissal authority

If a feature tries to move alarm-critical correctness back into Flutter, it is probably the wrong design.

### Prefer Features That Compound

The best expansion features should make the app better for both end users and future contributors.

Examples:

- backup/export helps users keep their setup and helps contributors reason about serialized state
- gradual volume ramp improves UX without adding a new mission surface
- skip-next makes recurring alarms more usable without changing the scheduling model

## Priority Buckets

## Bucket 1: Daily Usability

These are the most valuable near-term features because they improve the app every day without introducing large architectural risk.

### Candidate Features

- skip next occurrence for repeating alarms
- gradual volume ramp
- richer ringtone options
- better empty-state and first-alarm education after onboarding

### Why This Bucket Comes First

- low architectural risk
- high user-visible value
- fits the current scheduler and editor model
- creates a stronger baseline before more ambitious mission work

### Recommended First Slice

- skip next occurrence
- gradual volume ramp
- better empty state and first-alarm guidance after onboarding

That would produce a strong practical release without changing the mission platform.

## Bucket 2: Power-User Reliability Features

These features deepen trust and control for people who rely on the app heavily.

### Candidate Features

- local backup/export
- restore/import
- alarm history
- holiday/date skip rules
- timezone/travel handling refinements
- richer OEM guidance and recovery help
- advanced diagnostics surface for alarm health and recent failures

### Why This Bucket Matters

The core alarm engine is now good enough that users will start expecting continuity and recovery features, not just raw alarm firing.

### Recommended Sequencing

1. backup/export
2. restore/import
3. alarm history
4. timezone/travel handling
5. holiday/date skip rules

Backup and restore should come before more scheduling complexity, because they make experimentation safer for both users and maintainers.

## Bucket 3: Mission Expansion

The mission platform is real now, so additional missions are viable. They should still be chosen carefully.

### Candidate Features

- memory mission
- shake mission
- multiple accepted QR targets
- stricter anti-cheat tuning for existing missions
- chained missions
- weighted or randomized mission sets

### Recommended Next Mission

The most sensible next mission is `Memory`.

Why:

- no new device permission
- no new sensor or camera edge cases
- purely local interaction logic
- good fit for the current mission runtime model

`Shake` is more fragile because it depends on motion heuristics and will reopen anti-cheat arguments much faster.

### Mission Expansion Rules

Any new mission should:

- define valid mission activity explicitly
- define how quiet-timer resets are earned
- survive interruption and session recovery
- fail clearly when prerequisites are unavailable
- avoid introducing Flutter-only completion authority

## Bucket 4: Vision And Sensor Platform Bets

These are the features that are exciting but more expensive and riskier than the earlier buckets.

### Candidate Features

- object recognition mission using the existing native vision pipeline
- multi-object or location-like recognition flows
- NFC mission
- wearable or companion-device integrations
- widgets and launcher shortcuts

### Guidance

These should not be treated as casual next steps. They are platform bets.

The strongest candidate here is object recognition, because the QR mission already proved the camera ownership model and the native analyzer boundary.

The right time to attempt it is after:

- daily usability features are stronger
- backup/export exists
- the current QR vision pipeline has another cycle of hardening

## Recommended Expansion Roadmap

## Release Line A: Usability Upgrade

Goal:

Make the app more practical for everyday use without changing the core architecture.

Scope:

- skip next occurrence
- gradual volume ramp
- better empty-state and first-alarm guidance after onboarding

Success criteria:

- repeating alarms feel less rigid
- wake-up experience feels less abrupt
- the post-onboarding home state feels intentional and ready
- no regression in exact scheduling or mission enforcement

## Release Line B: Reliability Upgrade

Goal:

Help users trust the app with real long-term use.

Scope:

- backup/export
- restore/import
- alarm history

Success criteria:

- users can move or preserve their setup locally
- recent alarm events can be inspected
- contributors can reason about serialized state more easily

## Release Line C: Mission Upgrade

Goal:

Add one new mission without destabilizing the platform.

Scope:

- memory mission
- mission-authoring doc update
- extra mission-state recovery tests

Success criteria:

- the new mission uses the same native enforcement model
- no special-case scheduler logic is introduced
- the mission platform remains composable

## Release Line D: Advanced Platform Upgrade

Goal:

Push the vision/sensor platform forward once the practical app is stronger.

Scope:

- object recognition spike
- model size and performance budgeting
- permission and fallback UX design

Success criteria:

- object recognition can be prototyped without redesigning the camera stack
- runtime cost is measurable and documented
- the feature remains optional and failure-tolerant

## Suggested Next Sprint

The best next sprint is:

- skip next occurrence
- gradual volume ramp
- better empty state and first-alarm guidance after onboarding

Why this is the best next move:

- it improves the app for every user, every day
- it uses the existing alarm and session architecture
- it avoids reopening high-risk permission and sensor work immediately after stabilization
- it creates a cleaner product baseline before the next mission sprint

Implementation guidance for this sprint:

- `skip next occurrence` should be represented as a concrete skipped local occurrence date in the alarm's own timezone, not as a boolean flag
- `gradual volume ramp` should move playback from `Ringtone` to `MediaPlayer`, expose a per-alarm ramp toggle that defaults to `off`, use per-instance ramping when enabled, and apply a carefully restored temporary minimum-volume floor only when system volume is too low to be audible
- direct-boot behavior must remain intact, which means pre-unlock ringing needs a bundled or otherwise direct-boot-safe fallback tone instead of depending on custom or credential-protected audio sources
- the bundled fallback tone should come from the new alarm asset already added to the repo and be packaged as an Android raw resource for direct-boot-safe playback

## Documentation Expectations During Expansion

Each expansion line should update:

- `README.md` when the public feature set changes
- `docs/testing/test-strategy.md` when a feature changes release validation needs
- `docs/architecture/overview.md` when system ownership or invariants shift
- ADRs when a feature changes platform policy or architecture direction

Expansion work should not be allowed to quietly erode the engineering clarity that made the core stable.

## Anti-Goals For The Next Phase

Do not rush into these just because the base is now stable:

- iOS support
- cloud sync
- account systems
- analytics dependency
- multiple large mission types in one sprint
- object recognition before the next practical usability release

The stable base is an asset. The next phase should compound it, not spend it.
