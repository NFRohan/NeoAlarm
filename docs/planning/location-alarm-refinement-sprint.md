# Location Alarm Refinement Sprint

## Goal

Refine location alarms from a technically working MVP into a clearer, more trustworthy feature without changing the core native execution boundary.

This sprint is about three things:

- making health and repair states visible and actionable
- hardening trigger confidence around geofence registration and recovery
- improving setup, editing, and search quality without rewriting the map stack

## Product Direction

Location alarms remain:

- one-shot alarms
- geofence-driven, not continuous background GPS tracking
- explicit-distance alarms, not semantic-radius alarms

The product should communicate "near destination alert" honestly rather than implying exact stop detection.

## Settled Decisions

### Radius UX

Do not use opaque semantic labels like `Near`, `City`, or `Transit` as the primary selection model.

Use explicit distances:

- `500 m`
- `1000 m`
- `1500 m`

Support them with helper copy such as:

- `500 m is better for walking or slow traffic.`
- `1000-1500 m is safer for buses and trains because location alerts can be delayed.`

### Health Model

Keep a health model, but separate truly global blockers from per-alarm state.

Global health conditions:

- missing foreground location access
- missing background location access
- location services disabled
- Play services unavailable
- battery restriction / optimization risk

Per-alarm health conditions:

- geofence not registered for this alarm
- already inside this alarm's radius at arm time
- last armed / last transition state
- future alarm-specific confidence or warning states

### Repair Model

Repair actions should not live in setup.

Users should be able to recover a broken location alarm from:

- Settings
- the saved alarm card
- the editor / detail surface

### Search Provider Direction

Keep map rendering unchanged for this sprint:

- `flutter_map`
- OpenStreetMap tiles

Improve search quality separately:

- preserve `LocationSearchRepository` as the abstraction boundary
- add BYOK search-provider support
- implement Mapbox geocoding as the first upgraded provider
- keep Nominatim as the zero-config fallback

This gives the biggest practical UX win with much less churn than a full Google Maps or Mapbox map migration.

## Sprint Goals

### 1. Health And Repair UX

Location alarms should clearly explain whether they are usable right now.

Deliverables:

- per-alarm health display on dashboard cards
- global blocker states reused cleanly across all location alarms
- alarm-specific health surfaced where it matters
- repair actions from dashboard and editor
- periodic health reevaluation on app resume / permission return

Recommended user-facing states:

- `Ready`
- `Needs location access`
- `Needs background access`
- `Location off`
- `Geofence not armed`
- `Play services unavailable`
- `Battery restriction may block triggers`
- `Approximate location may be unreliable`

### 2. Trigger Confidence Improvements

The trigger path needs more defensive behavior than "register once and trust it forever."

Deliverables:

- retry / deferred geofence registration after boot or transient failure
- stronger reboot re-arm behavior
- explicit already-inside-radius handling
- passive foreground/unlock fallback review and tightening
- hybrid arrival assist using an outer approach zone plus passive fused-location updates
- duplicate-trigger suppression visibility and validation
- clearer per-alarm registration metadata such as last armed / last transition time

Delivered so far:

- location alarms armed while the phone is already inside the destination radius now enter a persisted `waiting for exit` state instead of being treated as immediately triggerable
- passive foreground fallback no longer treats mere presence inside the radius as a fresh entry while that state is active
- native location records now persist an approach state for outer-zone tracking
- outer approach geofences and a global passive fused-location listener are now wired as a hybrid arrival assist
- passive listener cleanup now happens when alarms trigger, disable, delete, or leave the outer approach zone

Settled direction:

- keep the configured radius as the true trigger radius
- keep the inner geofence as the primary arrival trigger
- add an outer approach zone at roughly `3x` the configured radius
- while inside the outer zone, use passive fused-location updates as a low-cost assist
- do not add always-on active polling or a default foreground-service tracking mode in this sprint

### 3. Cleaner Editing Flow

Saved location alarms should feel first-class, not like a side path back into setup.

Deliverables:

