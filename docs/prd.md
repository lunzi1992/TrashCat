# PRD：TrashCat（MVP）

> 版本：v0.1 | 日期：2026-06-16 | 作者：lunzi  
> 状态：Draft → 待开发

---

## 1. 问题定义

### 用户痛点

Mac 用久了会产生大量「看不见的垃圾」：
- **系统缓存**：系统和应用产生的缓存文件，动辄几十 GB
- **临时文件**：/tmp、日志文件，日积月累从不清除
- **应用残留**：已删除的应用，其配置文件、缓存、偏好设置（plist）、容器数据全部留在磁盘上——这是 macOS 最大的设计缺陷之一

用户（lunzi 本人也是）的典型场景：
> 「我明明把 A 软件拖进废纸篓清空了，为什么磁盘空间没回来多少？去 ~/Library 里一看，那个软件留了一堆东西，手动找又麻烦又怕删错。」

### 为什么现有方案不够好

| 选型 | 为什么不选 |
|------|-----------|
| CleanMyMac | 年费 $40、有遥测、功能太多用不上 |
| AppCleaner | 只做卸载，不能扫历史残留 |
| OnyX | 界面太硬核，不像给人用的 |
| 手动清理 | 目录结构复杂，怕删错系统文件 |
| 腾讯柠檬 | 闭源、有广告、只面向中文用户 |

### 业务目标

- **主要目标**：做一个自己用着爽的 Mac 清理工具
- **次要目标**：开源到 GitHub，获得社区认可（stars / contributors）
- **长期目标**：成为 Mac 用户首选的免费清理工具

---

## 2. 用户故事

### MVP 核心用户故事

| ID | 用户故事 | 优先级 |
|----|---------|--------|
| US-01 | 作为 Mac 用户，我希望能**一键扫描**系统中的垃圾文件，以便快速了解有多少空间可以释放 | P0 |
| US-02 | 作为 Mac 用户，我希望能**一键清理**扫描出的垃圾文件，以便快速释放磁盘空间 | P0 |
| US-03 | 作为 Mac 用户，我希望能看到**已卸载应用残留的文件列表**，以便清理它们释放空间 | P0 |
| US-04 | 作为 Mac 用户，我希望能按**文件类别**（缓存/日志/临时文件/残留）分别查看扫描结果，以便了解垃圾来源 | P1 |
| US-05 | 作为 Mac 用户，我希望清理前能**预览**每个文件/目录的路径，以便确认不会误删重要数据 | P1 |
| US-06 | 作为 Mac 用户，我希望看到清理结果的**统计数据**（释放了多少空间），以便感知工具价值 | P1 |

### V2 用户故事（本期不做）

| ID | 用户故事 | 说明 |
|----|---------|------|
| US-07 | 作为 Mac 用户，我希望能**手动选择**要清理的具体项目 | 精细化控制 |
| US-08 | 作为 Mac 用户，我希望能**定时自动扫描**并提醒我 | 被动使用场景 |
| US-09 | 作为开发者，我希望能清理 **Xcode / npm / Docker** 缓存 | 开发者特化 |
| US-10 | 作为 Mac 用户，我希望能看到**磁盘空间可视化** | DaisyDisk 式交互 |

---

## 3. 功能范围

### ✅ In Scope（MVP）

#### 3.1 扫描引擎

| 扫描目标 | 路径 | 说明 |
|----------|------|------|
| 用户缓存 | `~/Library/Caches/` | 排除正在运行的应用缓存？MVP 先全量标记 |
| 系统缓存 | `/Library/Caches/` | 需管理员权限 |
| 用户日志 | `~/Library/Logs/` | 应用日志文件 |
| 临时文件 | `/tmp/`, `/private/tmp/` | 系统临时目录，重启不会自动清 |
| 废纸篓 | `~/.Trash/` | 有时候清不干净 |
| 应用残留 | `~/Library/Preferences/`、`~/Library/Application Support/`、`~/Library/Containers/`、`~/Library/Group Containers/` | **核心差异化功能** |

#### 3.2 应用残留检测逻辑

```
1. 获取当前已安装应用列表（从 /Applications、~/Applications、Launchpad 数据库）
2. 获取每个应用的 bundle identifier
3. 扫描以下目录中的所有文件/目录：
   - ~/Library/Preferences/        (*.plist 文件)
   - ~/Library/Application Support/ (应用数据目录)
   - ~/Library/Caches/              (应用缓存目录)
   - ~/Library/Containers/          (沙盒应用容器)
   - ~/Library/Group Containers/    (应用组共享容器)
   - ~/Library/Saved Application State/
4. 将无法匹配到任何已安装应用的 bundle ID 的文件/目录标记为「残留」
5. 安全白名单：排除 Apple 系统应用相关、排除已知安全路径
```

