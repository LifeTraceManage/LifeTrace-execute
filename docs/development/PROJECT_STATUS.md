# LifeTrace Execute 项目进度

更新时间：2026-09-20

## 1. 当前阶段

LifeTrace Execute 的正式生产客户端已经切换到 Flutter。自 2026-09-18 起，正式生产分支统一回归：

```text
main
```

`refactor/flutter-production` 完成历史迁移使命，不再作为日常开发入口；后续功能从 `main` 建 feature 分支，通过 Flutter Production CI 后合回 `main`。

Flutter 客户端 cutover 已完成：旧 Compose `app/`、根级 Android Gradle 工程和 legacy Compose CI 已于 2026-09-20 从 `main` 删除。迁移前实现只通过 Git 历史保留。

当前不是“UI 壳迁移阶段”。Flutter 已经建立真实 Local-first、Cloud Sync、后台同步、文件上传、Reminder/Notification、Important Date、Daily Review 与 Pomodoro/FocusSession 等纵向业务链。

## 2. 已验证的生产基础设施

Flutter 生产链已经具备：

- Drift / SQLite；
- Repository / Riverpod；
- business row + Outbox 同事务；
- Auth v1；
- secure session；
- stable deviceId；
- Sync v1 snapshot / push / pull；
- accepted / duplicate / rejected / conflict；
- keepLocal / keepServer；
- tombstone / rebase；
- WorkManager 后台同步；
- Android 13+ notification permission；
- Android local notification；
- reboot notification recovery；
- Cloud files API / upload queue；
- Android Debug APK 与 Web Release 构建 Gate。

统一 Sync scope 当前包含：

```text
execution.task
execution.project
execution.calendar_event
execution.important_date
execution.focus_session
execution.memo
execution.reminder
review.daily
file.metadata
entity.link
```

## 3. 已形成真实纵向闭环的模块

### Task 基础纵向链

已完成：

- Drift Task；
- CRUD；
- status / priority / description；
- scheduledAt / dueAt；
- Project 归属；
- Local-first Outbox；
- Sync v1；
- conflict / keepLocal / keepServer；
- Reminder 接入；
- Task Detail 真实数据链。

仍未把 Task 1.0 全部高级能力标记完成，重复规则 / occurrence / waiting / dependency 等仍按长期计划继续推进。

### Project

已完成真实 Project CRUD、Task 归属、Drift、Outbox、Sync、conflict 与真实页面。

### Calendar Event

已完成：

- 真实月份日期数学；
- Event CRUD；
- Task 时间映射；
- Drift / Outbox / Sync / conflict；
- Reminder；
- Calendar agenda 与月历 marker。

### Important Date

已完成：

- Cloud typed `execution.important_date` contract；
- 公历 / 农历；
- once / yearly；
- lunarYear；
- 闰月；
- lunar golden vectors；
- Drift v9；
- Local-first CRUD；
- Sync / conflict；
- Calendar marker / agenda；
- Today 近期重要日期；
- Reminder；
- yearly Reminder fired 后自动续下一次真实发生日期。

Cloud contract 已合并至 LifeTrace Cloud main。

最终 Flutter Gate：

```text
run 34680178657
Drift code generation       PASS
flutter analyze             PASS
flutter test                PASS
Android debug APK           PASS
Web release preview         PASS
```

### Reminder / Android Notification

已完成：

- typed `execution.reminder`；
- Task Reminder；
- Calendar Reminder；
- Important Date Reminder；
- scheduled / fired / dismissed / cancelled；
- Android 13+ permission；
- notification channel；
- reboot receiver；
- foreground/background reconcile；
- notification tap 路由；
- duplicate active Reminder 收敛；
- Sync / conflict。

### Collection / Memo / File

已完成：

- Memo Local-first；
- text / idea / link / image / audio / file Domain 类型；
- Inbox / archive / important / delete；
- Memo → Task；
- Memo → Project；
- EntityLink；
- file.metadata；
- media upload queue；
- Cloud files prepare/upload/complete；
- retry；
- synced attachment metadata；
- Memo 删除不误删共享 FileMetadata。

仍需按 1.0 Gate 继续核对六种入口的真实 UI 采集行为，尤其语音采集流程。

### Daily Review

已完成当前 Daily Review 纵向链：

- `review.daily` typed contract；
- Drift；
- mood / energy；
- task completion snapshot；
- bestThing / problem / tomorrowPriority / note；
- save / reopen / edit；
- Sync / conflict。

验证 run：

