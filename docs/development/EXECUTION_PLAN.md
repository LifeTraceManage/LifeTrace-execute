# LifeTrace Execute 完整执行计划与验收标准

更新时间：2026-08-27

> 本文档定义 LifeTrace Execute 从当前浏览器高保真原型到可发布 Android 客户端的完整执行计划、LifeTrace Cloud 接入方案、阶段 Gate 与最终验收标准。
>
> 功能需求以 [`REQUIREMENTS.md`](./REQUIREMENTS.md) 为 Source of Truth；项目实时状态记录在 [`PROJECT_STATUS.md`](./PROJECT_STATUS.md)；UI 规则记录在 [`UI_SPEC.md`](./UI_SPEC.md)。本文档负责回答“按什么顺序做、做到什么程度才算完成”。

---

## 1. Purpose & Scope / 目标与范围

### 1.1 最终目标

交付一个可长期使用的 **LifeTrace Execute Android 执行中心**，具备：

- 今天：统一展示今日焦点、任务、习惯、日程、完成状态与复盘入口；
- 任务：任务 CRUD、状态流转、重复任务、等待项、提醒、番茄专注；
- 项目：项目 CRUD、项目进度、项目任务、项目归档；
- 日历：月视图、日程、任务截止日期、重要日期、公历/农历；
- 收集：文本、想法、链接、图片/文件等快速收集与后续整理；
- 复盘：每日复盘与后续历史复盘；
- 我的：账号、设备、同步状态、偏好与数据管理；
- 离线可用：无网络时主要执行功能仍可读写；
- 多端同步：与 `zhouxingxing1279/LifeTrace` 的 LifeTrace Cloud 使用同一账号与同步协议；
- 数据一致：Android、Web/桌面及其他 LifeTrace 客户端最终看到同一份云端数据。

### 1.2 不在本项目重复建设的能力

LifeTrace Execute **不新建第二套云端后端**，直接复用 LifeTrace 主仓库已有 Cloud：

```text
zhouxingxing1279/LifeTrace
├── services/cloud/                 # Rust + Axum + PostgreSQL
├── crates/lifetrace-contracts/     # 共享领域/认证/同步协议
└── contracts/
    ├── openapi/
    └── json-schema/
```

已确认的 Cloud 能力包括：

- `POST /api/v1/auth/login` 原生客户端登录；
- opaque access token + refresh token；
- 用户 / Session / Device 管理；
- `GET /api/v1/sync/capabilities`；
- `POST /api/v1/sync/push`；
- `POST /api/v1/sync/pull`；
- `POST /api/v1/sync/snapshot`；
- PostgreSQL 云端持久化；
- 文件元数据 + S3 兼容对象存储；
- 隐私导出与账号删除；
- 生产 HTTPS、安全响应头与严格生产配置。

### 1.3 功能保护规则

后续实现不得以“简化”或“重构”为理由删除已经确认的能力。

固定保留：

- 底部一级导航：今天 / 任务 / 项目 / 日历 / 收集；
- “我的”：通过右上角头像进入；
- “复盘”：从今天页进入；
- 项目、收集、重要日期、番茄钟等已登记功能。

允许调整视觉层级和入口位置，但功能能力必须保留。

### 1.4 完成定义

项目只有同时满足以下条件才可标记为 **1.0 完成**：

1. 浏览器原型与 Android 核心页面一致；
2. Android 核心模块不是 Mock Data；
3. 本地数据库、认证、离线写入、同步已打通；
4. LifeTrace Cloud 能接收、保存并回传 Execute 数据；
5. 两台设备可完成新增、修改、删除、离线恢复和冲突测试；
6. 重要日期和番茄钟达到本文验收标准；
7. 自动化测试、构建、发布和回归 Gate 全部通过；
8. 文档、需求状态、证据链接与实际代码一致。

---

## 2. Architecture & Integration / 架构与云端集成

### 2.1 总体架构

采用 **Local-first + Cloud Sync**：

```text
┌──────────────────────────────┐
│ LifeTrace Execute Flutter    │
│                              │
│ Flutter UI / Riverpod        │
│   ↓                          │
│ Domain / Use Cases           │
│   ↓                          │
│ Repository                   │
│   ├── Drift / SQLite         │
│   └── Sync Engine            │
│          ↓ HTTPS             │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│ LifeTrace Cloud              │
│ Rust + Axum                  │
│ PostgreSQL                   │
│ Auth + Device + Sync v1      │
└──────────────────────────────┘
```