#### 3.3 功能清单

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 一键扫描 | 点击按钮 → 扫描所有目标目录 → 汇总结果 | P0 |
| 一键清理 | 点击按钮 → 删除所有扫描结果 → 报告释放空间 | P0 |
| 分类展示 | 按「缓存」「日志」「临时文件」「应用残留」「废纸篓」分类 | P1 |
| 大小统计 | 每个分类显示总大小，可展开查看详情 | P1 |
| 清理报告 | 清理完成后显示释放的文件数和空间大小 | P1 |
| 安全确认 | 清理前弹出确认对话框，避免误操作 | P0 |
| 权限引导 | 首次使用引导用户授权「全磁盘访问」 | P0 |

### ❌ Non-goals（明确不做）

| 不做的事 | 原因 |
|----------|------|
| 恶意软件扫描 | 需要持续维护病毒库，个人项目不可持续 |
| 内存优化 / 系统加速 | 现代 macOS 不需要，且可能引入不稳定性 |
| 浏览器隐私清理 | 浏览器自带，不需要重复造轮子 |
| 应用更新管理 | 不是清理工具的核心职责 |
| 实时后台监控 | MVP 不应复杂化，手动触发即可 |
| 启动项管理 | macOS Ventura+ 系统设置已内置 |
| 网络遥测 / 云同步 | **绝对不做**。本工具的核心承诺是隐私 |
| 付费功能 / 内购 | MVP 阶段完全免费开源 |

---

## 4. 技术方向建议

### 技术选型

| 层面 | 建议方案 | 理由 |
|------|---------|------|
| 语言 | Swift | macOS 原生开发首选，性能好，系统 API 丰富 |
| UI 框架 | SwiftUI | 现代声明式 UI，开发效率高，自带暗色模式 |
| 最低系统 | macOS 13 (Ventura) | SwiftUI 稳定，用户覆盖率够 |
| 架构 | MVVM | 扫描引擎独立于 UI，方便测试和复用 |
| 打包 | DMG + 公证 (notarization) | Apple 要求，否则 Gatekeeper 拦截 |
| 签名 | 个人 Apple Developer 账号 ($99/年) | 必须签名才能分发，开源后社区可以自行编译 |

### 扫描引擎设计

```
ScannableProtocol
├── CacheScanner        → ~/Library/Caches/, /Library/Caches/
├── LogScanner          → ~/Library/Logs/
├── TempScanner         → /tmp/, /private/tmp/
├── TrashScanner        → ~/.Trash/
└── OrphanScanner       → 应用残留检测（最复杂）
```

关键点：
- 扫描器并发执行，使用 `TaskGroup` 或 `DispatchGroup`
- 结果统一汇总到 `ScanResult` 模型
- 删除操作使用 `FileManager.trashItem`（移到废纸篓，可恢复）而非 `removeItem`（永久删除）
  - 这是一个重要的产品决策：**默认安全**，用户可以从废纸篓恢复
  - 后续可以加「深度清理」选项使用永久删除

### 权限要求

| 权限 | 用途 | 获取方式 |
|------|------|---------|
| 全磁盘访问 | 扫描 ~/Library 等受保护目录 | 引导用户到「系统设置 → 隐私与安全性 → 全磁盘访问」 |
| 可访问性（可选） | 如果做菜单栏快捷入口 | 暂不需要 |

### 项目结构建议

```
cleanMac/
├── cleanMac.xcodeproj
├── Sources/
│   ├── App/                  # App 入口
│   │   └── cleanMacApp.swift
│   ├── UI/                   # SwiftUI 视图
│   │   ├── ContentView.swift
│   │   ├── ScanView.swift
│   │   ├── ResultView.swift
│   │   ├── SettingsView.swift
│   │   └── Components/
│   ├── Engine/               # 扫描引擎
│   │   ├── ScannerProtocol.swift
│   │   ├── CacheScanner.swift
│   │   ├── LogScanner.swift
│   │   ├── TempScanner.swift
│   │   ├── TrashScanner.swift
│   │   ├── OrphanScanner.swift
│   │   └── ScanCoordinator.swift
│   ├── Model/                # 数据模型
│   │   ├── ScanResult.swift
│   │   ├── CleanCategory.swift
│   │   └── AppInfo.swift
│   └── Utils/                # 工具类
│       ├── PermissionManager.swift
│       └── FileSizeFormatter.swift
├── Tests/                    # 单元测试
├── Resources/                # 资源文件
│   └── Assets.xcassets
└── docs/                     # 文档
    ├── competitive-analysis.md
    └── prd.md
```

---

## 5. 交互流程设计

### 主流程

```
[启动 App]
    │
    ▼
[权限检查] ──没有权限──▶ [引导授权页面]
    │
    ▼
[主页：大扫帚按钮 + "开始扫描"]
    │
    ▼
[扫描中... 进度动画 + 当前扫描目录提示]
    │
    ▼
[扫描结果页：分类卡片 + 总大小]
    │
    ├── [用户可展开每个分类查看详情]
    │
    ▼
[「一键清理」按钮]
    │
    ▼
[确认弹窗：「将删除 X 个文件，释放 Y GB，文件将移入废纸篓」]
    │
    ├── 取消 → 返回结果页
    │
    ▼
[清理执行 → 清理报告：「成功释放 Y GB！」]
```

