# Release Plan: Location Alarms

## Why This Feature Matters

Location alarms solve a real failure mode that time alarms do not: the user falls asleep on a bus or train and needs an alert near a destination rather than at a fixed clock time.

This is a strong fit for NeoAlarm because it extends the same product promise:

- dependable alerting
- local-first behavior
- practical user value instead of novelty

It is also a larger platform feature than a normal alarm option, so it needs explicit planning before implementation.

## Implementation Progress

Current implementation checkpoint:

- trigger-kind, health-model, and native persistence groundwork are already landed
- provider-agnostic search scaffolding is landed with a Nominatim-backed first implementation and a clean path for a better BYOK provider
- the search + map-confirmation setup flow is built behind a dedicated map widget boundary
- native geofence registration scaffolding, receiver handoff, and reboot/time-change resync hooks are in progress
- setup-time diagnostics now check health and already-inside-radius state through the native layer
- passive foreground fallback checks are wired on app resume so we are not trusting geofence delivery blindly
- the dashboard now exposes a first-pass location-alarm entry path for real-device validation
- device-level location readiness now lives in Settings, while the setup flow stays focused on destination selection, radius, and already-inside-radius warnings
- the setup surface has been tightened with an inline search action and no generic seeded `Pinned location` query text

Current refinement direction after the first exposed MVP:

- better per-alarm health and repair UX
- stronger registration/retry confidence
- hybrid geofence plus passive-approach assistance near destination
- cleaner saved-alarm editing
- search quality improvement through a BYOK provider strategy

Still intentionally pending before the feature is exposed:

- richer per-alarm repair actions outside the setup flow
- device validation of geofence registration and transition behavior
- retry/deferred re-registration after boot / Play services unavailability
- fuller tone and mission editing for location alarms

## Initial Recommendation

Treat this as a major release line after `v1.0.3`, not as a side feature.

Recommended release theme:

- `Location alarms that trigger near a saved destination`

Do **not** treat this as continuous live GPS tracking. The correct Android-first implementation is geofencing with careful background-location handling.

## Research Summary

### Android Platform Direction

Android's current geofencing documentation still points to geofences, geofence transitions, and a `BroadcastReceiver` as the intended model for proximity-based triggers.

Important current platform constraints:

- geofencing requires `ACCESS_FINE_LOCATION`
- geofencing also requires `ACCESS_BACKGROUND_LOCATION` on Android 10+
- Android allows up to `100` geofences per app per device user
- geofences can trigger on `ENTER`, `EXIT`, or `DWELL`
- users on Android 12+ can grant only approximate location
- if the app has only approximate location, background location is approximate too
- on Android 11+, background location is granted through Settings, not directly from the same initial runtime permission dialog
- Android recommends incremental permission requests: foreground first, background later

Play policy also matters:

- background location must be tied to a core user-facing feature
- the app should request the minimum scope necessary
- background location needs clear in-app disclosure and strong justification

## What This Means For NeoAlarm

### Correct Execution Boundary

Location alarms should follow the same authority split as regular alarms:

- Flutter owns place selection, setup UX, permission education, and alarm summaries
- native Android owns geofence registration, transition handling, persistence, and alarm trigger authority

That keeps correctness out of the Flutter runtime and fits the existing NeoAlarm architecture.

### Failure Model Must Be Explicit

The first version of this plan assumed an overly simple state:

- geofence registered -> eventually triggers

That is not a safe product assumption.

Location alarms need a real health model, not just a permission check.

## Location Alarm Health Model

Each armed location alarm should have an explicit derived health state, surfaced in both native logic and Flutter UI.

Recommended first-pass states:

- `HEALTHY`
- `NO_FOREGROUND_PERMISSION`
- `NO_BACKGROUND_PERMISSION`
- `LOCATION_DISABLED`
- `GEOFENCE_NOT_REGISTERED`
- `PLAY_SERVICES_UNAVAILABLE`
- `BATTERY_RESTRICTED`
- `LOW_LOCATION_CONFIDENCE`

These are not all equivalent in severity.

Recommended user-facing labels:

- `Ready`
- `Needs location access`
- `Needs background access`
- `Location off`
- `Geofence not armed`
- `Play services unavailable`
- `Battery restriction may block triggers`
- `Approximate location may be unreliable`

This should be visible per alarm, not only in a global diagnostics screen.

Why this matters:

- location alarms will fail for more reasons than time alarms
- if users cannot see that an alarm is unhealthy, trust will collapse after the first silent miss

## Reliability Strategy

### OEM And Geofencing Delivery Risk

Geofencing is the right primitive for MVP, but it should not be treated as infallible delivery.

Known risks:

- OEM background throttling
- delayed receivers
- Play services callback delays
- battery management interference on Samsung/Xiaomi-style devices

