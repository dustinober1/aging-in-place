import SwiftUI

/// Reusable large tappable card for the senior home screen.
/// Uses `ViewThatFits` to switch from HStack to VStack at larger accessibility text sizes.
struct SummaryCardView: View {
    let title: String
    let summary: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                // Default: horizontal layout
                cardContent(horizontal: true)
                // AX large text fallback: vertical layout
                cardContent(horizontal: false)
            }
        }
        .frame(minHeight: A11y.minTouchTarget)
        .accessibilityLabel("\(title): \(summary)")
        .accessibilityHint("Double tap to open")
    }

    @ViewBuilder
    private func cardContent(horizontal: Bool) -> some View {
        let icon = Image(systemName: systemImage)
            .font(.title2)
            .frame(width: A11y.minTouchTarget, height: A11y.minTouchTarget)
            .foregroundStyle(Color.accentColor)

        let textStack = VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        let chevron = Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(Color.secondary)

        Group {
            if horizontal {
                HStack(spacing: 12) {
                    icon
                    textStack
                    chevron
                }
                .padding(16)
                .frame(minHeight: A11y.minCardHeight)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        icon
                        Spacer()
                        chevron
                    }
                    textStack
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: A11y.minCardHeight)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

/// Non-button version for use inside NavigationLink.
struct SummaryCardContent: View {
    let title: String
    let summary: String
    let systemImage: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            cardContent(horizontal: true)
            cardContent(horizontal: false)
        }
        .frame(minHeight: A11y.minTouchTarget)
        .accessibilityLabel("\(title): \(summary)")
    }

    @ViewBuilder
    private func cardContent(horizontal: Bool) -> some View {
        let icon = Image(systemName: systemImage)
            .font(.title2)
            .frame(width: A11y.minTouchTarget, height: A11y.minTouchTarget)
            .foregroundStyle(Color.accentColor)

        let textStack = VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        let chevron = Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(Color.secondary)

        Group {
            if horizontal {
                HStack(spacing: 12) {
                    icon
                    textStack
                    chevron
                }
                .padding(16)
                .frame(minHeight: A11y.minCardHeight)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        icon
                        Spacer()
                        chevron
                    }
                    textStack
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: A11y.minCardHeight)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SummaryCardView(
            title: "Medications",
            summary: "No medications yet",
            systemImage: "pills.fill"
        ) {}
        SummaryCardView(
            title: "Mood",
            summary: "Not recorded today",
            systemImage: "heart.fill"
        ) {}
    }
    .padding()
}
