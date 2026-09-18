# LifeTrace Execute UI / Interaction Specification

更新时间：2026-09-10

## 1. 目标

该文档定义 LifeTrace Execute 当前 UI 与交互基线。正式客户端现以 `flutter_app/` 为实现目标；`flutter-preview/` 与既有设计稿作为视觉参考来源。

原则：

1. Flutter 正式客户端应尽量还原已确认的高保真设计，而不是重新发明一套页面；
2. 技术栈重构不得删除已经确认的功能；
3. Android 生产构建使用真实系统状态栏/安全区，假的设备框和状态栏只允许出现在 Web Preview；
4. Flutter 页面存在不等于业务功能完成。

## 2. 设备与布局基准

主视觉基准：

```text
360 × 800 dp
```

桌面 Web Preview：

- 居中展示固定 360×800 手机画布；
- 手机框可以模拟状态栏、底部导航和设备边框；
- 页面内容区域独立滚动；
- 浏览器宽度不得改变手机内部布局宽度。

移动浏览器与 Android：

- 使用真实设备可用尺寸；
- 使用 `SafeArea` / `MediaQuery` 处理系统 inset；
- 不绘制假的状态栏或手势区。

## 3. 导航结构

底部一级导航固定为：

| 入口 | 作用 |
| --- | --- |
| 今天 | 日常执行总览与复盘入口 |
| 任务 | 任务搜索、筛选、创建和执行 |
| 项目 | 项目列表、状态和进度 |
| 日历 | 日期与日程组织 |
| 收集 | 快速捕获信息与 Inbox 整理 |

要求：

- Active destination 使用蓝色图标/文字；
- Inactive destination 使用中性灰；
- 不新增第六个一级导航；
- “我的”从头像进入；
- “今日复盘”从 Today 进入独立页面；
- Focus/Pomodoro 属于任务执行工作流，不单独占一级导航。

## 4. 视觉 Token

```text
Primary Blue       #2468F2
Primary Blue Soft  #EDF4FF
Ink                #111827
Muted              #6B7280
Background         #FBFCFE
Surface            #FFFFFF
Surface Muted      #F5F7FB
Border             #E6EAF0
Orange             #FF9F2F
Green              #16A36A
Red                #F05252
Purple             #7C3AED
Teal               #0F9F83
```

视觉方向：明亮、克制、高信息密度、少投影、少大卡片。列表、时间线、层级排版优先于“每块内容都做成 Card”。

## 5. 圆角与层级

建议：

```text
Chip / 小控件      7–9
输入框              10–12
普通 Panel          10–12
主强调区域          14–18
Web 设备框          28+
```

正式 Android 不需要设备框圆角。

## 6. Typography

中文优先系统字体回退：

```text
Noto Sans SC
PingFang SC
Microsoft YaHei
System UI
```

建议：

- Screen title：20–22，800/900；
- Section title：12–15，700/900；
- Row title：10.5–13，700/900；
- Body：10–12.5；
- Meta：8.5–10.5。

360dp 宽度下必须保持真机可读性，不能为了“塞下设计稿”过度缩小文字。

## 7. 页面规范

### Today

目标顺序：

1. `9月9日 · 星期三` / 问候 / 头像；
2. 一周日期条；
3. TODAY FOCUS；
4. 今日统计：待完成 / 日程 / 习惯；
5. “现在”；
6. “接下来”；
7. 今日任务；
8. 复盘入口。

避免恢复成大面积统计卡片堆叠。

### Tasks

必须保留搜索、状态/时间筛选、优先级、截止时间、新建任务入口。Task Detail 至少包含标题、状态、项目、截止时间、安排时间、提醒、优先级、备注、子任务与开始专注。

创建/编辑在移动端优先 Bottom Sheet 或独立编辑页，具体取决于字段复杂度；核心操作不得为空回调。

### Focus

- 25:00 默认专注；
- 显示关联任务；
- 开始/暂停/继续/放弃/跳过；
- 今日专注时间、番茄次数、连续天数；
- 正式实现计时状态必须跨页面、后台与进程恢复保持一致。

### Projects / Project Detail

项目列表显示名称、状态、进度、任务完成数与截止时间。项目详情显示总体进度、总任务/已完成/待完成、下一步、里程碑、项目任务。

### Calendar

- 真实年月/月历；
- 当前/选中日期；
- 有内容日期 marker；
- 月/周/日程视图入口；
- 选中日下方统一时间线；
- Important Date 与 Reminder 后续接真实数据。

### Collection

快速收集固定保留：文字、图片、语音、链接、文件、想法。必须保留 Inbox 与整理能力。

### Review

Daily Review 至少包含心情/评分、任务完成统计、收获、改进、明日第一优先级与保存；后续接历史复盘。Weekly Review 保留在 1.0 范围。

### Profile / My

至少保留个人资料、Cloud 状态、账号与安全、设备、同步与数据、通知、外观、通用设置、关于。

## 8. Flutter 组件方向

逐步沉淀：

```text
AppShell
ScreenHeader
SectionHeader
TaskRow
ProjectRow
TimelineItem
StatusChip
SearchField
BottomSheet
SettingsRow
EmptyState
PhonePreviewFrame   # Web only
```

正式业务页面应从 Theme / design tokens 获取通用样式，不要在每个页面复制一套颜色和尺寸。

## 9. 设计到生产的当前流程

```text
已确认高保真设计
        ↓
flutter_app/ UI 基线
        ↓
抽取 Flutter Design System
        ↓
接 Domain / Repository / SQLite
        ↓
接 Local-first / Sync
        ↓
Widget / integration / E2E
        ↓
Android 真机验证
```

不再执行“设计 → Jetpack Compose”的旧流程。

## 10. 当前 UI 下一步

UI 层已经有主要页面基线，下一步不继续铺更多静态壳。优先：

1. 把现有单文件/part 原型拆为正式 Flutter feature/component 结构；
2. Task UI 接真实 Flutter state 与本地数据库；
3. 抽取统一 Theme、spacing、typography 和交互组件；
4. 用 golden/widget test 做关键页面视觉回归；
5. 真实业务迁移后再逐模块精修。