### Passive Fallback Check

MVP should include a low-cost sanity fallback:

- when the app naturally wakes into the foreground
- or when the device is unlocked and NeoAlarm becomes active again
- check current location against armed location alarms
- if the device is already inside a geofence that should have triggered, fire the alarm then

This is not continuous polling.

It is a passive recovery check for missed geofence delivery.

This should be preferred over scheduled background polling for MVP because:

- lower battery cost
- simpler policy story
- still gives us a hedge against OEM callback weirdness

### Hybrid Approach Assist

NeoAlarm should extend this reliability policy with a lightweight approach-state machine.

Recommended direction:

- keep the configured radius as the true arrival radius
- keep the inner geofence as the primary trigger
- add an outer approach zone at roughly `3x` the configured radius
- once the device enters that outer zone, register a passive fused-location listener
- if passive updates show the device has entered the inner radius before the inner geofence transition arrives, trigger the alarm then
- remove passive listeners after trigger, disable, delete, or approach cleanup

This is intentionally a low-cost assist, not a move to continuous active background polling.

### Battery Restriction Handling

Location alarms should not silently ignore battery-management risk.

If the app can detect:

- aggressive battery restriction
- exclusion from battery optimization is missing on a device where the user enabled a location alarm

then the alarm should move into a warning health state such as:

- `BATTERY_RESTRICTED`

and the UI should surface a repair action or explanation.

### Reboot And Direct-Boot Implications

Geofences are not a fire-and-forget persistent primitive across every system event.

Android's geofencing guidance explicitly says apps must re-register geofences after:

- device reboot
- app reinstall
- app data clear
- Google Play services data clear
- `GEOFENCE_NOT_AVAILABLE`

For NeoAlarm, that creates a direct-boot design question:

- location alarm configuration itself should be persisted in device-protected storage if we want armed location alarms to survive reboot before first unlock
- the app should listen for boot and locked-boot completion the same way the time-alarm engine already does
- the app should attempt to re-register location alarms after reboot if they are still armed

However, one thing must be treated as a spike item rather than an assumption:

- whether Google Play services geofencing registration is reliably available before first unlock on all target devices

So the plan should assume:

- location alarm state survives reboot
- re-registration is required after reboot
- true pre-unlock geofence restoration needs validation during the spike

### Reboot Re-Registration Retry

Re-registration after reboot cannot assume a single successful attempt.

Potential problems:

- Play services may not be ready yet
- location services may still be initializing
- the user may not have unlocked yet

So the plan should include:

- deferred re-registration if immediate registration fails
- explicit retry scheduling with backoff or retry windows
- success/failure state persisted so the alarm can surface as unhealthy instead of silently remaining unarmed

### Recommended Android Primitive

Use geofencing, not periodic background location polling.

Why:

- lower battery cost
- closer to the platform-supported model
- better fit for a local alarm engine
- easier to reason about than keeping a long-lived location loop alive in the background

### Product Name

Internally and in the UI, prefer:

- `Location alarm`

over:

- `GPS alarm`

Reason:

- geofencing is the real mechanism
- the user expectation should be "alert me near this destination", not "precise GPS stop detection"

### Map And Search Provider Strategy

For MVP, NeoAlarm should support both:

- place search
- dropping or adjusting a pin on a map

The recommended provider split is:

- map UI: OpenStreetMap tiles through `flutter_map`
- place search/geocoding: a provider abstraction with an improved BYOK implementation when configured

Current implementation:

- `flutter_map` for map rendering and pin interaction
- a `LocationSearchRepository` abstraction in Flutter
- Nominatim as the first provider behind that abstraction for MVP

Recommended next provider step:

- keep `flutter_map` for now
- add Mapbox geocoding behind the same repository abstraction
- treat Nominatim as the no-key fallback rather than the primary long-term search experience

Why this remains the right map/search split:

- no Google Maps SDK billing or account setup
- consistent with NeoAlarm's lightweight and open ethos
- keeps provider choice swappable if search quality becomes a problem later
- lets search quality improve without forcing an immediate map migration

Important guardrails:

- the alarm model should store only label, latitude, longitude, and radius
- the alarm model should not depend on provider-specific place IDs for MVP
- search provider choice should stay behind an interface so we can swap Nominatim out later without rewriting the UI flow

## MVP Product Shape

### Core Flow

1. User creates a location alarm
2. User searches for a destination or drops a pin on the map
3. User confirms the destination on the map
4. User chooses a trigger radius
5. App requests location permissions incrementally
6. Native Android registers a geofence
7. When the device enters the geofence, NeoAlarm triggers a normal ringing session

### Trigger Rule

For MVP, use:

- geofence `ENTER`

