import SwiftUI

@MainActor struct OnboardingView: View {
    let model: OnboardingModel
    let finish: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var committing = false
    @State private var celebrationStartedAt = Date()

    private var actionEnabled: Bool {
        !committing && (model.step != .commitment || model.allCommitted)
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height
            VStack(spacing: 0) {
                HStack {
                    if model.step != .welcome {
                        Button("Back", systemImage: "chevron.left") { model.back() }
                            .accessibilityIdentifier("onboardingBack")
                    }
                    Spacer()
                    Button("Skip") { model.complete() }.accessibilityIdentifier("onboardingSkip")
                }.font(.subheadline).tint(.white).frame(minHeight: 44).padding(.horizontal, 22)
                    .disabled(committing)
                ScrollView {
                    Group {
                        if model.step == .welcome { welcome(height: geometry.size.height) }
                        else if model.step == .commitment { commitment(height: geometry.size.height) }
                        else { demonstration(height: geometry.size.height, wide: wide) }
                    }
                    .frame(maxWidth: wide ? 760 : 540)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }.scrollIndicators(.hidden).id(model.step)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if model.step == .commitment {
                    Text(committing ? "You’re all set" : "\(model.goals.count) of 3 checked")
                        .font(.subheadline).foregroundStyle(PhoneTheme.auxiliaryText)
                        .accessibilityIdentifier(committing ? "onboardingCommitted" : "onboardingGoalCount")
                }
                Button(model.step == .commitment ? "Commit" : "Continue") {
                    if model.step == .commitment {
                        guard model.allCommitted, !committing else { return }
                        celebrationStartedAt = .now
                        committing = true
                    } else { model.advance() }
                }
                .font(.headline).foregroundStyle(.white.opacity(actionEnabled ? 1 : 0.6))
                .frame(maxWidth: .infinity, minHeight: 54)
                .background {
                    if actionEnabled { Capsule().fill(PhoneTheme.gradient) }
                    else { Capsule().fill(PhoneTheme.card) }
                }
                .buttonStyle(.plain)
                .disabled(!actionEnabled)
                .accessibilityHint(model.step == .commitment && !model.allCommitted
                    ? "Check all three boxes to enable Commit." : "")
                .accessibilityIdentifier("onboardingContinue")
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(PhoneTheme.onboarding)
        }
        .overlay {
            if committing, !reduceMotion {
                CompletionConfetti(startedAt: celebrationStartedAt)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .sensoryFeedback(.success, trigger: committing) { _, started in started }
        .task(id: committing) {
            guard committing else { return }
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 1200)) }
            catch { return }
            finish()
        }
        .background {
            PhoneTheme.onboarding.ignoresSafeArea()
            if model.step == .welcome || model.step == .commitment {
                LinearGradient(stops: [
                    .init(color: Color(red: 0.19, green: 0.17, blue: 0.32), location: 0),
                    .init(color: Color(red: 0.23, green: 0.11, blue: 0.18), location: 0.30),
                    .init(color: PhoneTheme.onboarding, location: 0.65)
                ], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    private func welcome(height: CGFloat) -> some View {
        VStack(spacing: 28) {
            HStack(spacing: 14) {
                Image(systemName: "laurel.leading").font(.largeTitle).accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("Your words.").font(.largeTitle.bold())
                    Text("Your pace.").font(.largeTitle.bold())
                }
                Image(systemName: "laurel.trailing").font(.largeTitle).accessibilityHidden(true)
            }.padding(.top, max(12, min(54, height * 0.05)))
            Text("One script.\nRoom for another take.")
                .font(.title2.weight(.semibold)).multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.84))
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Welcome to").font(.largeTitle.bold())
                    Text("teleprompterpal.com").font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                }.accessibilityElement(children: .combine)
                Text("Find your words, face the lens\nand speak at your own pace.")
                    .font(.title3).foregroundStyle(PhoneTheme.auxiliaryText)
            }.multilineTextAlignment(.center).padding(.top, max(12, min(42, height * 0.05)))
            HStack(alignment: .top, spacing: 12) {
                welcomeNote("Keep your place", symbol: "text.alignleft", detail: "Your script moves with you.")
                welcomeNote("Keep your original", symbol: "film.stack", detail: "Trim and crop a separate edit.")
            }.padding(.top, 12)
        }.padding(.horizontal, 24).padding(.bottom, 20)
    }

    private func welcomeNote(_ title: String, symbol: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.white)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(PhoneTheme.auxiliaryText)
        }.frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(16).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
    }

    private func demonstration(height: CGFloat, wide: Bool) -> some View {
        let headline: String
        let subtitle: String
        switch model.step {
        case .confidence:
            headline = "Feel natural\non camera"
            subtitle = "A little preparation. More room to be yourself."
        case .prompting:
            headline = "Let the words\ncome to you"
            subtitle = "Read your script without memorizing every line."
        default:
            headline = "Make every\ntake your own"
            subtitle = "Record clearly. Trim, crop and share."
        }
        let layout = wide && !typeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 28))
            : AnyLayout(VStackLayout(spacing: 30))
        return layout {
            VStack(spacing: 18) {
                Text(headline).font(.largeTitle.bold()).multilineTextAlignment(.center)
                    .accessibilityIdentifier("onboardingHeadline")
                Text(subtitle).font(.title3).foregroundStyle(PhoneTheme.auxiliaryText)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                if model.step == .quality {
                    ViewThatFits {
                        HStack(spacing: 12) { qualityBadges }
                        VStack(spacing: 12) { qualityBadges }
                    }.padding(.top, 14)
                }
            }.frame(maxWidth: .infinity).padding(.horizontal, 24)
            OnboardingPhone(prompt: model.step == .prompting, crop: model.step == .quality)
                .frame(width: wide ? 210 : nil)
                .frame(maxWidth: wide ? 240 : 360)
                .frame(height: wide ? max(240, height - 120) : max(320, min(550, height * 0.64)))
                .padding(.horizontal, wide ? 0 : 30)
                .accessibilityHidden(true)
        }.padding(.horizontal, wide ? 20 : 0)
    }

    @ViewBuilder private var qualityBadges: some View {
        ForEach(["1080p", "30 FPS", "On-device"], id: \.self) { title in
            Text(title).font(.subheadline.weight(.semibold)).padding(.horizontal, 18).padding(.vertical, 12)
                .background(.white.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
        }
    }

    private func commitment(height: CGFloat) -> some View {
        VStack(spacing: 16) {
            Text("I’m ready to").font(.largeTitle.bold())
            Text("Check all three boxes, then tap Commit.")
                .font(.title3).foregroundStyle(PhoneTheme.auxiliaryText)
                .multilineTextAlignment(.center)
            VStack(spacing: 16) {
                ForEach(RecordingGoal.allCases) { goal in
                    let selected = model.goals.contains(goal)
                    Button {
                        if reduceMotion { model.toggle(goal) }
                        else { withAnimation(.easeOut(duration: 0.35)) { model.toggle(goal) } }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: selected ? "checkmark.square.fill" : "square")
                                .font(.title2).foregroundStyle(selected ? .white : .white.opacity(0.55))
                            Text(goal.rawValue).font(.title3).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }.padding(16).frame(maxWidth: .infinity, minHeight: 76)
                            .background(.white.opacity(selected ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(selected ? 0.72 : 0.12), lineWidth: 1))
                    }.buttonStyle(.plain)
                        .disabled(committing)
                        .accessibilityLabel(goal.rawValue).accessibilityValue(selected ? "Selected" : "Not selected")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("onboardingGoal_\(goal.id)")
                }
            }.padding(.top, max(24, min(120, height * 0.14)))
            if model.allCommitted, !committing {
                Label("Ready for your first take", systemImage: "checkmark.circle.fill")
                    .font(.headline).padding(.top, 8)
                    .accessibilityIdentifier("onboardingReady")
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 30)
    }
}

