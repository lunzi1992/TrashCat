# TrashCat 扫描与清理策略

> 版本：v0.2 draft  
> 日期：2026-06-16  
> 核心原则：不要把判断压力交给普通用户。TrashCat 必须在底层先判断清楚，再决定展示方式和默认动作。

## 1. 产品目标校准

TrashCat 不是一个“扫到什么都列出来”的文件浏览器，也不是一个靠吓人的空间数字制造焦虑的清理器。

新的产品目标是：

> 帮 Mac 用户找出真正能释放空间的来源，并把它们分成“可以放心清理”“需要解释后确认”“只做空间诊断”三类；默认只处理确定安全、可重建、低风险的内容。

这意味着：
- 默认清理范围宁可小，也不能误伤用户数据。
- 大空间占用要被发现，但不等于可以自动删除。
- 应用残留必须从“确定残留”降级为“可能残留”，直到规则足够可靠。
- 系统关键路径不扫描、不展示、不提供清理入口。

## 2. 三层清理模型

### 2.1 推荐清理

用户可以直接一键清理，默认勾选。

纳入条件：
- 文件属于明确的缓存、日志、临时文件。
- 删除后系统或应用可以自动重建。
- 不包含账号、文档、数据库主体、备份、工程产物、照片、邮件主体等用户数据。
- 不在系统关键路径内。

初始范围：
- `~/Library/Caches/*`
- `~/Library/Logs/*`
- `/tmp/*`
- `/private/tmp/*`
- `/private/var/tmp/*`
- 浏览器明确 cache 子目录：
  - `Cache`
  - `Code Cache`
  - `Service Worker/CacheStorage`
  - `Service Worker/ScriptCache`
  - Firefox `cache2`

建议加约束：
- 临时目录文件默认只清理 7 天以上未修改的项目。
- 正在运行的应用相关缓存先跳过，或降级到“需要确认”。
- 删除单位优先按目录或规则单元聚合，不按海量零散文件让用户判断。

### 2.2 需要确认

用户能看懂影响说明后再决定，默认不勾选。

纳入条件：
- 通常可以重建，但删除会带来明显代价。
- 删除后可能需要重新下载、重新索引、重新登录，或第一次启动变慢。
- 不应混入“一键推荐清理”。

初始范围：
- Xcode `DerivedData`
- Xcode `iOS DeviceSupport`
- CoreSimulator 中“不可用设备”或可由系统工具确认的旧运行时数据
- 包管理器缓存：Homebrew、npm、pnpm、yarn、pip、Gradle、Maven、Cargo、Go module cache
- Docker build cache、未使用 image、未使用 container
- 浏览器缓存之外的浏览器可重建数据

处理方式：
- 尽量调用官方命令或稳定 API，而不是直接搬目录。
- 例如模拟器优先使用 `simctl delete unavailable`，Docker 优先使用 `docker system df` 和明确的 prune 类操作。
- UI 展示“删除后的代价”，而不是展示复杂路径。

### 2.3 空间诊断

只告诉用户这里为什么大，不默认删除；初期可以不提供删除按钮。

纳入条件：
- 占用空间大，但很可能包含用户数据。
- 用户需要业务语义才能判断。
- 删除后恢复成本高，即使移入废纸篓也不应轻易建议。

初始范围：
- iOS 设备备份：`~/Library/Application Support/MobileSync/Backup`
- Xcode Archives：`~/Library/Developer/Xcode/Archives`
- Photos Library
- Mail 数据库和附件
- Messages 附件
- 微信、飞书、Slack、Telegram、Discord 等聊天软件的数据和下载文件
- Docker volumes
- 虚拟机镜像、Parallels/VMware/UTM 数据
- 大文件和重复文件

处理方式：
- 展示应用名、占用大小、数据性质、推荐动作。
- 推荐动作可以是“打开位置”“打开对应 App 管理”“查看说明”，而不是直接清理。

## 3. 永不扫描或永不清理的区域

以下路径不进入普通扫描器；如果为了统计磁盘占用需要触达，也只能只读统计，不能列入清理结果。

- `/System`
- `/bin`
- `/sbin`
- `/usr`
- `/private/var/db`
- `/private/var/folders` 中非当前用户临时目录之外的内容
- `/Library/Keychains`
- `~/Library/Keychains`
- Photos Library 内部结构
- Mail 数据库主体
- App 沙盒容器根目录
- 不明来源的 `Application Support` 大目录
- 任何权限不足但仍能通过特殊方式访问的系统数据

## 4. 扫描器重构方向

当前扫描器按路径和文件枚举组织，下一步应改成规则驱动。

建议引入 `CleanRule` / `ScanPolicy`：

```swift
struct CleanRule {
    let id: String
    let title: String
    let owner: String
    let paths: [String]
    let category: CleanCategory
    let riskLevel: RiskLevel
    let defaultSelected: Bool
    let deletionUnit: DeletionUnit
    let minAgeDays: Int?
    let requiresAppNotRunning: Bool
    let deleteStrategy: DeleteStrategy
    let impactSummary: String
}
```

规则必须表达：
- 这是什么。
- 为什么能删或为什么不能默认删。
- 删除单位是什么。
- 删除后有什么代价。
- 是否默认选中。
- 是否需要调用官方工具。

## 5. 下一步实施路线

### Phase A：收紧安全边界

- 从普通缓存扫描中移出 iOS Backup、Xcode Archives、CoreSimulator Devices。
- 临时目录增加文件年龄过滤。
- 废纸篓单独成区，不与“推荐清理”共用重复分组。
- 确认弹窗显示风险构成：推荐清理多少项、需要确认多少项、谨慎处理多少项。
- “全选”改为“选择推荐项”，避免一键选中高风险内容。

### Phase B：规则化扫描

- 引入 `CleanRule`。
- 把缓存、日志、浏览器缓存迁移到规则。
- 每个扫描结果带上 rule id、风险等级、影响说明和删除策略。
- 扫描结果按“可删除单元”聚合，而不是按单个文件堆列表。

### Phase C：空间诊断

- 新增“大空间诊断”视图。
- 首批诊断 iOS Backup、Xcode Archives、Docker、聊天软件、虚拟机镜像。
- 初期只展示，不默认清理。
- 后续为每类诊断补充官方清理入口或明确的安全清理策略。

## 6. 验收标准

MVP 下一版不以“扫出多少 GB”为主要指标，而以以下标准验收：

- 默认选中的项目必须全部属于“推荐清理”。
- 扫描结果中不出现系统关键路径。
- 高风险占用能被发现，但不会被默认删除。
- 用户无需理解 macOS 路径，也能知道每类空间来自什么、删除代价是什么。
- 清理前能明确看到本次选择包含哪些风险层级。
