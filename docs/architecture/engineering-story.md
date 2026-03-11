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

## Why Alarm Persistence Lives In Device-Protected Storage

There is an important difference between:

- data that is private to the app after unlock
- data that must still be available before first unlock after reboot

An alarm app needs the second category for alarm-critical state.

Android clears scheduled alarms on reboot. If the app wants to restore them on `BOOT_COMPLETED` and `LOCKED_BOOT_COMPLETED`, it has to read persisted alarm definitions at that moment. Credential-protected storage is too late for that.

That is why alarm definitions and active ring-session state live in device-protected storage instead of normal app-private credential storage.

This is not a casual storage choice. It is a reliability decision:

- reboot recovery should not wait for first unlock
- exact alarm rebuilding should work in direct boot mode
- active alarm state should remain consistent with how the scheduler is restored

This does increase the importance of local security controls. Once alarm-critical persistence becomes direct-boot readable, backup policy and exported-component discipline matter even more. That is one reason the project also disables Android auto-backup in MVP and treats the security model as part of the architecture.

## Why Flutter Startup Must Stay Minimal In Direct Boot

Direct boot introduces a trap that is easy to miss in Flutter projects.

The Flutter engine can start and render UI before first unlock, but not every plugin or startup-time package is safe in that environment. A dependency that assumes credential-protected preferences, normal file access, or a fully unlocked user session can crash the Flutter side even while the native alarm engine is behaving correctly.

That is why the project treats Flutter startup as a constrained surface:

- `main.dart` should remain minimal
- no nonessential plugin initialization should happen eagerly at startup
- unlocked state must be confirmed explicitly through the native layer
- before first unlock, the app should show only alarm-critical UI or a minimal holding screen

This is a hard boundary, not a style preference.

If contributors casually add startup dependencies without thinking about direct boot, they can break exactly the scenario the native alarm engine was designed to survive.

## Why Local-First Still Needs A Tight Attack Surface

Local-first is not the same thing as low-risk.

An alarm app still exposes security-sensitive behavior:

- it can wake the screen
- it can take over the lock-screen experience
- it can schedule work to run later without user interaction
- it stores mission state and alarm definitions locally

That means the project has to care about local attack surface, not just network attack surface.

The right standard is:

- another app should not be able to trigger alarm-only UI states casually
- internal reschedule and ringing paths should not be open to arbitrary external callers
- local persistence should not quietly escape into backup flows if the product promises on-device privacy
- release distribution should use proper signing hygiene rather than debug-era defaults

For this project, security is therefore mostly about component boundaries, permission use, persistence policy, and exported-surface discipline.

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

## Optimization Audit Snapshot: March 11, 2026

By the end of Sprint 7, the product behavior was strong enough that the next engineering question was no longer "does it work?" but "does it work efficiently under stress?"

That matters for an alarm app because the runtime is not idle while the user is sleeping or racing to dismiss an alarm. The system is doing real-time work at the worst possible moment:

- sensor-driven mission progress
- silent-mission inactivity enforcement
- camera analysis
- active session recovery and repainting while the screen is on

An optimization audit on March 11, 2026 identified five issues worth recording before the implementation changed.

### 1. Steps Progress Was Polling The Entire Active Session Too Frequently

The first version of the steps mission refreshed the full active alarm session from Flutter four times per second.

That was acceptable as a bootstrap because it kept the UI simple and let the native steps mission prove itself quickly. It was not a good long-term shape:

- every poll crossed the method channel
- every poll re-read persisted native session data
- every poll rebuilt more Flutter state than the step counter actually needed

This was the clearest signal that the active-session model needed a push path, not just a query path.

### 2. Quiet-Timer Refreshes Were Using Service Churn For A Small State Update

Mission activity updates were routed back through the ringing service even when the only real work was:

- extend the mission timeout deadline
- persist the updated session
- reschedule the timeout alarm

