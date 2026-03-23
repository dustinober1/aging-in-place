import CloudKit
import Foundation

struct iCloudIdentityService: Sendable {
    static func fetchRecordID() async -> String? {
        do {
            let recordID = try await CKContainer.default().userRecordID()
            return recordID.recordName
        } catch { return nil }
    }

    static func fetchUserName() async -> String? {
        do {
            let recordID = try await CKContainer.default().userRecordID()
            let identity = try await CKContainer.default().userIdentity(forUserRecordID: recordID)
            let components = identity?.nameComponents
            return components.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }
        } catch { return nil }
    }

    static func requestDiscoverability() async -> Bool {
        do {
            let status = try await CKContainer.default().requestApplicationPermission(.userDiscoverability)
            return status == .granted
        } catch { return false }
    }
}
