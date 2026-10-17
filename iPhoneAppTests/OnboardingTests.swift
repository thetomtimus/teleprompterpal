import Foundation
import Testing
@testable import TeleprompterPhone

@MainActor struct OnboardingTests {
    @Test func completionSurvivesRelaunchAndReplayDoesNotEraseIt() throws {
        let name = "onboarding.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = OnboardingModel(defaults: defaults)
        first.showIfNeeded()
        #expect(first.presented)
        first.complete()
        let reopened = OnboardingModel(defaults: defaults)
        reopened.showIfNeeded()
        #expect(!reopened.presented)
        reopened.replay()
        #expect(reopened.presented)
        #expect(reopened.step == .welcome)
        #expect(reopened.completed)
        #expect(OnboardingModel(defaults: defaults).completed)
    }

    @Test func fiveStepsHaveBoundedNavigationAndIndependentCommitments() throws {
        let name = "onboarding.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = OnboardingModel(defaults: defaults)
        model.back()
        #expect(model.step == .welcome)
        for _ in 0..<8 { model.advance() }
        #expect(model.step == .commitment)
        model.toggle(.practice)
        model.toggle(.confidence)
        #expect(!model.allCommitted)
        model.toggle(.share)
        #expect(model.allCommitted)
        model.toggle(.confidence)
        #expect(!model.allCommitted)
        model.replay()
        #expect(model.goals.isEmpty)
        #expect(model.step == .welcome)
    }
}
