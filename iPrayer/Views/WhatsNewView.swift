//
//  WhatsNewView.swift
//  iPrayer
//
//  A short summary shown once to people who UPDATE the app. Fresh installs see onboarding instead.
//

import SwiftUI

struct WhatsNewView: View {
    /// The release this page describes. It is shown to anyone who hasn't yet seen a page for this
    /// version or a later one, so a bug-fix release (1.1.1) doesn't show it a second time.
    /// When writing the page for a new release, update this and `items`.
    static let contentVersion = "1.1.0"
    
    struct Item: Identifiable {
        let icon: String
        let color: Color
        let text: String         // AppTranslations key, one short line
        /// nil shows the item to everyone; otherwise only to people using one of these app languages
        var languages: Set<String>? = nil
        var id: String { text }
    }
    
    static let items: [Item] = [
        Item(icon: "sparkles", color: .cyan, text: "A new Liquid Glass look"),
        Item(icon: "headphones", color: .pink, text: "Quran recitation with six reciters"),
        Item(icon: "arrow.down.circle.fill", color: .mint, text: "Download surahs to listen offline"),
        Item(icon: "book.fill", color: .yellow, text: "Complete recitation marks in the Quran text"),
        Item(icon: "bookmark.fill", color: .orange, text: "Resume at your verse, bookmarks and verse search"),
        Item(icon: "textformat.size", color: .teal, text: "Text size and a dark reading theme"),
        Item(icon: "bell.badge.fill", color: .red, text: "Prayer alerts a week ahead, plus a pre-prayer reminder"),
        Item(icon: "square.grid.2x2.fill", color: .purple, text: "Widgets in each prayer's colors"),
        Item(icon: "calendar", color: .blue, text: "Tomorrow's times and a Verse of the Day on Home"),
        Item(icon: "globe", color: .green, text: "Right-to-left layout for Arabic and Urdu", languages: ["ar", "ur"]),
        Item(icon: "icloud.fill", color: .indigo, text: "Streak, bookmarks and reading position in iCloud")
    ]
    
    /// True when `seenVersion` is older than this page. Compares numerically, so "1.10" > "1.9".
    static func shouldShow(after seenVersion: String) -> Bool {
        seenVersion.isEmpty || seenVersion.compare(contentVersion, options: .numeric) == .orderedAscending
    }
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(AppTranslations.translate("What's New", to: appLanguage))
                        .font(.custom("AvenirNext-Bold", size: 34))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("\(AppTranslations.catalogString("Version", language: appLanguage)) \(Self.contentVersion)")
                        .font(.custom("AvenirNext-Medium", size: 15))
                        .foregroundColor(.gray)
                }
                .padding(.top, 44)
                .padding(.bottom, 26)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Self.items.filter { $0.languages?.contains(appLanguage) ?? true }) { item in
                            HStack(spacing: 14) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(item.color)
                                    .frame(width: 34, height: 34)
                                    .background(item.color.opacity(0.16))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                
                                Text(AppTranslations.translate(item.text, to: appLanguage))
                                    .font(.custom("AvenirNext-Medium", size: 16))
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)
                }
                
                Button(action: { dismiss() }) {
                    Text(AppTranslations.translate("Continue", to: appLanguage))
                        .font(.custom("AvenirNext-Bold", size: 18))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .glassEffect(.regular.tint(.teal).interactive(), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    WhatsNewView()
}
