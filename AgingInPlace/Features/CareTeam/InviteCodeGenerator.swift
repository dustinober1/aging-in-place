import Foundation

/// Generates offline single-use alphanumeric invite codes in the format "CARE-XXXX-XXXX".
struct InviteCodeGenerator {

    /// Generates a unique invite code in the format "CARE-XXXX-XXXX".
    /// Uses the first 8 hex characters of a UUID (dashes removed), uppercased,
    /// then split into two 4-character segments separated by a dash.
    ///
    /// Example output: "CARE-7F3A-9C2B"
    static func generate() -> String {
        let raw = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let first = String(raw.prefix(4))
        let second = String(raw.dropFirst(4).prefix(4))
        return "CARE-\(first)-\(second)"
    }
}
