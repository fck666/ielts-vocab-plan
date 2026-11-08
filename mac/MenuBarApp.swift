import AppKit
import Foundation
import ServiceManagement

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let cardVisibilityKey = "desktopCard.isVisible"
    private var statusItem: NSStatusItem!
    private var statusLine: NSMenuItem!
    private var openItem: NSMenuItem!
    private var cardItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var cardController: DesktopVocabularyCardWindowController?
    private var learningWindowController: LearningWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        VocabularySpeech.shared.warmUp()
        buildMenu()
        updateLoginItemMenu()
        showMainWindow()
        if UserDefaults.standard.object(forKey: cardVisibilityKey) as? Bool == true {
            showVocabularyCard()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "ieltsvocab" {
            switch url.host {
            case "study":
                let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                let week = query.first(where: { $0.name == "week" })?.value.flatMap(Int.init) ?? 1
                let day = query.first(where: { $0.name == "day" })?.value.flatMap(Int.init) ?? 1
                let word = query.first(where: { $0.name == "word" })?.value
                showStudyRoute(week: min(max(week, 1), 50), day: min(max(day, 1), 6), word: word)
            case "card":
                toggleVocabularyCard()
            default:
                break
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { showMainWindow() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        VocabularySpeech.shared.stop()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let learningWindowController else { return .terminateNow }
        learningWindowController.flushLearningData { saved in
            if saved {
                sender.reply(toApplicationShouldTerminate: true)
            } else {
                let alert = NSAlert()
                alert.messageText = "最新学习进度尚未保存"
                alert.informativeText = "可以取消退出后重试，或先导出学习数据。仍然退出可能丢失最近的修改。"
                alert.addButton(withTitle: "取消退出")
                alert.addButton(withTitle: "仍然退出")
                sender.reply(toApplicationShouldTerminate: alert.runModal() == .alertSecondButtonReturn)
            }
        }
        return .terminateLater
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateStatus()
        updateLoginItemMenu()
    }

    private func buildMenu() {
        buildApplicationMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "book.closed.fill", accessibilityDescription: "IELTS Vocabulary Lab")
            button.image?.isTemplate = true
            button.toolTip = "IELTS Vocabulary Lab"
        }

        let menu = NSMenu()
        menu.delegate = self
        let heading = NSMenuItem(title: "IELTS Vocabulary Lab", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())

        statusLine = NSMenuItem(title: "离线可用 · 数据保存在本机", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        openItem = NSMenuItem(title: "打开学习窗口", action: #selector(openStudyPage), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        cardItem = NSMenuItem(title: "显示桌面单词卡", action: #selector(toggleVocabularyCard), keyEquivalent: "")
        cardItem.target = self
        menu.addItem(cardItem)
        menu.addItem(.separator())

        loginItem = NSMenuItem(title: "登录时启动", action: #selector(toggleLoginAtLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        let quitItem = NSMenuItem(title: "退出 IELTS Vocabulary Lab", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
        updateStatus()
    }

    private func buildApplicationMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 IELTS Vocabulary Lab", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 IELTS Vocabulary Lab", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出 IELTS Vocabulary Lab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: Selector(("cut:")), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: Selector(("copy:")), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: Selector(("paste:")), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: Selector(("selectAll:")), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    @objc private func openStudyPage() {
        showMainWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func showMainWindow() {
        if learningWindowController == nil {
            learningWindowController = LearningWindowController()
        }
        learningWindowController?.showMainWindow()
    }

    private func showStudyRoute(week: Int, day: Int, word: String?) {
        if learningWindowController == nil {
            learningWindowController = LearningWindowController()
        }
        learningWindowController?.showStudy(week: week, day: day, word: word)
    }

    @objc private func toggleVocabularyCard() {
        if let cardController, cardController.window?.isVisible == true {
            cardController.close()
            return
        }
        showVocabularyCard()
    }

    private func showVocabularyCard() {
        let controller = cardController ?? DesktopVocabularyCardWindowController()
        controller.onClose = { [weak self, weak controller] in
            guard let self else { return }
            if self.cardController === controller { self.cardController = nil }
            UserDefaults.standard.set(false, forKey: self.cardVisibilityKey)
            self.updateCardMenu()
        }
        cardController = controller
        controller.showCard()
        UserDefaults.standard.set(true, forKey: cardVisibilityKey)
        updateCardMenu()
    }

    private func updateStatus() {
        statusLine.title = "离线可用 · 数据保存在本机"
        openItem.title = learningWindowController?.window?.isVisible == true ? "显示学习窗口" : "打开学习窗口"
        updateCardMenu()
    }

    private func updateCardMenu() {
        let isVisible = cardController?.window?.isVisible == true
        cardItem.title = isVisible ? "隐藏桌面单词卡" : "显示桌面单词卡"
        cardItem.state = isVisible ? .on : .off
    }

    @objc private func toggleLoginAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else if service.status == .requiresApproval {
                openLoginItemsSettings()
                return
            } else {
                try service.register()
            }
            updateLoginItemMenu()
            if service.status == .requiresApproval {
                openLoginItemsSettings()
                showError("需要允许登录启动", detail: "请在“系统设置 > 通用 > 登录项”中允许 IELTS Vocabulary Lab。")
            }
        } catch {
            showError("设置登录启动失败", detail: error.localizedDescription)
        }
    }

    private func updateLoginItemMenu() {
        switch SMAppService.mainApp.status {
        case .enabled:
            loginItem.title = "登录时启动"
            loginItem.state = .on
            loginItem.isEnabled = true
        case .requiresApproval:
            loginItem.title = "在系统设置中允许登录启动…"
            loginItem.state = .off
            loginItem.isEnabled = true
        case .notRegistered:
            loginItem.title = "登录时启动"
            loginItem.state = .off
            loginItem.isEnabled = true
        case .notFound:
            loginItem.title = "登录时启动不可用"
            loginItem.state = .off
            loginItem.isEnabled = false
        @unknown default:
            loginItem.title = "登录时启动"
            loginItem.state = .off
            loginItem.isEnabled = false
        }
    }

    private func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showError(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
