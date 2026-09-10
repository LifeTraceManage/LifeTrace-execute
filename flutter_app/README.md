# LifeTrace Execute Flutter App

`flutter_app/` is the new production client target for LifeTrace Execute.

The project is being migrated from the legacy Jetpack Compose client under `app/` to Flutter. The legacy Android implementation stays in the repository temporarily as the source for already-implemented Local-first, Auth and Sync behavior. It must not receive new product UI work during the migration except for blocking fixes.

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

## Migration rule

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

During migration, already-working Compose behavior is ported module by module. Do not replace real Compose data flows with Flutter mock data and then mark the module complete.

## Bootstrap locally

```bash
cd flutter_app
flutter create . --platforms=android,web --org com.lifetrace --project-name lifetrace_execute
flutter pub get
```

After Android platform bootstrap, keep the production Android `applicationId` and namespace as:

```text
com.lifetrace.execute
```

This preserves continuity with the current Android package.

## Current status

M0 is verified: Flutter analyze, widget tests, Android debug build and Web build pass in CI. The data, auth, local-first and sync layers are not yet ported; the Compose implementation remains the behavioral reference until each Flutter vertical slice is verified.
