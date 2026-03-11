# Documentation Index

This project treats documentation as part of the engineering surface, not as a cleanup step after implementation.

## Start Here

- Read [documentation-strategy.md](documentation-strategy.md) for the documentation contract.
- Read [planning/overall-plan.md](planning/overall-plan.md) for the full implementation roadmap.
- Read [planning/sprint-plan.md](planning/sprint-plan.md) for the execution sequence.
- Read [testing/test-strategy.md](testing/test-strategy.md) for the quality and CI model.
- Read [testing/performance-workflow.md](testing/performance-workflow.md) for Macrobenchmark, Perfetto, and dependency-audit usage.
- Browse [../screenshots](../screenshots) for current app screenshots used in the repository front page and visual documentation.
- Read [architecture/engineering-story.md](architecture/engineering-story.md) to understand why the system is shaped this way.
- Read [architecture/overview.md](architecture/overview.md) for the high-level technical model.
- Read [architecture/active-session-lifecycle.md](architecture/active-session-lifecycle.md) for the authoritative active alarm state machine.
- Read [contributing/engineering-standards.md](contributing/engineering-standards.md) before making architecture or behavior changes.

## By Audience

### I want to understand the system quickly

- [planning/overall-plan.md](planning/overall-plan.md)
- [architecture/engineering-story.md](architecture/engineering-story.md)
- [architecture/overview.md](architecture/overview.md)
- [architecture/active-session-lifecycle.md](architecture/active-session-lifecycle.md)
- [testing/performance-workflow.md](testing/performance-workflow.md)

### I want to see the delivery roadmap

- [planning/overall-plan.md](planning/overall-plan.md)
- [planning/sprint-plan.md](planning/sprint-plan.md)
- [architecture/active-session-lifecycle.md](architecture/active-session-lifecycle.md)

### I want to understand testing and release confidence

- [testing/test-strategy.md](testing/test-strategy.md)
- [testing/performance-workflow.md](testing/performance-workflow.md)
- [planning/sprint-plan.md](planning/sprint-plan.md)
- [adr/0006-security-hardening-and-release-pipeline.md](adr/0006-security-hardening-and-release-pipeline.md)
- [adr/0009-event-driven-active-session-and-vision-lifecycle.md](adr/0009-event-driven-active-session-and-vision-lifecycle.md)
- [adr/0011-overlapping-alarm-session-stack.md](adr/0011-overlapping-alarm-session-stack.md)

### I want to implement or review alarm delivery behavior

- [architecture/overview.md](architecture/overview.md)
- [adr/0001-flutter-ui-native-android-core.md](adr/0001-flutter-ui-native-android-core.md)
- [architecture/active-session-lifecycle.md](architecture/active-session-lifecycle.md)
- [adr/0004-mission-confirmation-and-inactivity-retrigger.md](adr/0004-mission-confirmation-and-inactivity-retrigger.md)
- [adr/0005-detector-driven-steps-and-mission-activity-policy.md](adr/0005-detector-driven-steps-and-mission-activity-policy.md)
- [adr/0006-security-hardening-and-release-pipeline.md](adr/0006-security-hardening-and-release-pipeline.md)
- [adr/0007-direct-boot-alarm-persistence.md](adr/0007-direct-boot-alarm-persistence.md)
- [adr/0008-direct-boot-safe-flutter-startup.md](adr/0008-direct-boot-safe-flutter-startup.md)
- [adr/0009-event-driven-active-session-and-vision-lifecycle.md](adr/0009-event-driven-active-session-and-vision-lifecycle.md)
- [adr/0011-overlapping-alarm-session-stack.md](adr/0011-overlapping-alarm-session-stack.md)

### I want to work on QR or future vision missions

- [adr/0002-native-vision-mission-pipeline.md](adr/0002-native-vision-mission-pipeline.md)
- [architecture/overview.md](architecture/overview.md)
- [adr/0009-event-driven-active-session-and-vision-lifecycle.md](adr/0009-event-driven-active-session-and-vision-lifecycle.md)

### I want to work on sensor missions or mission anti-cheat

- [architecture/active-session-lifecycle.md](architecture/active-session-lifecycle.md)
- [contributing/mission-authoring.md](contributing/mission-authoring.md)
- [adr/0005-detector-driven-steps-and-mission-activity-policy.md](adr/0005-detector-driven-steps-and-mission-activity-policy.md)
- [adr/0009-event-driven-active-session-and-vision-lifecycle.md](adr/0009-event-driven-active-session-and-vision-lifecycle.md)

### I want to add a new architectural decision

- [adr/README.md](adr/README.md)
- [adr/TEMPLATE.md](adr/TEMPLATE.md)

### I want to contribute safely

- [contributing/engineering-standards.md](contributing/engineering-standards.md)
- [contributing/mission-authoring.md](contributing/mission-authoring.md)
- [adr/0006-security-hardening-and-release-pipeline.md](adr/0006-security-hardening-and-release-pipeline.md)
- [adr/0008-direct-boot-safe-flutter-startup.md](adr/0008-direct-boot-safe-flutter-startup.md)

## Documentation Layers

- `README.md`: top-level project orientation.
- `LICENSE`: GPLv3 project license.
- `docs/documentation-strategy.md`: what documentation must exist and when it must be updated.
- `docs/planning/*.md`: roadmap and sprint-level execution planning.
- `docs/testing/*.md`: quality strategy, CI expectations, and device-testing approach.
- `docs/testing/performance-workflow.md`: performance benchmarking, Perfetto capture, and dependency-audit workflow.
- `screenshots/`: current app screenshots for the README and future visual documentation.
- `docs/architecture/*.md`: stable system-level understanding and engineering narrative.
- `docs/adr/*.md`: irreversible or high-impact decisions with context and tradeoffs.
- `docs/contributing/*.md`: contributor workflow and engineering expectations.

If you change system behavior and cannot identify which document should be updated, update this index first so the gap becomes explicit.
