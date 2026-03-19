import SwiftUI
import SwiftData

struct SeniorHomeView: View {
    @Query private var circles: [CareCircle]

    private var seniorName: String {
        circles.first?.seniorName ?? "there"
    }

    private var memberCount: Int {
        circles.first?.members.count ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    greetingHeader
                    cardList
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: EmergencyContactListView()) {
                        Label("Emergency Contacts", systemImage: "cross.case.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(Color.red)
                    }
                    .accessibilityLabel("Emergency Contacts")
                }
            }
        }
    }

    // MARK: - Greeting

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingForTimeOfDay())
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Cards

    private var cardList: some View {
        VStack(spacing: 16) {
            NavigationLink(destination: PlaceholderDetailView(title: "Medications")) {
                SummaryCardContent(
                    title: "Medications",
                    summary: "No medications yet",
                    systemImage: "pills.fill"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: PlaceholderDetailView(title: "Mood")) {
                SummaryCardContent(
                    title: "Mood",
                    summary: "Not recorded today",
                    systemImage: "heart.fill"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: CareTeamListView(embedded: true)) {
                SummaryCardContent(
                    title: "Care Team",
                    summary: memberCount == 0 ? "No members yet" : "\(memberCount) member\(memberCount == 1 ? "" : "s")",
                    systemImage: "person.3.fill"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: PlaceholderDetailView(title: "Calendar")) {
                SummaryCardContent(
                    title: "Calendar",
                    summary: "No upcoming appointments",
                    systemImage: "calendar"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    /// Returns time-of-day greeting for the senior.
    /// - morning: 0–11, afternoon: 12–16, evening: 17–23
    func greetingForTimeOfDay(hour: Int? = nil) -> String {
        let currentHour = hour ?? Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch currentHour {
        case 0..<12:
            timeOfDay = "Good morning"
        case 12..<17:
            timeOfDay = "Good afternoon"
        default:
            timeOfDay = "Good evening"
        }
        return "\(timeOfDay), \(seniorName)"
    }
}

/// Placeholder destination view for Phase 2 features.
struct PlaceholderDetailView: View {
    let title: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "clock",
            description: Text("This feature is coming soon.")
        )
        .navigationTitle(title)
    }
}

#Preview {
    SeniorHomeView()
        .modelContainer(for: [CareCircle.self, EmergencyContact.self], inMemory: true)
}
