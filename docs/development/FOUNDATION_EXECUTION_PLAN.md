# LifeTrace Execute 全功能交付执行文档

更新时间：2026-08-30

> 文件名继续保留 `FOUNDATION_EXECUTION_PLAN.md`，用于兼容仓库现有文档入口与 `AGENTS.md`。从本次更新开始，本文不再只定义“基础可用版本”，而是作为 **LifeTrace Execute 全功能 1.0 的当前最高优先级执行计划**。
>
> 本轮目标：把当前“Cloud/Sync 基础设施 + Task 单模块 + 多个高保真 UI 外壳”推进为一个可以长期真实使用、完整离线、完整同步、可发布的 Android 执行中心。
>
> **全部功能**的边界定义为：`REQUIREMENTS.md`、`UI_SPEC.md`、`EXECUTION_PLAN.md` 中已经确认、已经设计或已经进入正式规划的 1.0 能力全部实现。已经确认的功能不得再以“首版先不做”“以后补”“先做外壳”为理由跳过；尚未登记的未来设想不自动扩大 1.0 范围。

---

## 0. 执行总原则

### 0.1 功能完成不是页面完成

一个业务模块只有形成下面的纵向闭环，才允许标记为 `已完成`：

```text
Requirement / Product Rule
        ↓
Domain Model / Business Rule
        ↓
Room Entity / DAO / Migration
        ↓
Repository / UseCase
        ↓
ViewModel / UI State
        ↓
Flutter UI / Real Interaction
        ↓
Offline Behavior
        ↓
Sync / File / Notification（适用时）
        ↓
Automated Tests
        ↓
CI / Smoke / E2E Evidence
```

以下情况一律不计为功能完成：

- 只有 Flutter 页面；
- 仍依赖 `MockData`；
- 使用固定用户名、固定日期、固定统计数字代替真实数据；
- 核心按钮仍是空 `onClick = {}`；
- 使用 `remember` 保存需要跨页面/重启保留的业务数据；
- 只写 Room 但没有 Repository / UI；
- 需要同步的实体没有 Outbox / Sync；
- 修改 Room Schema 却没有 Migration；
- `testDebugUnitTest` PASS 但没有真实业务测试；
- 只在单设备工作，没有验证离线/同步/删除/冲突。

### 0.2 不再采用“最小版功能裁剪”

之前基础计划中存在“先支持文本/想法/链接”“提醒先做基础版”等阶段性最小范围。从本次更新开始：

- 阶段可以分批实现；
- **最终 1.0 Gate 不允许裁剪已确认功能**；
- 图片、文件、语音收集必须完成；
- Task recurrence / occurrence / waiting / reminder / completion / dependency 必须完成；
- 重要日期公历/农历/闰月必须完成；
- 番茄钟后台、进程恢复、通知、历史必须完成；
- Profile 中设备、同步、通知、外观、数据管理必须形成真实行为；
- 每日复盘、历史复盘以及已规划的周复盘必须完成；
- 多实体、多设备、离线和冲突必须完成。

### 0.3 不复制第二套架构

继续复用：

- LifeTrace Cloud；
- Auth v1；
- Sync v1；
- Room；
- Outbox；
- WorkManager；
- Android Keystore；
- Cloud 文件 API / 对象存储；
- 主仓库已有的 execution contract / registry。

禁止为 Project、Memo、Calendar 等实体各复制一套独立 Sync Coordinator。

---

## 1. 当前代码事实基线

### 1.1 已经真正落地

当前 Android 已有正式基础设施：

- `lifetrace-execute-android` AppId；
- LifeTrace Cloud 登录 / refresh / logout；
- Android Keystore + AES-GCM 会话保护；
- installation-level 稳定 `deviceId`；
- HTTPS Cloud origin 校验；
- Sync capability / schema capability 校验；
- Room 数据库；
- `sync_outbox` / `sync_state` / `sync_conflicts`；
- WorkManager 后台同步；
- Task CRUD；
- Task 状态 / 优先级 / 描述 / scheduledAt / dueAt；
- Task 搜索 / 筛选；
- Task Snapshot / Push / Pull；
- accepted / duplicate / conflict / rejected；
- tombstone；
- 同实体连续修改 rebase；
- Task Conflict Resolver / Bottom Sheet / ViewModel action 基础设施。

