import Foundation

public enum VpnCheckRunner {
    public static func run(homeCountryCode: String = "RU") async -> CheckResult {
        async let geoIP = GeoIPChecker.check(homeCountryCode: homeCountryCode)
        async let indirect = IndirectSignsChecker.check()
        let direct = DirectSignsChecker.check()

        let geoResult = await geoIP
        let indirectResult = await indirect

        let verdict = VerdictEngine.evaluate(
            geoIPDetected: geoResult.detected,
            directDetected: direct.detected,
            indirectDetected: indirectResult.detected,
            directNeedsReview: direct.needsReview,
            indirectNeedsReview: indirectResult.needsReview
        )

        return CheckResult(
            geoIP: geoResult,
            directSigns: direct,
            indirectSigns: indirectResult,
            verdict: verdict
        )
    }
}

