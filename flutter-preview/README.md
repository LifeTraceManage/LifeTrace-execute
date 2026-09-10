# LifeTrace Execute Flutter Preview

High-fidelity, runnable mobile UI prototype for LifeTrace Execute.

This folder is **design/prototype code**, not the production data layer. The production Android client remains under `app/` and keeps its Local-first / Room / Sync architecture.

## Online preview

https://lifetracemanage.github.io/LifeTrace-execute/

The preview is automatically validated from the `feature/flutter-high-fidelity-preview` branch and then deployed to GitHub Pages by a workflow hosted on the default branch. This keeps the `github-pages` environment compatible with GitHub Pages deployment protection while still publishing the preview branch.

Desktop browsers use `lib/preview_main.dart` and render the app inside a fixed **360 × 800** phone viewport. Narrow/mobile browsers keep the normal full-screen mobile layout.

## Run locally

```bash
cd flutter-preview
flutter create . --platforms=android,web --project-name lifetrace_execute_preview
flutter pub get
```

Desktop browser preview with the 360 × 800 device frame:

```bash
flutter run -d chrome -t lib/preview_main.dart
```

Normal Android/mobile app entry point:

```bash
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