Not recommended for MVP:

- `DWELL`, which may be slower or less intuitive
- route awareness, transit-stop intelligence, or ETA prediction

### Already-Inside-Geofence Case

`ENTER` alone is not enough.

If the user is already inside the destination geofence when the alarm is armed, the transition may never fire as expected.

So the registration path should also:

- fetch a current location snapshot if possible
- check whether the device is already inside the chosen radius

Recommended behavior:

- if already inside, warn clearly and let the user decide whether to trigger immediately or pick a different destination

This should be treated as a first-class setup case, not an edge case discovered later.

### Radius

MVP should expose a small set of explicit presets rather than a free-form slider.

Recommended presets:

- `500 m`
- `1000 m`
- `1500 m`

Why presets:

- easier to explain
- less likely to create a false sense of exactness
- easier to test

Why larger values:

- Android geofence alerts are not instantaneous
- the platform documentation says alerts can be late, often under 2 minutes, around 2-3 minutes under background limits, and up to 6 minutes after long stationary periods
- on a bus or train, a user can travel well past a small radius before the `ENTER` transition is delivered

That means a tight `300 m` geofence is likely too optimistic for transit alarms. NeoAlarm should prefer larger, reality-based presets rather than pretending stop-level precision is guaranteed.

Recommended helper copy instead of semantic labels:

- `500 m is better for walking or slow traffic.`
- `1000-1500 m is safer for buses and trains because location alerts can be delayed.`

The explicit distance should stay primary. Helper copy should explain the tradeoff rather than replacing the real unit with a brand-like label.

### Alarm Lifecycle

For MVP, location alarms should be:

- one-shot by default

After firing:

- remove the active geofence
- mark the alarm as completed or disabled, depending on the final product model

Repeating location alarms should be deferred until the base model proves reliable.

## Permissions Strategy

### Permission Flow

Do this incrementally:

1. request foreground location first
2. explain why background access is needed
3. request background location only when the user actually enables a location alarm

Do **not** request foreground and background location together.

### Pre-Permission UX

The background request should not be a cold technical permission prompt.

The feature needs a pre-permission screen with explicit choice framing, for example:

- `Use location alarm with basic setup`
- `Enable full reliability`

Why:

- asking too early will tank acceptance
- asking too late will make the setup feel broken
- users should understand the tradeoff before Android sends them to Settings for background access

### Education Requirements

The feature will need a dedicated disclosure screen before the background request:

- why NeoAlarm needs location in the background
- that it is only used to trigger a destination alarm
- that users can decline and still use normal alarms

### Approximate Location

Because users can choose approximate location, the product must tolerate it.

MVP policy:

- if only approximate location is granted, still allow location alarms
- surface guidance that larger radii are safer with approximate location

Do not block the feature just because precise location is unavailable.

### Signal Limits And Underground Travel

Location alarms should explicitly disclose that they depend on location availability.

Android's geofencing troubleshooting guidance notes:

- geofence triggering often depends on network location
- poor or absent reliable data connectivity can prevent alerts
- Wi-Fi and network availability significantly affect geofence behavior

For the transit use case, that means:

- underground metro or subway travel is a known weak spot
- if the device loses usable location/network context underground, the geofence may not trigger until the user emerges and the system can resolve location again

The setup UI should say this plainly, for example:

- `Location alarms require GPS or network location. They may be late or fail underground.`

## Data Model Direction

The existing alarm model assumes time-based alarms. Location alarms need a sibling trigger model.

Recommended direction:

- add an alarm trigger type
  - `time`
  - `location`

Location alarm data should include:

- trigger kind
- destination label
- latitude
- longitude
- radius meters
- health state
- geofence id
- registered at
- last transition at
- next armed state

Do not try to overload the existing hour/minute-only model into pretending location alarms are just special time alarms.

## Native Android Architecture Direction

### New Native Pieces

Likely additions:

- `LocationAlarmRecord` fields or a generalized trigger model in `AlarmRecord`
- a geofence registration coordinator
- a geofence transition `BroadcastReceiver`
- a location health evaluator
- a path that converts a transition into a normal NeoAlarm ringing session
- an idempotent trigger gate so duplicate geofence deliveries do not create duplicate ringing sessions

### Idempotency Rules

Geofence transitions must be deduplicated.

The system should protect against:

- duplicate `ENTER` delivery
- quick repeated delivery for the same geofence
- receiver replay after restart/recovery

Recommended policy:

- store the last trigger timestamp per location alarm
- ignore repeat trigger attempts inside a short native cooldown window
- mark the alarm as no longer armed once a one-shot location alarm has successfully triggered

### Existing Pieces That Should Stay Reused

- `AlarmRingingService`
- ring session persistence
- mission handling
- dismissal flows
- playback policy

