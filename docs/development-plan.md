# TrashCat 产品开发计划

> 版本：v0.1 | 日期：2026-06-16 | 作者：lunzi  
> 开发模式：个人项目，正常节奏（不快不慢）  
> 技术栈：Swift + SwiftUI，macOS 13+，MVVM，零外部依赖

---

## 一、大局观：Now / Next / Later

### 🟢 Now —— MVP（预计 4-6 周）

> **一句话目标**：在自己 Mac 上跑起来，能安全扫描、默认只清理确定安全项，并解释大空间占用。

| 阶段 | 内容 | 预计周期 |
|------|------|---------|
| Phase 1 | 工程搭建 | 1-2 天 |
| Phase 2 | 扫描引擎 | 1-2 周 |
| Phase 3 | UI 开发 | 1-2 周 |
| Phase 4 | 联调 + 自测 | 1 周 |
| Phase 5 | 打包发布 | 2-3 天 |

### 🔵 Next —— V1.1（MVP 发布后 2-4 周）

- 规则驱动扫描策略 `CleanRule` / `ScanPolicy`
- 大空间诊断
- 更严格的默认清理白名单
- 定时提醒
- 中英双语
- 菜单栏快捷入口

### ⚪ Later —— V2+

- 磁盘空间可视化
- 大文件/重复文件
- 开发者工具缓存

---

## 二、MVP 详细任务拆解

### Phase 1：工程搭建（2 天）

| ID | 任务 | 产出 | MoSCoW |
|----|------|------|--------|
| S-01 | 创建 Xcode 项目（TrashCat） | `.xcodeproj` | Must |
| S-02 | 搭建目录结构（App/UI/Engine/Model/Utils） | 空壳项目 | Must |
| S-03 | 配置 App Icon（TrashCat_app.png） | Assets.xcassets | Must |
| S-04 | 创建基础 SwiftUI 骨架（ContentView + 导航） | 可运行空 App | Must |
| S-05 | Git tag `v0.1.0-dev` | 基线版本 | Should |

### Phase 2：扫描引擎（1-2 周）

| ID | 任务 | 产出 | MoSCoW |
|----|------|------|--------|
| E-01 | 定义 `Scannable` 协议 | 协议接口 | Must |
| E-02 | 实现 `ScanCoordinator`（并发调度） | 协调器 | Must |
| E-03 | 实现 `CacheScanner`（~/Library/Caches） | 缓存扫描 | Must |
| E-04 | 实现 `LogScanner`（~/Library/Logs） | 日志扫描 | Must |
| E-05 | 实现 `TempScanner`（/tmp） | 临时文件扫描 | Must |
| E-06 | 实现 `TrashScanner`（~/.Trash） | 废纸篓扫描 | Must |
| E-07 | 实现 `OrphanScanner`（可能应用残留检测） | 核心诊断，不默认清理 | Must |
| E-08 | 实现 `CleanManager`（删除操作，移入废纸篓） | 清理逻辑 | Must |
| E-09 | 实现 `RiskAssessor` / 初版风险分层 | 推荐清理 / 需要确认 / 谨慎处理 | Must |
| E-10 | 引入规则层 `CleanRule` / `ScanPolicy` | 扫描策略可解释、可测试 | Must |
| E-11 | 单元测试（Mock 目录结构） | 覆盖系统路径排除、默认选择、安全路径 | Should |

**引擎模块架构**：
```
Engine/
├── ScannableProtocol.swift      # 扫描器协议
├── ScanCoordinator.swift         # 并发调度 + 结果汇总
├── Scanners/
│   ├── CacheScanner.swift
│   ├── LogScanner.swift
│   ├── TempScanner.swift
│   ├── TrashScanner.swift
│   └── OrphanScanner.swift
├── CleanManager.swift            # 删除操作
└── PermissionManager.swift       # 权限检查
```

### Phase 3：UI 开发（1-2 周）

| ID | 任务 | 产出 | MoSCoW |
|----|------|------|--------|
| U-01 | 权限引导页（首次启动） | 引导界面 | Must |
| U-02 | 主页面（大扫帚按钮 + "开始扫描"） | 待扫描状态 | Must |
| U-03 | 扫描中动画（进度 + 当前扫描目录） | 扫描状态 | Must |
| U-04 | 结果页（分类卡片 + 总大小） | 扫描完成状态 | Must |
| U-05 | 清理确认弹窗 | 确认对话框 | Must |
| U-06 | 清理报告页（释放空间统计） | 清理完成状态 | Must |
| U-07 | 暗色模式适配 | 自动跟随系统 | Should |
| U-08 | 错误状态处理 | 错误提示 + 重试 | Must |

### Phase 4：联调 + 自测（1 周）

