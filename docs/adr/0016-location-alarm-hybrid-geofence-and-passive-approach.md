# 0016: Location Alarm Hybrid Geofence And Passive Approach

## Status

Accepted

## Context

Location alarms already use Android geofencing as the primary trigger mechanism.

That gives NeoAlarm the right battery and policy posture, but it leaves a real product gap:

- geofence transitions can be late
- transit users can move a meaningful distance during that delay
- OEM background behavior can make delivery fuzzier than a user expects

The obvious response would be continuous background polling or an always-on higher-accuracy tracking mode.

That is not a good default for NeoAlarm because it would:

- increase battery cost
- increase background-complexity and policy risk
- push the feature toward foreground-service requirements for reliable behavior
- weaken the product's lightweight and practical posture

NeoAlarm needs a middle ground that improves approach accuracy without turning location alarms into an always-tracking subsystem.

## Decision

NeoAlarm will use a hybrid state machine for location alarms.

### Primary Trigger Model

The inner geofence remains the source of truth for alarm arrival.

- the configured radius is the actual trigger radius
- entering that geofence triggers the normal NeoAlarm ringing flow
- one-shot cleanup still happens after a successful trigger

### Approach Assist Model

NeoAlarm may arm an outer approach zone around the destination.

Recommended initial policy:

- outer approach radius: approximately `3x` the configured trigger radius
- inner trigger radius: the user-selected destination radius

While the device is outside the outer zone:

- geofence-only behavior applies

When the device enters the outer zone:

- keep the inner geofence armed
- register a passive fused-location listener as a low-cost assist

While the device remains in the approach zone:

- passive location updates may be used to detect crossing into the inner radius earlier than the inner geofence transition arrives
- passive updates may also refresh alarm-specific confidence or state metadata

When the device enters the inner radius:

- trigger the alarm
- remove passive listeners
- clear approach-state bookkeeping

When the alarm is disabled, deleted, or triggered:

- remove all location listeners and approach-state metadata

### Location Provider Policy

The hybrid assist will use Android's fused location provider, not raw GPS polling.

That means:

- `GeofencingClient` remains the primary proximity trigger
- `FusedLocationProviderClient` remains the source for passive assist behavior and one-shot location snapshots

NeoAlarm will not attempt to build its own lower-level GPS plus sensor fusion stack.

### Background Tracking Policy

NeoAlarm will not use continuous active background polling by default.

Specifically:

- no always-on balanced-power tracking loop
- no always-on high-accuracy tracking loop
- no default foreground service just to improve location-alarm precision

Future opt-in enhanced-accuracy behavior may revisit temporary active tracking, but that is explicitly out of scope for the current refinement sprint.

## Consequences

### Positive

- keeps geofencing as the battery-efficient backbone
- improves the chance of detecting arrival sooner when the system is already producing location updates
- avoids making foreground-service location tracking the default product behavior
- fits the current native execution boundary with minimal architectural churn

### Negative

- passive listeners are still best-effort, not guaranteed
- underground or no-signal scenarios remain a known weakness
- the outer-zone state machine adds more native lifecycle bookkeeping
- users may still need larger radii for bus and train use cases

### Operational Implications

- native persistence should capture enough approach-state metadata to recover cleanly
- duplicate-trigger suppression must continue to apply whether arrival came from geofence entry or passive detection
- validation must include outer-zone entry, inner-radius arrival, and cleanup behavior

## Alternatives Considered

### Geofence Only

Rejected as the sole strategy because:

- it is the cheapest approach but does not address the observed latency problem well enough for transit use cases

### Continuous Background Polling

Rejected because:

- higher battery cost
- background update throttling limits the real-world value
- stronger foreground-service pressure for reliability

### Foreground-Service High-Accuracy Tracking Near Destination

Rejected as the default because:

- it is too heavy for the base product posture
- it adds notification and policy complexity
- it should be reserved, if ever used, for a future opt-in mode rather than the default location-alarm path
