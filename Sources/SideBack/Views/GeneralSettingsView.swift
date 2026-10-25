import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 0)
            PreferenceRow(title: "Startup") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Launch at login", isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    if model.loginRequiresApproval {
                        Button("Approve in Login Items…", action: model.openLoginSettings)
                            .controlSize(.small)
                    }
                }
            }
            PreferenceRow(title: "Menu bar") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Hide menu-bar icon", isOn: Binding(
                        get: { !model.configuration.showMenuBarIcon },
                        set: { model.configuration.showMenuBarIcon = !$0 }
                    ))
                    Text("Open SideBack again to return to Settings.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if !model.isTrusted {
                PreferenceRow(title: "Accessibility") {
                    Button("Grant Access…", action: model.requestPermission)
                        .help("Enable SideBack in Privacy & Security → Accessibility.")
                }
            }
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, 36)
        .padding(.vertical, 28)
    }
}
