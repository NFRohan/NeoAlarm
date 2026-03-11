# Engineering Story

## The Problem We Are Solving

Most alarm apps are easy to copy at the UI level and hard to trust at the systems level. A serious alarm app is not a clock widget with extra screens. It is a reliability product that happens to have a UI.

That distinction drives the entire architecture.

## Why Flutter Is Not The Alarm Engine

Flutter is a strong choice for product velocity, interface quality, and cross-platform ergonomics. It is not the right place to anchor alarm-critical behavior on Android.

An alarm app has to survive:

- overnight Doze
- reclaimed app processes
- boot and time changes
- lock-screen launch constraints
- sensor and camera mission handoff while the ring service is already active

For those reasons, the app uses Flutter as the shell and native Android as the execution core.

## Why This Is A Dart And Kotlin Split, Not A Plugin Grab Bag

The project is not split between Dart and Kotlin because "some things were easier native."

It is split because the product has two fundamentally different responsibilities:

- product surface and interaction design
- reliability-critical Android execution

Dart owns the parts that benefit from fast UI iteration and a clean declarative shell:

- dashboard and settings flows
- alarm editing
- diagnostics presentation
- mission UI and interaction rendering

Kotlin owns the parts that must remain correct even if Flutter is not present at the moment the system wakes:

- exact alarm scheduling
- ring-session persistence
- audio and vibration ownership
- lock-screen/full-screen launch
- inactivity timers and re-trigger behavior
- dismissal authorization

That split is important because it keeps the bridge narrow and intentional. The goal is not "Flutter app plus some native helpers." The goal is a UI shell talking to a native alarm engine that has clear authority.

When that authority line is blurry, alarm apps accumulate hidden failure modes:

- UI state starts acting like source of truth
- mission progress becomes route-dependent
- background enforcement depends on a live isolate
- contributors add features by expanding the bridge instead of strengthening the model

The Dart/Kotlin split is therefore a systems boundary, not a convenience choice.

## Why The Project Is Local-First

The project exists partly as a rejection of ad-driven alarm apps. The cleanest way to keep that promise is to make the product work entirely on-device:

- no account dependency
- no backend dependency
- no telemetry dependency
- no internet dependency in MVP

This also improves reliability. An alarm should not degrade because a remote service changed or became unavailable.

## Why The Active Alarm Needs A Real State Machine

An active alarm is not just "currently ringing" or "not ringing."

As soon as missions, snooze caps, recovery, and inactivity enforcement exist, the system needs to distinguish meaningfully different states:

- `ringing`
- `mission_active`
- `snoozed`

Those states are not UI decoration. They change what the system is allowed to do:

- whether audio should be playing
- whether dismissal is legal
- whether a timeout should re-trigger the alarm
- whether the lock-screen experience should stay active
- how recovery should behave after process death

Without a persisted state machine, contributors end up encoding these rules indirectly through flags, route assumptions, or service-local conditions. That works only until the first serious recovery bug.

The state machine exists to make alarm behavior explicit and recoverable.

## Why Unsupported Missions Are Hidden Instead Of Merely Disabled

There is a difference between:

- a feature that exists but is temporarily unavailable
- a feature that cannot run on this device right now

For the second case, leaving the mission visible in the editor is the wrong signal. It tells the user "this is part of the configuration surface" even though saving that configuration would create a broken alarm.

That is why the `Steps` mission disappears from the editor when:

- the device does not expose a usable live step detector
- `ACTIVITY_RECOGNITION` has not been granted

The repair path still exists, but it belongs in diagnostics and settings rather than in the alarm editor itself. The editor should describe what can be configured now. Settings should explain how to make more missions available.

## Why The Mission System Must Be Modular

Dismissal missions are the main reason contributors will want to extend the project. If missions are embedded directly into the ring service or UI routing, every new challenge becomes an architecture risk.

The project therefore needs a mission contract with strict boundaries:

- the alarm engine decides when a mission is required
- a mission driver decides how completion is evaluated
- the UI renders progress and input for the active mission

This separation should make it possible to add new missions without re-auditing the scheduler on every feature.

## Why Mission Solving Does Not Silence The Alarm Immediately

The first naive version of a mission alarm is easy to imagine:

- the alarm fires
- the mission screen appears
- the sound keeps blasting until the mission is done

That approach is simple, but it is poor product design for any mission that takes real time. If a user is genuinely engaging with the challenge, continuous full-volume ringing becomes noise rather than enforcement.

The opposite extreme is also flawed:

- the mission screen opens
- the alarm immediately goes silent

That weakens the alarm because opening a screen is not evidence of real engagement. A user can tap into the mission and then do nothing.

The confirmation step exists to solve that tension.

It creates a deliberate transition:

- first, the alarm is firing and demanding attention
- then, the user explicitly accepts mission work
- only then is the alarm allowed to become silent

That is why the confirmation screen is not just a UX flourish. It is the product-level boundary between coercion and effort.

Once the user crosses that boundary, silence is conditional rather than permanent. Native inactivity enforcement makes the quiet period earned and revocable.

## Why Mission Silence Is Enforced Natively

If a mission becomes silent, the system still needs a way to punish stalling.

That cannot depend on:

- a Flutter timer
- a particular widget being mounted
- route-local state
- a best-effort callback after process reclaim

The inactivity timeout is native because it is part of the enforcement model, not just the interface. A mission may be quiet only while the native layer still has evidence that the user is engaged.

That design is stricter, but it keeps the product honest: the silence during mission solving is a controlled state, not a loophole.

## Why Mission Activity Must Be Mission-Specific

One of the easiest ways to accidentally weaken the alarm is to define "activity" too loosely.

If any pointer event can refresh the silent-mission timer, then the timer stops measuring engagement and starts measuring screen contact. That creates obvious cheats:

- random tapping can keep a math mission quiet
- permission-repair flows can accidentally buy silence
- empty touches on a steps screen can replace actual walking

The project therefore treats activity as mission-specific evidence:

- math uses answer-field interaction and answer submission
- steps uses accepted native step-detector events
- generic touches do not count unless the mission explicitly defines them as meaningful

This matters because the timer is not decorative. It is part of dismissal enforcement.

## Why The Math Mission Is More Than A Toy Feature

Math is the first mission not because it is the most exciting one, but because it proves the platform shape with low hardware complexity.

It is the right first mission to validate:

- mission-specific configuration
- native runtime progress
- multi-step completion instead of one-shot dismissal
- UI-to-native answer submission
- recovery of in-progress mission state
- silence plus inactivity re-trigger during active solving

If the math mission cannot be made coherent, the more complex `Steps` and `QR` missions would be built on a weak base.

## Why The Steps Mission Uses `TYPE_STEP_DETECTOR`

Android exposes two step-related hardware sensors with very different behavior:

- `TYPE_STEP_COUNTER` gives a cumulative total since reboot and may batch updates
- `TYPE_STEP_DETECTOR` emits an event when the device believes a step happened

For background wellness tracking, the counter can be acceptable. For a live alarm mission, it is the wrong tool. The user is staring at the screen and expects the mission to react immediately.

The steps mission therefore uses `TYPE_STEP_DETECTOR` because:

- the UI needs prompt progress feedback
- the silence timer needs real-time walking evidence
- a cumulative reboot-total counter introduces unnecessary bookkeeping and weaker UX

This still does not produce perfect anti-cheat. Device vendors can classify some motion badly. That is why the implementation also filters impossible cadence bursts instead of pretending the hardware signal is perfect.

## Why Permission Recovery Does Not Buy Quiet Time

The settings and mission surfaces must help the user recover from revoked permissions, especially for `ACTIVITY_RECOGNITION`.

But a repair action is not evidence that the mission is being solved.

If a permission button refreshed the quiet timer, a user could keep the alarm silent indefinitely by poking the repair path without ever restoring the mission prerequisite or making progress.

That is why permission recovery is supported but does not itself count as mission activity.

## Why The Quiet Timer Is Visible

Once mission solving becomes silent, the user needs to understand that the silence is conditional.

Without a visible timer:

- users can be surprised by a re-trigger while they are mid-problem or mid-walk
- it is harder to tell whether the app is still recognizing real activity
- contributors are forced to reason about invisible enforcement state

The quiet timer exists for clarity, not decoration.

Just as importantly, it is derived from the persisted native timeout deadline. Flutter does not guess at a 30-second window locally. The UI reads the same authoritative deadline the alarm engine will use for re-triggering.

## Why QR Is More Than A QR Feature

The first vision mission is QR scanning, but the real engineering decision is to establish the camera boundary correctly now.

If QR is implemented as a disposable plugin tied to one screen, future object-recognition work will require rewriting the camera stack. Instead, the project should build a reusable native vision pipeline:

- CameraX handles preview and frame analysis
- a `VisionAnalyzer` consumes frames
- mission logic reacts to analyzer results

That keeps v1 practical while making future TinyML or TFLite work a matter of swapping analyzers, not redesigning ownership.

## Why The Documentation Must Be Strong

This repository will attract contributors who are capable of extending it beyond the original author. That only works if the engineering story is visible.

Strong documentation should answer:

- what is guaranteed
- what is merely preferred
- what constraints forced a design
- where to put new work
- which decisions are already settled

If the answer to those questions lives only in source code, the project will slow down as soon as the first non-trivial feature lands.
