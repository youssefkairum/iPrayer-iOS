import SwiftUI

struct PremiumWidgetCardStyle: ViewModifier {
    /// nil lets the card size itself to its content (used by full-width cards)
    var height: CGFloat? = 140
    
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: height)
            .background(Material.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func premiumWidgetCard(height: CGFloat? = 140) -> some View {
        self.modifier(PremiumWidgetCardStyle(height: height))
    }
}
