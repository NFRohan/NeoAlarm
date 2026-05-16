# 0015: Location Alarm Geofencing And Provider Strategy

## Status

Accepted

## Context

NeoAlarm is considering a new alarm type that triggers near a saved destination rather than at a fixed wall-clock time.

This feature has a strong product case:

- users fall asleep on buses and trains
- time-based alarms are not enough for this use case
- destination-based alerting fits NeoAlarm's practical reliability-oriented identity

However, location alarms are much riskier than normal time alarms because they involve:

- background location permissions
- Google Play policy scrutiny
- geofence delivery latency
- OEM background behavior
- reboot re-registration
- unreliable or absent network/GPS conditions such as underground travel

The first planning pass also left too much ambiguity in three critical areas:

- what health and failure states the feature should expose
- whether NeoAlarm should trust geofencing delivery without any fallback checks
- what map and place-search provider strategy should be used for an MVP-sized user base

## Decision

NeoAlarm will implement location alarms with the following strategy.

### Trigger Model

Location alarms will be built on Android geofencing, not continuous background GPS polling.

For the MVP:

- geofence transition type: `ENTER`
- alarm type: one-shot
- radius presets: `Near (500 m)`, `City (1000 m)`, `Transit (1500 m)`

If a user is already inside the geofence at arm time, the setup flow must detect that and warn instead of assuming an `ENTER` transition will fire later.

### Execution Boundary

The existing NeoAlarm authority split remains intact:

- Flutter owns place search, pin placement, destination confirmation, permission education, health presentation, and summaries
- native Android owns geofence registration, transition handling, health evaluation, re-registration, duplicate suppression, and conversion into a normal ringing session

Location alarms must not move alarm-critical correctness back into Flutter.

### Health Model

Location alarms will not be modeled as a simple "registered or not" feature.

Each location alarm will derive an explicit health state.

Initial states:

- `HEALTHY`
- `NO_FOREGROUND_PERMISSION`
- `NO_BACKGROUND_PERMISSION`
- `LOCATION_DISABLED`
- `GEOFENCE_NOT_REGISTERED`
- `PLAY_SERVICES_UNAVAILABLE`
- `BATTERY_RESTRICTED`
- `LOW_LOCATION_CONFIDENCE`

These health states must surface in the UI per alarm, not only in a diagnostics screen.

### Reliability Policy

NeoAlarm will use geofencing as the primary trigger, but will not trust it as a perfect delivery channel.

The MVP will include a passive fallback check:

- when the app naturally returns to the foreground
- or when the device is unlocked and NeoAlarm becomes active again
- compare current location against armed location alarms
- if the device is already inside a geofence that should have triggered, trigger the alarm then

This fallback is not continuous polling and is intended as a low-cost hedge against OEM callback or geofence delivery issues.

### Reboot Policy

Location alarm configuration should survive reboot, and armed location alarms must be re-registered after reboot.

The implementation must assume geofences need re-registration after:

- device reboot
- app reinstall
- app data clear
- Google Play services data clear
- `GEOFENCE_NOT_AVAILABLE`

Re-registration must not assume a single immediate success. The implementation should support deferred registration or retry when Play services or location services are not yet ready.

True pre-unlock geofence re-registration remains a spike-validation item rather than a guaranteed property.

### Duplicate Trigger Policy

Geofence transitions must be treated as potentially duplicated or replayed.

The native layer must:

- track a stable geofence ID
- persist `registered_at`
- persist `last_transition_at`
- suppress duplicate triggers inside a native cooldown window
- disarm a one-shot location alarm after successful trigger

### Provider Strategy

The MVP will support both:

- place search
- dropping/adjusting a pin on a map

Provider choice for MVP:

- map rendering: OpenStreetMap tiles via `flutter_map`
- place search/geocoding: a provider abstraction with Nominatim as the first implementation

This decision is based on:

- small expected user volume
- no desire to take on Google Maps SDK/billing setup for the MVP
- alignment with NeoAlarm's lightweight and open posture

The product must not hardcode search-provider assumptions into the core alarm model.

The alarm record should store:

- destination label
- latitude
- longitude
- radius

It should not depend on provider-specific place IDs for correctness.

## Consequences

### Positive

- the feature fits the existing native alarm authority model
- the MVP stays battery-conscious by using geofencing, not polling
- the health model reduces the chance of silent trust-destroying failures
- the provider choice keeps MVP complexity and cost low
- the abstraction boundary leaves room to swap search providers later if quality is insufficient

### Negative

- background location permission flow is still complex
- public Nominatim quality and usage constraints may limit the MVP
- approximate location and OEM behavior still create unavoidable real-world fuzziness
- this feature will need more field validation than normal alarm features

### Operational Implications

- location alarms need stronger per-alarm diagnostics than time alarms
- the release needs explicit UX disclosure about underground and poor-signal behavior
- Samsung and other OEMs must be part of the validation matrix

## Alternatives Considered

### Continuous Background Location Polling

Rejected for MVP because:

- higher battery cost
- worse Play/policy story
- more background complexity
- unnecessary if geofencing plus fallback checks are sufficient

### Google Maps + Places For MVP

Rejected for initial MVP because:

- API keys and billing overhead
- stronger vendor lock-in
- more configuration and release complexity than needed for a very small user base

This can be revisited later if search quality becomes a real user problem.

### Geofencing With No Fallback Check

Rejected because:

- too optimistic about OEM behavior
- creates a trust-destroying silent-failure path
- leaves NeoAlarm with no recovery path when callbacks are delayed or missed
