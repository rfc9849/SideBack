import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable {
    case general
    case buttons
    case applications
    case advanced

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .buttons: "computermouse"
        case .applications: "square.grid.2x2"
        case .advanced: "slider.horizontal.3"
        }
    }

    var size: NSSize {
        NSSize(width: 640, height: self == .applications ? 410 : self == .advanced ? 310 : 220)
    }
}

@MainActor
final class SettingsTabViewController: NSTabViewController {
    init(model: AppModel) {
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        transitionOptions = []
        for page in SettingsPage.allCases {
            let controller = NSHostingController(rootView: SettingsPane(model: model, page: page))
            controller.sizingOptions = []
            controller.preferredContentSize = page.size
            let item = NSTabViewItem(viewController: controller)
            item.identifier = page.rawValue
            item.label = page.title
            item.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: page.title)
            addTabViewItem(item)
        }
        selectedTabViewItemIndex = 0
        preferredContentSize = SettingsPage.general.size
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.toolbar?.displayMode = .iconAndLabel
        view.window?.toolbar?.allowsUserCustomization = false
        resizeToSelectedPage(animated: false)
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        resizeToSelectedPage(animated: true)
    }

    private func resizeToSelectedPage(animated: Bool) {
        guard let identifier = tabView.selectedTabViewItem?.identifier as? String,
              let page = SettingsPage(rawValue: identifier) else { return }
        preferredContentSize = page.size
        guard let window = view.window else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: page.size))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.setFrame(frame, display: true, animate: animated && window.isVisible)
    }
}

private struct SettingsPane: View {
    @ObservedObject var model: AppModel
    let page: SettingsPage
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.persistenceError {
                Text(error).font(.caption).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
            switch page {
            case .general: GeneralSettingsView(model: model)
            case .buttons: ButtonsSettingsView(model: model)
            case .applications: ApplicationsSettingsView(model: model)
            case .advanced: StatusSettingsView(model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .alert("SideBack", isPresented: Binding(
            get: { isVisible && model.errorMessage != nil },
            set: { if !$0 && isVisible { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct PreferenceRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text(title).foregroundStyle(.secondary).frame(width: 148, alignment: .trailing)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