Task 是目前唯一接近正式纵向闭环的业务模块。

### 1.2 尚未形成完整业务闭环

当前仍需要重点完成：

- Task Conflict UI 最终接通；
- Project；
- Task 高级能力；
- Calendar / CalendarEvent / occurrence；
- Important Date；
- Reminder / Android Notification；
- Collection / Memo / Tags / Files / Voice；
- Daily Review / Weekly Review；
- Goal / Habit 与 Today 聚合；
- Pomodoro / FocusSession；
- Today 真实聚合；
- Profile / Devices / Settings / Data Management；
- Generic Multi-entity Sync；
- 真实 Unit / DB / UI / E2E 测试；
- Release 构建与发布 Gate。

### 1.3 当前产品判断

> 当前项目是 **“正式 Cloud/Auth/Sync 基础设施 + Task 第一条纵向链 + 其余主要页面高保真外壳”**，不是完整产品。

后续开发按本文 Phase Gate 推进，不再以“页面数量”衡量完成度。

---

## 2. LifeTrace Execute 1.0 全功能范围

以下能力全部属于 1.0 Release Scope。

### 2.1 Cloud / Account / Local-first

必须完成：

- 登录；
- access token / refresh token；
- token 受控刷新；
- logout；
- 稳定 deviceId；
- Secure Session；
- HTTPS-only；
- 多账号数据隔离；
- Local-first CRUD；
- Outbox；
- Snapshot；
- Push；
- Pull；
- changeId 幂等；
- baseServerVersion conflict；
- tombstone；
- rejected / retryable 分类；
- 网络恢复自动同步；
- App 启动 / 前台 / 登录后 / 本地写入 / 周期性同步；
- 手动同步；
- 新设备全量恢复；
- 本地 DB 可从 Cloud 重建。

### 2.2 Today / 今天

Today 必须成为真实聚合页，而不是单独维护一份 Today 数据。

实现：

- 当前用户真实问候信息；
- 系统真实日期 / 时区；
- 一周日期条；
- 今日焦点；
- 今日概览；
- 今日任务；
- 逾期未完成任务；
- 今日安排任务；
- 当前进行中任务；
- Calendar Event / occurrence；
- 重要日期；
- 项目摘要；
- 习惯 / 目标执行信息；
- 今日专注统计；
- 今日完成统计；
- 复盘入口与复盘摘要；
- 在 Today 直接完成/恢复任务；
- 点击进入 Task / Project / Calendar / Review 对应详情。

所有统计必须由 Repository 数据实时计算。

### 2.3 Tasks / 任务

完整范围：

- 新建 / 查看 / 编辑 / 删除；
- TODO / 进行中 / 等待 / 已完成；
- 优先级；
- 描述 / 备注；
- 项目归属；
- scheduledAt；
- dueAt；
- Reminder；
- recurrence rule；
- task occurrence；
- waiting item；
- completion result；
- task dependency；
- 子任务能力；
- 搜索；
- 状态筛选；
- 项目筛选；
- 时间/优先级筛选；
- 离线 CRUD；
- Cloud Sync；
- 冲突处理；
- 删除 tombstone；
- 番茄钟关联任务。

Cloud 相关实体优先复用：

```text
execution.task
execution.recurrence_rule
execution.task_occurrence
execution.waiting_item
execution.reminder
execution.completion_result
execution.task_dependency
execution.entity_link
```

子任务关系必须使用明确的领域关系/契约实现，不能只在 UI 中缩进展示假数据。

### 2.4 Projects / 项目

完整范围：

