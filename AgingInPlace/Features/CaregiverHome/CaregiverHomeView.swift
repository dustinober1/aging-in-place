import SwiftUI
import SwiftData

struct CaregiverHomeView: View {
    /// In a real app this would come from the logged-in caregiver's profile.
    /// For Phase 1 we read from AppStorage (set during onboarding in Plan 02).
    @AppStorage("caregiverName") private var caregiverName: String = "Caregiver"
    @AppStorage("caregiverMemberID") private var caregiverMemberIDString: String = ""

    @Query(sort: \CareRecord.lastModified, order: .reverse)
    private var allRecords: [CareRecord]

    @Query private var members: [CareTeamMember]

    /// The current caregiver's granted categories, derived from their CareTeamMember record.
    private var grantedCategories: Set<PermissionCategory> {
        guard let memberID = UUID(uuidString: caregiverMemberIDString),
              let member = members.first(where: { $0.id == memberID })
        else {
            // No member record yet — default to all categories granted
            return Set(PermissionCategory.allCases)
        }
        return Set(member.grantedCategories)
    }

    /// Recent records filtered to granted categories only (revoked categories hidden entirely).
    private var filteredRecords: [CareRecord] {
        allRecords.filter { grantedCategories.contains($0.category) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    greetingHeader
                    recentActivitySection
                    quickActionsSection
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
            Text("Hello, \(caregiverName)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    "No recent activity",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Care records will appear here.")
                )
                .frame(minHeight: 160)
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredRecords.prefix(20)) { record in
                        ActivityRow(record: record, members: members)
                    }
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink(destination: LogMedicationView(schedule: nil)) {
                    QuickActionLabel(
                        title: "Log Dose",
                        systemImage: "pills.fill"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: LogCareVisitView()) {
                    QuickActionLabel(
                        title: "Log Visit",
                        systemImage: "stethoscope"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: LogMoodView(authorType: .caregiver)) {
                    QuickActionLabel(
                        title: "Log Mood",
                        systemImage: "heart.fill"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: AddEventView()) {
                    QuickActionLabel(
                        title: "Add Appointment",
                        systemImage: "calendar.badge.plus"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: CareHistoryView()) {
                    QuickActionLabel(
                        title: "Care History",
                        systemImage: "clock.arrow.circlepath"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let record: CareRecord
    let members: [CareTeamMember]

    private var authorName: String {
        members.first(where: { $0.id == record.authorMemberID })?.displayName ?? "Unknown"
    }

    private var categoryIcon: String {
        switch record.category {
        case .medications: return "pills.fill"
        case .mood: return "heart.fill"
        case .careVisits: return "cross.case.fill"
        case .calendar: return "calendar"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon)
                .font(.body)
                .frame(width: A11y.minTouchTarget, height: A11y.minTouchTarget)
                .foregroundStyle(Color.accentColor)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(record.category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary)
                Text("by \(authorName)")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Text(record.lastModified.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .frame(minHeight: A11y.minTouchTarget)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.category.displayName) logged by \(authorName), \(record.lastModified.formatted(.relative(presentation: .named)))")
    }
}

// MARK: - Quick Action Label

private struct QuickActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: A11y.minTouchTarget)
        .padding(.vertical, 16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel(title)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Schema(AgingInPlaceSchemaV2.models),
        migrationPlan: AgingInPlaceMigrationPlan.self,
        configurations: [config]
    )
    return CaregiverHomeView()
        .modelContainer(container)
}