private struct OnboardingPhone: View {
    let prompt: Bool
    let crop: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Image("OnboardingPresenter").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                Capsule().fill(.black).frame(width: 88, height: 26).padding(.top, 16)
                if prompt {
                    Text("Look toward the lens.\nTake a breath.\nLet the words come to you.")
                        .font(.title3.weight(.medium)).multilineTextAlignment(.center)
                        .padding(20).padding(.top, 38).frame(maxWidth: .infinity)
                        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 30))
                        .padding(8)
                }
                if crop {
                    RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.85), lineWidth: 2)
                        .padding(.horizontal, 30).padding(.top, 82).padding(.bottom, 24)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 38))
            .overlay(RoundedRectangle(cornerRadius: 38).stroke(.white.opacity(0.22), lineWidth: 2))
            .padding(4).background(.black, in: RoundedRectangle(cornerRadius: 42))
        }
    }
}

private struct CompletionConfetti: View {
    let startedAt: Date
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: scenePhase != .active)) { timeline in
            Canvas { context, size in
                let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
                let colors: [Color] = [PhoneTheme.magenta, PhoneTheme.violet, .cyan, .yellow, .green]
                for index in 0..<64 {
                    let angle = Double(-165 + (index * 47 % 150)) * .pi / 180
                    let speed = max(600, size.height * (1.05 + Double(index * 31 % 45) / 100))
                    let x = size.width / 2 + cos(angle) * speed * elapsed
                    let y = size.height - 42 + sin(angle) * speed * elapsed + 520 * elapsed * elapsed
                    var particle = context
                    particle.opacity = max(0, min(1, (1.2 - elapsed) / 0.4))
                    particle.translateBy(x: x, y: y)
                    particle.rotate(by: .degrees(Double(index * 29) + elapsed * Double(150 + index * 17 % 360)))
                    let box = CGRect(x: -3, y: -5, width: index.isMultiple(of: 3) ? 9 : 5, height: 10)
                    particle.fill(Path(roundedRect: box, cornerRadius: 1), with: .color(colors[index % colors.count]))
                }
            }
        }
    }
}