UI 不直接调用 HTTP；网络层不直接修改 UI 状态。所有写入先进入统一领域/Repository 层，再以同一事务写本地实体与 Outbox。

### 2.2 Flutter 推荐分层

```text
flutter_app/lib/
├── app/                # app shell / routing / providers
├── features/           # Flutter Screen / state / interaction
├── domain/             # Entity / UseCase / business rules
├── data/
│   ├── local/          # Drift DAO / DB / migrations
│   ├── remote/         # Auth / Sync / Files API
│   ├── repository/     # Repository implementation
│   └── sync/           # Outbox / Pull / Conflict / Snapshot
└── core/
    ├── auth/
    ├── network/
    ├── time/
    └── logging/
```

### 2.3 LifeTrace Cloud 对接原则

Cloud 接口与 wire format **不由 Execute 仓库自行定义第二份**。

契约优先级：

1. `LifeTrace/crates/lifetrace-contracts/`
2. `LifeTrace/contracts/openapi/`
3. `LifeTrace/contracts/json-schema/`
4. Execute Android 映射模型

当 Execute 需要新增云端实体时，先修改 **LifeTrace 主仓库的共享契约和注册表**，再更新 Android。

### 2.4 当前 Cloud 已注册的执行域实体

LifeTrace 主仓库当前已把以下实体注册为 `UserOwned + Bidirectional + Optimistic`：

```text
execution.goal
execution.weekly_review
execution.project
execution.recurrence_rule
execution.task
execution.task_dependency
execution.task_occurrence
execution.waiting_item
execution.calendar_event
execution.calendar_occurrence
execution.memo
execution.memo_tag
execution.memo_tag_relation
execution.reminder
execution.completion_result
execution.entity_link
```

这意味着 Execute 不需要为任务/项目/日历重新设计一套 REST CRUD；优先通过统一 Sync v1 进行多端复制。

### 2.5 当前契约缺口与计划新增

当前这些 `execution.*` 类型虽然已在 Cloud 注册，但仍通过 `RegisteredJson` 做通用 JSON 校验，主要只保证 `meta.id` 存在。1.0 前必须完成执行域契约加固。

计划在 LifeTrace 主仓库增加强类型 `execution` DTO，并生成 JSON Schema / OpenAPI 证据。

另外新增两个明确实体：

#### `execution.important_date`

用于保存：

- 标题；
- 生日 / 纪念日 / 里程碑 / 其他；
- 公历 / 农历；
- 仅一次 / 每年；
- 公历年月日；
- 农历年/月/日；
- 是否闰月；
- 提醒设置；
- 启用状态；
- `meta` / schema version。

不把农历生日硬塞进普通 Gregorian calendar event，以免丢失原始农历语义。

#### `execution.focus_session`

用于同步番茄/专注历史：

- 关联 taskId（可空）；
- focus / break 类型；
- plannedSeconds；
- actualSeconds；
- startedAt / endedAt；
- completed / interrupted；
- originDeviceId；
- `meta` / schema version。

番茄钟“25/5、50/10、自定义偏好”使用 `user.preference`，不为设置再创建独立实体。

### 2.6 认证接入

Android 原生客户端使用 Cloud 已有认证流：

```text
POST /api/v1/auth/login
  email
  password
  appId
  deviceId
  deviceName
  platform
  clientVersion
  requestedScopes

→ accessToken
→ refreshToken
→ user
→ session
→ scopes
```

执行要求：

- 为 Execute 注册稳定 `appId`；
- `deviceId` 安装后生成并持久化，不随 App 重启变化；
- access token 仅驻留必要生命周期；
- refresh token 使用 Android Keystore 保护的安全存储；
- 401 时只允许一次受控刷新并重放请求；
- refresh 失效后进入重新登录态；
- “退出当前设备”调用 Cloud logout；
- “设备管理”读取并展示 Cloud 设备状态，后续支持撤销其他设备。

### 2.7 阶段执行顺序

