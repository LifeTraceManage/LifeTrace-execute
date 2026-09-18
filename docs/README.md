# LifeTrace Execute 文档中心

本目录是 LifeTrace Execute 的统一文档入口。后续开发、Agent 执行、代码评审和版本验收都应先从这里进入，不依赖聊天记录作为工程事实。

## 当前架构状态

从 2026-09-10 起，LifeTrace Execute 正式客户端开始从 Jetpack Compose 迁移到 Flutter。

当前目录职责：

```text
docs/
├── README.md
└── development/
    ├── README.md
    ├── REQUIREMENTS.md
    ├── FOUNDATION_EXECUTION_PLAN.md
    ├── FLUTTER_REFACTOR_PLAN.md
    ├── PROJECT_STATUS.md
    ├── IMPLEMENTATION_LOG.md
    ├── EXECUTION_PLAN.md
    └── UI_SPEC.md
```

## 文档优先级

1. 产品范围：`REQUIREMENTS.md`；
2. 当前业务 Phase / Release Gate：`FOUNDATION_EXECUTION_PLAN.md`；
3. Flutter 客户端技术栈迁移与 Cutover：`FLUTTER_REFACTOR_PLAN.md`；
4. 当前代码事实：`PROJECT_STATUS.md` + 代码/CI；
5. 长期架构：`EXECUTION_PLAN.md`；
6. 视觉和交互：`UI_SPEC.md`。

旧文档中仍出现 `Compose / Room / WorkManager` 等技术栈描述时，客户端实现方式以 `FLUTTER_REFACTOR_PLAN.md` 为覆盖规则；产品能力与 Gate 不因此改变。

## 开发前阅读顺序

```text
AGENTS.md
docs/README.md
docs/development/README.md
docs/development/REQUIREMENTS.md
docs/development/FOUNDATION_EXECUTION_PLAN.md
docs/development/FLUTTER_REFACTOR_PLAN.md
docs/development/PROJECT_STATUS.md
docs/development/IMPLEMENTATION_LOG.md
```

涉及 UI 再读 `UI_SPEC.md`；涉及 Cloud/长期架构再读 `EXECUTION_PLAN.md`。

## 当前生产客户端目录

```text
flutter_app/      # 新生产 Flutter 客户端目标
app/              # 旧 Compose 客户端，迁移期行为参考
flutter-preview/  # 高保真设计历史参考
web-preview/      # 旧浏览器原型
```

新的客户端业务实现优先进入 `flutter_app/`。旧 Compose 仅保留阻断修复或迁移支持，不继续承接新的产品 UI。

## 完成定义

一个功能只有形成真实纵向链才算完成：

```text
Requirement
→ Domain
→ Drift/SQLite + migration
→ Repository
→ Flutter state
→ Flutter UI
→ Offline
→ Outbox / Sync
→ Tests
→ CI / Smoke / E2E
```

静态 Flutter 页面、Mock 数据、空操作不计入正式完成度。

## 当前功能 Phase

产品 Phase 顺序仍保持：

```text
F0   Task 冲突闭环 + 测试基线
F1   Generic Sync Core + Execution Contracts
F2   Project
F3   Advanced Task
F4   Calendar + ImportantDate + Reminder
F5   Collection + Tags + Files + Voice
F6   Daily/Weekly Review
F7   Goal/Habit
F8   Pomodoro/FocusSession
F9   Today aggregation
F10  Profile/Devices/Settings/Data
F11  Full Sync/Offline/E2E/Release
```

Flutter 迁移阶段 M0-M5 描述“用什么客户端技术完成这些 Phase”，不替代上面的产品 Phase。

## 每批提交后

必须同步：代码、自动化测试、`PROJECT_STATUS.md`、`IMPLEMENTATION_LOG.md`；需求变化才改 `REQUIREMENTS.md`，Phase/Gate 变化才改 `FOUNDATION_EXECUTION_PLAN.md`，Flutter 技术路线变化才改 `FLUTTER_REFACTOR_PLAN.md`。
