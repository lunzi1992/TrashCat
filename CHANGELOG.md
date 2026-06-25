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

## [0.3.0] — 2026-06-25 — P0 冲刺：DMG 分发 + 进度反馈 + 测试 + 报告升级

### 📦 DMG 分发

- **一键打包脚本** `scripts/build-dmg.sh`，产出 `TrashCat-{version}.dmg`（2.2MB）
- Ad-hoc 签名（无需付费 Apple Developer 账号）
- 拖拽安装 DMG（含 /Applications 快捷方式）
- README 补充 Gatekeeper 绕过说明（右键→打开 / `xattr -cr`）

### 📡 扫描进度实时反馈

- `ScanState` 新增 `filesScanned` + `filesFound` 字段
- 每个扫描器完成后实时更新进度
- ScanningView 显示"已发现 N 个文件"+"N / ? 个目录已扫描"
- 进度条反映实际扫描器完成比例

### 📊 清理报告升级

- `CleanResult` 新增 `categoryBreakdown`（按分类统计释放空间和文件数）
- CleanReportView 按分类展示明细表（图标 + 文件数 + 大小）
- 新增"打开废纸篓"按钮，一键跳转恢复
- 显示清理耗时

### 🧪 单元测试补齐

新增 4 个测试文件，59 个断言，覆盖率翻倍：

| 文件 | 断言数 | 覆盖范围 |
|------|:------:|---------|
| RuleRegistryTests | 16 | 注册表完整性、风险一致性、关键规则存在性 |
| CleanItemTests | 18 | isCleanable、riskLevel、聚合模型、TierGroup 构建 |
| OrphanScannerTests | 10 | bundle ID 匹配、系统前缀过滤、orphan reason |
| ScanPolicyAdvancedTests | 15 | blocklist 边界、路径分类、显示名/解释 |

### 📝 文档

- README 功能列表更新（实时进度、清理报告明细）
- README 新增 DMG 打包说明（`./scripts/build-dmg.sh`）
- README 猫窝结构补充 scripts/ 和 deliverables/

---

## [0.2.1] — 2026-06-25 — 性能优化 + UI 打磨

### ⚡ 展开/折叠秒开

经历三轮性能优化，根治了结果页展开卡顿 5 秒的问题：

- **第 1 轮**：`selectedSize`/`selectedCount` 从 O(n) 计算属性改为增量 `@State`
- **第 2 轮**：`AppGroup`/`RuleGroup`/`TierGroup` 的 `totalSize`/`ids` 从 computed 改为 `let` 存储属性，消除级联重算
- **第 3 轮**：`TierCard`/`RuleRow`/`AppRow` 拆为独立 View struct，各自持有 `@State isExpanded`，展开只重渲染自身，父级不动

### 🔧 P1/P2 代码修复

- **onAppear 重复注册 scanner**：`didRegister` 守卫，避免每次导航回结果页都追加 scanner
- **扫描循环缺取消检查**：`RuleScanner`/`BrowserCacheScanner` 循环内新增 `Task.isCancelled` 检查
- **O(n×m) 规则查找**：`RuleRegistry.all.first(where:)` 替换为 `RuleRegistry.byId` 字典 O(1)
- **force-unwrap 消除**：`RiskLevel.<` 改为 `guard let` 安全解包
- **浏览器去重**：`discoverInstalledBrowsers` 增加 `seen: Set<String>` 去重
- **旧 scanner 清理**：`CacheScanner`/`LogScanner`/`TempScanner`/`TrashScanner` 从 pbxproj 编译目标移除

### 🎨 UI 改进

- 展开后规则和应用按占用空间从大到小排序
- 初始状态全部折叠，首页秒出

---

## [0.2.0] — 2026-06-17 — 规则引擎 + 安全加固
- [ ] Docker 清理（需调用官方 CLI）
- [ ] Homebrew cask 安装
