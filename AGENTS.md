# LifeTrace Execute Development Instructions

These instructions apply to the entire repository.

## Required reading before implementation

Before changing production code, read in this order:

1. `docs/README.md`
2. `docs/development/README.md`
3. `docs/development/REQUIREMENTS.md`
4. `docs/development/FOUNDATION_EXECUTION_PLAN.md`
5. `docs/development/FLUTTER_REFACTOR_PLAN.md`
6. `docs/development/PROJECT_STATUS.md`
7. `docs/development/IMPLEMENTATION_LOG.md`

For UI changes also read `docs/development/UI_SPEC.md`.
For long-term architecture decisions also read `docs/development/EXECUTION_PLAN.md`.

## Current client architecture decision

LifeTrace Execute is migrating its production client from Jetpack Compose to Flutter.

- `flutter_app/` is the new production client target.
- `app/` is the legacy Compose client and remains temporarily as the behavioral/data/sync reference during migration.
- `flutter-preview/` is a design/history reference and must not be confused with the production Flutter client.
- New product UI and new client-side feature implementation should target `flutter_app/`.
- The legacy Compose client should receive only blocking fixes or migration-support changes until Flutter cutover.

`docs/development/FLUTTER_REFACTOR_PLAN.md` is the architecture override for client-technology references in older documents. Product scope and Phase order still come from `REQUIREMENTS.md` and `FOUNDATION_EXECUTION_PLAN.md`.

## Current priority

Follow the current Foundation Phase defined in `docs/development/FOUNDATION_EXECUTION_PLAN.md`, but implement the remaining client work in Flutter according to `FLUTTER_REFACTOR_PLAN.md`.

Do not skip ahead to add new UI shells while the current Phase Gate is incomplete.

## Definition of implemented

A business module is not implemented merely because a Flutter screen exists.

The expected Flutter vertical slice is:

```text
Requirement / Product Rule
→ Domain Model / Business Rule
→ Drift / SQLite table + DAO + migration
→ Repository / UseCase
→ Riverpod state / UI state
→ Flutter UI / real interaction
→ Offline behavior
→ Transactional Outbox / Sync when applicable
→ Automated tests
→ CI / smoke / E2E evidence
```

If important parts of this chain are missing, document the module as `Flutter UI 已迁移`, `开发中`, or another accurate partial state instead of `已完成`.

## Production-code constraints

- Do not introduce MockData as a production runtime data source.
- Do not leave core user actions as empty callbacks.
- Do not use widget-local state as persistent business storage.
- Local-first business writes must persist locally before network sync.
- Synced entities must use the shared Outbox / Sync Core architecture instead of copying a separate sync engine for each entity.
- SQLite schema changes require explicit migrations and migration tests.
- New business behavior requires meaningful automated tests.
- Do not mark a feature complete solely because `flutter test` exits successfully; confirm real tests exist and execute.
- Preserve existing Cloud Auth v1 / Sync v1 behavior and wire compatibility during the migration.
- Preserve Android application id `com.lifetrace.execute` and the existing Execute Cloud app identity unless a documented migration changes them.

## Migration rule

Do not replace a real Compose production behavior with a Flutter mock and call the migration complete. Port existing working behavior module by module, verify parity, then retire the legacy implementation only after the corresponding Flutter Gate passes.

## Documentation updates after implementation

After a verified development batch:

1. update `docs/development/PROJECT_STATUS.md` with the real current state;
2. update `docs/development/IMPLEMENTATION_LOG.md` with implementation facts, commit SHA and test/CI evidence;
3. update `docs/development/REQUIREMENTS.md` only if product requirements changed;
4. update `docs/development/FOUNDATION_EXECUTION_PLAN.md` only if phase order, dependencies or Gate criteria changed;
5. update `docs/development/FLUTTER_REFACTOR_PLAN.md` when migration architecture or cutover criteria change.

Never pre-mark planned work as complete.

## Validation

For Flutter production batches, at minimum run:

```text
flutter analyze
flutter test
flutter build apk --debug
```

For Web preview changes also run a Flutter Web build.

For sync, offline, database migration, notification, timer or multi-device behavior, also perform the specific smoke/E2E Gate defined by the Foundation and Flutter refactor plans.

The legacy Android Compose CI may remain during migration as regression evidence, but it is no longer the target for new product implementation.

## Source of truth

When documentation disagrees with verified code/CI behavior, verified implementation is the factual source. Correct stale documentation immediately rather than reverting correct code to match stale text.
