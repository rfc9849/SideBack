import SwiftUI

struct StatusSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var showingAbout = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PreferenceRow(title: "Accessibility") {
                        HStack {
                            Text(model.isTrusted ? "Granted" : "Not granted")
                            Spacer()
                            Button("Settings…", action: model.requestPermission)
                        }
                    }
                    PreferenceRow(title: "Listener") {
                        HStack {
                            Text(model.statusTitle)
                            Spacer()
                            Button("Reconnect", action: model.retryListener)
                        }
                    }
                    if case .failed(let reason) = model.engineStatus {
                        PreferenceRow(title: "") {
                            Text(reason).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    PreferenceRow(title: "Foreground app") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.activeApplicationName)
                            Text(model.activeBundleIdentifier ?? "Unknown bundle identifier")
                                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    PreferenceRow(title: "Matching rule") {
                        Text(model.resolvedRule.ruleName ?? "Unlisted applications")
                    }
                }
                .padding(28)
            }
            HStack {
                Button("About SideBack") { showingAbout = true }
                    .buttonStyle(.link)
                    .popover(isPresented: $showingAbout) { AboutView() }
                Spacer()
                Button("Quit SideBack") { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
    }
}
