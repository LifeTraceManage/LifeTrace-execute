# LifeTrace Execute Flutter Preview

High-fidelity, runnable mobile UI prototype for LifeTrace Execute.

This folder is **design/prototype code**, not the production data layer. The production Android client remains under `app/` and keeps its Local-first / Room / Sync architecture.

## Online preview

https://lifetracemanage.github.io/LifeTrace-execute/

The preview is automatically validated from the `feature/flutter-high-fidelity-preview` branch and then deployed to GitHub Pages by a workflow hosted on the default branch. This keeps the `github-pages` environment compatible with GitHub Pages deployment protection while still publishing the preview branch.

## Run locally

```bash
cd flutter-preview
flutter create . --platforms=android,web --project-name lifetrace_execute_preview
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