- 新建 / 查看 / 编辑 / 删除；
- 进行中 / 暂停 / 完成 / 归档；
- 标题；
- 描述；
- 开始时间；
- 截止时间；
- 项目任务列表；
- Task 项目归属编辑；
- 项目进度；
- 任务完成数 / 总数；
- 项目归档；
- 项目删除后的 Task 关系处理；
- 离线；
- Cloud Sync；
- 冲突；
- tombstone。

进度能从任务推导时，不维护第二份容易冲突的进度真值。

项目成员/协作信息只有在存在真实 Cloud contract 与数据源时显示；禁止使用 Mock 成员头像制造“已支持协作”的假象。

### 2.5 Calendar / 日历

完整范围：

- `YearMonth` 驱动真实月视图；
- 正确月份天数；
- 正确星期偏移；
- 上月 / 下月；
- 回到今天；
- 选择日期；
- 有内容日期 marker；
- Calendar Event CRUD；
- all-day / timed event；
- Calendar occurrence；
- Task scheduled / due 映射；
- Reminder；
- Important Date marker；
- 选中日的统一时间线；
- 离线；
- Cloud Sync；
- 冲突与删除。

### 2.6 Important Dates / 重要日期

必须全部支持：

- 生日；
- 纪念日；
- 里程碑；
- 其他；
- 单次公历；
- 每年公历；
- 单次农历；
- 每年农历；
- 农历年份；
- 农历月 / 日；
- 闰月；
- 启用 / 停用；
- Reminder；
- 新增 / 编辑 / 删除；
- 当年公历派生日期；
- 日历 marker；
- 近期重要日期；
- 多端同步。

农历原始字段是 Source of Truth。必须使用经过验证的农历转换实现，并建立 golden vectors。

Cloud entity：`execution.important_date`。

### 2.7 Collection / 收集

UI 中已有的六类快速收集全部实现：

- 文本；
- 图片；
- 语音；
- 链接；
- 文件；
- 想法。

同时完成：

- Inbox；
- 类型筛选；
- Memo CRUD；
- 标签；
- 标签关系；
- 归档；
- 删除；
- 转任务；
- 文件/图片/语音上传状态；
- 上传失败重试；
- 离线创建文本类内容；
- 网络恢复后同步/上传；
- 多端同步。

结构优先复用：

```text
execution.memo
execution.memo_tag
execution.memo_tag_relation
execution.entity_link
file.metadata
/api/v1/files
```

图片、语音、大文件内容本身不得塞进 Sync JSON；Sync 只保存业务元数据与文件引用。

### 2.8 Review / 复盘

完整范围：

#### Daily Review

- 今日评分；
- 心情；
- 今日收获；
- 改进项；
- 明日第一优先级 / 明日计划；
- 当日真实任务统计；
- 保存；
- 再次打开读取；
- 编辑；
- 历史列表；
- 历史详情；
- 离线；
- Cloud Sync；
- 冲突处理。

优先复用 LifeTrace 已有 `review.daily`。

#### Weekly Review

既然 Cloud 已注册 `execution.weekly_review`，1.0 同步实现：

- 周期选择；
- 本周完成摘要；
- 本周收获；
- 问题/改进；
- 下周重点；
- 保存 / 编辑 / 历史；
- Cloud Sync。

### 2.9 Goals / Habits 与执行聚合

长期执行计划已经要求 Today 展示 habit / goal 信息。正式实现时：

1. 先确认 LifeTrace 主仓库现有 Goal / Habit contract 与数据归属；
2. 能复用现有 LifeTrace 领域实体时直接复用；
3. 禁止为了 Execute 再创建一套重复 Habit/Goal 后端；
4. Today 展示真实今日习惯完成情况与目标/焦点摘要；
5. 对用户可操作的完成动作必须真实持久化并同步；
6. 如果当前 Cloud 缺少所需 contract，先在 LifeTrace contracts 补齐并完成 contract test，再接 Android。

Cloud 已存在 `execution.goal` 时优先复用其明确契约；Habit 则以主仓库真实 contract 为准。

### 2.10 Pomodoro / Focus

完整范围：