- `Change destination`
- `Change radius`
- `Open repair actions`
- better saved-alarm editing flow without replaying the entire setup process for small changes

Delivered so far:

- location alarms now use a location-specific editor header instead of the time picker hero
- time-only controls such as repeat and timezone are hidden for location alarms
- saved location alarms can reopen the destination setup flow directly from the editor
- alarm-specific geofence retry is now available from the editor when the alarm is unarmed
- device-readiness fixes remain in Settings rather than being duplicated inside the editor

### 4. Setup And Map UX Polish

The setup flow works, but it still needs clearer guidance.

Deliverables:

- explicit distance-based helper copy
- underground / no-signal warning
- clearer already-inside-radius messaging
- recover vertical space in the setup surface
- better map affordances for selection adjustment
- small map convenience helpers where useful

Recommended warning copy direction:

- `Location alarms require GPS or network location and may be late or fail underground.`

### 5. Better Search Quality Through BYOK

Search quality is the weakest part of the MVP for Bangladesh and similar regions.

Deliverables:

- configurable BYOK provider path for location search
- Mapbox geocoding implementation behind the repository abstraction
- graceful fallback to Nominatim when no key is configured
- no map-renderer migration in this sprint

## Non-Goals

Do not include these in this sprint:

- full Google Maps SDK migration
- full Mapbox map migration
- route awareness or transit-stop intelligence
- repeating location alarms
- semantic radius labels as the primary UX
- analytics/history for location alarms
- large visual redesign of the map surface

## Execution Order

### Phase 1: Health And Repair

Status: In progress

Delivered so far:

- shared location-health repair labels in the domain model
- dashboard repair actions for saved location alarms
- saved location alarms can now request permission repair, open location settings, retry geofence arming, and route battery-restriction recovery from the dashboard
- app-resume reevaluation now refreshes saved location-alarm health instead of leaving stale status on cards
- device-level location readiness now lives in Settings instead of the destination setup flow

- refine health model split
- add dashboard/editor repair actions
- add periodic reevaluation on resume / permission return

### Phase 2: Trigger Confidence

- implement deferred/retry re-registration
- tighten boot/re-arm flow
- improve already-inside and duplicate-trigger handling
- add the hybrid geofence plus passive-listener approach-state machine

### Phase 3: Editing Improvements

- expose destination/radius updates cleanly
- add repair entry points

### Phase 4: Setup Copy And Map Polish

- add a current-location recenter control so users can jump the map to their live position without panning across the world
- keep the search field focused on real queries instead of generic seeded labels like `Pinned location`
- replace the large stacked search action with a compact inline search icon button
- replace remaining ambiguous copy
- add underground/no-signal warning
- polish selection helpers

### Phase 5: BYOK Search Upgrade

- keep current map renderer
- add Mapbox geocoding provider
- preserve Nominatim fallback

## Acceptance Criteria

We can call this sprint successful when:

- a saved location alarm clearly indicates whether it is ready or unhealthy
- users can repair unhealthy location alarms from the dashboard or editor
- a reboot or transient Play services failure does not silently leave armed alarms permanently unregistered
- saved location alarms are easy to edit without restarting the entire setup flow
- setup guidance uses explicit distances and honest warning copy
- Mapbox-backed search works when configured, while Nominatim still works as fallback

## Validation Checklist

### Functional

- create, save, edit, and delete location alarms
- grant permissions incrementally
- revoke permissions and verify repair paths
- disable and re-enable location services
- confirm geofence re-registration after reboot or reschedule path
- validate already-inside-radius handling

### Trigger Reliability

- walking test
- bus/train-style larger-radius test
- screen-off test
- reboot test
- duplicate-trigger suppression test
- outer-zone passive-assist entry and cleanup test

### Search Provider

- Nominatim fallback still works with no BYOK configuration
- Mapbox search works with configured key
- Bangladesh search quality is materially better on Mapbox than on Nominatim for real queries

## Release Theme

Recommended release theme after this sprint:

- `Location alarms that feel trustworthy`
