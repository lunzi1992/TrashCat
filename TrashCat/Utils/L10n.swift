import Foundation

/// Lightweight i18n enum for TrashCat UI strings.
/// All user-facing strings go through here. Add new keys as needed.
/// The data model layer (RuleRegistry titles, RiskLevel names) uses its own displayName property.

enum L10n {
    // MARK: - Home Screen
    static let appTitle = NSLocalizedString("app.title", value: "TrashCat", comment: "")
    static let appTagline = NSLocalizedString("app.tagline", value: "垃圾就像老鼠。我是那只抓老鼠的猫。", comment: "Home screen slogan")
    static let scanButton = NSLocalizedString("scan.button", value: "开始扫描", comment: "")
    static let scanHint = NSLocalizedString("scan.hint", value: "让我闻一闻你的 Mac 里藏了什么", comment: "")
    static let errorTitle = NSLocalizedString("error.title", value: "出问题了", comment: "")
    static let retryButton = NSLocalizedString("retry.button", value: "重试", comment: "")

    // MARK: - Scan Screen
    static let scanningPreparing = NSLocalizedString("scan.preparing", value: "准备扫描...", comment: "")
    static let scanningFinishing = NSLocalizedString("scan.finishing", value: "收尾中...", comment: "")
    static let scanningSniffing = NSLocalizedString("scan.sniffing", value: "正在嗅探...", comment: "")
    static let scanningCaught = NSLocalizedString("scan.caught", value: "已捕获 %d 只老鼠", comment: "")
    static let scanningFound = NSLocalizedString("scan.found", value: "已发现 %d 个文件", comment: "")
    static let scanningDirs = NSLocalizedString("scan.dirs", value: "%d / %d 个扫描项已完成", comment: "")
    static let scanCancel = NSLocalizedString("scan.cancel", value: "取消扫描", comment: "")
    static let scanFooter = NSLocalizedString("scan.footer", value: "TrashCat 正在翻你 Mac 的角落...", comment: "")

    // MARK: - Results Screen
    static let resultsTitle = NSLocalizedString("results.title", value: "扫描完成", comment: "")
    static let resultsDuration = NSLocalizedString("results.duration", value: "用时 %.1f 秒", comment: "")
    static let resultsRescan = NSLocalizedString("results.rescan", value: "重新扫描", comment: "")
    static let resultsSelected = NSLocalizedString("results.selected", value: "已选 %d/%d 项", comment: "")
    static let resultsClean = NSLocalizedString("results.empty", value: "你的 Mac 很干净！没找到任何垃圾文件，好猫表示很满意。", comment: "")
    static let resultsEmptySubtitle = NSLocalizedString("results.emptySubtitle", value: "你的 Mac 很干净！没找到任何垃圾文件，好猫表示很满意。", comment: "")

    // MARK: - Footer
    static let selectRecommended = NSLocalizedString("select.recommended", value: "选择推荐项", comment: "")
    static let deselectAll = NSLocalizedString("select.deselectAll", value: "取消全选", comment: "")
    static let cleanSafe = NSLocalizedString("clean.safe", value: "安全清理", comment: "")
    static let cleanReview = NSLocalizedString("clean.review", value: "确认后清理", comment: "")

    // MARK: - Tier Headers
    static let tierTrash = NSLocalizedString("tier.trash", value: "废纸篓", comment: "")
    static let tierDiagnostic = NSLocalizedString("tier.diagnostic", value: "空间诊断", comment: "")
    static let tierDiagnosticExplanation = NSLocalizedString("tier.diagnostic.explanation", value: "这些是占用空间较大的用户数据或开发数据，只用于定位来源，不会被 TrashCat 自动清理。", comment: "")
    static let tierTrashExplanation = NSLocalizedString("tier.trash.explanation", value: "这些项目已经在废纸篓中，清理后会进入系统废纸篓处理流程。", comment: "")

    // MARK: - Labels
    static let labelDiagnosticOnly = NSLocalizedString("label.diagnosticOnly", value: "仅诊断", comment: "Shown on non-cleanable items")
    static let labelApps = NSLocalizedString("label.apps", value: "%d 个应用", comment: "")
    static let labelFiles = NSLocalizedString("label.files", value: "%d 个文件", comment: "")
    static let labelMoreFiles = NSLocalizedString("label.moreFiles", value: "...还有 %d 个文件", comment: "")
    static let labelCategories = NSLocalizedString("label.categories", value: "%d 类", comment: "")

    // MARK: - Clean Report
    static let reportDone = NSLocalizedString("report.done", value: "清理完成！", comment: "")
    static let reportPartial = NSLocalizedString("report.partial", value: "部分完成", comment: "")
    static let reportFreed = NSLocalizedString("report.freed", value: "已释放", comment: "")
    static let reportSpace = NSLocalizedString("report.space", value: "空间", comment: "")
    static let reportFilesMoved = NSLocalizedString("report.filesMoved", value: "共 %d 个文件被移入废纸篓", comment: "")
    static let reportDuration = NSLocalizedString("report.duration", value: "用时 %.1f 秒", comment: "")
    static let reportDetail = NSLocalizedString("report.detail", value: "清理明细", comment: "")
    static let reportTrashHint = NSLocalizedString("report.trashHint", value: "文件在废纸篓里，随时可以恢复", comment: "")
    static let reportOpenTrash = NSLocalizedString("report.openTrash", value: "打开废纸篓", comment: "")
    static let reportDoneButton = NSLocalizedString("report.doneButton", value: "好的", comment: "")
    static let reportTrashExplanation = NSLocalizedString("report.trash.explanation", value: "仅会处理 TrashCat 支持安全清理的项目；空间诊断项不会被清理。", comment: "")

    // MARK: - Confirm Dialog
    static let confirmTitle = NSLocalizedString("confirm.title", value: "确认清理？", comment: "")
    static let confirmFilesCount = NSLocalizedString("confirm.filesCount", value: "将移动 %d 个文件到废纸篓", comment: "")
    static let confirmSizeFreed = NSLocalizedString("confirm.sizeFreed", value: "清空废纸篓后可释放 %@", comment: "")
    static let confirmDangerWarning = NSLocalizedString("confirm.dangerWarning", value: "⚠️ 选中的文件包含谨慎处理项，请确认后继续。", comment: "")
    static let confirmSafeHint = NSLocalizedString("confirm.safeHint", value: "文件会先移入废纸篓，后悔了还能恢复。", comment: "")
    static let confirmThinkAgain = NSLocalizedString("confirm.thinkAgain", value: "再想想", comment: "")
    static let confirmClean = NSLocalizedString("confirm.clean", value: "清理！", comment: "")

    // MARK: - Risk Levels
    static let riskSafe = NSLocalizedString("risk.safe", value: "推荐清理", comment: "")
    static let riskCaution = NSLocalizedString("risk.caution", value: "需要确认", comment: "")
    static let riskDanger = NSLocalizedString("risk.danger", value: "谨慎处理", comment: "")

    // MARK: - Errors
    static let errorNotCleanable = NSLocalizedString("error.notCleanable", value: "此项不支持自动清理，已跳过", comment: "")

    // MARK: - Rules (RuleRegistry i18n)
    static func ruleTitle(for id: String) -> String {
        NSLocalizedString("rule.\(id).title", value: id, comment: "")
    }
    static func ruleDescription(for id: String) -> String {
        NSLocalizedString("rule.\(id).desc", value: id, comment: "")
    }
    static func ruleImpact(for id: String) -> String {
        NSLocalizedString("rule.\(id).impact", value: id, comment: "")
    }
}
