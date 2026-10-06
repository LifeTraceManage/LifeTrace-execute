# LifeTrace Mobile Workspace Architecture

Status: implemented on `refactor/unified-mobile-shell`.

## Decision

LifeTrace mobile is one installable application and one account surface. Business domains are workspaces rather than top-level features forced into Execute.

```text
LifeTrace Mobile
├── Shell
│   ├── workspace switcher
│   ├── account / settings (shared direction)
│   └── application lifecycle
├── Core
│   ├── cloud / identity
│   ├── background sync
│   ├── notifications
│   └── settings
└── Workspaces
    ├── Execute
    │   ├── Today / Tasks / Projects
    │   ├── Calendar / Collection
    │   └── Review / Focus / Goals / Habits
    └── Assets
        ├── asset inventory
        ├── lifecycle events
        ├── analytics / reminders
        └── local-first repository + cloud sync
```

## Implemented migration

The former `LifeTrace-assets` application code is migrated under `flutter_app/lib/workspaces/assets`. Its domain model, repository, local database, cloud session/sync implementation, analytics, reminders, UI and update service are preserved. The release checker now targets the unified `LifeTrace-execute` release stream.

The existing Execute data/domain/features layout is deliberately not mass-moved in this migration. Moving hundreds of imports provides little product value and creates avoidable regression risk. The existing `Shell` is therefore the Execute workspace boundary while `LifeTraceShell` owns workspace selection. Future refactors can move Execute files physically behind `workspaces/execute` incrementally.

## Workspace rules

A workspace owns its domain-specific navigation, screens and domain logic. Shared authentication, application settings, update delivery, sync primitives and design tokens should move toward shared/core layers. A workspace must not add new items to another workspace's bottom navigation.

New domains such as Health should be introduced as a new workspace. Health device permissions and Android-native bridges belong to the Health workspace/platform adapter, not Execute.

## Compatibility

The Dart package name remains `lifetrace_execute` during this migration so existing imports, generated code and tests do not break. The user-visible application title is `LifeTrace`.

## Exit criteria for retiring LifeTrace-assets

1. Unified client passes existing Execute tests plus migrated Assets regression tests.
2. Assets workspace can initialize its local repository and retain cloud synchronization behavior.
3. Unified release/update path is verified.
4. The standalone Assets repository receives a migration/archival notice and no longer accepts feature development.
