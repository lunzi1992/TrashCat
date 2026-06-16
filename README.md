# 🐱 TrashCat — 你的 Mac 捕鼠官

<p align="center">
  <img src="Resources/icon.png" width="128" alt="TrashCat logo">
</p>

<p align="center">
  <strong>垃圾就像老鼠。TrashCat 是那只抓老鼠的猫。</strong>
</p>

<p align="center">
  <a href="#-背景故事">背景故事</a> •
  <a href="#-功能">功能</a> •
  <a href="#-安装">安装</a> •
  <a href="#-技术栈">技术栈</a> •
  <a href="#-开发">开发</a> •
  <a href="#-路线图">路线图</a>
</p>

---

## 📖 背景故事

你的 Mac 是一座大房子。

你每天在里面工作、娱乐、创造。偶尔觉得某个应用没用了，把它拖进废纸篓，清空——以为这就完事了。

**但事情没那么简单。**

你把应用赶出了大门，它却在你看不到的角落里留下了窝：藏在 `~/Library` 深处的配置文件，躲在 `Caches` 夹层里的缓存，窝在 `Containers` 暗处的沙盒数据……日积月累，几十 GB 的「老鼠」在你的 Mac 里繁衍生息。

市面上的所谓「灭鼠公司」要么收年费（CleanMyMac $40/年），要么进门就到处装摄像头（遥测），要么给你一本厚厚的《灭鼠手册》让你自己学（OnyX）。

**我们只想要一只猫。一只好猫。**

于是有了 TrashCat——开源、免费、不偷看，一个专门在你 Mac 里抓「数字老鼠」的猫。

你只需要点一下，它就钻进系统的每个角落，把那些藏的、躲的、赖着不走的，统统叼出来。然后「喵」一声——你的 Mac 干净了。

---

> *Every Mac deserves a good mouser. Meet yours.* 🐱

---

## ✨ 这是干什么的

- 🐭 **抓老鼠（扫描垃圾）**——一键扫描系统垃圾、缓存、临时文件
- 🪹 **端老鼠窝（应用残留清理）**——已删除的应用留下的配置文件、容器、缓存，一个不剩
- 📊 **交差（清理报告）**——清楚地告诉你抓了多少只「老鼠」，释放了多少空间
- 🔒 **忠心（100% 本地）**——不上传任何数据，不联网，不开后门，代码全开源

## 🐭 打猎清单

### MVP —— 第一波老鼠窝

- [x] **系统缓存**——`~/Library/Caches` 的老鼠窝
- [x] **应用残留**——已经「卸载」但窝还在的那些（plist、容器、配置）
- [x] **日志文件**——各种 `.log`，全是老鼠脚印
- [x] **临时文件**——`/tmp` 里的流浪鼠
- [x] **废纸篓残留**——你以为清干净了？再闻闻
- [x] 分类呈现——老鼠按品种分组，一目了然
- [x] 一键捕杀——点一下，全部叼走
- [x] 安全保险——叼进废纸篓而非直接咬死，后悔了还能捡回来

### TrashCat 不抓的东西

- ❌ 病毒 / 恶意软件（那是看门狗的活）
- ❌ 内存 / CPU（猫不管水电暖）
- ❌ 联网偷看（TrashCat 不出门）
- ❌ 收保护费（永远免费）

## 📦 领养一只 TrashCat

### 下载 DMG

> 从 [Releases](https://github.com/lunzi1992/TrashCat/releases) 页面下载最新 `.dmg`，拖进 Applications 即可。

### 自己编译

```bash
git clone https://github.com/lunzi1992/TrashCat.git
cd trashcat
open TrashCat.xcodeproj
# Xcode → Product → Archive
```

**系统要求**：macOS 13 (Ventura) 以上，给猫一个干净的新家。

## 🛠 这只猫什么构造

| 部位 | 材料 |
|------|------|
| 骨架 | Swift 5.9+ |
| 皮毛 | SwiftUI |
| 神经 | MVVM |
| 地盘 | macOS 13 Ventura+ |
| 外包装 | DMG + Apple 公证 |
| 血缘 | 纯 Apple 框架，零外部依赖 |

## 🏗 猫窝结构

```
trashcat/
├── Sources/
│   ├── App/              # 猫脑袋（入口）
│   ├── UI/               # 猫的脸（界面）
│   │   └── Components/   # 胡须、耳朵等零件
│   ├── Engine/           # 猫鼻子（扫描引擎）
│   ├── Model/            # 猫的脑子（数据模型）
│   └── Utils/            # 猫爪子（工具）
├── Tests/                # 猫的体检报告
├── Resources/            # 猫粮（图标资源）
└── docs/                 # 猫的档案
    ├── prd.md
    └── competitive-analysis.md
```

## 🔒 猫的品格

- **不出门**——不需要网络权限，断网照常干活
- **不偷看**——零遥测、零埋点、零崩溃上报
- **不撒谎**——代码全开源，每个人都可以审计每一行
- **不惹事**——文件先叼进废纸篓而非直接删除，后悔来得及

## 🗺 打猎路线图

### 🐾 第一波出击（MVP）

- [x] 系统垃圾扫描与清理
- [x] 应用残留检测
- [x] 基础 UI
- [ ] DMG 发布

### 🐾 第二波出击（Next）

- [ ] 手动选择要抓的老鼠
- [ ] 定时巡逻提醒
- [ ] 中英双语（猫也学外语）
- [ ] 菜单栏猫窝

### 🐾 第三波出击（Later）

- [ ] 磁盘空间可视化（老鼠地图）
- [ ] 大文件 / 重复文件
- [ ] 开发者工具缓存（程序员的猫）

## 🤝 一起养猫

欢迎投喂！Issues、PR、建议、星星，来者不拒。

```bash
# 领回家
gh repo fork lunzi1992/TrashCat --clone

# 开新窝
git checkout -b feature/your-feature

# 交作业
gh pr create
```

## 📄 许可

MIT License — 随便养、随便改、随便送人。

---

<p align="center">
  <i>TrashCat 在睡觉。你的 Mac 在变脏。快醒醒它。</i>
</p>

<p align="center">
  <sub>🐱 Made by <a href="https://github.com/lunzi1992">lunzi</a> · Hefei · 2026</sub>
</p>
