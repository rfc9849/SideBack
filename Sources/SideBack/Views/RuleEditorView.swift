import SideBackCore
import SwiftUI

struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rule: ApplicationRule
    @State private var error: String?
    let onSave: (ApplicationRule) throws -> Void

    init(rule: ApplicationRule, onSave: @escaping (ApplicationRule) throws -> Void) {
        _rule = State(initialValue: rule)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Application Rule").font(.headline)
            Form {
                TextField("Name", text: $rule.name)
                Picker("Match", selection: $rule.match) {
                    ForEach(ApplicationMatch.allCases, id: \.self) { match in
                        Text(match.title).tag(match)
                    }
                }
                TextField(rule.match == .exact ? "Bundle identifier" : "Bundle ID prefix", text: $rule.bundleIdentifier)
                    .font(.body.monospaced())
                if rule.match == .exact {
                    HStack {
                        Spacer()
                        Button("Choose Application…", action: chooseApplication)
                    }
                } else {
                    Text("Example: com.apple.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Picker("Action", selection: $rule.method) {
                    ForEach(NavigationMethod.allCases, id: \.self) { method in
                        Text(method.title).tag(method)
                    }
                }
                .help(methodDescription)
                if rule.method != .passthrough {
                    Toggle("Enabled", isOn: $rule.isEnabled).toggleStyle(.checkbox)
                }
            }
            .textFieldStyle(.roundedBorder)
            if let error {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save", action: save).keyboardShortcut(.defaultAction)
                    .disabled(rule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || rule.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private var methodDescription: String {
        switch rule.method {
        case .swipe:
            "Simulate a navigation swipe. Compatibility depends on the app and macOS version."
        case .passthrough:
            "Keep native mouse behavior, overriding broader rules."
        }
    }

    private func chooseApplication() {
        guard let application = ApplicationPicker.choose(), let identifier = application.bundleIdentifier else { return }
        rule.name = application.name
        rule.bundleIdentifier = identifier
    }

    private func save() {
        rule.name = rule.name.trimmingCharacters(in: .whitespacesAndNewlines)
        rule.bundleIdentifier = rule.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try onSave(rule)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