- 25/5；
- 50/10；
- 用户默认时长偏好；
- 开始；
- 暂停；
- 继续；
- 重置；
- focus / break phase；
- 当前轮次；
- 今日完成番茄数；
- 关联 Task；
- 页面切换不丢状态；
- App 后台；
- 锁屏；
- 系统回收后恢复；
- 时间校准；
- 完成通知；
- 中断状态；
- FocusSession 历史；
- 今日专注统计；
- 多端同步。

计时 Source of Truth 必须基于 `startedAt / expectedEnd / pausedAt / remainingWhenPaused` 等持久化状态恢复，而不是依赖每秒 coroutine 持续存活。

Cloud entity：`execution.focus_session`。

### 2.11 Reminder / Notification

Reminder 不只是一个字段，必须形成 Android 系统行为：

- Android 13+ 通知权限；
- Notification Channel；
- Task reminder；
- Calendar reminder；
- Important Date reminder；
- Pomodoro completion notification；
- schedule；
- cancel；
- reschedule；
- 重启后恢复；
- 时区/时间变化后重算；
- 通知点击进入正确业务页面；
- 用户通知偏好。

首要目标是可靠性；只有确实需要严格 exact alarm 的场景才引入额外权限和合规处理。

### 2.12 Profile / My / Settings

“我的”必须成为真实设置与数据中心：

- 真实 displayName；
- 真实 email；
- Cloud 登录状态；
- 当前设备；
- Device 列表；
- 设备撤销；
- 最后同步时间；
- pending outbox 数；
- blocked 数；
- conflict 数；
- 手动同步；
- 全量重新同步；
- 冲突列表；
- 冲突详情与解决；
- 通知设置；
- 外观设置；
- 通用设置；
- 用户偏好；
- 数据管理；
- 隐私导出；
- 账号删除；
- 退出当前设备；
- 关于；
- App version / build 信息。

任何暂时没有后端能力的操作不得伪装成功。需要 Cloud 支持时必须真实调用 Cloud 并展示实际结果。

---

## 3. 数据与同步目标架构

### 3.1 Room 业务数据

最终至少覆盖：

```text
tasks
projects
recurrence_rules
task_occurrences
waiting_items
task_dependencies
calendar_events
calendar_occurrences
important_dates
memos
memo_tags
memo_tag_relations
reminders
completion_results
daily_reviews
weekly_reviews
focus_sessions
preferences_cache

# 根据 LifeTrace 真实 Goal/Habit contract 增加对应本地表/映射
```

同步基础表继续共享：

```text
sync_outbox
sync_state
sync_conflicts
```

### 3.2 Generic Sync Core

在第二个正式同步实体大规模接入前，将当前 Task 专用同步逻辑抽取为：

```text
data/sync/
├── SyncEngine.kt
├── SyncEntityHandler.kt
├── SyncRegistry.kt
├── SyncScheduler.kt
├── SyncWorker.kt
├── ConflictRepository.kt
└── handlers/
    ├── TaskSyncHandler.kt
    ├── ProjectSyncHandler.kt
    ├── CalendarEventSyncHandler.kt
    ├── ImportantDateSyncHandler.kt
    ├── MemoSyncHandler.kt
    ├── ReminderSyncHandler.kt
    ├── ReviewSyncHandler.kt
    ├── FocusSessionSyncHandler.kt
    └── ...
```

Sync Engine 统一负责：

- session；
- capabilities；
- push batch；
- pull；
- snapshot；
- cursor；
- retry；
- conflict store；
- blocked / rejected；
- tombstone；
- WorkManager；
- single-flight。

Entity Handler 只负责：

- `entityType`；
- payload mapper；
- snapshot apply；
- pull upsert/delete；
- accepted serverVersion；
- rebase payload。

### 3.3 Cloud Contract 前置 Gate

正式接入某个 entity 前必须确认：

- registry 已注册；
- capabilities 能发现；
- typed DTO / schema 明确；
- schemaVersion 策略明确；
- required field 可验证；
- Android mapper 有 contract test。

