# LifeTrace Execute Flutter App

`flutter_app/` is the production client for LifeTrace Execute.

The Jetpack Compose implementation that previously lived under `app/` was retired from `main` on 2026-09-20 after Flutter became the production implementation. Historical Compose behavior remains available through Git history; new work belongs only in this Flutter client.

## Online preview

The repository GitHub Pages preview is now built from this production Flutter client rather than from the old `flutter-preview/` folder:

```text
https://lifetracemanage.github.io/LifeTrace-execute/
```

Desktop Web uses the 360×800 phone frame; Android production uses real system insets.

## Product UI baseline

The current Flutter screens are promoted from the high-fidelity preview and preserve the fixed primary navigation:

- 今天
- 任务
- 项目
- 日历
- 收集

“我的”仍从头像进入；“今日复盘”仍从 Today 进入。

## Production completeness rule

A screen existing in Flutter does not mean the business module is complete. Production completion still requires the vertical slice:

```text
Requirement
→ Domain
→ SQLite/Drift local persistence
→ Repository
→ Flutter state layer
→ Flutter UI
→ transactional Outbox
→ LifeTrace Sync v1
→ tests
→ CI / smoke / E2E
```

Do not replace real production data flows with Flutter mock data and then mark a module complete. Keep the verified Local-first, persistence, Sync, notification/file behavior and automated gates intact.

## Run locally

The production Android platform project is committed under `flutter_app/android/`. Do not recreate or run the retired root Kotlin/Compose project.

```bash
cd flutter_app
flutter pub get
dart run build_runner build
flutter run
```

The production Android `applicationId` and namespace are fixed to:

```text
com.lifetrace.execute
```

For a clean device check, uninstall any previously installed legacy APK first:

```bash
adb uninstall com.lifetrace.execute
```

Then run `flutter run` from `flutter_app/`. This guarantees the installed app is built from the current Flutter production entrypoint `lib/main.dart`.

## Current status

Flutter is the sole production client. The repository already contains real Drift/SQLite, Riverpod/Repository, Auth v1, Local-first Outbox, Sync v1, background sync, reminder/notification, file upload and multiple business vertical slices. Remaining 1.0 work is tracked in `../docs/development/PROJECT_STATUS.md`; legacy Compose source is no longer part of the active codebase.
