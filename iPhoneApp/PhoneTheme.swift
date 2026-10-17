import SwiftUI
import UIKit

/// Named roles for the owner's pinned, dark recording workspace.
enum PhoneTheme {
    static let canvas = Color(red: 29 / 255, green: 34 / 255, blue: 37 / 255)
    static let card = Color(red: 39 / 255, green: 41 / 255, blue: 46 / 255)
    static let onboarding = Color(red: 21 / 255, green: 21 / 255, blue: 21 / 255)
    static let record = Color(red: 224 / 255, green: 47 / 255, blue: 54 / 255)
    static let magenta = Color(red: 213 / 255, green: 20 / 255, blue: 166 / 255)
    static let violet = Color(red: 98 / 255, green: 76 / 255, blue: 225 / 255)
    static var auxiliaryText: Color { Color.primary.opacity(0.72) }
    static var gradient: LinearGradient {
        LinearGradient(colors: [magenta, violet], startPoint: .leading, endPoint: .trailing)
    }
    static var canvasUI: UIColor { UIColor(red: 29 / 255, green: 34 / 255, blue: 37 / 255, alpha: 1) }
}

enum PhoneSection: Int, Hashable { case scripts = 1, videos = 2 }

/// The pinned three-part dock uses native Buttons and SF Symbols. Keeping the
/// action separate from the two sections also avoids iOS 27's extra floating bar.
struct RecordingDock<Control: View>: View {
    let selection: PhoneSection?
    var enabled = true
    let select: (PhoneSection) -> Void
    @ViewBuilder let control: () -> Control

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                section(.scripts, title: "Scripts", symbol: "text.alignleft")
                Spacer(minLength: 96)
                section(.videos, title: "Videos", symbol: "play.rectangle")
            }.padding(.horizontal, 28)
            control().padding(.bottom, 10)
        }
        .frame(height: 82)
        .background(PhoneTheme.canvas.ignoresSafeArea(edges: .bottom))
    }

    private func section(_ value: PhoneSection, title: String, symbol: String) -> some View {
        Button { select(value) } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 22))
                Text(title).font(.caption).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }.foregroundStyle(selection == value ? .white : .white.opacity(0.65))
                .frame(maxWidth: .infinity, minHeight: 66)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selection == value ? .isSelected : [])
        .accessibilityIdentifier(value == .scripts ? (selection == nil ? "closeReader" : "scriptsTab") : "videosTab")
    }
}

extension ToolbarContent {
    @ToolbarContentBuilder func referenceChrome() -> some ToolbarContent {
        if #available(iOS 26, *) { self.sharedBackgroundVisibility(.hidden) }
        else { self }
    }
}

struct RecordCircle: View {
    let title: String
    let identifier: String
    var stopping = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle().fill(.white)
                .overlay {
                    if stopping {
                        RoundedRectangle(cornerRadius: 6).fill(PhoneTheme.record).padding(22)
                    } else {
                        Circle().fill(PhoneTheme.record).padding(6)
                    }
                }
                .frame(width: 66, height: 66)
                .shadow(color: .white.opacity(0.16), radius: 7)
                .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain).disabled(!enabled)
        .accessibilityLabel(title).accessibilityIdentifier(identifier)
    }
}
