import Foundation

public enum VerdictEngine {
    public static func evaluate(
        geoIPDetected: Bool,
        directDetected: Bool,
        indirectDetected: Bool,
        directNeedsReview: Bool,
        indirectNeedsReview: Bool
    ) -> Verdict {
        switch (geoIPDetected, directDetected, indirectDetected) {
        case (true, true, _), (true, _, true):
            return .detected
        case (true, false, false):
            return .needsReview
        case (false, true, true):
            return .needsReview
        default:
            break
        }

        if directNeedsReview || indirectNeedsReview {
            return .needsReview
        }

        return .notDetected
    }
}