`execution.important_date`、`execution.focus_session` 以及当前仍为 RegisteredJson 的 execution entity 必须在 LifeTrace 主仓库完成契约加固，不能依赖“任意 JSON 能存进去”作为正式实现。

---

## 4. 全功能开发 Phase

后续 Agent/Codex 必须按顺序推进。一个 Phase Gate 未通过时，不得为了“看起来进度快”跳去铺后面的 UI 外壳。

## Phase F0：Task 现有闭环 + 真实测试基线

### 实现

- 将 `TaskConflictResolutionSheet` 真正接入 `TasksScreen`；
- 连接 `keepServer()` / `keepLocal()`；
- 冲突处理后解除 blocked；
- keepLocal 自动重新排队同步；
- 建立 `flutter_app/test`；
- Task Mapper 测试；
- Repository CRUD + Outbox 事务测试；
- localVersion / serverVersion 测试；
- accepted rebase；
- conflict keepServer / keepLocal；
- date/time helper 测试。

### Gate

- Task CRUD 真机可用；
- 离线 CRUD 可用；
- 冲突 UI 可解决；
- 真实业务单测存在；
- `assembleDebug` PASS；
- `testDebugUnitTest` PASS；
- `lintDebug` PASS。

---

## Phase F1：Generic Sync Core + Execution Contracts

### 实现

- 从 `TaskSyncCoordinator` 抽取 Generic Sync Engine；
- Task 切换到 `TaskSyncHandler` 后行为不回退；
- 建立 Sync Registry；
- 统一多 entity scheduler；
- 明确 entity-scope cursor；
- 完成 execution typed contract / schema 补强；
- Android contract mapper tests；
- capabilities/schema 不兼容时 fail-safe。

### Gate

- Task 全部现有 Sync 测试仍通过；
- 新 handler 接入不复制 coordinator；
- snapshot / push / pull / conflict / rejected / tombstone 全部有测试；
- Contract tests 在 LifeTrace 主仓库通过。

---

## Phase F2：Project 完整纵向链

### 实现

- Domain / Entity / DAO / Migration；
- Repository；
- ViewModel；
- Project CRUD；
- 状态流转；
- 项目详情；
- 项目 Task 列表；
- Task Project Selector；
- 真实进度计算；
- Archive；
- Delete relation policy；
- Outbox；
- Project Sync Handler；
- conflict / tombstone。

### Gate

设备 A 创建项目并给 Task 归属项目，设备 B 同步后项目、Task 归属和进度均正确；离线编辑后恢复同步正确。

---

## Phase F3：Task 全部高级能力

### 实现

- Reminder；
- recurrence rule；
- occurrence generation；
- waiting item；
- completion result；
- dependency；
- subtask；
- 完整筛选；
- Task Detail；
- 每个辅助实体的 Room / Repository / Sync Handler；
- 重复任务编辑策略（本次/以后/整个系列如产品契约需要）；
- occurrence 幂等生成；
- waiting workflow；
- 删除/修改关联关系规则。

### Gate

- 重复任务跨重启不重复生成；
- 跨设备 occurrence 一致；
- waiting / reminder / dependency / completion 均持久化和同步；
- Task Detail 不包含空操作。

---

## Phase F4：Calendar + Important Date + Reminder

### 实现

- 真实 `YearMonth` 月历；
- Calendar Event / occurrence 完整纵向链；
- Task 时间映射；
- Important Date 完整纵向链；
- 公历 / 农历 / yearly / once / leap month；
- Reminder Repository；
- Android Notification；
- reboot/timezone reschedule；
- Calendar / ImportantDate / Reminder Sync Handler；
- 农历 golden vectors。

### Gate

- 月历日期数学正确；
- 普通 Event CRUD + sync；
- 单次/每年公历正确；
- 单次/每年农历正确；
- 闰月测试通过；
- Notification 真机触发；
- 重启后提醒仍存在。

---

## Phase F5：Collection 全类型 + Tags + Files

### 实现

全部六种入口：

```text
文本 / 图片 / 语音 / 链接 / 文件 / 想法
```

并完成：

