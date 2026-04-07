import CFNetwork
import Darwin
import Foundation
import Network
import SystemConfiguration

#if canImport(NetworkExtension)
import NetworkExtension
#endif

public enum IndirectSignsChecker {
    private static let suspiciousInterfaceTokens = ["utun", "tap", "tun", "ppp", "ipsec"]

    public static func check() async -> CategoryResult {
        var findings = [Finding]()
        var detected = false
        var needsReview = false

        if let scopedInterfaces = readScopedInterfaces() {
            let suspicious = scopedInterfaces.filter { isSuspiciousInterfaceName($0) }
            findings.append(Finding(description: "Scoped interfaces: \(scopedInterfaces.joined(separator: ", "))"))
            if !suspicious.isEmpty {
                findings.append(Finding(description: "Suspicious scoped interfaces: \(suspicious.joined(separator: ", "))", detected: true))
                detected = true
            }
        } else {
            findings.append(Finding(description: "Unable to read __SCOPED__ interfaces from CFNetwork settings", needsReview: true))
            needsReview = true
        }

        let p2pInterfaces = readPointToPointInterfaces()
        if !p2pInterfaces.isEmpty {
            findings.append(Finding(description: "P2P interfaces detected: \(p2pInterfaces.joined(separator: ", "))", needsReview: true))
            needsReview = true
        }

        let pathSample = await samplePathInterfaces()
        if !pathSample.names.isEmpty {
            findings.append(Finding(description: "NWPath available interfaces: \(pathSample.names.joined(separator: ", "))"))
        }
        if !pathSample.suspiciousInterfaces.isEmpty {
            findings.append(Finding(description: "NWPath suspicious interfaces: \(pathSample.suspiciousInterfaces.joined(separator: ", "))", detected: true))
            detected = true
        } else if pathSample.hasOtherTypeInterface {
            findings.append(Finding(description: "NWPath has .other interfaces", needsReview: true))
            needsReview = true
        }

        #if canImport(NetworkExtension)
        let vpnStatus = await readNEVPNStatus()
        findings.append(Finding(description: "NEVPNManager status: \(vpnStatus.description)", needsReview: vpnStatus.needsReview))
        if vpnStatus.needsReview {
            needsReview = true
        }
        #endif

        if looksLikeOnlyPrivateRelaySignal(detected: detected, findings: findings) {
            findings.append(Finding(description: "Signal can match iCloud Private Relay, manual classification recommended", needsReview: true))
            needsReview = true
        }

        return CategoryResult(
            name: "IndirectSigns",
            detected: detected,
            findings: findings,
            needsReview: needsReview
        )
    }

    private static func readScopedInterfaces() -> [String]? {
        guard
            let unmanaged = CFNetworkCopySystemProxySettings(),
            let settings = unmanaged.takeRetainedValue() as? [String: Any],
            let scoped = settings["__SCOPED__"] as? [String: Any]
        else {
            return nil
        }

        return scoped.keys.sorted()
    }

    private static func isSuspiciousInterfaceName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return suspiciousInterfaceTokens.contains(where: { lower.contains($0) })
    }

    private static func readPointToPointInterfaces() -> [String] {
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0, let first = addressList else {
            return []
        }
        defer { freeifaddrs(addressList) }

        var current = first
        var result = Set<String>()

        while true {
            let flags = current.pointee.ifa_flags
            if (flags & UInt32(IFF_POINTOPOINT)) != 0, let name = current.pointee.ifa_name {
                let ifName = String(cString: name)
                if ifName != "lo0" {
                    result.insert(ifName)
                }
            }

            guard let next = current.pointee.ifa_next else {
                break
            }
            current = next
        }

        return result.sorted()
    }

    private static func samplePathInterfaces() async -> (names: [String], suspiciousInterfaces: [String], hasOtherTypeInterface: Bool) {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "rknhardering.nwpath")

            var finished = false
            let finish: ([String], [String], Bool) -> Void = { names, suspicious, hasOther in
                guard !finished else { return }
                finished = true
                monitor.cancel()
                continuation.resume(returning: (names, suspicious, hasOther))
            }

            monitor.pathUpdateHandler = { path in
                let names = path.availableInterfaces.map { $0.name }.sorted()
                let suspicious = names.filter { isSuspiciousInterfaceName($0) }
                let hasOther = path.availableInterfaces.contains { $0.type == .other }
                finish(names, suspicious, hasOther)
            }

            monitor.start(queue: queue)

            queue.asyncAfter(deadline: .now() + 1.5) {
                finish([], [], false)
            }
        }
    }

    #if canImport(NetworkExtension)
    private static func readNEVPNStatus() async -> (description: String, needsReview: Bool) {
        let manager = NEVPNManager.shared()

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                manager.loadFromPreferences { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }

            let status = manager.connection.status
            switch status {
            case .connected, .connecting, .reasserting:
                return ("\(status.rawValue) (configured via NEVPNManager)", true)
            case .invalid, .disconnected, .disconnecting:
                return ("\(status.rawValue)", false)
            @unknown default:
                return ("unknown", true)
            }
        } catch {
            return ("unavailable: \(error.localizedDescription)", false)
        }
    }
    #endif

    private static func looksLikeOnlyPrivateRelaySignal(detected: Bool, findings: [Finding]) -> Bool {
        guard detected else {
            return false
        }
        let suspiciousMessages = findings.filter { $0.detected }.map { $0.description.lowercased() }
        return suspiciousMessages.count == 1 && suspiciousMessages.first?.contains("utun") == true
    }
}
