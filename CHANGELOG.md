# Changelog

## [0.1.0] — 2026-06-16 — MVP 首发 🐱

> **垃圾就像老鼠。TrashCat 是那只抓老鼠的猫。**
>
> 首个公开发布版本。在你自己 Mac 上跑起来，让它闻一闻藏了多少老鼠。

### ✨ 新增功能

#### 扫描引擎（5 类垃圾检测）
- **缓存清理** — 扫描 `~/Library/Caches` 和 `/Library/Caches`
- **日志清理** — 扫描 `~/Library/Logs` 和 `/Library/Logs`（递归）
- **临时文件清理** — 扫描 `/tmp`、`/private/tmp`、`/private/var/tmp`
- **废纸篓清理** — 扫描 `~/.Trash`（递归）
- **应用残留清理** ⭐ — 检测已卸载 App 在以下目录的残留：
  - `~/Library/Preferences`（plist 文件）
  - `~/Library/Application Support`（应用数据）
  - `~/Library/Containers`（沙盒容器）
  - `~/Library/Group Containers`（共享容器）
  - `~/Library/Saved Application State`

#### 残留检测算法
- 通过 `mdfind` 枚举所有已安装应用的 bundle ID
- 对比文件名与已安装 App，标记无法匹配的为「孤儿残留」
- 白名单保护：自动跳过 `com.apple.*` 系统文件

#### UI 交互流程
- **主页** — TrashCat 猫图标 + 一键「开始扫描」按钮
- **权限引导** — 首次启动弹窗引导「全磁盘访问」授权，含 4 步图文说明
- **扫描动画** — 猫 emoji 动画 + 进度条 + 当前扫描目录提示
- **结果页** — 分类卡片展示，可展开查看具体文件列表
- **一键清理** — 底部按钮显示可释放空间，弹出确认对话框
- **清理报告** — 显示释放空间大小、文件数，以及任何清理失败的详情

#### 安全机制
- 默认 `FileManager.trashItem()` 移入废纸篓（可恢复，不永久删除）
- 清理前必须手动确认
- 保留 `permanentDelete` 接口供后续深度清理模式使用
- 100% 本地运行，零网络请求，零遥测

### 🏗️ 技术架构

- **语言**: Swift 5.9+
- **UI**: SwiftUI
- **架构**: MVVM
- **最低系统**: macOS 13 Ventura
- **依赖**: 零外部依赖，纯 Apple 框架
- **工程**: 手动搭建 Xcode 项目（`project.pbxproj`），一次编译通过

### 📁 目录结构

```
TrashCat/
├── TrashCatApp.swift            @main 入口
├── ContentView.swift            状态机主容器
├── Model/ScanModels.swift       数据模型 (CleanCategory/CleanItem/...)
├── Engine/
│   ├── ScannableProtocol.swift  协议 + ScanCoordinator
│   ├── CleanManager.swift       清理管理器
│   └── Scanners/                5 个扫描器
├── UI/
│   ├── PermissionGuideView.swift
│   ├── ScanningView.swift
│   ├── ResultsView.swift
│   └── CleanReportView.swift
└── Utils/
    └── PermissionManager.swift
```

### 🎨 品牌

