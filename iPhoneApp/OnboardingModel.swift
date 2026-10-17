import Foundation
import Observation

enum OnboardingStep: Int, CaseIterable { case welcome, confidence, prompting, quality, commitment }
enum RecordingGoal: String, CaseIterable, Identifiable {
    case confidence = "Feel confident when I press record"
    case share = "Create a take I’m proud to share"
    case practice = "Keep showing up for my ideas"
    var id: Self { self }
}

@MainActor @Observable final class OnboardingModel {
    private static let completedKey = "phone.onboarding.completed.v1"
    @ObservationIgnored private let defaults: UserDefaults
    private(set) var completed: Bool
    var presented = false
    private(set) var step = OnboardingStep.welcome
    private(set) var goals: Set<RecordingGoal> = []
    var allCommitted: Bool { goals.count == RecordingGoal.allCases.count }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        completed = defaults.bool(forKey: Self.completedKey)
    }

    static func configured() -> OnboardingModel {
        #if DEBUG && targetEnvironment(simulator)
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--p2-test-root=") }),
           let id = UUID(uuidString: String(argument.dropFirst("--p2-test-root=".count))),
           let defaults = UserDefaults(suiteName: "onboarding.\(id.uuidString)") {
            let model = OnboardingModel(defaults: defaults)
            if SimulatorIntegrationFixture.accepts("--p6b-skip-onboarding") { model.complete() }
            return model
        }
        #endif
        return OnboardingModel()
    }

    func showIfNeeded() { if !completed { presented = true } }
    func replay() { step = .welcome; goals = []; presented = true }
    func advance() {
        if let next = OnboardingStep(rawValue: step.rawValue + 1) { step = next }
    }
    func back() {
        if let previous = OnboardingStep(rawValue: step.rawValue - 1) { step = previous }
    }
    func toggle(_ goal: RecordingGoal) {
        if goals.contains(goal) { goals.remove(goal) } else { goals.insert(goal) }
    }
    func complete() {
        defaults.set(true, forKey: Self.completedKey)
        completed = true
        presented = false
    }
}
