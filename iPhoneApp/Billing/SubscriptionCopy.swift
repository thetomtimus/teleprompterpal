import Foundation

enum SubscriptionCopy {
    static func period(_ period: SubscriptionPeriod, count: Int = 1, includeOne: Bool = false) -> String {
        let value = period.value * count
        let unit: String
        switch period.unit {
        case .day: unit = value == 1 ? "day" : "days"
        case .week: unit = value == 1 ? "week" : "weeks"
        case .month: unit = value == 1 ? "month" : "months"
        case .year: unit = value == 1 ? "year" : "years"
        }
        return value == 1 && !includeOne ? unit : "\(value) \(unit)"
    }

    static func pricedPeriod(_ plan: SubscriptionPlan) -> String {
        "\(plan.displayPrice) every \(period(plan.period))"
    }

    static func terms(_ plan: SubscriptionPlan) -> String {
        let renewal = "\(pricedPeriod(plan)). Renews automatically until cancelled. Manage or cancel in Apple subscription settings."
        guard let trial = plan.eligibleTrial else { return renewal }
        let length = period(trial.period, count: trial.numberOfPeriods, includeOne: true)
        return "Free for \(length), then \(renewal)"
    }

    static func result(_ result: SubscriptionActionResult) -> String {
        switch result {
        case .purchased: "Purchase verified."
        case .restored: "Purchases restored."
        case .nothingToRestore: "No active subscription was found."
        case .pending: "Awaiting purchase approval. Access will update when Apple confirms approval."
        case .cancelled: "Purchase cancelled."
        case .unverified: "The purchase could not be verified. Try Restore Purchases to check again."
        case .failed: "The purchase or restore could not be completed. Try again when the store is available."
        case .unavailable: "Subscription access could not be confirmed. Check your connection and try again."
        case .busy: "A purchase or restore is already in progress."
        }
    }
}