```text
34583113910
Drift / Analyze / Tests / Android / Web   PASS
```

仍未完成：

- Daily Review 历史列表 / 详情；
- Weekly Review。

### Background Sync

已完成：

- app startup / foreground；
- login initial sync；
- local-write delayed sync；
- 6h periodic fallback；
- connected constraint；
- retry classification；
- media upload integration；
- Reminder reconcile；
- Focus recovery integration。

### Pomodoro / FocusSession

2026-09-15 已完成 F8 当前纵向链：

- 本地持久化 `FocusTimerState`；
- synced `execution.focus_session` 历史；
- 25/5；
- 50/10；
- mode preference 持久化；
- task link；
- start / pause / resume / reset / skip；
- 以 `expectedEndAt` 作为时间真值，不依赖每秒递减保存状态；
- page switch 不丢状态；
- app restart / process death recovery；
- Focus → Break → Idle 恢复；
- foreground 与 WorkManager recovery；
- Focus/Break Android notification；
- notification tap 回到 Focus；
- 一轮稳定 sessionId，recovery 不重复生成 Session；
- Session + Outbox + 下一阶段 TimerState 同事务；
- FocusSession Snapshot / Push / Pull；
- conflict / keepLocal / keepServer；
- Focus 历史；
- Today 真实 Focus 状态、今日专注时长、完成轮次；
- task detail 启动 Focus 时自动关联任务。

专项测试覆盖：

- pause wall-clock exclusion；
- resume expectedEndAt 重建；
- process death 跨 Focus 边界；
- process death 跨 Focus + Break；
- duplicate recovery；
- incomplete reset；
- 50/10 persistence；
- session/outbox/state transaction；
- stable session id idempotency；
- Cloud mapper；
- Sync pipeline；
- conflict resolution。

最终 Flutter Gate：

```text
run 34924805960
commit 170a9f83d7a39e18410bdfd7a597f42e7aea2c5b + Today Focus follow-up
Drift code generation       PASS
flutter analyze             PASS
flutter test                PASS
Android debug APK           PASS
Web release preview         PASS
workflow                    SUCCESS
```

> 注：run 的最终 head 包含 Focus Sync/Conflict tests 与 Today 真实 Focus 卡片；以该 run 记录为当前 F8 Gate 证据。

## 4. 当前仍未完成的 1.0 主要范围

不能因为上述模块已通过 CI 就把整个产品标记为 1.0 完成。剩余重点包括：

- Task recurrence / occurrence / dependency / waiting 完整闭环；
- Collection 六种采集入口最终核验与语音采集；
- Daily Review 历史；
- Weekly Review；
- Goal / Habit 正式接入；
- Today 全量真实聚合，删除剩余静态假数据；
- Profile / Devices / Settings / Data；
- full multi-device / offline / staging E2E；
- release signing / release build / R8 / performance / security hardening；

## 5. 当前技术架构

```text
Flutter UI
    ↓
Riverpod / Commands / Domain Rules
    ↓
Repository
    ↓
Drift / SQLite
    ├── business entities
    ├── local-only timer/upload state
    ├── sync_outbox
    ├── sync_state
    └── sync_conflicts
    ↓
Generic Sync v1
    ↓
LifeTrace Cloud
```

重要架构边界：

- `FocusTimerState` 是设备本地运行状态，不跨设备同步；
- `execution.focus_session` 是结束后的历史事实，跨设备同步；
- binary 文件不进入 Sync JSON；
- `file.metadata` / `entity.link` 进入 Sync；
- Android notification 是本地投递结果，业务源数据仍是 Drift + Cloud entity。

## 6. 下一批

当前建议继续按未完成真实能力推进：

1. Daily Review 历史 + Weekly Review；
2. Goal / Habit contract 与真实 Repository；
3. Today F9 全量真实聚合，删除剩余 Mock/静态统计；
4. Task advanced（recurrence / occurrence / dependency / waiting）补齐；
5. Profile / Device / Settings / Data；
6. F11 多设备 E2E 与 Release hardening。

## 7. 当前判定

当前准确状态：

> **Flutter 已经从 UI 壳进入真实生产业务迁移中后段。Task 基础、Project、Calendar、Important Date、Reminder、Collection/Files、Daily Review 当前切片、Background Sync 与 Pomodoro/FocusSession 已形成真实纵向链并有 CI 证据；但 Weekly Review、Goal/Habit、Today 全量聚合、Task Advanced、Profile/Data 与最终 Release/E2E 尚未完成，因此 LifeTrace Execute 仍不能标记 1.0 完成。**
