import XCTest
import SwiftData
@testable import AgingInPlace

final class CareHistoryTests: XCTestCase {

    // MARK: - Container helper

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Schema(AgingInPlaceSchemaV2.models),
            migrationPlan: AgingInPlaceMigrationPlan.self,
            configurations: [config]
        )
    }

    // MARK: - Helpers

    private func makeEncryptedMedPayload(drugName: String, dose: String = "10mg", notes: String = "") throws -> Data {
        struct MedPayload: Codable {
            let drugName: String
            let dose: String
            let notes: String
        }
        let payload = MedPayload(drugName: drugName, dose: dose, notes: notes)
        let json = try JSONEncoder().encode(payload)
        return try EncryptionService.seal(json, for: .medications)
    }

    private func makeEncryptedVisitPayload(meals: String = "", mobility: String = "", observations: String = "", concerns: String = "") throws -> Data {
        struct VisitPayload: Codable {
            let meals: String
            let mobility: String
            let observations: String
            let concerns: String
        }
        let payload = VisitPayload(meals: meals, mobility: mobility, observations: observations, concerns: concerns)
        let json = try JSONEncoder().encode(payload)
        return try EncryptionService.seal(json, for: .careVisits)
    }

    // MARK: - Test 1: Unified timeline: merge by date descending

    func testUnifiedTimelineMergedByDateDescending() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()

        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-172800)

        // CareVisitLog today, MedicationLog yesterday, MoodLog 2 days ago
        let visitLog = CareVisitLog(
            encryptedPayload: try makeEncryptedVisitPayload(observations: "Good mobility"),
            visitDate: now,
            authorMemberID: memberID
        )
        let medLog = MedicationLog(
            encryptedPayload: try makeEncryptedMedPayload(drugName: "Aspirin"),
            administeredAt: yesterday,
            authorMemberID: memberID
        )
        let moodLog = MoodLog(
            moodValue: 4,
            authorMemberID: memberID,
            authorType: .senior
        )
        moodLog.loggedAt = twoDaysAgo

        context.insert(visitLog)
        context.insert(medLog)
        context.insert(moodLog)
        try context.save()

        // Fetch all three types
        let medLogs = try context.fetch(FetchDescriptor<MedicationLog>())
        let visitLogs = try context.fetch(FetchDescriptor<CareVisitLog>())
        let moodLogs = try context.fetch(FetchDescriptor<MoodLog>())

        // Build unified entries and sort by date descending
        var entries: [(date: Date, category: PermissionCategory)] = []
        for log in medLogs {
            entries.append((date: log.administeredAt, category: .medications))
        }
        for log in visitLogs {
            entries.append((date: log.visitDate, category: .careVisits))
        }
        for log in moodLogs {
            entries.append((date: log.loggedAt, category: .mood))
        }
        let sorted = entries.sorted { $0.date > $1.date }

        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].category, .careVisits,  "CareVisitLog (today) should be first")
        XCTAssertEqual(sorted[1].category, .medications, "MedicationLog (yesterday) should be second")
        XCTAssertEqual(sorted[2].category, .mood,        "MoodLog (2 days ago) should be third")
    }

    // MARK: - Test 2: Category filter returns only matching entries

    func testCategoryFilterReturnsOnlyMatchingType() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()
        let now = Date()

        let medLog = MedicationLog(
            encryptedPayload: try makeEncryptedMedPayload(drugName: "Lisinopril"),
            administeredAt: now,
            authorMemberID: memberID
        )
        let visitLog = CareVisitLog(
            encryptedPayload: try makeEncryptedVisitPayload(),
            visitDate: now,
            authorMemberID: memberID
        )
        let moodLog = MoodLog(moodValue: 3, authorMemberID: memberID, authorType: .senior)

        context.insert(medLog)
        context.insert(visitLog)
        context.insert(moodLog)
        try context.save()

        // Build all entries
        struct HistoryEntry { let category: PermissionCategory; let date: Date }
        var allEntries: [HistoryEntry] = []
        for log in try context.fetch(FetchDescriptor<MedicationLog>()) {
            allEntries.append(HistoryEntry(category: .medications, date: log.administeredAt))
        }
        for log in try context.fetch(FetchDescriptor<CareVisitLog>()) {
            allEntries.append(HistoryEntry(category: .careVisits, date: log.visitDate))
        }
        for log in try context.fetch(FetchDescriptor<MoodLog>()) {
            allEntries.append(HistoryEntry(category: .mood, date: log.loggedAt))
        }

        // Filter to .medications only
        let filtered = allEntries.filter { $0.category == .medications }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].category, .medications)
        // Other categories should not be present
        XCTAssertFalse(filtered.contains(where: { $0.category == .careVisits }))
        XCTAssertFalse(filtered.contains(where: { $0.category == .mood }))
    }

    // MARK: - Test 3: Date range filter returns only records within range

    func testDateRangeFilterReturnsOnlyRecordsInRange() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()

        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let endOfToday = startOfToday.addingTimeInterval(86400)
        let yesterday = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-172800)

        // Three medication logs: today, yesterday, 2 days ago
        let todayMed = MedicationLog(
            encryptedPayload: try makeEncryptedMedPayload(drugName: "A"),
            administeredAt: now,
            authorMemberID: memberID
        )
        let yesterdayMed = MedicationLog(
            encryptedPayload: try makeEncryptedMedPayload(drugName: "B"),
            administeredAt: yesterday,
            authorMemberID: memberID
        )
        let oldMed = MedicationLog(
            encryptedPayload: try makeEncryptedMedPayload(drugName: "C"),
            administeredAt: twoDaysAgo,
            authorMemberID: memberID
        )

        context.insert(todayMed)
        context.insert(yesterdayMed)
        context.insert(oldMed)
        try context.save()

        // Fetch all and filter to today only
        let all = try context.fetch(FetchDescriptor<MedicationLog>())
        let todayOnly = all.filter { $0.administeredAt >= startOfToday && $0.administeredAt < endOfToday }

        XCTAssertEqual(todayOnly.count, 1, "Only 1 record should be from today")
        // Verify it's the today entry by checking time proximity
        let diff = abs(todayOnly[0].administeredAt.timeIntervalSinceNow)
        XCTAssertLessThan(diff, 5.0, "The today record should be within 5 seconds of now")
    }

    // MARK: - Test 4: Keyword search on decrypted content matches expected records

    func testKeywordSearchMatchesDecryptedContent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()
        let now = Date()

        // Insert a MedicationLog with "Metformin" in its encrypted payload
        let metforminPayload = try makeEncryptedMedPayload(drugName: "Metformin", dose: "500mg")
        let aspirinPayload = try makeEncryptedMedPayload(drugName: "Aspirin", dose: "81mg")

        let metforminLog = MedicationLog(encryptedPayload: metforminPayload, administeredAt: now, authorMemberID: memberID)
        let aspirinLog   = MedicationLog(encryptedPayload: aspirinPayload,   administeredAt: now, authorMemberID: memberID)

        context.insert(metforminLog)
        context.insert(aspirinLog)
        try context.save()

        // Fetch and decrypt all, build summaries
        struct MedPayload: Codable { let drugName: String; let dose: String; let notes: String }
        let all = try context.fetch(FetchDescriptor<MedicationLog>())
        var matches: [MedicationLog] = []
        let searchTerm = "metformin"

        for log in all {
            if let plain = try? EncryptionService.open(log.encryptedPayload, for: .medications),
               let decoded = try? JSONDecoder().decode(MedPayload.self, from: plain) {
                let summary = "\(decoded.drugName) \(decoded.dose)"
                if summary.localizedCaseInsensitiveContains(searchTerm) {
                    matches.append(log)
                }
            }
        }

        XCTAssertEqual(matches.count, 1, "Only Metformin log should match 'metformin' search")
    }

    // MARK: - Test 5: Empty search string returns all records

    func testEmptySearchStringReturnsAllRecords() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let memberID = UUID()
        let now = Date()

        let med1 = MedicationLog(encryptedPayload: try makeEncryptedMedPayload(drugName: "Drug A"), administeredAt: now, authorMemberID: memberID)
        let med2 = MedicationLog(encryptedPayload: try makeEncryptedMedPayload(drugName: "Drug B"), administeredAt: now, authorMemberID: memberID)
        let med3 = MedicationLog(encryptedPayload: try makeEncryptedMedPayload(drugName: "Drug C"), administeredAt: now, authorMemberID: memberID)

        context.insert(med1)
        context.insert(med2)
        context.insert(med3)
        try context.save()

        struct MedPayload: Codable { let drugName: String; let dose: String; let notes: String }
        let all = try context.fetch(FetchDescriptor<MedicationLog>())
        let searchTerm = ""

        // Empty search: all records returned (no filter applied)
        var results: [MedicationLog] = []
        for log in all {
            if searchTerm.isEmpty {
                results.append(log)
            } else if let plain = try? EncryptionService.open(log.encryptedPayload, for: .medications),
                      let decoded = try? JSONDecoder().decode(MedPayload.self, from: plain) {
                if "\(decoded.drugName) \(decoded.dose)".localizedCaseInsensitiveContains(searchTerm) {
                    results.append(log)
                }
            }
        }

        XCTAssertEqual(results.count, 3, "Empty search should return all 3 records")
    }
}