### 状态设计

| 状态 | 界面表现 |
|------|---------|
| 未扫描 | 大图标 + CTA 按钮 |
| 扫描中 | 进度指示器 + 动画 |
| 扫描完成（有垃圾）| 分类卡片 + 总大小醒目展示 |
| 扫描完成（无垃圾）| 「你的 Mac 很干净 🎉」 |
| 清理完成 | 释放空间统计 |
| 无权限 | 权限引导页 |
| 错误 | 错误提示 + 重试按钮 |

---

## 6. 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| **误删系统文件** | 用户系统不稳定 | 白名单机制；默认移入废纸篓；扫描时不纳入系统关键路径 |
| **Apple 审核/公证被拒** | 无法分发 dmg | 使用标准 FileManager API，不调用私有 API；及时跟进公证要求 |
| **macOS 更新破坏兼容性** | 工具失效 | 关注 WWDC；扫描路径动态获取而非硬编码 |
| **用户删除重要配置文件** | 已安装应用异常 | 残留检测只标记「已卸载应用」的文件，不碰现用应用 |
| **权限获取困难** | 用户放弃使用 | 首次引导清晰；提供手动授权步骤截图 |

### 隐私合规说明

- ✅ 所有扫描在本地完成，**不上传任何数据到任何服务器**
- ✅ 不采集用户行为数据、不埋点、不崩溃报告上传
- ✅ 不需要网络权限，可以完全断网使用
- ✅ 代码开源，任何人可审计

---

## 7. 指标体系

虽然这是个人项目，但设定指标有助于衡量质量：

| 指标 | 类型 | 目标 |
|------|------|------|
| 单次扫描时间 | 性能 | < 30 秒（SSD） |
| 残留检测准确率 | 质量 | > 95%（不过度标记已安装应用的文件） |
| 误删率 | 安全 | 0%（白名单 + 废纸篓机制保障） |
| 内存占用 | 性能 | < 200MB |
| 安装包大小 | 体验 | < 20MB |
| GitHub Stars（发布后） | 社区 | 首月 100+ |

---

## 8. MVP 路线图（Now-Next-Later）

### 🟢 Now（MVP，1-2个月）

- [ ] 项目初始化（Xcode 工程、SwiftUI 骨架）
- [ ] 权限引导页面
- [ ] 缓存扫描器
- [ ] 日志扫描器
- [ ] 临时文件扫描器
- [ ] 废纸篓扫描器
- [ ] 应用残留扫描器（核心差异化）
- [ ] 扫描结果 UI（分类卡片）
- [ ] 一键清理功能
- [ ] 清理确认 + 报告
- [ ] DMG 打包 + Apple 公证
- [ ] GitHub repo + README
- [ ] 自己用 2 周，修 bug

### 🔵 Next（V1.1，3-4个月）

- [ ] 手动选择清理项
- [ ] 扫描历史记录
- [ ] 定时提醒（可选）
- [ ] 中文/英文双语支持
- [ ] 菜单栏快捷入口
- [ ] 更精细的残留检测（扫描更多目录）

### ⚪ Later（V2+）

- [ ] 磁盘空间可视化（DaisyDisk 式旭日图）
- [ ] 大文件/重复文件查找
- [ ] 开发者工具缓存（Xcode、npm、Docker）
- [ ] iOS 备份清理
- [ ] 浏览器缓存清理（可选）
- [ ] Homebrew cask 安装方式

---

## 9. 附录：关键参考目录

macOS 上常见的垃圾文件目录清单：

```
# 用户缓存
~/Library/Caches/

# 系统缓存
/Library/Caches/
/System/Library/Caches/

# 日志
~/Library/Logs/
/Library/Logs/

# 临时文件
/tmp/
/private/tmp/
/private/var/tmp/
/private/var/folders/

# 应用残留重点扫描
~/Library/Preferences/              # .plist 文件
~/Library/Application Support/      # 应用支持文件
~/Library/Containers/               # 沙盒容器（完整应用数据）
~/Library/Group Containers/         # 应用组共享数据
~/Library/Saved Application State/  # 应用状态保存
~/Library/Cookies/                  # Cookie
~/Library/WebKit/                   # WebKit 缓存

# 废纸篓
~/.Trash/

# 开发者相关（V2）
~/Library/Developer/Xcode/DerivedData/
~/Library/Developer/Xcode/iOS DeviceSupport/
~/Library/Developer/CoreSimulator/
~/.gradle/caches/
~/.npm/_cacache/
~/Library/Containers/com.docker.docker/
```

---

> **下一步**：确定产品名称 → 搭建 Xcode 工程 → 开始写第一个扫描器。
