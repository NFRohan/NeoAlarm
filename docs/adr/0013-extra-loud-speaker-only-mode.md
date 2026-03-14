# 0013. Extra Loud Speaker-Only Mode

## Status

Accepted

## Context

NeoAlarm now uses `MediaPlayer` for alarm playback, which makes it possible to add audio-session effects that were not practical on the earlier `Ringtone` path.

An `Extra loud mode` feature is useful for users who want a slightly stronger alarm without forcing a global device-volume change for every alarm. However, this is not a safe feature to enable blindly on every route. Headphones, Bluetooth devices, and other private outputs should not receive unexpected loudness enhancement.

## Decision

The project adopts these rules for the first version of `Extra loud mode`:

1. The feature is a per-alarm toggle.
2. It defaults to `off`.
3. When enabled, the ringing service attaches `LoudnessEnhancer` to the alarm playback audio session.
4. The first shipped gain is conservative: `+200 mB`.
5. The enhancer is applied only when the current output route is considered speaker-safe.
6. If wired headphones, Bluetooth audio, USB audio, or other private routes are active, the enhancer is not applied.
7. If enhancer setup fails for any reason, playback falls back to normal alarm audio rather than failing the alarm.

## Consequences

Positive:

- the feature is easy to understand and opt into per alarm
- the shipped gain stays conservative while still giving a meaningful boost
- private listening routes are protected from accidental loudness enhancement
- the alarm engine remains reliable even when the effect cannot be attached

Tradeoffs:

- output-route detection is heuristic and OEM audio stacks may still vary
- the first version intentionally does not try to maximize loudness
- this adds one more playback branch that must be validated on real devices

## Notes

This ADR does not promise OEM-identical behavior. It sets a conservative policy that should be safe enough to validate on real devices before considering stronger gain values or broader route handling.
