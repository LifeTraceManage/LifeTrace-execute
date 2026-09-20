# LifeTrace Execute

LifeTrace Execute 是 LifeTrace 的独立执行中心，负责今天、任务、项目、日历、收集、专注与复盘等日常执行场景。

## 当前客户端方向

从 2026-09-18 起，`main` 是唯一正式生产分支，正式客户端为 **Flutter**：

- `flutter_app/`：正式生产客户端；
- `flutter-preview/`：此前高保真 Flutter 设计原型，仅保留作设计历史参考；
- `web-preview/`：旧浏览器设计原型；
- LifeTrace Cloud：继续复用统一 Rust + Axum + PostgreSQL 后端，不建设第二套 Execute 云端。

这次是**客户端实现技术栈重构，不是产品重做**。底层 Cloud 契约、Local-first 规则、Sync v1 语义和产品范围继续保留。

Flutter 重构计划：[`docs/development/FLUTTER_REFACTOR_PLAN.md`](docs/development/FLUTTER_REFACTOR_PLAN.md)

## 固定信息架构

底部一级导航保持：

1. 今天
2. 任务
3. 项目
4. 日历
5. 收集

“我的”通过头像进入；“今日复盘”从 Today 进入；专注/番茄与任务工作流关联；重要日期属于日历域。

## Flutter 正式客户端

```text
flutter_app/
├── lib/
│   ├── main.dart
│   ├── screens_a.dart
│   ├── screens_b.dart
│   ├── screens_c.dart
│   └── web_preview_main.dart
├── test/
├── pubspec.yaml
└── README.md
```

当前第一批迁移已经把确认过的高保真 UI 提升为 `flutter_app/` 的正式 UI 基线。Android 生产入口使用真实系统安全区；模拟状态栏和手机外壳只用于 Web 评审预览。

> Flutter 已完成 Local-first、Drift、Repository、Outbox、Cloud Sync v1，以及 Project、Calendar、Collection、Review、Goal/Habit、Today、Focus、Profile 等多条真实业务链。当前剩余重点是 Task Advanced（waiting / dependency / recurrence / occurrence / completion）、全实体多设备 E2E 与 Release hardening。

## 生产架构目标

继续采用 **Local-first + LifeTrace Cloud Sync**：

```text
Flutter UI
    ↓
Riverpod state / use case
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
LifeTrace Sync v1
    ├── capabilities
    ├── snapshot
    ├── push
    └── pull
    ↓
LifeTrace Cloud / PostgreSQL
```

关键兼容要求：

- Android `applicationId` 保持 `com.lifetrace.execute`；
- Android Cloud AppId 保持 `lifetrace-execute-android`；
- 继续使用 Auth v1、Sync v1；
- 本地写入仍要求业务实体和 Outbox 同一 SQLite transaction；
- 保留 changeId 幂等、baseServerVersion 冲突、cursor、tombstone、rebase、retry 分类等既有语义。

## 迁移顺序

Flutter 不是一次性把旧代码删除重写，而是以纵向业务链迁移：

```text
M0  Flutter 正式壳与 UI 基线
M1  Flutter Foundation / Drift / Auth / Sync primitives
M2  Task 完整纵向链迁移
M3  Cloud Auth + Sync 运行时对齐
M4  Project / Advanced Task / Calendar / Collection / Review / Focus / Today / Profile
M5  Flutter 客户端 Cutover（已完成）+ Release hardening
```

旧 Compose `app/`、根级 Android Gradle 工程和 legacy Compose CI 已于 2026-09-20 从 `main` 删除；正式开发、CI 与发布均以 `main/flutter_app` 为准。

## 文档入口

后续开发统一从 [`docs/README.md`](docs/README.md) 进入。核心文档：

- `REQUIREMENTS.md`：产品范围 Source of Truth；
- `FOUNDATION_EXECUTION_PLAN.md`：功能 Phase 与 Gate；
- `FLUTTER_REFACTOR_PLAN.md`：客户端技术栈迁移与 Cutover 标准；
- `PROJECT_STATUS.md`：当前真实进度；
- `IMPLEMENTATION_LOG.md`：提交和 CI 证据；
- `UI_SPEC.md`：UI/交互基线。

## Flutter 验证

新的生产 Flutter CI：

```text
.github/workflows/flutter-production-ci.yml
```

基础 Gate：

```text
flutter analyze
flutter test
flutter build apk --debug
flutter build web --release
```

涉及数据库、离线、同步、后台任务、通知、计时和多设备时，仍需执行相应 migration / smoke / E2E Gate。

项目 1.0 的完成定义仍然是：**所有已确认功能形成真实纵向闭环，生产路径不依赖 MockData，核心数据可本地持久化与离线使用，需要同步的实体可跨设备同步，并有真实自动化测试、CI 和发布证据。**
