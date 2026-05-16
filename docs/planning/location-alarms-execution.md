# Location Alarms Execution Plan

## Goal

Ship location alarms as a reliable new trigger type without collapsing the native execution boundary or hardwiring the MVP provider choice into the alarm core.

## Delivery Strategy

The work is intentionally split into vertical slices that preserve a runnable app after each step.

## Slice 1: Trigger And Health Groundwork

Status: Completed

Delivered:

- trigger-kind support in the shared alarm model
- location-trigger and health-state domain types
- native persistence support for location alarm records
- scheduler guardrails so location alarms are not mis-scheduled as time alarms
- location capability fields in engine status
- native permission/settings hooks for foreground/background location
- provider abstraction for location search
- first Nominatim-backed repository implementation
- provider abstraction is in place so search can move to a BYOK provider later without touching the alarm core

Validation:

- `flutter analyze`
- `flutter test`
- `flutter build apk --release`

Notes:

- the provider abstraction is the important architectural win here
- Nominatim is the first implementation, not a core dependency of the alarm model
- the next refinement pass should upgrade search quality behind the same abstraction rather than rewriting the map flow

## Slice 2: Flutter Setup Flow

Status: Completed

Target:

- search-first destination setup
- map confirmation with pin adjustment
- explicit distance presets with helper guidance
- no geofence arming yet

Deliverables:

- location setup controller/state
- search UI using `LocationSearchRepository`
- map UI isolated behind a widget boundary that can be replaced later if the provider strategy changes
- return a normalized `AlarmLocationTrigger` draft payload
- radius preset domain with explicit distance choices

Delivered:

- `LocationAlarmSetupController` and immutable setup state
- `LocationAlarmSetupScreen` that returns a normalized location-trigger draft
- `LocationAlarmMap` as the dedicated map-rendering boundary
- `flutter_map` + OpenStreetMap tile rendering with `latlong2`
- a current-location recenter control that uses native fused-location lookup to jump and zoom the map without tying the setup flow to a specific map provider
- unit coverage for setup-controller search, pin-drop, and edit seeding

Validation:

- parser and state tests where useful
- smoke verification that the setup flow loads, searches, and returns a selected destination payload
- `flutter analyze`
- `flutter test`
- `flutter build apk --release`

Notes:

- the setup flow exists but is intentionally not exposed from the dashboard yet
- this keeps users away from a half-armed location alarm until native geofence arming is ready
- future refinement should improve copy and search quality without replacing the whole flow

## Slice 3: Native Geofence Registration

Status: In progress

Target:

- register, remove, and re-register location alarm geofences natively
- keep location alarms persisted in device-protected storage
- keep failure visible through health state instead of silent misses

Deliverables:

- geofence coordinator
- transition receiver
- native health evaluation
- per-alarm registration bookkeeping
- reboot re-registration scaffolding with retry/defer hooks

Delivered so far:

- `LocationAlarmCoordinator` for geofence register/remove/sync flows
- `LocationAlarmReceiver` with duplicate-trigger suppression and handoff into the normal ringing path
- background `rescheduleAll` integration so reboot/time-change resync covers location alarms too
- asynchronous method-channel handling for location-alarm upsert, enable/disable, delete, and reschedule operations
- Android manifest receiver wiring and Play services location dependency
- setup-time native diagnostics for health and already-inside-radius checks
- passive foreground fallback check wired through the app resume path
- dashboard card rendering can now show location-trigger radius and health state when location alarms start appearing in the list
- the setup flow now stays focused on destination selection and radius choice, while device-level readiness lives in Settings
- saved location alarms now expose dashboard-level repair actions for the common recoverable health states
- app resume now refreshes saved location-alarm health instead of relying only on stale persisted state
- alarms armed while already inside the destination radius now persist a `waiting for exit` health state so passive fallback does not trigger them until the phone leaves the radius first
- the search field no longer seeds generic labels like `Pinned location`, and the old stacked search button has been replaced with a compact inline icon action to recover vertical space
- the design direction is now settled on a hybrid model where the configured radius stays as the real trigger radius and a larger outer approach zone can enable passive fused-location assistance without default foreground-service tracking
- native location records now persist an approach state so outer-zone tracking survives store round-trips
- inner and outer geofences now arm together, and outer-zone entry/exit drives passive fused-location listener registration and cleanup
- passive location updates can now trigger arrival when they show the device crossing into the inner radius before the inner geofence callback arrives

Still pending inside this slice:

- retry/deferred re-registration strategy after boot / Play services unavailability
- fuller repair actions around location health states in editor/detail surfaces
- current real-device validation of geofence registration and trigger behavior

Validation:

- `adb` / `dumpsys` inspection of registered state where available
- duplicate-trigger suppression checks
- already-inside-geofence checks
- `flutter analyze`
- `flutter test`
- `flutter build apk --release`

## Slice 4: End-To-End Alarm Arming

Status: In progress

Target:

- save location alarms from Flutter
- arm geofences from native
- trigger a normal NeoAlarm ringing session on transition

Deliverables:

- editor/dashboard integration for location alarms
- per-alarm health display
- duplicate-trigger gate
- one-shot disarm behavior after successful trigger

Delivered so far:

- dashboard add flow now offers `Time alarm` vs `Location alarm`
- location alarms can be created from the setup flow and saved into the real alarm list
- location alarms can be edited by reopening the destination setup flow
- dashboard cards now show location radius and health state for location alarms
- the alarm editor now gives location alarms a dedicated destination/radius summary instead of reusing the time alarm header
- time-only controls are hidden for location alarms, and editor retry-arming is available for alarm-specific unarmed cases

Current limitation:

- the first exposed location-alarm flow saves with the existing default tone and mission settings
- a full location-specific editor for tone and mission customization is still deferred until the trigger path is validated
- existing saved alarms still rely on edit-and-resave to re-arm after the user fixes missing location access, though the setup flow no longer tries to own that repair path

Validation:

- real-device trigger tests
- restart/recovery tests
- screen-off behavior on Samsung

## Slice 5: Reliability Hardening

Status: Pending

Target:

- passive fallback checks
- reboot/locked-boot behavior review
- OEM and poor-signal guidance

Deliverables:

- passive foreground/unlock fallback check
- outer-zone passive fused-location listener with cleanup after trigger or exit
- repair states for battery restriction, location disabled, and permission revocation
- user-facing reliability copy

Validation:

- walking tests
- traffic/transit tests
- underground behavior expectations
- reboot tests

## Current Implementation Notes

- Slice 1 is complete and green
- Slice 2 is complete and green
- Slice 3 has real native scaffolding but is not feature-complete yet
- setup-time validation still catches already-inside-radius cases, but device-level readiness is now intentionally surfaced outside setup
- location alarms are now exposed for real-device validation, but they are still intentionally MVP-scoped while the native retry/re-registration work finishes
