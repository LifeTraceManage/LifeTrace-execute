# Flutter Production Refactor Plan

更新时间：2026-09-10

## 1. Architecture decision

LifeTrace Execute production client is migrating from Jetpack Compose to Flutter.

Target:

```text
flutter_app/                 # production client target
  lib/
  test/
  android/                   # generated/committed after foundation bootstrap
  web/                       # preview/review target

app/                         # legacy Compose client, frozen during migration
flutter-preview/             # design/history reference; no longer production target
```

The product scope, LifeTrace Cloud contracts and Local-first semantics do not change. This is a client implementation refactor, not a product reset.

## 2. Non-negotiable compatibility

- Android package/applicationId stays `com.lifetrace.execute`.
- Cloud AppId stays `lifetrace-execute-android` for the Android client unless the Cloud contract is explicitly versioned later.
- Existing LifeTrace Auth v1 and Sync v1 are reused.
- Local-first writes remain `business entity + outbox` in one SQLite transaction.
- `changeId`, `baseServerVersion`, cursor, tombstone, conflict, rejected/retryable semantics remain compatible.
- No second backend and no second sync protocol.
- Existing user data must be migrated or remain readable across the client cutover.

## 3. Technology mapping

| Legacy Android | Flutter target |
| --- | --- |
| Jetpack Compose | Flutter Material 3 + custom design system |
| ViewModel / StateFlow | Riverpod Notifier/AsyncNotifier |
| Room | Drift + SQLite |
| Android Keystore wrapper | `flutter_secure_storage` backed by platform secure storage |
| WorkManager | `workmanager` plugin on Android, lifecycle-triggered sync as foreground supplement |
| custom HTTP transport | Dio-based Cloud client with controlled refresh/replay |
| Android Notification | `flutter_local_notifications` |
| Navigation Compose | `go_router` |

Package choices are introduced only when the corresponding vertical slice is implemented and tested; dependencies are not added merely for architecture decoration.

## 4. Migration phases

### M0 — Flutter production shell

- create `flutter_app/`;
- promote the approved high-fidelity UI baseline;
- remove preview naming from the production entrypoint;
- add Flutter production CI;
- keep Compose client intact as behavioral reference.

Gate: analyze + widget tests + Android debug build + Web build.

### M1 — Flutter foundation

Create production structure:

```text
lib/
  app/
  core/
    auth/
    network/
    sync/
    storage/
    time/
  domain/
  data/
    local/
    remote/
    repository/
  features/
```

Introduce routing, dependency injection/state container, Drift database, schema migrations, secure session store, Cloud transport, sync primitives and background scheduling.

Gate: database migration tests + secure-session tests + Cloud contract tests + cold-start smoke.

### M2 — Task vertical slice parity

Port the already-real Compose Task chain first:

```text
ExecutionTask
→ Drift task table
→ task repository
→ task state/notifier
→ Tasks/TaskDetail Flutter UI
→ transactional outbox
→ snapshot/push/pull
→ conflict resolution
```

Must retain CRUD, status, priority, description, scheduledAt/dueAt, search/filter, tombstone, rebase and conflict handling.

Gate: offline CRUD + process restart + push/pull + conflict + deletion tests.

### M3 — Auth and sync operational parity

Port login/refresh/logout, stable deviceId, secure tokens, capability checks, startup sync, local-write sync scheduling, periodic fallback and retry classification.

Gate: real Cloud login + second-device pull + network-loss/recovery smoke.

### M4 — Remaining product phases

Continue the existing F2–F10 order in Flutter:

Project → Advanced Task → Calendar/ImportantDate/Reminder → Collection → Review → Goal/Habit → FocusSession → Today aggregation → Profile/Devices/Settings/Data.

Each module still needs the complete vertical slice before being marked complete.

### M5 — Cutover

Only after Flutter reaches functional parity and Release Gate passes:

- make Flutter the only production client;
- archive/remove legacy Compose build files;
- update all docs and CI;
- run migration/reinstall/upgrade tests using `com.lifetrace.execute`;
- publish signed Android release.

## 5. UI migration rule

The 360×800 high-fidelity design is the visual baseline. Production Android uses real system insets and system status/navigation areas. The simulated phone status bar/device frame is Web-preview-only and must never be rendered as fake system chrome in the Android production build.

## 6. Status discipline

During migration there are three distinct states:

- `Flutter UI 已迁移`: visual/interaction shell exists;
- `Flutter 业务迁移中`: real local/domain/sync path partially ported;
- `Flutter 已验证`: vertical slice and its CI/E2E gate are complete.

Do not call a module complete simply because the Flutter screen exists.