That meant "user is still solving the mission" could wake service lifecycle machinery that was really designed for audio ownership and ringing transitions.

This was the wrong boundary. Extending a deadline is engine state management, not a foreground-service concern.

### 3. The Active Alarm Screen Was Repainting Too Much For The Quiet Timer

The visible quiet timer was useful, but the initial implementation refreshed the whole active alarm screen several times per second.

That is a poor trade:

- the timer itself is tiny
- the screen around it is visually heavy
- mission widgets do not need to rebuild just because a countdown ticked

The timer needed to become a local repaint surface rather than a reason to rebuild the whole ringing UI.

### 4. Vision Session Startup Was Too Eager To Rebind Camera Resources

The QR mission runner and native vision manager were both biased toward "start again just to be safe."

That is understandable during early camera work, but it creates extra churn:

- repeated preview/session startup on resume and widget update
- repeated provider rebinds even when the active config did not actually change
- unnecessary latency during permission recovery and scanner resume

The intended architecture was already session-based. The implementation needed to become idempotent enough to match that model.

### 5. Vision Resources Needed An Explicit Lifecycle End

The first vision implementation stopped scanning, but it did not yet make strong guarantees about releasing every long-lived native resource when the activity or engine was torn down.

For a real alarm app, that is not a minor cleanup item. Camera analyzers, executors, and scanner clients are exactly the sort of resources that look harmless until enough retries, resumes, or activity recreation events accumulate.

The audit therefore treated explicit disposal as part of correctness, not just memory hygiene.

### What This Audit Means

The main lesson was that reliability and performance were converging on the same engineering rule:

- the native alarm engine should own state transitions cheaply
- Flutter should repaint only the parts that actually changed
- mission progress should move by events when the system already knows something changed
- camera resources should behave like owned session resources, not convenient globals

The optimization pass that follows this audit is therefore not about micro-benchmarks. It is about bringing the implementation into line with the architecture the project already claims to have.

### Optimization Response

The implementation pass that followed this audit made five structural changes.

First, active-session propagation became event-driven instead of relying on high-frequency Flutter polling. Native session persistence now emits active-session updates to Flutter, which means the UI can react to real state changes rather than repeatedly asking for the whole session just to move a steps counter.

Second, mission-activity timeout refreshes were pulled out of the ringing service and into a dedicated native coordinator. Extending the silent-mission deadline is now treated as a small state-and-scheduling update instead of a reason to spin up foreground-service lifecycle work.

Third, the visible quiet timer stayed in the product, but its repaint scope became local. The timer still updates smoothly, but it no longer forces the entire active-alarm surface to rebuild several times per second.

Fourth, the QR mission startup path became idempotent. Re-entering the same camera mission configuration now reuses the existing session when possible instead of rebinding preview and analysis just because Flutter resumed or rebuilt a mission widget.

Fifth, the vision pipeline gained an explicit disposal path. Camera analysis resources, scanner state, and executor ownership now end with the activity lifecycle instead of relying on process cleanup as a hidden resource-management strategy.

These changes matter because they improve three things at once:

- battery and CPU behavior while an alarm is active
- UI smoothness during live missions
- contributor clarity about where state changes are supposed to happen

That combination is the real goal of the optimization work. The project should feel faster because the architecture became tighter, not because the code accumulated isolated performance tricks.

## Security Audit Snapshot: March 11, 2026

A source audit of the Android and Flutter codebase on March 11, 2026 found four issues worth recording before wider distribution.

### 1. Full-Screen Alarm UI Must Not Trust A Forgeable Activity Action

The launcher activity is exported because it has to be launchable by the system and the user.

That is fine.

What is not fine is letting an external caller supply an action string that is treated as sufficient proof that the activity should behave like an active alarm surface.

The current implementation allows the window to enter alarm-style lock-screen/full-screen mode when the activity sees the internal alarm action, even if that action was supplied from outside the app.

That is the wrong trust boundary.

