# LifeTrace Execute 开发文档指南

本目录保存直接指导 LifeTrace Execute 开发的文档。

## 当前客户端技术路线

从 2026-09-10 起，正式客户端实现目标是 `flutter_app/`。旧 Jetpack Compose `app/` 在迁移阶段保留为已经实现的 Local-first / Auth / Sync 行为参考，但不再承接新的产品 UI 开发。

旧文档中的 `Compose / ViewModel / Room / WorkManager` 客户端技术描述，由 [`FLUTTER_REFACTOR_PLAN.md`](FLUTTER_REFACTOR_PLAN.md) 映射到 Flutter 实现；产品范围与业务 Gate 不变。

## 推荐阅读顺序

每次开始新的开发批次时：

1. [`REQUIREMENTS.md`](REQUIREMENTS.md) — 产品范围；
2. [`FOUNDATION_EXECUTION_PLAN.md`](FOUNDATION_EXECUTION_PLAN.md) — 当前业务 Phase 与 Gate；
3. [`FLUTTER_REFACTOR_PLAN.md`](FLUTTER_REFACTOR_PLAN.md) — Flutter 架构、迁移顺序和 Cutover 标准；
4. [`PROJECT_STATUS.md`](PROJECT_STATUS.md) — 当前真实完成度；
5. [`IMPLEMENTATION_LOG.md`](IMPLEMENTATION_LOG.md) — 最近提交和 CI 证据；
6. [`EXECUTION_PLAN.md`](EXECUTION_PLAN.md) — Cloud、长期架构和最终 Release；
7. [`UI_SPEC.md`](UI_SPEC.md) — Flutter UI/交互基线。

## 两套阶段不要混淆

业务交付仍按 F0→F11 推进；Flutter 重构按 M0→M5 推进。

```text
业务 Phase：决定“下一个必须完成哪个产品纵向链”
Flutter Migration：决定“这些纵向链如何从 Compose 迁到 Flutter”
```

换成 Flutter 不允许重置已经完成的真实能力，也不允许借重构跳过原有 Gate。

## Flutter 模块完成标准

任何业务模块只有同时满足下面的纵向链，才可以标记为已完成：

```text
Requirement / Product Rule
    ↓
Domain Model / Business Rule
    ↓
Drift / SQLite Entity + DAO + Migration
    ↓
Repository / UseCase
    ↓
Riverpod Notifier / UI State
    ↓
Flutter UI / Real Interaction
    ↓
Offline behavior
    ↓
Transactional Outbox / Sync / File / Notification（适用时）
    ↓
Automated Tests
    ↓
CI / Smoke / E2E evidence
```

状态建议：

| 状态 | 含义 |
| --- | --- |
| `未实现` | 没有正式业务代码 |
| `Flutter UI 已迁移` | 只有视觉与交互壳，真实数据链尚未迁移 |
| `开发中` | 已进入正式业务链但纵向闭环未完成 |
| `基础可用` | 本地 CRUD/持久化/核心交互完成 |
| `同步可用` | Local-first + Cloud Sync 主链打通 |
| `已验证` | 对应 CI/E2E/smoke Gate 有证据 |
| `已完成` | 满足当前版本 Definition of Done |

## 开发任务拆分

不要按“做一个 Flutter 页面”拆任务，优先按业务纵向链：

```text
Task Domain + SQLite
Task Repository + State
Task CRUD UI
Task + Outbox transaction
Task Sync Handler
Conflict / Tombstone / Rebase
Task tests
Offline / Cloud smoke
```

当前最优先的是把旧 Compose 已经真实可用的 Task 纵向链迁到 Flutter，再继续 F2-F10。

## Flutter 基础验证

每个 Flutter Batch 至少执行：

```text
flutter analyze
flutter test
flutter build apk --debug
```

Web Preview 相关变化再执行 Flutter Web build。数据库、后台同步、通知、计时、多设备能力还要执行各自专项 Gate。

## 禁止事项

- 不得用 Flutter Mock 页面替换旧 Compose 真实业务后宣称迁移完成；
- 不得把网络请求设为业务写入前置条件；
- 不得为每个实体复制独立 Sync Engine；
- SQLite schema 变化必须有 migration 与测试；
- 核心按钮不得为空操作；
- 不得把需要持久化的数据只存 Widget State；
- 不得因为改用 Flutter 删除已确认功能；
- 不得在 CI / E2E 没证据时提前标记完成。

## 文档维护

- `REQUIREMENTS.md`：产品需求；
- `FOUNDATION_EXECUTION_PLAN.md`：F0-F11 业务顺序/Gate；
- `FLUTTER_REFACTOR_PLAN.md`：M0-M5 客户端迁移；
- `PROJECT_STATUS.md`：实时状态；
- `IMPLEMENTATION_LOG.md`：提交与验证事实；
- `UI_SPEC.md`：UI/交互；
- `EXECUTION_PLAN.md`：长期架构与 Release。
