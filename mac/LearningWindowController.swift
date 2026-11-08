import AppKit
import Combine
import SwiftUI

@MainActor
private final class NativeAppearanceAccessoryController: NSTitlebarAccessoryViewController {
    private let model: NativeAppModel
    private let appearanceControl: NSSegmentedControl
    private var modelSubscription: AnyCancellable?

    init(model: NativeAppModel) {
        self.model = model
        let images = [
            NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "跟随系统")!,
            NSImage(systemSymbolName: "sun.max", accessibilityDescription: "浅色")!,
            NSImage(systemSymbolName: "moon", accessibilityDescription: "深色")!
        ]
        appearanceControl = NSSegmentedControl(images: images, trackingMode: .selectOne, target: nil, action: nil)
        super.init(nibName: nil, bundle: nil)

        layoutAttribute = .trailing
        appearanceControl.frame = NSRect(x: 0, y: 0, width: 116, height: 28)
        appearanceControl.controlSize = .small
        appearanceControl.target = self
        appearanceControl.action = #selector(changeAppearance(_:))
        appearanceControl.toolTip = "切换应用外观：跟随系统、浅色或深色"
        appearanceControl.setAccessibilityLabel("应用外观")
        appearanceControl.setAccessibilityHelp("跟随系统、浅色或深色")
        for index in 0..<appearanceControl.segmentCount {
            appearanceControl.setWidth(34, forSegment: index)
        }
        view = appearanceControl

        modelSubscription = model.$appearance
            .removeDuplicates()
            .sink { [weak self] preference in
                self?.appearanceControl.selectedSegment = Self.segment(for: preference)
            }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func changeAppearance(_ sender: NSSegmentedControl) {
        let preferences = ["system", "light", "dark"]
        guard preferences.indices.contains(sender.selectedSegment) else { return }
        let preference = preferences[sender.selectedSegment]
        sender.selectedSegment = Self.segment(for: preference)
        model.appearance = preference
        view.window?.appearance = Self.windowAppearance(for: preference)
    }

    private static func segment(for preference: String) -> Int {
        switch preference {
        case "light": 1
        case "dark": 2
        default: 0
        }
    }

    private static func windowAppearance(for preference: String) -> NSAppearance? {
        switch preference {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }
}

@MainActor
final class LearningWindowController: NSWindowController {
    private let model = NativeAppModel()
    private var appearanceSubscription: AnyCancellable?
    private var appearanceAccessory: NSTitlebarAccessoryViewController?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1160, height: 790),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "IELTS Vocabulary Lab"
        window.minSize = NSSize(width: 740, height: 500)
        window.setFrameAutosaveName("IELTSVocabularyLab.MainWindow")
        super.init(window: window)
        appearanceSubscription = model.$appearance
            .removeDuplicates()
            .sink { [weak window] preference in
                window?.appearance = Self.windowAppearance(for: preference)
            }
        window.contentViewController = NSHostingController(rootView: NativeRootView(model: model) { [weak self] in
            self?.removeAutomaticSidebarToggle()
        })
        window.toolbar = nil
        let accessory = NativeAppearanceAccessoryController(model: model)
        window.addTitlebarAccessoryViewController(accessory)
        appearanceAccessory = accessory
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func showStudy(week: Int, day: Int, word: String?) {
        model.openRoute(week: week, day: day, word: word)
        showMainWindow()
    }

    func showMainWindow() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        removeAutomaticSidebarToggle()
        for delay in [0.05, 0.25] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.removeAutomaticSidebarToggle()
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func flushLearningData(completion: @escaping (Bool) -> Void) {
        completion(model.store.flush())
    }

    private static func windowAppearance(for preference: String) -> NSAppearance? {
        switch preference {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }

    private func removeAutomaticSidebarToggle() {
        guard let toolbar = window?.toolbar else { return }
        for index in toolbar.items.indices.reversed()
        where toolbar.items[index].itemIdentifier.rawValue.localizedCaseInsensitiveContains("sidebar")
            || toolbar.items[index].label.localizedCaseInsensitiveContains("sidebar")
            || toolbar.items[index].paletteLabel.localizedCaseInsensitiveContains("sidebar") {
            toolbar.removeItem(at: index)
        }
        toolbar.isVisible = false
    }
}
