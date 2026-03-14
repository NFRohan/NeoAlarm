# Architecture Decision Records

This directory stores Architecture Decision Records (ADRs).

ADRs are required when a change settles or revises a high-impact technical decision that future contributors would otherwise have to reconstruct from commit history.

## When To Write An ADR

Write an ADR when changing:

- subsystem ownership boundaries
- persistence model or schema strategy
- mission plugin contracts
- scheduling semantics
- permission and policy strategy
- camera or analyzer architecture
- build, packaging, or distribution strategy

## ADR Format

Use [TEMPLATE.md](TEMPLATE.md) and keep each ADR focused on one decision.

Recommended sections:

- Status
- Context
- Decision
- Consequences
- Alternatives considered

## Workflow

1. Create the next numbered ADR.
2. Keep the title concrete.
3. Link related ADRs when a decision depends on earlier ones.
4. Update architecture docs if the decision changes system understanding.

## Initial ADRs

- [0001-flutter-ui-native-android-core.md](0001-flutter-ui-native-android-core.md)
- [0002-native-vision-mission-pipeline.md](0002-native-vision-mission-pipeline.md)
- [0003-exact-alarm-permission-strategy.md](0003-exact-alarm-permission-strategy.md)
- [0004-mission-confirmation-and-inactivity-retrigger.md](0004-mission-confirmation-and-inactivity-retrigger.md)
- [0005-detector-driven-steps-and-mission-activity-policy.md](0005-detector-driven-steps-and-mission-activity-policy.md)
- [0006-security-hardening-and-release-pipeline.md](0006-security-hardening-and-release-pipeline.md)
- [0007-direct-boot-alarm-persistence.md](0007-direct-boot-alarm-persistence.md)
- [0008-direct-boot-safe-flutter-startup.md](0008-direct-boot-safe-flutter-startup.md)
- [0009-event-driven-active-session-and-vision-lifecycle.md](0009-event-driven-active-session-and-vision-lifecycle.md)
- [0010-performance-tooling-and-qr-dependency-tradeoff.md](0010-performance-tooling-and-qr-dependency-tradeoff.md)
- [0011-overlapping-alarm-session-stack.md](0011-overlapping-alarm-session-stack.md)
- [0012-mediaplayer-ramp-and-direct-boot-fallback.md](0012-mediaplayer-ramp-and-direct-boot-fallback.md)
- [0013-extra-loud-speaker-only-mode.md](0013-extra-loud-speaker-only-mode.md)
