import AppKit
import SideBackCore
import SwiftUI

struct ApplicationsSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var search = ""
    @State private var applications: [InstalledApplication] = []
    @State private var isScanning = false
    @State private var showingRules = false
    @State private var editingRule: ApplicationRule?

    private var filteredApplications: [InstalledApplication] {
        var catalog = Dictionary(uniqueKeysWithValues: applications.map { ($0.bundleIdentifier, $0) })
        for rule in model.configuration.rules where rule.match == .exact && rule.bundleIdentifier != Bundle.main.bundleIdentifier {
            if catalog[rule.bundleIdentifier] == nil {
                catalog[rule.bundleIdentifier] = .init(name: rule.name, bundleIdentifier: rule.bundleIdentifier, url: nil)
            }
        }
        return ApplicationList.ordered(Array(catalog.values), query: search, configuration: model.configuration)
    }

    var body: some View {
        VStack(spacing: 12) {
            ApplicationSearchField(text: $search).frame(height: 24)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredApplications) { application in
                        ApplicationCheckboxRow(
                            application: application,
                            isEnabled: Binding(
                                get: { resolution(for: application).method != .passthrough },
                                set: { model.setApplicationEnabled($0, name: application.name, bundleIdentifier: application.bundleIdentifier) }
                            )
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contextMenu {
                            Button("Customize…") {
                                editingRule = model.configuration.rules.first {
                                    $0.match == .exact && $0.bundleIdentifier == application.bundleIdentifier
                                } ?? .init(name: application.name, bundleIdentifier: application.bundleIdentifier)
                            }
                        }
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .border(Color(nsColor: .separatorColor))
            .overlay {
                if filteredApplications.isEmpty {
                    Text(isScanning ? "Scanning applications…" : search.isEmpty ? "No applications found" : "No matching applications")
                        .foregroundStyle(.secondary).allowsHitTesting(false)
                }
            }
            HStack(spacing: 8) {
                if isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Text("\(filteredApplications.count) applications").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await refreshApplications() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Rescan application folders")
                .disabled(isScanning)
                Button("Rules…") { showingRules = true }
            }
            .controlSize(.small)
        }
        .padding(24)
        .task { await refreshApplications() }
        .sheet(isPresented: $showingRules) { ApplicationRulesView(model: model) }
        .sheet(item: $editingRule) { rule in
            RuleEditorView(rule: rule) { try model.saveRule($0) }
        }
    }

    private func resolution(for application: InstalledApplication) -> ResolvedRule {
        RuleResolver.resolve(bundleIdentifier: application.bundleIdentifier, configuration: model.configuration)
    }

    private func refreshApplications() async {
        isScanning = true
        let identifier = Bundle.main.bundleIdentifier
        let scan = Task.detached(priority: .userInitiated) {
            InstalledApplicationScanner.scan(excluding: identifier)
        }
        let result = await withTaskCancellationHandler {
            await scan.value
        } onCancel: {
            scan.cancel()
        }
        guard !Task.isCancelled else { return }
        applications = result
        isScanning = false
    }
}

private struct ApplicationCheckboxRow: View {
    let application: InstalledApplication
    @Binding var isEnabled: Bool
    @State private var icon: NSImage?

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack(spacing: 10) {
                if let icon {
                    Image(nsImage: icon).resizable().frame(width: 24, height: 24)
                } else {
                    Image(systemName: "app").font(.title2).frame(width: 24, height: 24).foregroundStyle(.secondary)
                }
                Text(application.name)
                Spacer()
            }
        }
        .toggleStyle(.checkbox)
        .padding(.vertical, 3)
        .help(application.bundleIdentifier)
        .task(id: application.url) {
            await Task.yield()
            guard !Task.isCancelled, let url = application.url else { return }
            icon = NSWorkspace.shared.icon(forFile: url.path)
        }
    }
}
