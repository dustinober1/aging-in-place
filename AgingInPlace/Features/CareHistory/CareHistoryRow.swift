import SwiftUI

/// A single row in the unified care history timeline.
struct CareHistoryRow: View {
    let entry: CareHistoryEntry
    let authorName: String

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: categoryIcon)
                .font(.body)
                .frame(width: A11y.minTouchTarget, height: A11y.minTouchTarget)
                .foregroundStyle(categoryColor)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            // Summary and author
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)

                if let detail = entry.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                Text("by \(authorName)")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            // Relative date
            Text(entry.date.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: A11y.minTouchTarget)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.category.displayName): \(entry.summary), by \(authorName), \(entry.date.formatted(.relative(presentation: .named)))")
    }

    // MARK: - Helpers

    private var categoryIcon: String {
        switch entry.category {
        case .medications: return "pills.fill"
        case .mood: return "heart.fill"
        case .careVisits: return "stethoscope"
        case .calendar: return "calendar"
        }
    }

    private var categoryColor: Color {
        switch entry.category {
        case .medications: return Color.blue
        case .mood: return Color.pink
        case .careVisits: return Color.green
        case .calendar: return Color.orange
        }
    }
}

#Preview {
    let entry = CareHistoryEntry(
        id: UUID(),
        category: .medications,
        date: Date().addingTimeInterval(-3600),
        authorMemberID: UUID(),
        summary: "Metformin 500mg",
        detail: nil
    )
    return CareHistoryRow(entry: entry, authorName: "Alice")
        .padding()
}
