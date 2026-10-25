import SwiftUI

struct ButtonsSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 0)
            PreferenceRow(title: "Side buttons") {
                Toggle("Enable back and forward", isOn: $model.configuration.isEnabled)
            }
            PreferenceRow(title: "Direction") {
                Toggle("Swap back and forward", isOn: $model.configuration.swapButtons)
            }
            Spacer(minLength: 0)
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, 36)
        .padding(.vertical, 28)
    }
}