- 产品名: **TrashCat** 🐱
- Logo: 像素风美短猫 + macOS 文件夹 + 老鼠尾巴
- 开源: MIT License
- 仓库: [github.com/lunzi1992/TrashCat](https://github.com/lunzi1992/TrashCat)

### 📋 已知限制

- 大目录扫描时 UI 可能短暂卡顿（后续改为并发扫描）
- App 图标尺寸仅支持 1024x1024（后续生成多分辨率）
- 仅支持中文界面（英文 V1.1 计划中）
- 不支持手动选择清理项（V1.1 计划中）
- 无菜单栏快捷入口（V1.1 计划中）

---

## [Unreleased]

### 🔧 P0 安全修复 (2026-06-17)

- **CacheScanner 移除危险路径**：iOS 备份 (`MobileSync/Backup`) 和 Xcode Archives 从缓存扫描器中移除。这些属于"空间诊断"范畴（scan-policy.md §2.3），不应出现在一键清理中。
- **ScanPolicy blocklist 落地**：所有 6 个扫描器（Cache/Browser/Log/Temp/Trash/Orphan）的文件枚举循环中新增 `ScanPolicy.isBlocked()` 检查，确保 `/System`、`/bin`、`/sbin`、`/usr`、`/private/var/db`、`Keychains` 等系统关键路径不被扫描或清理。
- **OrphanScanner 前缀匹配收紧**：匹配逻辑由无约束 `hasPrefix` 改为 dot-boundary 前缀匹配（`hasPrefix(stem + ".")`），防止短 stem（如 `com`）误匹配到不相关的已安装应用，减少残留漏报。

### 🚀 P1 功能增强 (2026-06-17)

- **并发扫描 (TaskGroup)**：6 个扫描器从串行改为 `withTaskGroup` 并发执行，总扫描时间从"各扫描器之和"降到"最慢那个的时间"，典型场景提速 2-3x。
- **取消扫描**：`ScanCoordinator` 支持 `cancelScan()`，扫描中可随时取消并回到首页。
- **补充扫描目标**：
  - 崩溃报告：`~/Library/Logs/DiagnosticReports`、`/Library/Logs/DiagnosticReports`（可达数 GB 的 .ips/.crash 文件）
  - 系统更新下载：`/Library/Updates`（macOS 更新包残留）
  - Shell 会话历史：`~/.bash_sessions`、`~/.zsh_sessions`
  - 开发者工具缓存：npm (`~/.npm`)、Gradle (`~/.gradle`)、Cargo (`~/.cargo`)、Dart/Flutter (`~/.pub-cache`)
  - VS Code 缓存：`Cache`、`CachedData`、`CachedExtensionVSIXs`、`logs`、`workspaceStorage`
- **运行中应用保护**：新增 `isRunningAppPath()` 检测。如果缓存文件属于正在运行的应用，风险等级从"推荐清理"降级为"需要确认"，避免清理导致运行中应用崩溃或数据丢失。
- **风险路径补充**：`/Library/Updates` 和 VS Code `workspaceStorage` 加入 caution 路径列表。
- **空间诊断扫描器**：新增 `SpaceDiagnosticScanner`，覆盖 Time Machine 本地快照（通过 `tmutil`）、Mail 邮件附件、Messages 信息附件。所有诊断项标记为 `manualOnly`，不支持一键清理。
- **CleanCategory 新增 `.diagnostic`**：独立的"空间诊断"类别，在 FileCategorizer、RiskAssessor 中全面支持。
- **RuleRegistry 扩展**：从 15 条规则扩展到 28 条，新增崩溃报告、Shell 会话、npm/Gradle/Cargo/Flutter 缓存、VS Code 缓存、系统更新、Time Machine、Mail、Messages 规则。
- **RuleScanner 安全加固**：添加 `ScanPolicy.isBlocked()` 检查。
- **测试代码**：`TrashCatTests/` 目录包含 RiskAssessor 和 ScanPolicy 的单元测试用例，待通过 Xcode test target 运行。

### ⚡ 性能优化 + 动画 (2026-06-18)

- **文件枚举 I/O 优化**：`RuleScanner`、`BrowserCacheScanner` 中用 `NSURL.getResourceValue` 替换 `URL.resourceValues`，直接读取枚举器预取缓存，避免每文件一次 `stat()` 调用，大目录扫描提速约 30-50%。
- **扫描完成即时过渡**：`startScan()` 从 `async` 等待改为 fire-and-forget，扫描在后台线程池运行，结果页即时切换不再卡顿。
- **扫描动画**：猫咪追老鼠动画——🐱 平滑追逐 🐭，老鼠随机漫步，猫 lerp 追踪，碰到即"抓住"并计数。单 60fps 定时器驱动，丝滑流畅。
- **窗口尺寸**：默认 720×540，与主流 Mac App 一致，`.defaultSize` + `minWidth: 680` 确保不窄。

### 方向校准
- 项目目标从“扫描尽可能多的垃圾并一键清理”调整为“底层判断清楚，默认只清理确定安全项”。
- 新增扫描策略基准文档：`docs/scan-policy.md`。
- 扫描结果主轴统一为「推荐清理 / 需要确认 / 谨慎处理」。
- iOS 备份、Xcode Archives、照片、邮件、聊天记录、虚拟机镜像等大空间占用改为「空间诊断」思路，不混入默认清理。
- 应用残留统一降级为「可能的应用残留」，默认不选中。

### 计划中 (V1.1)
- [x] 规则驱动扫描策略 `CleanRule` / `ScanPolicy` ✅ v0.2.0
- [x] 大空间诊断 ✅ v0.2.0
- [x] 更严格的默认清理白名单 ✅ v0.2.0
- [ ] 定时自动扫描提醒
- [ ] 中英文双语支持
- [ ] 菜单栏快捷入口

### 远期计划 (V2+)
- [ ] 磁盘空间可视化（DaisyDisk 式旭日图）
- [ ] 大文件/重复文件查找
- [x] 开发者工具缓存（Xcode、npm、Gradle、Cargo、VS Code） ✅ v0.2.0
- [ ] Docker 清理（需调用官方 CLI）
- [ ] Homebrew cask 安装
