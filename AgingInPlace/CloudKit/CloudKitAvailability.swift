import CloudKit
import Foundation

enum CloudKitAccountStatus: Sendable {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
}

struct CloudKitAvailability: Sendable {
    static func checkAccountStatus() async -> CloudKitAccountStatus {
        do {
            let status = try await CKContainer.default().accountStatus()
            switch status {
            case .available:
                return .available
            case .noAccount:
                return .noAccount
            case .restricted:
                return .restricted
            case .couldNotDetermine:
                return .couldNotDetermine
            case .temporarilyUnavailable:
                return .temporarilyUnavailable
            @unknown default:
                return .couldNotDetermine
            }
        } catch {
            return .couldNotDetermine
        }
    }
}
