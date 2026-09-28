# LifeTrace Execute 需求台账

更新时间：2026-08-28

> 本文档是 LifeTrace Execute 的长期需求来源（Source of Truth）。后续新增、调整、取消需求都在这里维护，不以聊天记录代替产品需求文档。

## 1. 维护规则

- 每个需求使用稳定编号，避免后续讨论时指代不清。
- 新增功能不得以删除已确认功能为代价。
- 需求状态统一使用：`待设计` / `前端已设计` / `Android 待实现` / `开发中` / `已完成` / `暂缓`。
- 浏览器/Flutter 预览用于优先确认信息架构、视觉和交互；确认后的正式实现落到 Flutter 生产客户端。
- 需求有变更时，在本文末尾“变更记录”追加，不覆盖历史意图。

## 2. 已确认产品约束

### REQ-BASE-001 一级导航保持稳定

状态：**已确认**

底部一级导航固定保留：

1. 今天
2. 任务
3. 项目
4. 日历
5. 收集

“我的”从右上角头像进入；“今日复盘”从今天页进入独立页面。

### REQ-BASE-002 功能保护

状态：**已确认**

新增、重构、合并入口时，不得删除项目、收集、复盘、账号/设置等已经确认的能力。允许调整入口位置与视觉层级，但不能为了新增功能直接移除旧功能。

### REQ-CLOUD-001 LifeTrace Cloud 统一账号与同步

状态：**开发中**

LifeTrace Execute 必须连接 `zhouxingxing1279/LifeTrace` 现有 Cloud，不创建第二套账号系统或第二套 Execute 云端。

正式 Android 客户端要求：

- 使用 LifeTrace 原生账号；
- 使用独立稳定 AppId `lifetrace-execute-android`；
- 使用 Auth v1 access / refresh token；
- 设备有稳定 installation deviceId；
- Token 使用 Android 安全存储；
- 正式 Cloud 强制 HTTPS；
- 使用 LifeTrace Sync v1；
- 支持 snapshot / push / pull；
- 支持 changeId 幂等；
- 支持 baseServerVersion 乐观冲突；
- 支持 tombstone 删除传播；
- 支持新设备恢复；
- 登录成功后无需用户额外操作即可排队首次同步；
- 本地业务修改后应自动触发受网络约束的后台同步；
- 最终不同 LifeTrace 客户端看到同一份用户数据。

当前代码已实现 Auth、安全会话、Task Sync Coordinator、手动同步、登录后首次同步排队和 WorkManager 自动同步；真实多设备 E2E 仍是完成 Gate。

### REQ-CLOUD-002 Local-first / 离线执行

状态：**开发中**

Android 不允许把网络请求作为主要业务写入的前置条件。

业务写入要求：

```text
本地 Entity + Sync Outbox
```

必须在同一数据库事务提交。

断网时：

- 已同步数据仍可读取；
- 任务等核心业务仍可修改；
- 修改进入 Outbox；
- 网络恢复后由 WorkManager 自动重试；
- API 暂时失败不得导致本地任务丢失；
- 认证失败不得形成无限重试循环；
- retryable / 429 / 5xx / IO 错误允许受控退避重试。

---

## 3. 日历需求

### REQ-CAL-001 重要日期

状态：**Flutter 真实纵向链已实现并通过 CI；1.0 Release Gate 仍未完成**

#### 目标

在“日历”中增加独立的“重要日期”能力，用于维护生日、纪念日、里程碑以及只发生一次的重要日期。

#### 日期重复方式

必须支持：

- **仅一次**：某个明确日期只发生一次，例如考试、发布日、签约日。
- **每年重复**：每年在对应日期出现，例如生日、纪念日。
- 选择“生日”类型时，默认使用“每年重复”，但用户仍可修改。

#### 历法

必须同时支持：

- **公历**
- **农历**

农历日期需考虑：

- 农历月份与日期；
- 闰月；
- 对于“仅一次”的农历日期，需要保存农历年份；
- 对于“每年重复”的农历日期，每年应根据农历规则换算到当年的公历日期后展示与提醒。

> 浏览器原型阶段只负责完整设计输入、展示和交互状态，不自行实现不可靠的农历换算。正式 Android/数据层必须使用经过验证的农历历法转换实现。

#### 重要日期字段

建议数据模型至少包含：

- `id`
- `title`
- `type`：生日 / 纪念日 / 里程碑 / 其他
- `calendarType`：solar / lunar
- `repeatType`：once / yearly
- 公历日期，或农历年/月/日/闰月信息
- 是否启用
- 创建时间 / 更新时间

Cloud entity：`execution.important_date`。该类型已经进入 LifeTrace Sync v1 Registry；正式 Android 实现前仍需补强类型 DTO / Schema。

#### 日历页展示

- 日历页顶部或月历附近提供“重要日期”入口。
- 月历中对当前月可解析到的重大日期提供区别于普通日程的标记。
- 日历页展示近期重要日期摘要。
- 重要日期管理页展示名称、历法、重复方式和日期。
- 支持新增、编辑、删除重要日期。

#### 前端验收

- 可以从日历页进入“重要日期”。
- 可以新增“仅一次”的公历日期。
- 可以新增“每年重复”的公历日期。
- 可以选择农历并输入农历日期与闰月状态。
- 可以将类型设置为生日。
- 新增后的日期立即出现在重要日期列表中。
- 已存在的重要日期可以重新编辑或删除。

---

## 4. 任务需求

### REQ-TASK-CORE-001 Local-first 任务管理

状态：**开发中**

任务不能继续以 Mock Data 作为正式运行时数据源。

1.0 任务基础能力至少包括：