| Phase | 工作 | 输出 | Gate |
| --- | --- | --- | --- |
| P0 | 需求/架构冻结 | Requirements + 本计划 | 无未登记核心需求 |
| P1 | 浏览器 UI 收敛 | 全核心流程高保真原型 | 页面/交互评审通过 |
| P2 | Flutter UI 对齐 | Flutter 正式页面 | 与原型核心流程一致 |
| P3 | 本地数据层 | Room + Repository + 本地 CRUD | 飞行模式完整可操作 |
| P4 | Cloud 契约加固 | typed execution DTO + 新实体 | Contract tests 全绿 |
| P5 | Auth + Sync Core | 登录、push/pull/snapshot/conflict | 双设备同步 Gate 通过 |
| P6 | 全模块云端化 | Today/Task/Project/Calendar/Collection/Review/Profile | 无 Mock Data |
| P7 | 专项能力 | 重要日期/农历/番茄后台计时 | 专项验收通过 |
| P8 | 质量与发布 | CI、性能、安全、回归、APK | Release Gate 全绿 |

依赖关系必须遵循 `P0 → P1/P4 → P2/P3 → P5 → P6/P7 → P8`。P1 与 P4 可以并行，但不得在契约未定时硬编码生产数据格式。

---

## 3. Execution Modules / 功能模块执行计划

### 3.1 Today / 今天

实现：

- 从本地 Repository 聚合 task occurrence、calendar occurrence、habit log；
- 展示当前日焦点、待完成、已完成、习惯、项目摘要；
- 今日任务可直接完成；
- 进入日历、任务、项目和复盘；
- 同步后自动反映其他端修改。

验收关注：聚合正确、刷新稳定、离线可用，不能把 Today 做成独立重复数据源。

### 3.2 Tasks / 任务

实现范围：

- 新建 / 查看 / 编辑 / 删除；
- TODO / 进行中 / 等待 / 已完成；
- 优先级；
- 项目归属；
- 截止时间；
- Reminder；
- recurrence rule；
- occurrence；
- waiting item；
- completion result；
- 搜索与筛选；
- 番茄钟关联任务。

Cloud 主实体：`execution.task`，辅助实体使用现有 execution registry。

### 3.3 Projects / 项目

实现范围：

- 项目 CRUD；
- 状态：进行中 / 暂停 / 完成 / 归档；
- 项目描述、进度、截止时间；
- 项目任务列表；
- 完成度由任务数据可计算时不维护第二份冲突数据；
- 跨端同步与删除。

Cloud 主实体：`execution.project`。

### 3.4 Calendar / 日历

实现范围：

- 月视图；
- 日期选择；
- calendar event / occurrence；
- 任务截止日期映射；
- Reminder；
- 重要日期摘要与管理；
- 公历/农历显示。

Cloud 主实体：`execution.calendar_event`、`execution.calendar_occurrence`、`execution.reminder`，新增 `execution.important_date`。

### 3.5 Important Dates / 重要日期

必须支持：

- 单次公历；
- 每年公历；
- 单次农历；
- 每年农历；
- 生日默认每年；
- 闰月；
- 编辑 / 删除 / 停用；
- 生成当年显示日期；
- 多端同步。

农历原始值是 Source of Truth；“当年对应公历日”是派生结果，不反向覆盖农历原始值。

正式实现必须使用经过验证的农历转换实现，并使用固定测试向量覆盖闰月、跨年和边界日期。

### 3.6 Pomodoro / 番茄专注

必须支持：

- 25/5；
- 50/10；
- 开始 / 暂停 / 继续 / 重置；
- 关联任务；
- 前台 / 后台；
- 锁屏通知；
- App 被系统回收后恢复；
- 不依赖每秒后台线程维持正确时间，而以绝对时间/单调时钟恢复剩余时长；
- 完成一轮写 `execution.focus_session`；
- 今日专注统计可跨设备查看；
- 计时偏好同步到 `user.preference`。

### 3.7 Collection / 收集

实现范围：

- 文本 / 想法 / 链接 → `execution.memo`；
- 标签 → memo_tag / relation；
- 图片/文件 → LifeTrace `/api/v1/files` + `file.metadata`，业务实体只保存引用；
- 支持“转任务 / 归档 / 删除”。

大文件不得放进 Sync payload；遵循 LifeTrace Cloud 的对象存储签名 URL 机制。

### 3.8 Review / 复盘

实现：

- 今日状态；
- 今日收获；
- 改进；
- 明日优先级；
- 历史查看；
- 跨端同步。

优先复用主项目已有 `review.daily`；周复盘使用 `execution.weekly_review`，不重复建模。

### 3.9 Profile / 我的

实现：

- 当前用户；
- Cloud 登录态；
- 当前设备；
- 设备列表；
- 同步状态；
- 最后同步时间；
- 待同步数量；
- 冲突数量；
- 偏好；
- 退出登录；
- 隐私导出 / 账号删除入口按 Cloud 能力接入。

