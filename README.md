# alarms-oss

Android-first, local-first, open source alarm app built with Flutter and a native Android core.

## Documentation

- Project docs index: [docs/README.md](docs/README.md)
- Overall implementation plan: [docs/planning/overall-plan.md](docs/planning/overall-plan.md)
- Sprint plan: [docs/planning/sprint-plan.md](docs/planning/sprint-plan.md)
- Test strategy: [docs/testing/test-strategy.md](docs/testing/test-strategy.md)
- Architecture overview: [docs/architecture/overview.md](docs/architecture/overview.md)
- Engineering story: [docs/architecture/engineering-story.md](docs/architecture/engineering-story.md)
- Active session lifecycle: [docs/architecture/active-session-lifecycle.md](docs/architecture/active-session-lifecycle.md)
- Mission authoring guide: [docs/contributing/mission-authoring.md](docs/contributing/mission-authoring.md)

## Current Status

The project currently has:

- exact alarm scheduling and native alarm persistence
- a native foreground ringing service with full-screen recovery
- dashboard, editor, diagnostics, and settings flows
- math mission enforcement with configurable difficulty and problem count
- mission confirmation plus native inactivity re-trigger behavior
- steps mission enforcement with native `TYPE_STEP_DETECTOR` tracking
- activity-recognition gating in the editor plus settings-based repair/re-enable flow
- quiet-timer countdown UI sourced from the persisted native mission timeout
- exploit hardening so only mission-valid activity can keep a mission silent
