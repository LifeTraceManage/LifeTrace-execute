# LifeTrace Execute 工程实施记录

更新时间：2026-09-10

> 本文档只记录已经提交到代码仓的实现事实、验证证据和剩余阻塞。设计意图看 `REQUIREMENTS.md`，客户端迁移看 `FLUTTER_REFACTOR_PLAN.md`。

## 2026-09-10：生产客户端切换到 Flutter

### 架构决策

用户确认 LifeTrace Execute 正式客户端直接使用 Flutter 重构，不再继续以 Jetpack Compose 作为新功能目标。

已建立分支：

```text
refactor/flutter-production
```

旧 Compose `app/` 暂不删除，用于保证已实现的 Task / Auth / Local-first / Sync 行为有可核对的迁移来源。Flutter 对应 Gate 通过前，不允许用静态页面替代旧真实行为后直接宣称完成。

### Flutter production client

首个生产 Flutter 提交：

```text
c02ab09d727d0f4a34c1e023aa8c3ee8596cc64d
refactor: establish Flutter production client
```

已新增：

```text
flutter_app/
├── lib/main.dart
├── lib/screens_a.dart
├── lib/screens_b.dart
├── lib/screens_c.dart
├── lib/web_preview_main.dart
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
└── test/widget_test.dart
```

同时新增：

```text
docs/development/FLUTTER_REFACTOR_PLAN.md
.github/workflows/flutter-production-ci.yml
```

Flutter UI 直接继承已经确认的高保真基线，覆盖 Today / Tasks / Task Detail / Focus / Projects / Project Detail / Calendar / Collection / Daily Review / Profile。

生产入口与 Web Preview 已分离：Android 生产入口使用真实系统安全区；Web Preview 才模拟 360×800 手机框和状态栏。

### 文档切换

后续提交已将：

- `AGENTS.md`：改为 Flutter 生产纵向链与验证规则；
- `README.md`：改为 Flutter 为正式客户端目标；
- `PROJECT_STATUS.md`：记录 Flutter UI 已迁移、真实数据层尚待迁移。

### 当前验证

Flutter Production CI 已启动，Gate 包括：

```text
flutter analyze
flutter test
flutter build apk --debug
flutter build web --release --target lib/web_preview_main.dart
```

在 CI 最终成功前，本批次只标记为“工程已建立 / CI 验证中”，不提前写“生产 Flutter 已完成”。

### 下一批

优先执行 Flutter M1/M2：

1. 建立 Riverpod / routing / Drift / secure storage / Cloud transport / sync primitives；
2. 先迁移 Task，因为 Task 是旧 Compose 唯一接近完整生产纵向链的模块；
3. 保持 `com.lifetrace.execute` applicationId 和 `lifetrace-execute-android` Cloud AppId；
4. 迁移 Task + Outbox 同事务、Snapshot/Push/Pull、conflict、tombstone、rebase；
5. 完成真实离线与 Cloud E2E 后再逐步下线 Compose 对应实现。

---

## 2026-08-27 ～ 2026-08-28：Local-first / Cloud 第一阶段

### LifeTrace 主仓库

仓库：`zhouxingxing1279/LifeTrace`

已提交：

- `9180525c20d7233cdce7118a4c6d3425d3276fb5`
  - 新增 `AppId::EXECUTE_ANDROID = lifetrace-execute-android`。
- `ded783a0848fde553155f5ace5a2ffa966cfbf3a`
  - Execute Android 进入 supported app 授权逻辑；
  - 授予 account / devices / sync / execution / habits / reviews / files 所需权限。
- `fad49f3e5e3690ab998ff00957249050e2eb64e3`
  - Registry 新增 `execution.important_date`；
  - Registry 新增 `execution.focus_session`；
  - 两者均为 UserOwned / Bidirectional / Optimistic。
- `56e08ed4bf0403e4b0e2c490dcc91ceaadc5697f`
  - generic `EntityPayload` 接受两个新 execution entity；
  - 当前使用 RegisteredJson 进入统一 Sync v1。

验证：

- 本轮 LifeTrace contract tests 已通过；
- Cloud tests / Clippy / Docker / PostgreSQL smoke 所在完整 workflow 在记录本文时仍继续执行，未提前标记全绿。

已确认但未完成：

- `AuthService::capabilities()` 的信息性 `supportedApps` 硬编码列表仍需补 Execute；
- execution payload 仍大量使用 RegisteredJson；
- ImportantDate / FocusSession 强类型 DTO / Schema 尚未定义。

### LifeTrace Execute Android

#### Cloud Auth

已实现代码：

```text
core/cloud/
├── CloudContract.kt
├── CloudHttpTransport.kt
├── CloudSessionManager.kt
├── DeviceIdentityStore.kt
├── LifeTraceCloudClient.kt
├── LifeTraceSyncClient.kt
├── SecureSessionStore.kt
└── SyncModels.kt
```

功能：

- HTTPS-only Cloud origin；
- login / refresh / logout；
- Execute AppId；
- scope 校验；
- Sync capabilities；
- Keystore AES-GCM；
- access-token-expired 单次刷新重放；
- 登录成功后保存安全会话；
- 登录后立即 enqueue 首次 Task Sync。

#### Room / Outbox

已实现：

```text
data/local/
├── LifeTraceExecuteDatabase.kt
├── LifeTraceExecuteDao.kt
├── TaskEntity.kt
└── SyncEntities.kt
```

表：`tasks`、`sync_outbox`、`sync_state`、`sync_conflicts`。

关键约束：任务写入与 Outbox 同事务。

#### Task Repository / UI / Sync

已实现 Task create/update/complete/reopen/delete、状态、优先级、描述、dueAt、scheduledAt、搜索筛选、本地 Room Flow、Snapshot/Push/Pull、accepted/duplicate/rejected/conflict、tombstone、连续修改 rebase、WorkManager 自动同步和登录后首次同步。

该旧实现现在作为 Flutter 迁移行为参考，直到 Flutter Task 纵向链达到同等或更高 Gate。

#### Android CI

旧 Compose 工作流此前已验证：

```text
b139424b855f6ac0bacde9e6728ddd1cdd8ac87e
run 33134713967
assembleDebug       PASS
testDebugUnitTest   PASS
lintDebug           PASS
workflow            SUCCESS
```

这部分证据继续保留，但从 Flutter 重构开始，不再代表新生产客户端的完成状态。
