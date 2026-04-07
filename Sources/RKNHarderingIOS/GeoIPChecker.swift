import Foundation

public enum GeoIPChecker {
    private struct UnifiedGeoIP {
        let source: String
        let ip: String?
        let country: String?
        let countryCode: String?
        let isp: String?
        let org: String?
        let asn: String?
        let proxy: Bool?
        let hosting: Bool?
    }

    private struct GeoIPResponse: Decodable {
        let status: String?
        let country: String?
        let countryCode: String?
        let isp: String?
        let org: String?
        let asn: String?
        let proxy: Bool?
        let hosting: Bool?
        let query: String?
        let message: String?

        private enum CodingKeys: String, CodingKey {
            case status
            case country
            case countryCode
            case isp
            case org
            case asn = "as"
            case proxy
            case hosting
            case query
            case message
        }
    }

    private struct IpApiIsResponse: Decodable {
        struct Company: Decodable {
            let name: String?
        }

        struct ASN: Decodable {
            let asn: Int?
            let org: String?
            let name: String?
            let domain: String?
        }

        struct Location: Decodable {
            let country: String?
            let country_code: String?
        }

        let ip: String?
        let is_proxy: Bool?
        let is_vpn: Bool?
        let is_tor: Bool?
        let is_datacenter: Bool?
        let company: Company?
        let asn: ASN?
        let location: Location?
    }

    public static func check(
        homeCountryCode: String = "RU"
    ) async -> CategoryResult {
        let attempts = await fetchUnifiedGeoIp()

        if let best = attempts.first(where: { $0.error == nil })?.result {
            let countryMismatch = (best.countryCode?.uppercased() != homeCountryCode.uppercased())
            let hosting = best.hosting == true
            let proxy = best.proxy == true

            var findings = [
                Finding(description: "GeoIP source: \(best.source)"),
                Finding(description: "IP: \(best.ip ?? "n/a")"),
                Finding(description: "Country: \(best.country ?? "n/a") (\(best.countryCode ?? "n/a"))"),
                Finding(description: "ISP: \(best.isp ?? "n/a")"),
                Finding(description: "Org: \(best.org ?? "n/a")"),
                Finding(description: "AS: \(best.asn ?? "n/a")"),
                Finding(description: "GeoIP country mismatch", detected: countryMismatch),
                Finding(description: "IP marked as hosting", detected: hosting),
                Finding(description: "IP marked as proxy/VPN", detected: proxy),
            ]

            for attempt in attempts where attempt.error != nil {
                findings.append(Finding(description: "GeoIP fallback failed (\(attempt.source)): \(attempt.error!)", needsReview: true))
            }

            return CategoryResult(name: "GeoIP", detected: countryMismatch || hosting || proxy, findings: findings)
        }

        let errors = attempts.map { "\($0.source): \($0.error ?? "unknown error")" }.joined(separator: "; ")
        return CategoryResult(
            name: "GeoIP",
            detected: false,
            findings: [Finding(description: "GeoIP check failed for all providers: \(errors)", needsReview: true)],
            needsReview: true
        )
    }

    private static func fetchUnifiedGeoIp() async -> [(source: String, result: UnifiedGeoIP?, error: String?)] {
        var results = [(source: String, result: UnifiedGeoIP?, error: String?)]()
        results.append(await fetchFromIpApi())
        if results.last?.result != nil {
            return results
        }

        results.append(await fetchFromIpApiIs())
        return results
    }

    private static func fetchFromIpApi() async -> (source: String, result: UnifiedGeoIP?, error: String?) {
        let source = "ip-api.com"
        do {
            var request = URLRequest(url: URL(string: "http://ip-api.com/json/?fields=status,message,country,countryCode,isp,org,as,proxy,hosting,query")!)
            request.timeoutInterval = 6
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return (source, nil, "unexpected HTTP status")
            }

            let payload = try JSONDecoder().decode(GeoIPResponse.self, from: data)
            guard payload.status == "success" else {
                return (source, nil, "API error: \(payload.message ?? "unknown")")
            }

            let unified = UnifiedGeoIP(
                source: source,
                ip: payload.query,
                country: payload.country,
                countryCode: payload.countryCode,
                isp: payload.isp,
                org: payload.org,
                asn: payload.asn,
                proxy: payload.proxy,
                hosting: payload.hosting
            )
            return (source, unified, nil)
        } catch {
            return (source, nil, error.localizedDescription)
        }
    }

    private static func fetchFromIpApiIs() async -> (source: String, result: UnifiedGeoIP?, error: String?) {
        let source = "api.ipapi.is"
        do {
            var request = URLRequest(url: URL(string: "https://api.ipapi.is/")!)
            request.timeoutInterval = 6
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return (source, nil, "unexpected HTTP status")
            }

            let payload = try JSONDecoder().decode(IpApiIsResponse.self, from: data)
            let proxy = (payload.is_proxy == true) || (payload.is_vpn == true) || (payload.is_tor == true)
            let asnValue = payload.asn?.asn.map { "AS\($0)" }

            let unified = UnifiedGeoIP(
                source: source,
                ip: payload.ip,
                country: payload.location?.country,
                countryCode: payload.location?.country_code,
                isp: payload.company?.name ?? payload.asn?.name,
                org: payload.asn?.org,
                asn: asnValue,
                proxy: proxy,
                hosting: payload.is_datacenter
            )
            return (source, unified, nil)
        } catch {
            return (source, nil, error.localizedDescription)
        }
    }
}
