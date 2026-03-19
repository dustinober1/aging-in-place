import SwiftUI

/// Reusable 5-option horizontal mood picker.
/// Each button shows an emoji for the mood value (1 = very sad, 5 = very happy).
/// The selected mood has an accentColor background circle.
/// All buttons meet the 44pt minimum touch target requirement.
struct MoodPickerView: View {
    @Binding var selectedMood: Int

    private let options: [(value: Int, emoji: String, label: String)] = [
        (1, "😢", "Very sad"),
        (2, "😕", "Sad"),
        (3, "😐", "Neutral"),
        (4, "🙂", "Happy"),
        (5, "😄", "Very happy")
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.value) { option in
                Button {
                    selectedMood = option.value
                } label: {
                    ZStack {
                        Circle()
                            .fill(selectedMood == option.value ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                            .frame(width: A11y.minTouchTarget, height: A11y.minTouchTarget)

                        Text(option.emoji)
                            .font(.title2)
                    }
                }
                .frame(width: A11y.minTouchTarget, height: A11y.minTouchTarget)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(selectedMood == option.value ? [.isSelected] : [])
            }
        }
        .accessibilityLabel("Mood picker")
    }
}

#Preview {
    MoodPickerView(selectedMood: .constant(3))
        .padding()
}
