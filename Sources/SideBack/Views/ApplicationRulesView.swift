import AppKit
import SideBackCore
import SwiftUI

struct ApplicationRulesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: AppModel
    @State private var selection: UUID?
    @State private var editingRule: ApplicationRule?
    @State private var confirmingDelete = false

    private var selectedRule: ApplicationRule? {
        model.configuration.rules.first { $0.id == selection }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Application Rules").font(.headline)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 10) {
                Picker("Other applications:", selection: $model.configuration.defaultMethod) {
                    ForEach(NavigationMethod.allCases, id: \.self) { method in
                        Text(method.title).tag(method)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            List(selection: $selection) {
                ForEach(model.configuration.rules) { rule in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.name)
                            Text(rule.bundleIdentifier + (rule.match == .prefix ? "*" : ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(rule.isEnabled ? rule.method.title : NavigationMethod.passthrough.title)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                    .tag(rule.id)
                    .onTapGesture(count: 2) { editingRule = rule }
                }
            }
            .listStyle(.plain)
            .border(Color(nsColor: .separatorColor))
            HStack(spacing: 8) {
                Menu {
                    Button("Choose Application…", action: chooseApplication)
                    Button("Bundle Identifier or Prefix…") {
                        editingRule = .init(name: "", bundleIdentifier: "")
                    }
                    Divider()
                    Button("All Apple Apps", action: model.addApplePreset)
                } label: {
                    Image(systemName: "plus")
                }
                .fixedSize()
                .help("Add application or prefix")
                Button("Edit…") { editingRule = selectedRule }.disabled(selectedRule == nil)
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Image(systemName: "minus")
                }
                .disabled(selectedRule == nil)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 570, height: 400)
        .sheet(item: $editingRule) { rule in
            RuleEditorView(rule: rule) { try model.saveRule($0) }
        }
        .confirmationDialog("Remove \(selectedRule?.name ?? "this rule")?", isPresented: $confirmingDelete) {
            Button("Remove Rule", role: .destructive) {
                if let selection { model.deleteRule(id: selection) }
                selection = nil
            }
        } message: {
            Text("The application will inherit its prefix rule or the unlisted-app setting.")
        }
    }

    private func chooseApplication() {
        guard let application = ApplicationPicker.choose(), let identifier = application.bundleIdentifier else { return }
        editingRule = model.configuration.rules.first { $0.match == .exact && $0.bundleIdentifier == identifier }
            ?? .init(name: application.name, bundleIdentifier: identifier)
    }
}
