# RKNHardering iOS Module

Swift Package for iOS VPN/Proxy detection signals:
- GeoIP check (with provider fallback)
- direct proxy signs via `CFNetworkCopySystemProxySettings`
- indirect network signs via `NWPathMonitor` and interfaces
- verdict engine (`DETECTED / NEEDS_REVIEW / NOT_DETECTED`)

## Install (Swift Package Manager)
Add repository URL in Xcode SPM and import:

```swift
import RKNHarderingIOS
```

## Quick start

```swift
let result = await VpnCheckRunner.run(homeCountryCode: "RU")
print(result.verdict.rawValue)
```

## Xcode App Project

Generate app project:

```bash
ruby scripts/generate_xcodeproj.rb
```

Then open:

`RKNHarderingIOSApp/RKNHarderingIOSApp.xcodeproj`

Note: repository does not include personal signing data. Set your own Team in Xcode before running on device.
