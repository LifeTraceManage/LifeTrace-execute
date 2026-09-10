# LifeTrace Execute 项目进度

更新时间：2026-09-10

## 1. 当前阶段

LifeTrace Execute 已进入 **生产客户端 Flutter 重构阶段**。

当前载体：

- `flutter_app/`：新的正式生产客户端目标；
- `app/`：旧 Jetpack Compose Android 客户端，迁移期间保留为已经实现的 Local-first / Auth / Sync 行为参考；
- `flutter-preview/`：已确认高保真 Flutter UI 的设计历史来源；
- `web-preview/`：旧浏览器原型；
- LifeTrace Cloud：继续复用统一 Rust + Axum + PostgreSQL 后端。

本次重构不改变产品范围，也不重做 Cloud 协议。

## 2. Flutter 重构当前事实

已完成：

```text
refactor/flutter-production
├── flutter_app/                 # 新生产客户端目录
│   ├── lib/main.dart            # 生产 Flutter 入口
│   ├── lib/screens_a.dart
│   ├── lib/screens_b.dart
│   ├── lib/screens_c.dart
│   ├── lib/web_preview_main.dart
│   ├── pubspec.yaml
│   └── test/widget_test.dart
├── docs/development/FLUTTER_REFACTOR_PLAN.md
└── .github/workflows/flutter-production-ci.yml
```

当前 Flutter UI 已覆盖：Today、Tasks、Task Detail、Focus、Projects、Project Detail、Calendar、Collection、Daily Review、Profile。

生产 Android 入口不再绘制假的手机状态栏；模拟状态栏和设备框仅用于 Web Preview。

Flutter Production CI 已验证：

```text
run 34490908679
flutter analyze             PASS
flutter test                PASS
flutter build apk --debug   PASS
flutter build web           PASS
```

因此 **M0 的工程/构建基线已经建立并验证通过**。

## 3. 仍未迁移到 Flutter 的正式业务链

当前 `flutter_app/` 第一批是 **UI + 工程壳迁移**，以下真实生产能力仍主要存在于旧 Compose `app/`，尚未完成 Flutter 纵向闭环：

- Task Drift/SQLite 正式持久化；
- Task Repository / state；
- transactional Outbox；
- Cloud Auth v1；
- secure session；
- stable deviceId；
- Sync v1 snapshot / push / pull；
- conflict / tombstone / rebase；
- background sync；
- Project / Calendar / Collection / Review 等正式数据链。

因此不能把 Flutter 版本写成“功能已完成”。当前准确状态是：**Flutter UI 已迁移，Flutter 工程 Gate 已验证，生产数据层迁移开始。**

## 4. 旧 Compose 已有的可迁移能力

`app/` 已经具备并必须保持行为兼容的能力包括：

- `com.lifetrace.execute` applicationId；
- `lifetrace-execute-android` Cloud AppId；
- Auth v1 login / refresh / logout；
- Android Keystore + AES-GCM 会话保护；
- installation-level deviceId；
- Room：`tasks` / `sync_outbox` / `sync_state` / `sync_conflicts`；
- Task CRUD / status / priority / description / scheduledAt / dueAt；
- Task 搜索 / 筛选；
- Task + Outbox 同事务；
- Snapshot / Push / Pull；
- accepted / duplicate / conflict / rejected；
- tombstone；
- 同实体连续修改 rebase；
- WorkManager 自动同步基础设施。

Flutter 必须逐项迁移这些真实行为，不能用静态数据替代后直接下线 Compose。

## 5. Flutter 目标架构

```text
Flutter UI
    ↓
Riverpod state / UseCase
    ↓
Repository
    ↓
Drift / SQLite
    ├── business tables
    ├── sync_outbox
    ├── sync_state
    └── sync_conflicts
    ↓
Generic Sync Core
    ↓
LifeTrace Auth v1 / Sync v1
    ↓
LifeTrace Cloud
```

Android package/applicationId 最终必须保持：

```text
com.lifetrace.execute
```

## 6. 信息架构保护

继续固定：

- 底部：今天 / 任务 / 项目 / 日历 / 收集；
- 我的：头像进入；
- 今日复盘：Today 进入；
- 专注/番茄：与任务执行工作流关联；
- 重要日期：Calendar 域。

客户端技术栈更换不能成为删除既有功能的理由。

## 7. 当前迁移顺序

按照 `FLUTTER_REFACTOR_PLAN.md`：

```text
M0  Flutter 正式壳 + UI 基线                         已验证
M1  Flutter Foundation / Drift / Secure Storage / Cloud / Sync primitives
M2  Task 完整纵向链 parity
M3  Auth / Background Sync / real Cloud E2E parity
M4  F2-F10 剩余业务模块迁移
M5  Release Gate + Compose 下线
```

与原 1.0 功能顺序的关系：Flutter 完成 Foundation 后，仍继续执行原 F0→F11 的业务 Gate，不因为换技术栈重置产品计划。

## 8. 当前判定

当前项目不是“Flutter 已重构完成”，而是：

> **已正式切换 Flutter 为生产客户端目标，M0 工程与高保真 UI 基线已通过 Android/Web CI；旧 Compose 真实业务链作为迁移参考保留。下一步优先迁移 Task 的 Local-first + Sync 纵向链。**
