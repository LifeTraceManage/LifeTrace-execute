# LifeTrace Execute Flutter Preview

High-fidelity, runnable mobile UI prototype for LifeTrace Execute.

This folder is **design/prototype code**, not the production data layer. The production Android client remains under `app/` and keeps its Local-first / Room / Sync architecture.

## Run

```bash
cd flutter-preview
flutter pub get
flutter run
```

## Included flows

- Today
- Tasks
- Task detail
- Focus timer
- Projects
- Project detail
- Calendar
- Collection
- Daily review
- Profile

The Today screen uses static week labels as display-only information. Calendar cells are intentionally interactive because date selection is part of the Calendar product behavior.
