import XCTest
@testable import AgingInPlace

@MainActor
final class CloudKitSyncMonitorTests: XCTestCase {

    func testInitialStateIsNotStarted() {
        let monitor = CloudKitSyncMonitor()
        XCTAssertEqual(monitor.syncState, .notStarted)
    }

    func testUpdateToSyncing() {
        let monitor = CloudKitSyncMonitor()
        monitor.updateState(.syncing)
        XCTAssertEqual(monitor.syncState, .syncing)
    }

    func testUpdateToSynced() {
        let monitor = CloudKitSyncMonitor()
        monitor.updateState(.synced)
        XCTAssertEqual(monitor.syncState, .synced)
    }

    func testUpdateToError() {
        let monitor = CloudKitSyncMonitor()
        let error = NSError(domain: "test", code: 1)
        monitor.updateState(.error(error))
        if case .error(let e) = monitor.syncState {
            XCTAssertEqual((e as NSError).code, 1)
        } else {
            XCTFail("Expected error state")
        }
    }

    func testUpdateToNotAvailable() {
        let monitor = CloudKitSyncMonitor()
        monitor.updateState(.notAvailable)
        XCTAssertEqual(monitor.syncState, .notAvailable)
    }

    func testSyncStateDisplayText() {
        let monitor = CloudKitSyncMonitor()
        monitor.updateState(.notStarted)
        XCTAssertEqual(monitor.displayText, "")
        monitor.updateState(.syncing)
        XCTAssertEqual(monitor.displayText, "Syncing...")
        monitor.updateState(.synced)
        XCTAssertEqual(monitor.displayText, "Up to date")
        monitor.updateState(.notAvailable)
        XCTAssertEqual(monitor.displayText, "iCloud unavailable")
        let error = NSError(domain: "CKErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        monitor.updateState(.error(error))
        XCTAssertEqual(monitor.displayText, "Sync error")
    }
}