| ID | 任务 | 产出 | MoSCoW |
|----|------|------|--------|
| I-01 | 引擎 ↔ UI 联调 | 完整可用的 App | Must |
| I-02 | 真机测试（自己的 Mac） | bug list | Must |
| I-03 | 修复 P0 bug | 稳定版本 | Must |
| I-04 | 性能优化（扫描时间 < 30s） | 性能达标 | Should |
| I-05 | Git tag `v0.9.0-rc` | 候选发布版 | Must |

### Phase 5：打包发布（2-3 天）

| ID | 任务 | 产出 | MoSCoW |
|----|------|------|--------|
| P-01 | 配置 Developer ID 签名 | 已签名 App | Must |
| P-02 | DMG 打包（含背景图 + Applications 快捷方式） | `.dmg` 文件 | Must |
| P-03 | Apple 公证（notarization） | 通过 Gatekeeper | Must |
| P-04 | GitHub Release（dmg + changelog） | 公开发布 | Must |
| P-05 | Git tag `v1.0.0` | 正式版 | Must |

---

## 三、依赖关系图

```
S-01 → S-02 → S-03/S-04           # 工程搭建
                ↓
          E-01 → E-02              # 协议 → 协调器
                    ↓
    E-03  E-04  E-05  E-06  E-07   # 各扫描器（可并行开发）
                    ↓
               E-08                # 清理管理器（依赖扫描器完成）
                    ↓
    ┌─────── U-01~U-08 ───────┐    # UI 开发（可与 Phase 2 部分并行）
    └──────────────────────────┘
                    ↓
              I-01 → I-02 → I-03 → I-05
                    ↓
              P-01 → P-02 → P-03 → P-04
```

**关键路径**：ScanPolicy（E-10）是最重要模块 → 决定产品可信度

**可并行工作**：
- E-03~E-06（四个基础扫描器）可同时开发
- Phase 2 后半段可与 U-01~U-04 并行（引擎出风险分层数据 → UI 展示）

---

## 四、技术风险矩阵

| 风险 | 严重度 | 概率 | 缓解措施 |
|------|--------|------|---------|
| 误删系统关键文件 | 🔴 高 | 🟡 中 | 白名单机制 + 移入废纸篓而非永久删除 |
| macOS 权限 API 变化 | 🟡 中 | 🟢 低 | 使用标准 FileManager API，不做 hack |
| OrphanScanner 误判 | 🔴 高 | 🟡 中 | 只标记“可能残留”，默认不选中；规则成熟前不做一键清理 |
| 大空间数据被误当垃圾 | 🔴 高 | 🟡 中 | iOS 备份、Archives、照片、邮件、聊天记录、虚拟机只进空间诊断 |
| Apple 公证被拒 | 🟡 中 | 🟢 低 | 不用私有 API，及时跟进公证要求 |
| 大目录扫描卡 UI | 🟢 低 | 🟡 中 | 后台线程 + 进度回调 + 超时机制 |

---

## 五、数据模型（提前定）

### ScanResult

```swift
struct ScanResult {
    let category: CleanCategory
    let items: [CleanItem]
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var fileCount: Int { items.count }
}

enum CleanCategory: String, CaseIterable {
    case cache      // 缓存
    case logs       // 日志
    case temp       // 临时文件
    case trash      // 废纸篓
    case orphan     // 应用残留
    
    var displayName: String { /* 中文名称 */ }
    var iconName: String { /* SF Symbol 名称 */ }
}

struct CleanItem: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let category: CleanCategory
    let riskLevel: RiskLevel
    let ruleID: String?
    let impactSummary: String
}
```

### ScanPolicy

```swift
struct CleanRule {
    let id: String
    let title: String
    let owner: String
    let paths: [String]
    let category: CleanCategory
    let riskLevel: RiskLevel
    let defaultSelected: Bool
    let minAgeDays: Int?
    let deleteStrategy: DeleteStrategy
    let impactSummary: String
}
```

---

## 六、里程碑检查点

| 日期 | 里程碑 | 验收标准 |
|------|--------|---------|
| Week 1 Day 2 | M1: 工程跑通 | Xcode 能编译运行空白 App |
| Week 2 End | M2: 引擎跑通 | Scanner 能输出风险分层结果，默认选中项全为安全项 |
| Week 3 End | M3: UI 可用 | 手动点能完成「扫描→风险分层→安全清理」完整流程 |
| Week 4 End | M4: 自测通过 | 在自己 Mac 上用了 1 周没有误删/崩溃；高风险数据只展示不默认清理 |
| Week 5 | M5: 发布 | dmg 在 GitHub Release 可以下载 |

---

## 七、本周行动计划

> **本周目标**：Phase 1 + Phase 2 起步

| Day | 做什么 | 产出 |
|-----|--------|------|
| 今天 | 创建 Xcode 项目，搭骨架 | 能跑的空 App |
| 明天 | 定义 Scannable 协议 + CacheScanner | 第一个扫描器工作 |
| 本周 | 4 个基础 Scanner 写完 | 命令行可验证输出 |
| 下周 | OrphanScanner + CleanManager | 核心模块就绪 |

---

> **下一步**：开 Xcode，创项目。
