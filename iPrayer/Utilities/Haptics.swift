//
//  Haptics.swift
//  iPrayer
//
//  One place for the app's haptic vocabulary, so every screen uses the same few sensations:
//  `tap` for pressing a card, `selection` for switching tabs, `success` when something completes,
//  `rigid` when something is deleted.
//

import UIKit

@MainActor
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func rigid() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