---

## 4. Data & Sync / 数据与同步

### 4.1 本地数据库

Android 使用 Room/SQLite。至少包含：

```text
业务表
- tasks
- projects
- recurrence_rules
- task_occurrences
- waiting_items
- calendar_events
- calendar_occurrences
- important_dates
- memos / tags / relations
- reminders
- completion_results
- daily_reviews (或统一 review 映射)
- focus_sessions
- preferences cache

同步元数据
- sync_outbox
- sync_state
- sync_conflicts
```

### 4.2 本地写事务

所有可同步写操作必须满足：

```text
BEGIN
  update domain entity
  insert sync_outbox(changeId, entityType, entityId, baseServerVersion, payload...)
COMMIT
```

禁止出现“本地写成功但没有 Outbox”或“Outbox 写了但业务实体失败”。

### 4.3 Push

严格使用 LifeTrace Sync v1：

- `changeId` 是幂等键；
- `upsert` 发送完整实体 snapshot，不发送 JSON Patch；
- 新实体 `baseServerVersion = "0"`；
- 修改/删除必须携带客户端已知的 `baseServerVersion`；
- `clientModifiedAt` 只做审计，不参与排序或冲突解决；
- `accepted` 更新本地 serverVersion；
- `duplicate` 按成功处理；
- `conflict` 写入本地 `sync_conflicts`；
- `rejected` 不无限重试，记录稳定错误并提示修复。

### 4.4 Pull

- 只按服务端 cursor 顺序应用；
- 禁止按 `updatedAt` 重新排序；
- 一个 pull batch 必须在本地事务中原子应用；
- 只有整批成功后才能保存 `nextCursor`；
- delete 必须应用 tombstone；
- 服务端回传自己设备的 change 也必须幂等处理。

### 4.5 Snapshot

使用场景：

- 新设备首次登录；
- 本地 DB 重建；
- 服务端历史被裁剪并要求 snapshot；
- 用户主动执行“重新同步全部数据”。

验收要求：全量 snapshot 后再增量 pull，不丢实体、不复活已删除实体。

### 4.6 Conflict

Cloud 已采用 Optimistic conflict 模式。Android 处理策略：

- 无冲突：自动合并同步；
- 同一实体 serverVersion 已变化：不得 silent overwrite；
- 保存 client draft + server current；
- 在“我的 → 同步与数据 → 冲突”提供用户可理解的处理入口；
- 支持“保留云端 / 保留本地（形成新 change）”；
- 复杂字段后续可增加逐字段 merge，但不是 1.0 阻塞项。

### 4.7 删除

- 本地删除先表现为不可见；
- Outbox 发送 `delete`；
- Cloud 建 tombstone；
- 其他设备 pull tombstone 后删除本地实体；
- 不允许旧离线设备上线后把已删除实体重新 upsert 成“复活”。

### 4.8 同步触发

至少支持：

- 登录后；
- App 启动；
- 回到前台；
- 本地写入后 debounce；
- 网络恢复；
- WorkManager 周期性补偿；
- 用户手动刷新。

所有触发最终进入同一个 single-flight Sync Coordinator，禁止并行 Push/Pull 互相踩状态。

### 4.9 网络异常

- timeout / 5xx / 无网络：指数退避；
- 4xx 业务错误：按稳定 ErrorCode 处理，不盲目重试；
- 401：刷新 token 后最多重放一次；
- 429：遵循服务端限流窗口；
- 用户离线期间的 UI 不应因云端不可达而无法操作。

---

## 5. Security & Privacy / 安全与隐私

### 5.1 网络

生产环境：

- 仅 HTTPS；
- 禁止明文 HTTP Cloud 地址；
- 禁止关闭 TLS 证书验证；
- API base URL 使用 BuildConfig / 环境配置，不硬编码开发服务器；
- 日志不得输出 Authorization、access token、refresh token、密码。

### 5.2 凭证

- refresh token 使用 Android Keystore 保护；
- access token 不写普通明文 SharedPreferences；
- logout 后清理本地凭证；
- 设备撤销后该设备不能继续同步；
- 密码不写日志、不落本地数据库。

### 5.3 用户隔离

- 所有云端数据均由 Cloud 用户身份隔离；
- 切换账号必须清空/切换本地用户数据库命名空间；
- 任何用户 A 的缓存不得在用户 B 登录后展示。

