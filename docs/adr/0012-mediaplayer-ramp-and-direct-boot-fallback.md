# 0012. MediaPlayer Ramp And Direct-Boot Fallback

## Status

Accepted

## Context

NeoAlarm needed two usability improvements without weakening alarm reliability:

1. a `Skip next` feature for repeating alarms
2. a gradual volume ramp option for alarms that should start softer

The existing playback path used `Ringtone`, which is simple but poorly suited to per-instance volume control. It also behaved inconsistently on some devices after reboot-before-unlock, where the user's default alarm tone could not be trusted to resolve reliably in direct-boot mode.

## Decision

The project adopts these rules:

1. Repeating alarms represent `Skip next` as a concrete skipped local occurrence date in the alarm's own timezone, not as a boolean flag.
2. Alarm playback moves from `Ringtone` to `MediaPlayer`.
3. Gradual ramp is a per-alarm toggle that defaults to `off`.
4. When ramp is enabled, volume is raised on the player instance rather than by mutating the global stream as the normal behavior.
5. If the current system alarm volume is too low to be audible, the ringing service may apply a temporary minimum alarm-stream floor for the active session and must restore the prior value when the session ends.
6. Before first unlock after reboot, the alarm engine prefers a bundled direct-boot-safe fallback tone from Android raw resources rather than dynamically depending on the user's default alarm tone.

## Consequences

Positive:

- `Skip next` remains deterministic across reboot, reschedule, and timezone changes
- volume ramp becomes opt-in and per-alarm instead of a global behavioral surprise
- playback behavior is more controllable and better aligned with future custom-tone support
- direct-boot alarm playback becomes more predictable across OEMs

Tradeoffs:

- the ringing service now owns more playback lifecycle code than before
- a bundled fallback tone becomes part of the shipped app package
- playback and scheduler policy become more tightly documented because user expectations are easy to break here

## Notes

This ADR does not introduce arbitrary custom tone support yet. It only establishes the playback architecture that will make that future work possible without breaking direct-boot reliability.
