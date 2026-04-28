import UIKit
import SwiftUI

// NOTE: ProMotion 120Hz for SwiftUI scroll views is enabled via Info.plist:
//   <key>CADisableMinimumFrameDurationOnPhone</key><true/>
// SwiftUI negotiates frame rate automatically once that key is present.

// MARK: - Conditional Shadow
extension View {
    /// Applies a shadow only when `condition` is true — avoids GPU compositing on transparent shadows.
    @ViewBuilder
    func conditionalShadow(
        condition: Bool,
        color: Color = .black.opacity(0.3),
        radius: CGFloat = 8,
        x: CGFloat = 0,
        y: CGFloat = 4
    ) -> some View {
        if condition {
            self.shadow(color: color, radius: radius, x: x, y: y)
        } else {
            self
        }
    }

    /// Gives any view a scale + opacity bounce on tap — use on cards, rows, etc.
    func pressAnimation() -> some View {
        self.modifier(PressAnimationModifier())
    }
}

// MARK: - Press-Effect Button Style
/// Matches native iOS button physics: scale down on press, spring back on release.
/// Usage: Button { } label: { }.buttonStyle(PressEffect())
struct PressEffect: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Press Animation Modifier (for non-Button views)
private struct PressAnimationModifier: ViewModifier {
    @State private var isPressed = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded   { _ in isPressed = false }
            )
    }
}