- Memo Domain / Room / Repository；
- Tags / Relations；
- Inbox；
- 类型筛选；
- Archive；
- Delete；
- Convert to Task；
- file picker；
- image picker；
- audio/voice capture 或明确的 Android 音频采集流程；
- upload state；
- retry；
- Cloud file API；
- Memo / Tags / EntityLink Sync。

### Gate

- 六种入口都产生真实可读取数据；
- 文本类断网可创建；
- 文件恢复联网可继续上传；
- 转任务后关系真实存在；
- 第二设备能看到业务元数据和有效文件引用。

---

## Phase F6：Daily Review + Weekly Review

### 实现

- Daily Review 持久化；
- 真实 task/focus 完成统计；
- rating / mood 可选择；
- 保存 / 编辑；
- 历史列表 / 详情；
- Weekly Review；
- Review Repository；
- Sync；
- conflict。

### Gate

复盘保存后重启不丢；第二设备可读；同日期并发编辑不 silent overwrite；Today 摘要与 Review 数据一致。

---

## Phase F7：Goal / Habit 正式接入

### 实现

- 盘点 LifeTrace 主仓库现有 Goal/Habit contract；
- 复用现有真实数据模型；
- 缺 contract 时先补主仓库 contract，而不是 Execute 自建第二套；
- Android 本地映射 / Repository；
- 今日习惯完成动作；
- Goal/Focus 摘要；
- Offline / Sync；
- Today 数据接口准备。

### Gate

Today 后续使用的 Goal/Habit 数据全部来自真实 Repository；不存在 Mock habit/goal；跨端最终一致。

---

## Phase F8：Pomodoro / FocusSession

### 实现

持久化 Timer State：

```text
mode
focusSeconds
breakSeconds
phase
startedAt
expectedEndAt
pausedAt
remainingSecondsWhenPaused
linkedTaskId
round
```

完成：

- 25/5；
- 50/10；
- 用户偏好；
- start / pause / resume / reset；
- task link；
- page switch；
- background；
- lock screen；
- process death recovery；
- notification；
- focus/break transition；
- FocusSession 历史；
- Today focus stats；
- Sync Handler。

### Gate

- 前台计时误差满足长期计划标准；
- 后台/锁屏恢复正确；
- 强杀重启后状态可恢复或明确标记中断；
- 一轮只产生一个 FocusSession；
- sync retry 不重复 session。

---

## Phase F9：Today 最终真实聚合

Today 放在主要数据源完成之后收口，避免再次做成 Mock 聚合页。

### 实现

统一聚合：

- Task / occurrence；
- overdue；
- Calendar；
- Important Date；
- Project；
- Goal/Habit；
- FocusSession；
- Daily Review；
- 真实用户与日期。

完成 Today 所有点击行为、empty/loading/offline/syncing/error 状态。

### Gate

- 删除所有 Today 生产路径 `MockData`；
- 所有统计都可由底层实体重算；
- 其他端同步变化可以自动反映到 Today；
- 日期/时区变化后当天数据正确刷新。

---

## Phase F10：Profile / Devices / Settings / Data

### 实现

- 真实用户资料；
- Cloud connection；
- device list；
- revoke device；
- sync health；
- pending / blocked / conflict；
- conflict center；
- manual sync；
- rebuild/snapshot；
- notification preferences；
- appearance；
- general settings；
- data management；
- privacy export；
- account deletion；
- logout；
- About / version/build。

### Gate

Profile 中不存在“看起来可以点但没有结果”的正式入口；数据管理类操作与 Cloud 真实结果一致。

---

## Phase F11：全实体 Sync / Offline / E2E / Release

### Sync E2E

至少覆盖：

- A create → B pull；
- B update → A pull；
- duplicate changeId；
- conflict；
- keepLocal / keepServer；
- tombstone；
- 离线旧设备修改已删除实体；
- snapshot rebuild；
- cursor expired / snapshot required；
- 100+ changes；
- 多 entity 同时 pending；
- token refresh；
- device revoke；
- file metadata + object storage；
- App restart 后 outbox/cursor/conflict 保留。