In other words, location determines **when** an alarm starts, not how ringing works after trigger.

## UI Direction

### Setup

The editor likely needs a separate setup flow rather than cramming this into the current time editor.

Recommended shape:

- `New location alarm`
- search-first place picker
- map preview with pin confirmation
- optional pin adjustment on the map
- destination summary
- radius picker
- permission health state
- reliability notes about signal and underground behavior

Recommended setup rule:

- search is the primary input because it is faster for most users
- map adjustment stays available because the user asked for pin-drop support and it is valuable for visual confirmation

### Summary Copy

Good summary examples:

- `Triggers near Dhanmondi 27`
- `Triggers within 500 m of Banani Station`

Avoid wording that implies lane-level accuracy.

## Execution Prep

Before implementation starts, the spike should explicitly create these boundaries:

### Flutter-side prep

- `LocationSearchRepository`
- search result model with label + lat/lng
- search-first destination picker UI
- map confirmation screen using `flutter_map`
- radius preset UI with semantic labels
- health-state rendering for location alarms

### Native Android prep

- location-alarm trigger model in persistence
- geofence registration coordinator
- geofence transition receiver
- health evaluator
- reboot re-registration and retry path
- duplicate-trigger suppression
- passive fallback check on foreground resume/unlock

### Spike exit criteria

The spike is successful when we can prove:

- a location alarm can be armed from a searched place
- a location alarm can be armed from a dropped pin
- the geofence is visible in native state as registered
- already-inside detection works
- duplicate transitions do not create duplicate ringing sessions
- reboot re-registration failure becomes a visible unhealthy state instead of a silent miss

## Risks And Constraints

### Technical Risks

- background location permission friction
- OEM background behavior
- approximate location causing early or late triggers
- tunnels, underground rail, or poor signal conditions
- reboot requiring explicit geofence re-registration

### Product Risks

- users may expect exact stop detection
- users may blame the alarm for bad map/location conditions
- users may not understand radius tradeoffs

### Release Risk

Because background location is sensitive, this feature needs more policy and UX work than normal NeoAlarm releases.

## Recommended MVP Rules

- use geofencing, not continuous polling
- foreground location first, background location only when needed
- one-shot alarms only
- `ENTER` transitions only
- radius presets instead of arbitrary tuning
- allow approximate location, but warn appropriately
- fail unhealthy, not silently

## Explicit Non-Goals For V1 Of This Feature

- iOS support
- transit-line integration
- route-aware ETA alarms
- multiple active destination stops per single alarm
- smartwatch companion behavior
- repeated commuter-mode automations

## Proposed Delivery Plan

### Phase 1: Architecture Spike

- validate geofence registration/removal
- validate background permission flow
- validate receiver-to-ringing integration
- validate reboot re-registration behavior
- validate whether locked-boot re-registration is viable before first unlock
- confirm behavior on Samsung with screen off
- measure real-world trigger latency at different radii
- validate already-inside-geofence behavior at registration time
- validate duplicate trigger suppression
- validate passive foreground fallback checks

### Phase 2: Product MVP

- destination setup UX
- radius presets
- permission education and repair states
- one-shot location alarm persistence and trigger path
- per-alarm health indicators
- passive fallback checks on foreground resume/unlock

### Phase 3: Hardening

- approximate-location behavior review
- longer idle validation
- OEM guidance
- Play disclosure and store-listing language
- reboot retry strategy tuning
- field validation on bus/train and underground scenarios

## Testing Strategy

This feature cannot rely on unit tests alone.

Required test layers:

- emulator geofence simulation
- mock location injection for already-inside and near-boundary cases
- screen-off device testing
- reboot and re-registration testing
- duplicate delivery testing
- approximate-location testing
- real-world field testing:
  - walking
  - road traffic
  - bus or train
  - underground / tunnel failure behavior

## Success Criteria

This feature is ready when:

- a user can configure a destination alarm without confusion
- NeoAlarm can arm and trigger it natively in the background
- missing permissions create a visible unhealthy state instead of a silent failure
- approximate-location behavior is acceptable and documented
- the feature does not weaken the existing native execution boundary

## Sources

- Android geofencing: https://developer.android.com/develop/sensors-and-location/location/geofencing
- Android background location overview: https://developer.android.com/develop/sensors-and-location/location/background
- Android runtime location permissions: https://developer.android.com/develop/sensors-and-location/location/permissions/runtime
- Android background location request flow: https://developer.android.com/develop/sensors-and-location/location/permissions/background
- Google Play sensitive permissions policy: https://support.google.com/googleplay/android-developer/answer/9888170
- Google Play background location guidance: https://support.google.com/googleplay/android-developer/answer/9799150