The correct boundary is the persisted active ring session. A full-screen alarm experience should become active because the native alarm engine says there is an active alarm, not because an incoming intent claims there is one.

### 2. Local-Only Storage Must Not Leak Into Backup By Accident

The product promise is local-first and on-device.

Right now, alarm definitions and active mission/session data are stored in app-private preferences, which is acceptable for MVP persistence. But if backup is left enabled by default, that data may still flow into Android backup and device-transfer paths.

That is not a cryptographic break, but it is a real policy mismatch:

- alarm schedules are personal behavior data
- QR mission targets are part of dismissal configuration
- active session state is operational alarm data the user may reasonably assume stays only on the handset

If the project says "everything stays on-device," backup behavior has to be an intentional decision rather than a platform default.

### 3. Exported Reschedule Paths Must Be Narrow And Defensive

The boot/time/timezone reschedule receiver exists for legitimate system broadcasts.

That is also fine.

The risk comes from treating an exported receiver as a harmless utility surface. An exported receiver that immediately performs alarm rescheduling is part of the app's privileged behavior. If another app can explicitly target it, the receiver should still behave defensively:

- validate that the action is one of the allowed system reschedule triggers
- avoid turning scheduling failures into crash loops
- treat repeated external invocation as hostile noise, not as a normal caller pattern

This matters because alarm reliability work often creates exactly the sort of components that need strict exported-surface discipline.

### 4. Public Releases Need Real Signing Hygiene

The current release build configuration still uses the debug signing config.

That is acceptable for local development and device testing. It is not acceptable for public release engineering.

If contributors or users install public builds, release artifacts need:

- a dedicated release keystore
- controlled signing in CI or release infrastructure
- a clean distinction between local debug convenience and real distributed artifacts

This is less about an in-app exploit and more about treating distribution as part of the security model.

### What This Audit Means For The Project

The main lesson is that an alarm app should be treated as a system-behavior app, not just a utility UI.

Even without a backend and even without internet permission, the app still controls high-impact device behavior. That means the engineering bar has to include:

- exported component review
- storage and backup policy review
- release signing discipline
- regular security audits alongside reliability audits

These findings are recorded here because they affect architecture, not just cleanup. They are part of the engineering story of the project and should stay visible until they are resolved.

The initial mitigation pass adopted four concrete policies:

- lock-screen/full-screen alarm presentation is now authorized by persisted active-session state rather than a forgeable activity action
- Android auto-backup is disabled for MVP so local alarm and mission state does not quietly escape into backup flows
- the exported reschedule receiver now accepts only the expected system actions and treats failures defensively
- release signing moved to a local `key.properties` strategy with CI-secret support and a deliberate debug fallback for non-distribution builds

Those changes matter because they reinforce a broader rule: convenience boundaries are not security boundaries. Internal action strings, platform defaults, and development signing shortcuts are acceptable only when they do not weaken the trust model of the product.

## Why The Release Pipeline Is Part Of The Security Model

It is tempting to treat CI and release automation as separate from application security.

For this project, that would be a mistake.

The release pipeline decides:

- whether static analysis runs continuously
- whether dependency-risk changes are reviewed automatically
- whether release artifacts are reproducible
- whether signing material is handled explicitly or implicitly

That is why the repository now treats CI as part of the engineering boundary:

- build/test automation catches regressions
- CodeQL covers source-level SAST
- dependency review covers dependency-surface changes
- tagged release workflows define how installable APKs are produced and published

This is not bureaucracy. It is how an open-source app avoids shipping a different engineering standard than the one its source code claims to follow.

## Why The Documentation Must Be Strong

This repository will attract contributors who are capable of extending it beyond the original author. That only works if the engineering story is visible.

Strong documentation should answer:

- what is guaranteed
- what is merely preferred
- what constraints forced a design
- where to put new work
- which decisions are already settled

If the answer to those questions lives only in source code, the project will slow down as soon as the first non-trivial feature lands.
