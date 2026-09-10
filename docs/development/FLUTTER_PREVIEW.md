# Flutter 高保真前端原型

## 目的

`flutter-preview/` 是 LifeTrace Execute 的可运行高保真移动端设计基线，用于替代 M3E Canvas 在复杂自定义组件上的限制。

它不是当前正式数据层，也不改变 `app/` 中 Jetpack Compose + Room + Local-first + Sync v1 的生产架构。

## 当前页面

- Today
- Tasks
- Task Detail
- Focus
- Projects
- Project Detail
- Calendar
- Collection
- Daily Review
- Profile

## 交互语义

- Today 的日期和周日期条是信息展示，不响应点击，也不出现勾选态。
- Tasks / Projects 的筛选使用无勾选图标的 segmented control。
- Calendar 日期属于真实日期选择交互，可以点击。
- 子任务完成使用 Checkbox，因为这里的勾选有明确业务语义。
- Task → Focus、Today → Review、Project → Project Detail 等核心路径可以直接点击演示。
- Focus 页面包含真实前台倒计时原型；后台可靠计时仍属于正式 Android 实现范围。

## 视觉基线

遵循 `UI_SPEC.md`：

- 360×800dp 作为主要移动端参考尺寸；
- Primary Blue `#2563EB`；
- Background `#FAFBFF`；
- 低阴影、浅边框；
- 减少无意义 Card；
- Today 信息顺序：问候/日期 → 周日期 → Today Focus → 今日概览 → 时间线 → 今日任务 → 复盘；
- 五个固定一级导航：今天 / 任务 / 项目 / 日历 / 收集。

## 验证

GitHub Actions `Flutter Preview CI` 运行：

```text
flutter pub get
flutter analyze
flutter test
```

只有该 CI 通过后，才将这批原型代码视为“可运行设计基线”。它仍不代表任何业务模块完成。