### Release 工程

- Gradle Wrapper；
- Debug / Release；
- dev / staging / prod；
- release signing secret 注入；
- R8/ProGuard；
- Room Migration Tests；
- Unit Tests；
- UI Tests；
- Instrumentation Tests；
- Staging E2E；
- Crash / ANR 回归；
- 性能基线；
- 安全日志检查；
- APK/AAB 可重复构建。

---

## 5. 自动化测试最低覆盖

### 5.1 Unit

- Task state；
- Mapper；
- recurrence；
- occurrence；
- project progress；
- date/time；
- YearMonth；
- lunar wrapper；
- important date；
- reminder calculation；
- Pomodoro recovery；
- Today aggregation；
- retry classification；
- conflict/rebase。

### 5.2 Room / Repository

每个正式业务实体至少验证：

- create；
- update；
- delete；
- transaction；
- outbox；
- migration；
- restart persistence；
- pull apply；
- tombstone；
- conflict state。

### 5.3 UI Smoke

至少覆盖：

1. 登录；
2. 新建/编辑/完成 Task；
3. Task conflict；
4. Project + Task relation；
5. recurrence task；
6. waiting/reminder；
7. Calendar Event；
8. 公历 Important Date；
9. 农历 Important Date；
10. 文本收集；
11. 图片收集；
12. 语音收集；
13. 文件收集；
14. 收集转 Task；
15. Daily Review；
16. Weekly Review；
17. Goal/Habit 今日动作；
18. Pomodoro start/pause/recovery；
19. Today 聚合；
20. Device / Sync / Conflict Center；
21. Logout。

---

## 6. 全功能 Release Gate

以下条件 **全部满足** 才允许把 LifeTrace Execute 标记为 1.0 完成。

### Product

- [ ] 五个一级导航全部是真实功能；
- [ ] Today 完整真实聚合；
- [ ] Task 全能力完成；
- [ ] Project 全能力完成；
- [ ] Calendar 全能力完成；
- [ ] Important Date 全能力完成；
- [ ] Collection 六种入口全部完成；
- [ ] Daily Review 完成；
- [ ] Weekly Review 完成；
- [ ] Goal/Habit 接入完成；
- [ ] Pomodoro 完成；
- [ ] Reminder / Notification 完成；
- [ ] Profile / Device / Settings / Data 完成。

### No Shell

- [ ] 生产路径无 `MockData`；
- [ ] 无核心空 `onClick = {}`；
- [ ] 无静态假用户/假统计；
- [ ] 需要持久化的数据不使用 Widget/Provider 临时状态代替；
- [ ] 未实现功能不得伪装成可用。

### Local-first

- [ ] 核心业务无网络可读写；
- [ ] App 重启数据不丢；
- [ ] 网络失败不回滚已经成功的本地业务操作；
- [ ] 所有同步写入 Entity + Outbox 同事务；
- [ ] 所有 Room Schema 变更有 Migration + Migration Test。

### Cloud / Sync

- [ ] Generic Sync Core；
- [ ] 全部需要同步的 1.0 实体接入；
- [ ] snapshot / push / pull；
- [ ] duplicate；
- [ ] conflict；
- [ ] rejected；
- [ ] tombstone；
- [ ] offline retry；
- [ ] multi-device；
- [ ] new-device restore；
- [ ] user isolation；
- [ ] file metadata / object storage；
- [ ] typed contract/schema。

### Android Platform

- [ ] Android 13+ Notification Permission；
- [ ] Notification Channels；
- [ ] Reminder schedule/reschedule；
- [ ] reboot/timezone recovery；
- [ ] Pomodoro background/process recovery；
- [ ] Insets / keyboard / compact viewport 正确；
- [ ] 主要触控区域满足移动端可用性要求。

### Quality

