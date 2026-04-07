import Foundation

public struct Finding: Sendable {
    public let description: String
    public let detected: Bool
    public let needsReview: Bool

    public init(description: String, detected: Bool = false, needsReview: Bool = false) {
        self.description = description
        self.detected = detected
        self.needsReview = needsReview
    }
}

public struct CategoryResult: Sendable {
    public let name: String
    public let detected: Bool
    public let findings: [Finding]
    public let needsReview: Bool

    public init(name: String, detected: Bool, findings: [Finding], needsReview: Bool = false) {
        self.name = name
        self.detected = detected
        self.findings = findings
        self.needsReview = needsReview
    }
}

public enum Verdict: String, Sendable {
    case notDetected = "NOT_DETECTED"
    case needsReview = "NEEDS_REVIEW"
    case detected = "DETECTED"
}

public struct CheckResult: Sendable {
    public let geoIP: CategoryResult
    public let directSigns: CategoryResult
    public let indirectSigns: CategoryResult
    public let verdict: Verdict

    public init(geoIP: CategoryResult, directSigns: CategoryResult, indirectSigns: CategoryResult, verdict: Verdict) {
        self.geoIP = geoIP
        self.directSigns = directSigns
        self.indirectSigns = indirectSigns
        self.verdict = verdict
    }
}