### 5.4 文件与隐私

- 文件使用 Cloud 文件 API 和短时签名 URL；
- Sync 只同步元数据/引用，不把大文件编码进 JSON；
- 遵守 Cloud 既有领域 MIME/大小限制；
- 账号删除、隐私导出不在客户端虚报成功，必须以后端实际结果为准。

### 5.5 生产安全 Gate

Execute 发布前必须验证 Cloud 生产配置仍满足：HTTPS、Secure Session、受控 CORS、Secret 注入、数据库不暴露公网、生产 migration 策略和安全响应头要求。

---

## 6. Operations & Deployment / 构建、运维与发布

### 6.1 环境

至少区分：

```text
dev     本地/开发 Cloud
staging 与生产协议一致的验收环境
prod    正式环境
```

不同环境不得共享 token、数据库和对象存储凭证。

### 6.2 Android 构建

必须补齐：

- Gradle Wrapper；
- Debug / Release build；
- dev/staging/prod API base URL；
- application version / build number；
- release signing 通过安全方式注入；
- ProGuard/R8 基础规则；
- lint；
- unit tests；
- instrumentation tests。

### 6.3 Cloud

LifeTrace Cloud 继续在主仓库独立部署：

```text
services/cloud/
deploy/cloud/
```

Execute 不复制 Dockerfile 或数据库部署配置。

当新增 `execution.important_date` / `execution.focus_session` 或强类型 DTO 时：

1. 修改 LifeTrace contracts；
2. 更新 registry；
3. 更新 schema/OpenAPI 生成物；
4. 跑 contracts + cloud tests；
5. staging 部署；
6. Execute 再升级客户端契约；
7. 双端兼容测试通过后才能 prod。

### 6.4 可观测性

客户端至少记录非敏感事件：

- login success/failure category；
- sync start/end；
- push accepted/duplicate/conflict/rejected count；
- pull count/cursor；
- snapshot reason；
- background timer recovery；
- fatal/non-fatal error category。

禁止记录实体正文、密码、token 等敏感内容。

### 6.5 数据备份

Cloud PostgreSQL 与对象存储备份属于 LifeTrace Cloud 运维边界。Execute 的验收要求是：

- 新设备能通过 snapshot 重建本地数据；
- 本地数据库损坏时可以删除重建并从 Cloud 恢复；
- 未成功 push 的 Outbox 在“清数据”动作前必须明确告知会丢失。

---

## 7. Testing Strategy / 测试策略

### 7.1 单元测试

覆盖：

- 任务状态机；
- recurrence 计算；
- 重要日期规则；
- 公历/农历转换 wrapper；
- 番茄时钟时间恢复；
- Entity ↔ wire payload mapper；
- push result 处理；
- pull cursor 状态机；
- conflict 处理；
- retry 分类。

### 7.2 Contract Tests

在 LifeTrace 主仓库验证：

- 每个 execution entity schema；
- payload 缺必填字段会被拒绝；
- schemaVersion 不兼容可检测；
- 新 entity type 已进入 registry/capabilities；
- OpenAPI / JSON Schema 生成物与 Rust contract 一致。

### 7.3 Repository / DB Tests

- CRUD；
- migration；
- domain + outbox 同事务；
- pull batch 原子应用；
- tombstone；
- conflict 持久化；
- 重启后 cursor/outbox 不丢。

### 7.4 UI Tests

至少覆盖核心 happy path：

1. 登录；
2. 新建任务；
3. 完成任务；
4. 新建项目并关联任务；
5. 新建日程；
6. 新建公历生日；
7. 新建农历每年生日；
8. 启动/暂停番茄；
9. 新建收集项并转任务；
10. 保存复盘；
11. 查看同步状态；
12. 退出登录。

### 7.5 Sync Integration Tests

使用真实 LifeTrace Cloud staging 或本地 Docker PostgreSQL，至少覆盖：

- A 设备新增 → Cloud → B 设备 pull；
- B 修改 → A pull；
- 同一个 `changeId` 重复 push；
- A/B 同时修改同一实体；
- A 删除、B 离线修改再上线；
- 网络中断后 Outbox 重试；
- pull 中途本地事务失败；
- snapshot 恢复；
- token 过期刷新；
- device revoke；
- 100+ change 批量同步。

### 7.6 农历固定测试集

建立固定 golden vectors，而不是只手工点 UI：