- [ ] `:app:assembleDebug` PASS；
- [ ] `:app:testDebugUnitTest` PASS 且包含真实业务测试；
- [ ] `:app:lintDebug` PASS；
- [ ] Release build PASS；
- [ ] UI/Instrumentation 核心回归 PASS；
- [ ] Staging Sync E2E PASS；
- [ ] 双设备 E2E PASS；
- [ ] 农历 golden vectors PASS；
- [ ] Pomodoro recovery tests PASS；
- [ ] 文件上传/重试 PASS；
- [ ] 无核心 Crash / ANR；
- [ ] 安全日志不泄漏 password/token/entity 正文。

### Documentation

- [ ] `REQUIREMENTS.md` 状态与实际一致；
- [ ] `PROJECT_STATUS.md` 与实际一致；
- [ ] `IMPLEMENTATION_LOG.md` 有提交与验证证据；
- [ ] `UI_SPEC.md` 与最终 Android 行为无关键冲突；
- [ ] `EXECUTION_PLAN.md` 中长期架构要求已落实或明确记录差异。

---

## 7. 后续开发批次

推荐一个 Batch 对应一个 Phase 或一个 Phase 内可独立验收的纵向切片：

```text
Batch 01  F0 Task Closure + Tests
Batch 02  F1 Generic Sync + Contracts
Batch 03  F2 Project
Batch 04  F3 Task Advanced
Batch 05  F4 Calendar + ImportantDate + Reminder
Batch 06  F5 Collection + Files + Voice + Tags
Batch 07  F6 Daily/Weekly Review
Batch 08  F7 Goal/Habit
Batch 09  F8 Pomodoro / FocusSession
Batch 10  F9 Today Aggregation
Batch 11  F10 Profile / Device / Settings / Data
Batch 12  F11 Full E2E / Release Hardening
```

每个 Batch 完成后必须：

1. 跑对应单元/数据库/UI 测试；
2. 跑 `assembleDebug`；
3. 跑 `testDebugUnitTest`；
4. 跑 `lintDebug`；
5. 执行该 Phase 特定 Smoke/E2E；
6. 更新 `PROJECT_STATUS.md`；
7. 更新 `IMPLEMENTATION_LOG.md`；
8. 只有 Gate 全部满足后才进入下一 Phase。

---

## 8. 给后续 Agent / Codex 的执行约束

开始开发前必须阅读：

```text
docs/README.md
docs/development/README.md
docs/development/REQUIREMENTS.md
docs/development/FOUNDATION_EXECUTION_PLAN.md
docs/development/PROJECT_STATUS.md
docs/development/IMPLEMENTATION_LOG.md
```

涉及 UI 再读 `UI_SPEC.md`；涉及 Cloud/架构再读 `EXECUTION_PLAN.md`。

执行时：

1. 先检查当前 Phase 已完成到哪里；
2. 不重复已经正确实现的基础设施；
3. 以纵向业务闭环为单位修改代码；
4. 不提前铺后续 Mock UI；
5. 不因为上下文不足删减已确认功能；
6. Cloud contract 缺失时先补 contract，不在 Android 猜 wire format；
7. 数据库变更同步写 Migration/Test；
8. 同步实体必须接 Generic Sync；
9. 完成后提供真实测试/CI/E2E 证据；
10. 未通过 Gate 的功能在文档中保持 `开发中`，禁止提前标记 `已完成`。

---

## 9. 当前立即开始的任务

当前仍从 F0 开始，不因为目标扩大为“全部功能”而跳过基础质量：

1. 接通 Task Conflict UI；
2. 建立真实 `flutter_app/test`；
3. 补 Task Mapper / Repository / Conflict / Rebase 测试；
4. 确认 Task offline/conflict smoke；
5. 抽取 Generic Sync Core；
6. 加固 execution Cloud contracts；
7. Project 完整纵向实现；
8. 按 F3 → F11 连续推进，直到 **全功能 Release Gate 全部通过**。

> 最终目标不是“做完一个 Foundation”，而是：**LifeTrace Execute 当前规划内的所有功能全部真实实现、全部可持久化、全部可离线运行、需要同步的全部可跨设备同步，并具备自动化测试与发布证据。**
