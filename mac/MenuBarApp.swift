import AppKit
import Foundation

final class MenuBarAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var statusTimer: Timer?
    private var isRunning = false
    private var isBusy = false
    private var serverURL: URL?
    private var statusLine: NSMenuItem!
    private var openItem: NSMenuItem!
    private var stopItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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

        statusLine = NSMenuItem(title: "正在检查服务…", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        openItem = NSMenuItem(title: "打开学习页面", action: #selector(openStudyPage), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        stopItem = NSMenuItem(title: "停止服务", action: #selector(stopServer), keyEquivalent: "")
        stopItem.target = self
        menu.addItem(stopItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出并停止服务", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        statusTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
        refreshStatus()
        runLauncher(["start", "--no-open"]) { [weak self] result, error in
            guard let self else { return }
            if let error {
                self.showError("启动失败", detail: error)
            } else if let urlString = result?["url"] as? String, let url = URL(string: urlString) {
                self.serverURL = url
                NSWorkspace.shared.open(url)
            }
            self.refreshStatus()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusTimer?.invalidate()
        runLauncherSynchronously(["stop"])
    }

    @objc private func openStudyPage() {
        guard !isBusy else { return }
        if isRunning, let serverURL {
            NSWorkspace.shared.open(serverURL)
            return
        }
        isBusy = true
        updateMenu()
        runLauncher(["start", "--no-open"]) { [weak self] result, error in
            guard let self else { return }
            self.isBusy = false
            if let error {
                self.showError("启动失败", detail: error)
            } else if let urlString = result?["url"] as? String, let url = URL(string: urlString) {
                self.serverURL = url
                NSWorkspace.shared.open(url)
            }
            self.refreshStatus()
        }
    }

    @objc private func stopServer() {
        guard !isBusy, isRunning else { return }
        isBusy = true
        updateMenu()
        runLauncher(["stop"]) { [weak self] _, error in
            guard let self else { return }
            self.isBusy = false
            self.serverURL = nil
            if let error {
                self.showError("停止失败", detail: error)
            }
            self.refreshStatus()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func refreshStatus() {
        runLauncher(["status"]) { [weak self] result, _ in
            guard let self, let result else { return }
            self.isRunning = result["running"] as? Bool ?? false
            if let urlString = result["url"] as? String {
                self.serverURL = URL(string: urlString)
            } else {
                self.serverURL = nil
            }
            self.updateMenu()
        }
    }

    private func updateMenu() {
        if isBusy {
            statusLine.title = "正在处理…"
        } else if isRunning {
            let port = serverURL?.port.map(String.init) ?? ""
            statusLine.title = port.isEmpty ? "服务运行中" : "服务运行中 · \(port)"
        } else {
            statusLine.title = "服务已停止"
        }
        openItem.isEnabled = !isBusy
        stopItem.isEnabled = isRunning && !isBusy
    }

    private var projectRoot: URL {
        Bundle.main.bundleURL.deletingLastPathComponent()
    }

    private var launcherPath: URL {
        projectRoot.appendingPathComponent("launcher.py")
    }

    private func pythonPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/usr/bin/python3",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func runLauncher(
        _ arguments: [String],
        completion: @escaping ([String: Any]?, String?) -> Void
    ) {
        guard let python = pythonPath() else {
            completion(nil, "找不到 Python 3。请安装 Python 3 后重试。")
            return
        }
        guard FileManager.default.fileExists(atPath: launcherPath.path) else {
            completion(nil, "启动器文件不存在：\(launcherPath.path)")
            return
        }

        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [launcherPath.path] + arguments
        process.currentDirectoryURL = projectRoot
        process.standardOutput = output
        process.standardError = errors
        process.terminationHandler = { process in
            let stdout = output.fileHandleForReading.readDataToEndOfFile()
            let stderr = errors.fileHandleForReading.readDataToEndOfFile()
            let outputText = String(data: stdout, encoding: .utf8) ?? ""
            let errorText = String(data: stderr, encoding: .utf8) ?? ""
            var payload: [String: Any]?
            if let data = outputText.data(using: .utf8) {
                payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            }
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    completion(payload, nil)
                } else {
                    let detail = errorText.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(nil, detail.isEmpty ? "启动器退出代码：\(process.terminationStatus)" : detail)
                }
            }
        }
        do {
            try process.run()
        } catch {
            completion(nil, error.localizedDescription)
        }
    }

    private func runLauncherSynchronously(_ arguments: [String]) {
        guard let python = pythonPath() else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [launcherPath.path] + arguments
        process.currentDirectoryURL = projectRoot
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
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

let app = NSApplication.shared
let delegate = MenuBarAppDelegate()
app.delegate = delegate
app.run()
