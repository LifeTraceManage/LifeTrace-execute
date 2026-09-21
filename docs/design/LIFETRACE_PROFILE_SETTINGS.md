# LifeTrace Profile / Settings Design Standard

更新时间：2026-09-21

## 1. 目标

LifeTrace 系列 Android 客户端的“我的”不是单纯个人资料页，而是统一的 **账户、设备、数据、同步与应用设置中心**。

所有 LifeTrace App 应尽量保持同一信息架构和交互习惯，具体业务 App 只增加自己的专属设置项。

## 2. 视觉基线

Profile / Settings 统一的是**信息架构、交互语义和组件层级**，不强制所有 LifeTrace App 使用一套孤立色板。每个 App 的“我的”必须优先复用该 App 的正式 Theme / Design Token，避免 Profile 看起来像从另一个产品拼接进来。

Execute 当前遵循 `UI_SPEC.md` 的视觉基线：

- 主背景使用 `C.bg` / Surface 使用 `C.surface`；
- 主强调色使用 Primary Blue，辅助使用 Purple / Teal / Orange / Green 等已有语义色；
- 顶部 Hero 可使用与 Today 相同的浅蓝紫渐变体系；
- 账号、Cloud、设备状态使用小型 Status Pill，不制造第二套品牌组件；
- Section 通过留白、圆角容器和图标色区分层级，不使用连续全宽分割线；
- 少投影、少大卡片，不把每一个设置项独立做成 Card；
- 主要文本、圆角、间距、边框全部复用当前 App 的正式 token。

LifeTrace Yellow 可以作为其他产品的品牌强调色，但不应覆盖具体 App 已建立的视觉主题。

## 3. 固定信息架构

### 3.1 顶部账户 Hero

必须优先展示真实状态：

- 用户显示名；
- LifeTrace Account / 本地模式；
- Cloud 是否连接；
- 本地数据状态；
- 当前设备名称。

未登录时不得伪造用户资料，应明确显示“本地模式”。

### 3.2 数据与同步

推荐顺序：

1. 云端同步；
2. 本地数据；
3. 设备管理；
4. 数据导出与隐私。

所有状态必须来自真实 Repository / Local DB / Cloud 数据，禁止使用演示数字冒充真实数据。

### 3.3 应用

所有 LifeTrace App 都应保留：

- 通知与提醒；
- 外观；
- 应用设置。

业务 App 可以在本 Section 增加自己的局部设置，例如 Finance 的默认账户、Assets 的估值设置等。

### 3.4 LifeTrace

跨应用统一保留：

- 个人资料；
- 账户与安全；
- LifeTrace Cloud。

未来只有在真实能力已经接入后，才可加入：

- LifeTrace Agent；
- 已连接的 LifeTrace 服务；
- 其他 LifeTrace App。

不可先放“待接入”按钮制造假功能。

### 3.5 其他

至少包含：

- 关于 LifeTrace / 当前应用；
- 版本号；
- 开源许可。

帮助与反馈只有在存在真实反馈渠道时才展示。

## 4. 交互规则

- 点击顶部 Hero 进入个人资料；
- 有真实二级页面的设置项显示 chevron；
- 纯状态行不显示 chevron；
- 未登录 Cloud 时，本地功能仍可正常使用；
- Cloud 功能不可用时，应明确说明原因并提供“连接 Cloud”入口；
- destructive action（退出全部设备、删除账号等）必须进入二级页面并二次确认，不放在 Profile 首页。

## 5. Execute 当前映射

`LifeTrace-execute/flutter_app` 当前采用：

| Section | 入口 | 真实能力 |
| --- | --- | --- |
| 数据与同步 | 云端同步 | `CloudConnection` |
| 数据与同步 | 本地数据 | Drift / SQLite Local-first 状态说明 |
| 数据与同步 | 设备管理 | `DeviceManagement` |
| 数据与同步 | 数据导出与隐私 | `DataManagement` |
| 应用 | 通知与提醒 | `NotificationSettings` |
| 应用 | 外观 | `AppearanceSettings` |
| 应用 | 应用设置 | `GeneralSettings` |
| LifeTrace | 个人资料 | `ProfileDetails` |
| LifeTrace | 账户与安全 | `AccountSecurity` |
| LifeTrace | LifeTrace Cloud | `CloudConnection` |
| 其他 | 关于 LifeTrace | `AboutLifeTrace` |

## 6. 系列应用复用要求

后续 LifeTrace Assets、Finance 等客户端实现“我的”时：

1. 保持固定 Section 名称和相对顺序；
2. 复用各自 App 的正式 Theme / Design Token，不为“我的”单独建立第二套主题；
3. 不复制假数据；
4. 优先抽取共享 Widget / package，而不是各仓库复制后长期分叉；
5. 各应用专属设置放在“应用”Section，不改变账户、Cloud、设备、隐私等公共入口的含义。

## 7. 验收

“我的”页面完成需同时满足：

- 本地模式可正常渲染；
- Cloud 登录态可正常渲染；
- 设备/同步状态异常不会阻塞页面；
- 所有入口可到达真实功能页面；
- Android 与 Flutter Web Preview 使用同一 Flutter 页面实现；
- Widget test 覆盖固定 Section 和核心入口。
