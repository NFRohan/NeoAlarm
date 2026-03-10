# ADR 0003: Exact Alarm Permission Strategy

- Status: Accepted
- Date: 2026-03-11

## Context

The app is an alarm-clock product, and exact scheduling is part of the core promise. Android's exact-alarm model differs by OS generation:

- Android 13+ supports `USE_EXACT_ALARM` for qualifying alarm-clock or calendar apps
- Android 12 and 12L use the special app-access flow around `SCHEDULE_EXACT_ALARM`

Using only `SCHEDULE_EXACT_ALARM` on newer Android versions creates avoidable friction for the primary alarm-clock use case.

## Decision

Use:

- `USE_EXACT_ALARM` for Android 13+
- `SCHEDULE_EXACT_ALARM` only for Android 12 and 12L via `maxSdkVersion="32"`

Keep an in-app settings handoff for the older special-access path when exact-alarm capability is unavailable.

## Consequences

- Newer Android versions should not require a manual exact-alarm grant for the core alarm-clock role.
- Android 12 and 12L still have a user-visible special-access path, so the app must surface that clearly.
- The permission strategy is aligned with the app's sideload-first, alarm-clock-first distribution model.

## Alternatives Considered

- Use only `SCHEDULE_EXACT_ALARM` on every supported Android version
- Avoid exact alarms and rely on inexact or deferred scheduling

The first option adds unnecessary friction on newer Android versions. The second option breaks the product's reliability target.
