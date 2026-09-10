# Flutter 在线预览

LifeTrace Execute 的 Flutter 高保真原型通过 GitHub Pages 自动部署。

在线地址：

https://lifetracemanage.github.io/LifeTrace-execute/

## 部署规则

- 来源分支：`feature/flutter-high-fidelity-preview`
- 代码目录：`flutter-preview/`
- 工作流：`.github/workflows/flutter-pages.yml`
- 每次 `flutter-preview/**` 发生变更后自动重新构建并部署
- 也可以从 GitHub Actions 手动触发 `Deploy Flutter Preview to GitHub Pages`

## 构建 Gate

部署前必须依次通过：

```text
flutter create . --platforms=web --project-name lifetrace_execute_preview
flutter pub get
flutter analyze
flutter test
flutter build web --release --base-href "/LifeTrace-execute/"
```

如果仓库尚未启用 GitHub Pages，需要在 GitHub 仓库 Settings → Pages 中把 Source 设为 `GitHub Actions`。启用后无需再配置发布分支，部署由 Actions 完成。
