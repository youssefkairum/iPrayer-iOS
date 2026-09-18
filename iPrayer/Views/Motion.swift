//
//  Motion.swift
//  iPrayer
//
//  The app's shared motion: how cards react to a press, how a screen's cards arrive, and when
//  the main app is revealed from behind the splash screen or onboarding.
//

import SwiftUI
import Combine

/// True once the splash screen and onboarding are out of the way. Screens use it to start their
/// entrance animation at the moment they become visible rather than while still covered.
@MainActor
final class AppEntrance: ObservableObject {
    static let shared = AppEntrance()
    @Published var contentRevealed = false
    private init() {}
}

/// A tappable card: sinks slightly while pressed, with a light haptic on the way down.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.tap() }
            }
    }
}

/// Fades and floats a section into place, each one a beat after the previous.
private struct EntranceModifier: ViewModifier {
    let index: Int
    let shown: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 22)
            .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(Double(index) * 0.07), value: shown)
    }
}

extension View {
    /// Staggered arrival for the `index`-th section of a screen, played when `shown` turns true.
    func entrance(_ index: Int, shown: Bool) -> some View {
        modifier(EntranceModifier(index: index, shown: shown))
    }
}