- 普通农历日期；
- 春节附近跨公历年；
- 农历十二月跨年；
- 有闰月年份；
- 闰月日期；
- 每年重复生日连续至少 10 年转换；
- 不存在的闰月输入必须拒绝或明确处理。

### 7.7 番茄计时测试

- 前台运行 25 分钟误差；
- 切后台 10 分钟后恢复；
- 锁屏；
- 进程被杀后重启；
- 系统时间手工调整；
- 暂停后停留 5 分钟；
- 多次暂停继续；
- 完成后 focus_session 只写一次；
- 同一 session sync 重试不重复。

---

## 8. Acceptance Criteria / 验收标准

### 8.1 全局 Release Gate

以下全部满足才允许 1.0 发布：

| ID | 验收项 | 标准 |
| --- | --- | --- |
| AC-G-001 | 功能完整 | Requirements 中 1.0 范围无 `待设计/开发中` |
| AC-G-002 | 无 Mock | 核心页面数据来自 Repository，不再依赖 MockData |
| AC-G-003 | 离线 | 飞行模式下任务/项目/日历/收集/复盘可读取并写入 |
| AC-G-004 | 同步 | 恢复网络后离线修改自动进入 Cloud |
| AC-G-005 | 双设备 | 两台设备能最终一致 |
| AC-G-006 | 删除 | 删除后不会因旧设备上线复活 |
| AC-G-007 | 冲突 | 并发编辑不会 silent overwrite |
| AC-G-008 | 新设备 | snapshot 可恢复完整授权数据 |
| AC-G-009 | 构建 | release APK/AAB 可重复构建 |
| AC-G-010 | 回归 | 自动化核心用例全部通过 |

### 8.2 UI/UX

| ID | 标准 |
| --- | --- |
| AC-UI-001 | 浏览器设计中确认的核心信息架构在 Android 保持一致 |
| AC-UI-002 | 所有主要可点击控件触控区域 ≥ 48dp |
| AC-UI-003 | 核心页面在 compact Android viewport 无遮挡、截断和底部导航覆盖 |
| AC-UI-004 | 系统状态栏、导航栏、键盘 Insets 正确 |
| AC-UI-005 | 核心流程字体放大后仍可使用，不因固定高度导致关键按钮不可达 |
| AC-UI-006 | loading / empty / error / offline / syncing / conflict 均有明确状态 |

### 8.3 Authentication

| ID | 标准 |
| --- | --- |
| AC-AUTH-001 | 使用 Cloud `/api/v1/auth/login` 登录成功并拿到 TokenResponse |
| AC-AUTH-002 | deviceId 重启后稳定 |
| AC-AUTH-003 | access token 过期可用 refresh token 恢复 Session |
| AC-AUTH-004 | refresh 失效进入重新登录，不陷入无限 401 循环 |
| AC-AUTH-005 | logout 后旧 access/refresh 凭据不再继续同步 |
| AC-AUTH-006 | token/password 不出现在普通日志或数据库明文字段 |

### 8.4 Sync

| ID | 标准 |
| --- | --- |
| AC-SYNC-001 | 同一 changeId 重发 ≥3 次，Cloud 只产生一次业务变更，客户端识别 duplicate |
| AC-SYNC-002 | 断网写入 ≥20 条后恢复网络，最终全部同步且无重复 |
| AC-SYNC-003 | pull 严格按 cursor 应用，nextCursor 仅在整批成功后持久化 |
| AC-SYNC-004 | baseServerVersion 不匹配时形成 conflict，不覆盖服务端数据 |
| AC-SYNC-005 | delete 通过 tombstone 传播到第二台设备 |
| AC-SYNC-006 | 被删除实体不会被离线旧设备自动复活 |
| AC-SYNC-007 | 新设备 snapshot + pull 后与 Cloud 当前授权数据一致 |
| AC-SYNC-008 | App 强杀/重启后 outbox、cursor、conflict 全部保留 |
| AC-SYNC-009 | capabilities 不支持的 entity/schema 不盲目 push |
| AC-SYNC-010 | 100 条变更的正常网络同步无数据错序/丢失/重复 |

### 8.5 Tasks & Projects

- 任务/项目 CRUD 在离线状态可用；
- 任务状态、项目归属、截止日期同步到第二设备；
- 删除跨设备传播；
- 重复任务生成 occurrence 不产生重复实例；
- waiting/reminder/completion result 与任务实体关系正确；
- 项目删除/归档不会留下不可理解的悬挂 UI 状态。

### 8.6 Calendar & Important Dates

