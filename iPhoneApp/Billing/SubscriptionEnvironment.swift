import Foundation

enum SubscriptionEnvironment {
    static var isLocalTest: Bool {
        #if DEBUG && targetEnvironment(simulator)
        ProcessInfo.processInfo.environment["TELEPROMPTER_LOCAL_STOREKIT_TEST"] == "1"
            && ProcessInfo.processInfo.arguments.contains("--p5-local-paywall")
        #else
        false
        #endif
    }

    static var catalog: SubscriptionCatalog {
        #if DEBUG && targetEnvironment(simulator)
        if isLocalTest {
            return .init(productIDs: ["local.teleprompter.pro.monthly", "local.teleprompter.pro.annual"])
        }
        #endif
        return .unconfigured
    }
}
