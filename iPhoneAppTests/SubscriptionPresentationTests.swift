import Testing
@testable import TeleprompterPhone

struct SubscriptionPresentationTests {
    @Test func trialTermsUseTheActualOfferAndFullRenewalPrice() {
        let plan = SubscriptionPlan(id: "sample", name: "Annual", displayPrice: "₩29,000",
            period: .init(value: 1, unit: .year), eligibleTrial: .init(period: .init(value: 1, unit: .week), numberOfPeriods: 2))
        let terms = SubscriptionCopy.terms(plan)
        #expect(terms.contains("2 weeks") && terms.contains("₩29,000 every year"))
        #expect(terms.contains("cancel") && !terms.contains("7 days"))
    }

    @Test func ineligiblePlansNeverPromiseAFreeTrialOrMonthlyEquivalentAnnualPrice() {
        let plan = SubscriptionPlan(id: "sample", name: "Annual", displayPrice: "$9.99",
            period: .init(value: 1, unit: .year), eligibleTrial: nil)
        let terms = SubscriptionCopy.terms(plan)
        #expect(!terms.contains("Free") && !terms.contains("trial"))
        #expect(terms.hasPrefix("$9.99 every year") && !terms.contains("month"))
    }

    @Test func pendingUnverifiedAndNoRestoreResultsRemainDistinct() {
        #expect(SubscriptionCopy.result(.pending).contains("Awaiting"))
        #expect(SubscriptionCopy.result(.unverified).contains("could not be verified"))
        #expect(SubscriptionCopy.result(.nothingToRestore).contains("No active"))
        #expect(!SubscriptionCopy.result(.failed).contains("No active"))
        // Historical action feedback cannot assert current access after refund or expiry.
        #expect(!SubscriptionCopy.result(.purchased).contains("active"))
        #expect(!SubscriptionCopy.result(.restored).contains("active"))
    }
}
