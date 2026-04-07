import CFNetwork
import Foundation

public enum DirectSignsChecker {
    public static func check() -> CategoryResult {
        guard
            let unmanaged = CFNetworkCopySystemProxySettings(),
            let settings = unmanaged.takeRetainedValue() as? [String: Any]
        else {
            return CategoryResult(
                name: "DirectSigns",
                detected: false,
                findings: [Finding(description: "CFNetwork proxy settings are unavailable", needsReview: true)],
                needsReview: true
            )
        }

        let http = parseProxy(kind: "HTTP", settings: settings)
        let https = parseProxy(kind: "HTTPS", settings: settings)
        let socks = parseProxy(kind: "SOCKS", settings: settings)

        var findings = [
            Finding(description: http.summary, detected: http.detected),
            Finding(description: https.summary, detected: https.detected),
            Finding(description: socks.summary, detected: socks.detected),
        ]

        // kCFNetworkProxiesExceptionsList is unavailable on iOS SDK; read by raw key.
        if let excludes = settings["ExceptionsList"] as? [String], !excludes.isEmpty {
            findings.append(Finding(description: "Bypass domains configured: \(excludes.count)"))
        }

        return CategoryResult(
            name: "DirectSigns",
            detected: http.detected || https.detected || socks.detected,
            findings: findings
        )
    }

    private static func parseProxy(kind: String, settings: [String: Any]) -> (detected: Bool, summary: String) {
        let keys: (enabled: String, host: String, port: String)
        switch kind {
        case "HTTP":
            keys = ("HTTPEnable", "HTTPProxy", "HTTPPort")
        case "HTTPS":
            keys = ("HTTPSEnable", "HTTPSProxy", "HTTPSPort")
        case "SOCKS":
            keys = ("SOCKSEnable", "SOCKSProxy", "SOCKSPort")
        default:
            keys = ("", "", "")
        }

        let enabled = (settings[keys.enabled] as? NSNumber)?.boolValue ?? false
        let host = settings[keys.host] as? String
        let port = settings[keys.port] as? NSNumber

        let hasEndpoint = !(host?.isEmpty ?? true) && port != nil
        let detected = enabled && hasEndpoint

        let endpoint = hasEndpoint ? "\(host ?? "?"):\(port?.intValue ?? 0)" : "not configured"
        return (
            detected,
            "\(kind) proxy: enabled=\(enabled), endpoint=\(endpoint)"
        )
    }
}
