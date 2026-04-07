import Foundation

@MainActor
public final class VpnCheckViewModel: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var result: CheckResult?
    @Published public private(set) var errorMessage: String?

    public init() {}

    public func runCheck(homeCountryCode: String = "RU") {
        isRunning = true
        result = nil
        errorMessage = nil

        Task {
            let checkResult = await VpnCheckRunner.run(homeCountryCode: homeCountryCode)
            self.result = checkResult
            self.isRunning = false
        }
    }
}