| ID | 标准 |
| --- | --- |
| AC-CAL-001 | 普通 calendar event 可增删改并同步 |
| AC-CAL-002 | 单次公历重要日期保存并在对应日显示 |
| AC-CAL-003 | 每年公历生日跨年至下一年仍出现 |
| AC-CAL-004 | 单次农历可保存农历年/月/日/闰月原始信息 |
| AC-CAL-005 | 每年农历重要日期能正确换算当年公历显示日期 |
| AC-CAL-006 | 闰月输入和转换通过 golden vectors |
| AC-CAL-007 | Android A 创建农历生日，B 同步后原始农历字段完全一致 |
| AC-CAL-008 | 编辑/删除重要日期跨设备传播 |
| AC-CAL-009 | 农历派生公历值不得覆盖原始农历 Source of Truth |

### 8.7 Pomodoro

| ID | 标准 |
| --- | --- |
| AC-POMO-001 | 25/5、50/10 可切换 |
| AC-POMO-002 | 开始/暂停/继续/重置状态正确 |
| AC-POMO-003 | 可关联一个任务，任务删除后 session 历史仍安全可读 |
| AC-POMO-004 | 前台 30 分钟计时累计误差 ≤ 1 秒 |
| AC-POMO-005 | 后台/锁屏恢复后以时间戳重算，累计误差 ≤ 2 秒 |
| AC-POMO-006 | App 进程被杀后重启能恢复进行中的计时状态或明确标记中断，不静默丢失 |
| AC-POMO-007 | 一轮完成只产生一个 focus_session |
| AC-POMO-008 | focus_session 重试同步不重复 |
| AC-POMO-009 | 今日专注统计在第二设备同步后可一致重算 |

### 8.8 Collection / Files

- 文本/链接/想法离线可收集；
- 转任务后关系正确；
- 文件使用 `/api/v1/files` 元数据和短时 URL；
- 大文件不进入 Sync JSON；
- 上传失败可重试且元数据状态明确；
- 删除业务引用不会误删仍被其他实体引用的文件。

### 8.9 Review

- 复盘保存后重启仍存在；
- 同一日期只按契约允许的方式维护记录；
- 第二设备可同步查看；
- 离线编辑发生冲突时不 silent overwrite；
- Today 页摘要与 review 数据一致。

### 8.10 Performance & Stability

在选定的基准 Android 设备/模拟器上：

- 本地已有数据时主页面切换 p95 ≤ 300ms；
- 常规本地 CRUD 操作 UI 反馈 ≤ 150ms；
- 1000 tasks / 200 projects / 3000 calendar occurrences 下列表可正常滚动，无明显长时间主线程阻塞；
- 100 change 正常网络同步在 staging 环境完成且无超时（具体耗时记录为测试证据，不用牺牲正确性换速度）；
- 核心 E2E 回归无 Crash / ANR；
- 网络不可达不阻塞本地页面启动。

---

## 9. Risks & Mitigations / 风险与对策

### R1. Execute execution payload 当前缺少强类型校验

**风险**：Cloud 虽能同步 `execution.*`，但错误字段可能作为 RegisteredJson 被持久化。

**对策**：P4 在 LifeTrace contracts 新增 execution typed DTO，并以 schema/contract test 作为 P5 前置 Gate。

### R2. 农历规则复杂

**风险**：闰月、跨年、不同年份换算出错会导致生日提醒错误。

**对策**：保留农历原始值；使用成熟历法实现；建立 golden vectors；禁止浏览器原型算法直接搬到生产。

### R3. Android 后台计时不可靠

**风险**：依赖 `setInterval`/普通线程会在 Doze、锁屏、进程回收后漂移。

**对策**：保存 startedAt / paused state / expectedEnd；恢复时按可靠时钟重算；通知用于用户体验而非作为时间真值。

### R4. 双端冲突导致覆盖

**风险**：移动端离线时间长，恢复后基于旧版本覆盖新数据。

**对策**：严格 baseServerVersion + Cloud Optimistic conflict；冲突进入显式队列。

### R5. 删除复活

**风险**：旧设备离线 upsert 已删除记录。

**对策**：tombstone + base version 冲突测试列为 Release Gate。

### R6. 浏览器原型与 Android 双轨漂移

**风险**：两份 UI 各自演进。

**对策**：浏览器只做设计基线；每个需求标记“前端已设计 / Android 待实现 / 已完成”；Android 完成后更新 PROJECT_STATUS，不长期维护两套业务逻辑。

