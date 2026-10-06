# Assets Workspace Migration

The standalone `LifeTrace-assets` client is being absorbed into the unified LifeTrace mobile application.

Source of truth after merge: `LifeTraceManage/LifeTrace-execute/flutter_app/lib/workspaces/assets`.

Preserved capabilities: asset inventory, lifecycle events, current-value and cost analytics, warranty/maintenance reminders, local-first persistence, LifeTrace Cloud synchronization, entity links, and update checking. No asset business data model is intentionally removed by this migration.

Do not implement new Assets features in the standalone repository after this migration is merged. Changes should target the Assets workspace in the unified mobile client.
