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

### 计划中 (V1.1)
- [ ] 手动勾选要清理的具体项目
- [ ] 定时自动扫描提醒
- [ ] 中英文双语支持
- [ ] 菜单栏快捷入口

### 远期计划 (V2+)
- [ ] 磁盘空间可视化（DaisyDisk 式旭日图）
- [ ] 大文件/重复文件查找
- [ ] 开发者工具缓存（Xcode、npm、Docker）
- [ ] Homebrew cask 安装