### R7. 主仓库契约和客户端版本错配

**风险**：Cloud 先升级、新旧 Android 不兼容。

**对策**：capabilities + entity schema version；staging 双版本回归；只做向后兼容变更或提供迁移窗口。

### R8. Token / Secret 泄漏

**风险**：调试日志、崩溃日志、普通配置文件泄漏凭证。

**对策**：统一日志 redaction；Keystore；CI secret；禁止把生产凭证提交仓库。

### R9. 本地 DB migration 破坏已有数据

**对策**：每个 Room migration 必须有升级测试；禁止 release 使用 destructive migration 处理用户正式数据。

---

## 10. Traceability & Evidence / 追踪与验收证据

### 10.1 需求追踪

每个开发项必须满足：

```text
Requirement ID
    ↓
Design / UI
    ↓
Domain model / Cloud contract
    ↓
Implementation commit / PR
    ↓
Automated test
    ↓
Acceptance evidence
    ↓
PROJECT_STATUS 状态更新
```

任何新增需求先进入 `REQUIREMENTS.md`，再开发。

### 10.2 每个阶段必须留下的证据

#### P1 浏览器设计

- 页面截图或可运行 `web-preview`；
- 对应 Requirement ID；
- 交互路径说明。

#### P2 Android UI

- Flutter widget/golden / 真机截图；
- UI test；
- 与浏览器基线差异说明。

#### P3 本地层

- Room schema；
- migration tests；
- repository unit tests；
- 飞行模式录屏/测试记录。

#### P4 Cloud Contract

LifeTrace 主仓库证据：

- `crates/lifetrace-contracts` 修改；
- registry entity；
- JSON Schema；
- OpenAPI；
- contract/cloud test logs。

#### P5 Sync

- 双设备测试结果；
- accepted/duplicate/conflict/rejected 四类结果证据；
- cursor/tombstone/snapshot 测试；
- 离线恢复测试。

#### P6/P7 功能

- 各模块 E2E；
- 重要日期 golden vectors；
- 番茄后台/进程恢复测试。

#### P8 Release

- commit SHA；
- versionName/versionCode；
- CI URL / 结果；
- release APK/AAB hash；
- staging E2E 结果；
- 已知问题清单；
- `PROJECT_STATUS.md` 更新为发布状态。

### 10.3 当前事实基线（2026-08-27）

#### LifeTrace Execute

- 浏览器高保真主页面已建立；
- Important Dates 前端设计已建立；
- Pomodoro 前端设计已建立；
- Flutter Android 基础页面存在；
- Android 仍主要是 UI/Mock 阶段；
- 尚未完成正式 Room/Repository/Auth/Sync 集成。

#### LifeTrace Cloud

已确认：

- Rust + Axum + PostgreSQL；
- Auth v1 原生客户端登录；
- access/refresh token；
- Device；
- Sync capabilities；
- Push / Pull / Snapshot；
- server cursor；
- changeId 幂等；
- optimistic conflict；
- tombstone；
- 执行域大多数核心 entity type 已注册双向同步；
- 文件元数据 / 对象存储机制已存在。

待补：

- Execute execution 域完整强类型 DTO；
- `execution.important_date`；
- `execution.focus_session`；
- Android Execute 的 auth/sync client；
- Android 本地离线数据库和 Outbox；
- 跨设备 E2E。

### 10.4 下一步立即执行清单

按顺序：

1. **冻结 Execute 1.0 字段级领域模型**：Task / Project / Calendar / Memo / ImportantDate / FocusSession。
2. **在 LifeTrace 主仓库加固 execution contracts**，加入 `important_date`、`focus_session`。
3. **补 Execute Android Gradle Wrapper 和可重复构建**。
4. **建立 Room + Repository + sync_outbox/sync_state/sync_conflicts**。
5. **实现 LifeTrace Cloud Auth client**。
6. **实现 capabilities → snapshot → pull → push 的 Sync Coordinator**。
7. **先用 Task 做第一条纵向打通链路**：本地新增 → push → Cloud → 第二设备 pull。
8. **扩展到 Project / Calendar / Memo / Review**。
9. **落地 Important Date 农历与 Pomodoro 后台计时**。
10. **完成双设备、离线、冲突、删除、snapshot、Release Gate**。

> 原则：每完成一条纵向链路就交付可验证证据，不等所有页面一起完成后再做云端联调。
