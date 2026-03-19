import SwiftUI
import SwiftData

struct SeniorHomeView: View {
    @Query private var circles: [CareCircle]
    @Query(sort: \MedicationLog.administeredAt, order: .reverse)
    private var recentMedLogs: [MedicationLog]
    @Query(sort: \MoodLog.loggedAt, order: .reverse)
    private var recentMoodLogs: [MoodLog]
    @Query(sort: \CalendarEvent.eventDate, order: .forward)
    private var upcomingEvents: [CalendarEvent]

    private var seniorName: String {
        circles.first?.seniorName ?? "there"
    }

    private var memberCount: Int {
        circles.first?.members.count ?? 0
    }

    // MARK: - Computed summaries

    private var medicationSummary: String {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let todayLogs = recentMedLogs.filter { $0.administeredAt >= today && $0.administeredAt < tomorrow }
        if todayLogs.isEmpty {
            return "No medications today"
        }
        return "\(todayLogs.count) dose\(todayLogs.count == 1 ? "" : "s") logged today"
    }

    private var moodSummary: String {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let todayMoods = recentMoodLogs.filter { $0.loggedAt >= today && $0.loggedAt < tomorrow }
        if let latest = todayMoods.first {
            let emoji: String
            switch latest.moodValue {
            case 1: emoji = "😞"
            case 2: emoji = "😕"
            case 3: emoji = "😐"
            case 4: emoji = "🙂"
            case 5: emoji = "😄"
            default: emoji = "😐"
            }
            return "\(emoji) Mood: \(latest.moodValue)/5"
        }
        return "Not recorded today"
    }

    private var calendarSummary: String {
        let now = Date()
        if let next = upcomingEvents.first(where: { $0.eventDate >= now }) {
            return next.title
        }
        return "No upcoming appointments"
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
            NavigationLink(destination: MedicationListView()) {
                SummaryCardContent(
                    title: "Medications",
                    summary: medicationSummary,
                    systemImage: "pills.fill"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: LogMoodView(authorType: .senior)) {
                SummaryCardContent(
                    title: "Mood",
                    summary: moodSummary,
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

            NavigationLink(destination: CareCalendarView()) {
                SummaryCardContent(
                    title: "Calendar",
                    summary: calendarSummary,
                    systemImage: "calendar"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: CareHistoryView()) {
                SummaryCardContent(
                    title: "Care History",
                    summary: "Browse all care records",
                    systemImage: "clock.arrow.circlepath"
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Schema(AgingInPlaceSchemaV2.models),
        migrationPlan: AgingInPlaceMigrationPlan.self,
        configurations: [config]
    )
    return SeniorHomeView()
        .modelContainer(container)
}
