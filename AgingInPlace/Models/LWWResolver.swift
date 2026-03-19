import Foundation

/// Last-Write-Wins conflict resolver for CareRecord.
/// Compares two records by lastModified timestamp and breaks ties deterministically by UUID string.
struct LWWResolver {
    /// Returns the winning record between two candidates.
    /// The record with the later lastModified timestamp wins.
    /// If timestamps are equal, the record with the lexicographically larger UUID string wins.
    static func resolve(local: CareRecord, remote: CareRecord) -> CareRecord {
        if local.lastModified > remote.lastModified {
            return local
        } else if remote.lastModified > local.lastModified {
            return remote
        } else {
            // Equal timestamps — deterministic tiebreak by UUID string comparison
            return local.id.uuidString >= remote.id.uuidString ? local : remote
        }
    }

    /// Returns true if `candidate` should win over `current`.
    static func shouldReplace(current: CareRecord, with candidate: CareRecord) -> Bool {
        resolve(local: current, remote: candidate) === candidate
    }
}
