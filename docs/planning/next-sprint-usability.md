# Next Sprint: Everyday Usability

## Goal

Make NeoAlarm more practical for daily use without changing the core engine or expanding the mission platform.

This sprint is intentionally narrow. The app is now stable enough that the best next work is not more infrastructure. It is product polish that improves the wake-up experience and reduces friction in the most common flows.

## Sprint Scope

- skip next occurrence
- gradual volume ramp
- better empty state and first-alarm guidance after onboarding

## Why These Three

### Skip Next Occurrence

Repeating alarms are useful until the day the user needs just one exception. `Skip next` solves that without making the user disable the whole alarm or rebuild the schedule.

User value:

- handles holidays, appointments, and one-off schedule changes cleanly
- keeps repeating alarms useful instead of rigid

Engineering value:

- fits the existing recurrence and scheduling model
- does not require new mission or permission architecture

### Gradual Volume Ramp

The current alarm experience is reliable but abrupt. A configurable ramp makes wake-up less hostile while preserving alarm authority.

User value:

- softer wake-up experience
- better for users who do not want full-volume shock immediately

Engineering value:

- sits inside the existing native ringing service
- extends current alarm playback instead of introducing a new subsystem

### Better Empty State And First-Alarm Guidance

After onboarding, the user should land in a home state that feels ready, not unfinished.

User value:

- makes the first post-setup moment more understandable
- helps new users move from setup to their first real alarm confidently

Engineering value:

- low risk
- improves onboarding continuity without new platform complexity

## Scope Details

## 1. Skip Next Occurrence

### Product Behavior

- available only for repeating alarms
- skips only the next scheduled firing
- after the skipped occurrence passes, the alarm resumes its normal repeat rule automatically

### UX Surface

- action available from the alarm card or editor
- visible state that the next occurrence is skipped
- clear copy for when the alarm returns to normal repeating behavior

### Engineering Notes

- do not store a boolean skip flag
- store a one-off skipped occurrence key tied to the next scheduled local firing date
- represent the skip as a local occurrence date in the alarm's own timezone, for example `YYYY-MM-DD` or an equivalent epoch-day value
- next-trigger computation must ignore exactly one matching occurrence, not disable the alarm
- skipped state must survive app restarts and reboot rescheduling

### Done Criteria

- a repeating alarm can skip exactly one occurrence
- the following occurrence is still scheduled correctly
- reboot/timezone/time-change rescheduling preserves skip-next semantics
- one-time alarms do not expose the action

## 2. Gradual Volume Ramp

### Product Behavior

- alarm starts below full target volume when ramping is enabled
- volume rises over a configured interval until it reaches the target level
- default behavior remains immediate full-volume playback unless the user opts into ramping
- the user's global alarm volume should not be treated casually or left modified after the session ends

### UX Surface

- simple `Volume ramp up` toggle in the editor
- summary visible on the alarm card or editor

### Engineering Notes

- implement in the native ringing service
- do not rely on Flutter timers for the ramp
- ramp must behave correctly across service recovery and overlapping alarms
- target stream behavior must remain alarm-focused, not notification-focused
- move alarm playback from `Ringtone` to a controllable `MediaPlayer` instance so ramping is applied per playback instance rather than by mutating the global stream as the default behavior
- prefer `MediaPlayer` as the first migration target; it is simpler than `ExoPlayer` and sufficient for looping local alarm audio plus per-instance volume ramping
- add a per-alarm `volumeRampEnabled` flag that defaults to `false`
- keep the system `AudioManager` alarm stream where the user set it by default
- apply ramping through the player instance volume, not by immediately forcing the system stream upward
- handle the low-system-volume edge case explicitly: if the alarm stream is too low to be audible, the service may temporarily raise it to a minimum floor for the active alarm session, then restore the prior stream volume when the session ends
- keep a direct-boot-safe fallback tone for pre-unlock alarms after reboot; pre-unlock playback must not depend on custom or credential-protected tone sources
- treat bundled `res/raw` audio or another direct-boot-safe source as the fallback path before first unlock
- use the bundled alarm tone already added to `assets/school-bell.wav` as the source file for that Android raw-resource fallback

### Done Criteria

- ramp works on a real device during active ringing
- target volume is eventually reached
- ramp is opt-in per alarm and existing alarms continue to ring at full volume by default
- dismiss, snooze, mission start, and overlapping alarm transitions do not leave ramp state stuck
- behavior is documented for devices with different OEM audio quirks
- post-reboot locked-state alarms still ring reliably with the direct-boot-safe fallback path
- any temporary system-volume floor is restored correctly after the session ends

## 3. Better Empty State And First-Alarm Guidance

### Product Behavior

- after onboarding, the no-alarm state should feel intentional and ready
- the user should understand that setup is done and that they can now create their first alarm
- mission permissions should be described as contextual, not missing

### UX Surface

- stronger empty-state panel on the home screen
- onboarding-to-home continuity in copy and CTA wording
- optional hint that QR and Steps permissions are requested later only if those missions are chosen

### Engineering Notes

- this is a UX/copy sprint item, not a new state machine
- keep it light and avoid overbuilding tutorial logic

### Done Criteria

- the home screen no longer feels blank after onboarding
- first-time users are clearly guided to creating an alarm
- the messaging matches the current onboarding and settings permission policy

## Non-Goals

Not part of this sprint:

- one-time override for repeating alarms
- upcoming alarm summaries
- new mission types
- backup/export
- advanced travel/timezone behavior changes

## Test Plan

- verify skip-next across repeating alarms, reboot, and reschedule events
- verify gradual volume ramp on at least one Samsung device and one non-Samsung Android device
- verify empty-state UX after first-run onboarding completion and after manually clearing alarms
- verify no regression in existing alarm firing, snooze, mission start, and overlapping alarm behavior

## Release Shape

This sprint should produce a practical usability-focused release. It should feel like a quality-of-life upgrade, not a platform rewrite.