- 新建；
- 查看；
- 编辑；
- 删除；
- TODO / 进行中 / 等待 / 已完成；
- 优先级；
- 描述；
- 项目归属；
- 截止时间；
- 安排时间；
- 提醒；
- 重复规则；
- 搜索；
- 筛选；
- 离线写入；
- LifeTrace Cloud 多端同步；
- 冲突处理。

当前已实现代码：

- Room Flow 正式任务列表；
- 新建 / 编辑 / 删除；
- 标题 / 描述；
- TODO / 进行中 / 等待 / 已完成；
- 优先级；
- 完成 / 恢复；
- 搜索 / 筛选；
- `scheduledAt` / `dueAt`；
- Android 原生日期时间选择器；
- Task + Outbox 同事务；
- 手动 Task Sync；
- WorkManager 自动同步；
- 登录后首次 Task Snapshot 同步排队。

仍需完成：Project 归属、Reminder、重复规则 / occurrence、完整 waiting workflow 和冲突解决 UI。

### REQ-TASK-001 番茄时钟

状态：**前端已设计 / Android 待实现**

#### 目标

在“任务”页面加入番茄时钟，让任务管理和专注执行处于同一工作流，而不是单独新增一个一级导航。

#### 页面位置

- 番茄钟位于任务页顶部核心区域，优先级高于任务筛选列表。
- 不新增底部一级导航。
- 番茄钟可以关联当前要执行的任务。

#### 基础能力

必须支持：

- 默认专注时长 25 分钟；
- 默认休息时长 5 分钟；
- 开始；
- 暂停；
- 重置；
- 展示剩余时间；
- 展示当前是“专注”还是“休息”；
- 展示当前关联任务；
- 展示当前番茄轮次 / 今日完成番茄数。

#### 配置

前端首先提供：

- `25 / 5` 经典模式；
- `50 / 10` 深度专注模式；
- 选择关联任务。

后续数据层应允许保存用户默认专注/休息配置。

Cloud history entity：`execution.focus_session`。该类型已使用 LifeTrace Cloud typed contract，并已接入 Flutter Sync v1。运行中的倒计时状态使用设备本地持久化 `FocusTimerState`，不跨设备同步；结束后的 FocusSession 作为历史事实跨设备同步。

#### 计时行为

- 在应用内部切换“今天 / 任务 / 项目 / 日历 / 收集”时，计时状态不能因为页面切换被重置。
- 一轮专注结束后应进入休息状态并给出明确反馈。
- 一轮休息结束后可回到下一轮专注。
- Android 正式实现需要考虑 App 切后台、进程恢复、系统通知和时间校准；浏览器原型暂不作为后台计时实现依据。

#### 前端验收

- 任务页可看到高保真番茄时钟卡片。
- 可以开始 / 暂停 / 重置。
- 倒计时真实变化。
- 可以选择 `25/5` 或 `50/10`。
- 可以选择关联任务。
- 在一级页面间切换后返回任务页，当前计时状态仍然保留。

---

## 5. 当前需求状态摘要

| 需求 | 状态 |
| --- | --- |
| REQ-BASE-001 一级导航 | 已确认 |
| REQ-BASE-002 功能保护 | 已确认 |
| REQ-CLOUD-001 Cloud 统一账号与同步 | 开发中，Task 自动同步已接入 |
| REQ-CLOUD-002 Local-first | 开发中，Task 已落地 |
| REQ-CAL-001 重要日期 | Flutter 纵向链已实现：公历/农历/闰月/Reminder/Sync/冲突已通过 CI |
| REQ-TASK-CORE-001 任务管理 | 开发中，基础 CRUD/编辑/时间/后台同步已实现 |
| REQ-TASK-001 番茄时钟 | Flutter F8 纵向链已实现：持久化计时、恢复、通知、历史、Sync/冲突已通过 CI |

## 5.1 2026-09-15 实现事实补充

### Important Date

已实现并验证：

- typed `execution.important_date`；
- 公历 / 农历 / once / yearly / leap month；
- Drift / Repository / Outbox；
- Sync / conflict；
- Calendar / Today；
- Reminder 与 yearly reminder renewal；
- lunar golden vectors。

Flutter CI：`34680178657` 全绿。

### Pomodoro / FocusSession

已实现并验证：

- 25/5、50/10；
- task link；
- start / pause / resume / reset / skip；
- local-only persisted TimerState；
- `expectedEndAt` wall-clock recovery；
- page switch / background / process restart recovery；
- Focus/Break notifications；
- stable FocusSession idempotency；
- FocusSession history；
- Sync v1 snapshot / push / pull；
- conflict keepLocal / keepServer；
- Today Focus status / today duration / completed rounds。

Flutter CI：`34924805960` 全绿。

## 6. 变更记录

### 2026-08-28

- 登记 `REQ-CLOUD-001`：LifeTrace Cloud 统一账号与 Sync v1。
- 登记 `REQ-CLOUD-002`：Android Local-first / Room + Outbox。
- 登记 `REQ-TASK-CORE-001`：正式任务管理与多端同步。
- Task 正式运行时从 Mock 迁移到 Room / Repository。
- Task 补齐标题、描述、状态、优先级、安排时间与截止时间编辑。
- 接入 WorkManager：本地修改后自动同步、周期兜底同步、登录后首次同步。
- LifeTrace Cloud Registry 注册 `execution.important_date` 与 `execution.focus_session`。
- Android CI 已真实验证 assembleDebug / unit test / lint 全部通过。

### 2026-08-27

- 建立长期需求台账。
- 新增 `REQ-CAL-001`：日历重要日期，支持仅一次 / 每年、公历 / 农历、生日场景。
- 新增 `REQ-TASK-001`：任务页番茄时钟。
- 明确高保真设计作为交互基线，正式业务逻辑落到 Flutter / Local-first 数据层。
