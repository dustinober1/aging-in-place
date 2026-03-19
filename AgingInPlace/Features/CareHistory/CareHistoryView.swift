import SwiftUI
import SwiftData

// MARK: - CareHistoryEntry

/// A unified timeline entry representing any care record type.
struct CareHistoryEntry: Identifiable {
    let id: UUID
    let category: PermissionCategory
    let date: Date
    let authorMemberID: UUID
    let summary: String
    let detail: String?
}

// MARK: - Date Range Filter

enum HistoryDateRange: String, CaseIterable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case all = "All Time"

    func includes(_ date: Date) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        switch self {
        case .today:
            return calendar.isDateInToday(date)
        case .week:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return true }
            return date >= weekAgo
        case .month:
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else { return true }
            return date >= monthAgo
        case .all:
            return true
        }
    }
}

// MARK: - Author Filter

enum HistoryAuthorFilter: Equatable {
    case all
    case me(UUID)
}

// MARK: - CareHistoryView

struct CareHistoryView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \MedicationLog.administeredAt, order: .reverse)
    private var medicationLogs: [MedicationLog]

    @Query(sort: \CareVisitLog.visitDate, order: .reverse)
    private var visitLogs: [CareVisitLog]

    @Query(sort: \MoodLog.loggedAt, order: .reverse)
    private var moodLogs: [MoodLog]

    @Query private var members: [CareTeamMember]

    @State private var searchText: String = ""
    @State private var selectedCategory: PermissionCategory? = nil
    @State private var selectedDateRange: HistoryDateRange = .all

    // MARK: - Merge and filter

    private var allEntries: [CareHistoryEntry] {
        var entries: [CareHistoryEntry] = []

        // MedicationLogs
        for log in medicationLogs {
            let summary: String
            let detail: String?
            if let plain = try? EncryptionService.open(log.encryptedPayload, for: .medications),
               let decoded = try? JSONDecoder().decode(MedPayload.self, from: plain) {
                summary = "\(decoded.drugName) \(decoded.dose)"
                detail = decoded.notes.isEmpty ? nil : decoded.notes
            } else {
                summary = "Medication"
                detail = nil
            }
            entries.append(CareHistoryEntry(
                id: log.id,
                category: .medications,
                date: log.administeredAt,
                authorMemberID: log.authorMemberID,
                summary: summary,
                detail: detail
            ))
        }

        // CareVisitLogs
        for log in visitLogs {
            let summary: String
            let detail: String?
            if let plain = try? EncryptionService.open(log.encryptedPayload, for: .careVisits),
               let decoded = try? JSONDecoder().decode(VisitPayload.self, from: plain) {
                let firstField = [decoded.meals, decoded.mobility, decoded.observations, decoded.concerns]
                    .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                summary = firstField ?? "Care Visit"
                detail = nil
            } else {
                summary = "Care Visit"
                detail = nil
            }
            entries.append(CareHistoryEntry(
                id: log.id,
                category: .careVisits,
                date: log.visitDate,
                authorMemberID: log.authorMemberID,
                summary: summary,
                detail: detail
            ))
        }

        // MoodLogs
        for log in moodLogs {
            let emoji = moodEmoji(for: log.moodValue)
            let authorLabel = log.authorType == .senior ? "Self" : "Caregiver"
            let summary = "\(emoji) Mood: \(log.moodValue)/5 (\(authorLabel))"
            entries.append(CareHistoryEntry(
                id: log.id,
                category: .mood,
                date: log.loggedAt,
                authorMemberID: log.authorMemberID,
                summary: summary,
                detail: nil
            ))
        }

        // Sort descending by date
        return entries.sorted { $0.date > $1.date }
    }

    private var filteredEntries: [CareHistoryEntry] {
        allEntries.filter { entry in
            // Category filter
            if let cat = selectedCategory, entry.category != cat {
                return false
            }
            // Date range filter
            if !selectedDateRange.includes(entry.date) {
                return false
            }
            // Keyword search (in-memory, case-insensitive against decrypted summary)
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                let matchSummary = entry.summary.localizedCaseInsensitiveContains(term)
                let matchDetail = entry.detail?.localizedCaseInsensitiveContains(term) ?? false
                if !matchSummary && !matchDetail {
                    return false
                }
            }
            return true
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterControls
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        "No Records Found",
                        systemImage: "clock.arrow.circlepath",
                        description: Text(searchText.isEmpty ? "No care records match the selected filters." : "No records match \"\(searchText)\".")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredEntries) { entry in
                            CareHistoryRow(entry: entry, authorName: authorName(for: entry.authorMemberID))
                                .frame(minHeight: A11y.minTouchTarget)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Care History")
            .navigationBarTitleDisplayMode(.inline)
        }
        .searchable(text: $searchText, prompt: "Search care records")
    }

    // MARK: - Filter Controls

    private var filterControls: some View {
        VStack(spacing: 8) {
            // Category picker
            Picker("Category", selection: $selectedCategory) {
                Text("All").tag(PermissionCategory?.none)
                ForEach(PermissionCategory.allCases, id: \.self) { cat in
                    Text(cat.displayName).tag(Optional(cat))
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Filter by category")

            // Date range picker
            Picker("Date Range", selection: $selectedDateRange) {
                ForEach(HistoryDateRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Filter by date range")
        }
    }

    // MARK: - Helpers

    private func authorName(for memberID: UUID) -> String {
        members.first(where: { $0.id == memberID })?.displayName ?? "Unknown"
    }

    private func moodEmoji(for value: Int) -> String {
        switch value {
        case 1: return "😞"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😄"
        default: return "😐"
        }
    }

    // MARK: - Codable payload structs (private)

    private struct MedPayload: Codable {
        let drugName: String
        let dose: String
        let notes: String
    }

    private struct VisitPayload: Codable {
        let meals: String
        let mobility: String
        let observations: String
        let concerns: String
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Schema(AgingInPlaceSchemaV2.models),
        migrationPlan: AgingInPlaceMigrationPlan.self,
        configurations: [config]
    )
    return CareHistoryView()
        .modelContainer(container)
}
