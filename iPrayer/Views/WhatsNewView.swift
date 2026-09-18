//
//  WhatsNewView.swift
//  iPrayer
//
//  A short tour shown once to people who UPDATE the app. Fresh installs see onboarding instead.
//

import SwiftUI

struct WhatsNewView: View {
    /// The release this page describes. It is shown to anyone who hasn't yet seen a page for this
    /// version or a later one, so a bug-fix release (1.1.1) doesn't show it a second time.
    /// When writing the page for a new release, update this and `sections`.
    static let contentVersion = "1.1.0"
    
    struct Item: Identifiable {
        let icon: String
        /// English prayer name whose palette colours the tile, so the page uses the app's own colours
        let prayer: String
        let text: String         // AppTranslations key, one short line
        /// nil shows the item to everyone; otherwise only to people using one of these app languages
        var languages: Set<String>? = nil
        var id: String { text }
    }
    
    struct Section: Identifiable {
        let title: String        // AppTranslations key
        let items: [Item]
        var id: String { title }
    }
    
    static let sections: [Section] = [
        Section(title: "Quran", items: [
            Item(icon: "headphones", prayer: "Maghrib", text: "Quran recitation with six reciters"),
            Item(icon: "arrow.down.circle.fill", prayer: "Dhuhr", text: "Download surahs to listen offline"),
            Item(icon: "book.fill", prayer: "Asr", text: "Complete recitation marks in the Quran text"),
            Item(icon: "bookmark.fill", prayer: "Fajr", text: "Resume at your verse, bookmarks and verse search")
        ]),
        Section(title: "Every day", items: [
            Item(icon: "sun.horizon.fill", prayer: "Sunrise", text: "A Home screen that fits everything at a glance"),
            Item(icon: "text.book.closed.fill", prayer: "Asr", text: "Verse of the Day, on Home and as a widget"),
            Item(icon: "hands.and.sparkles.fill", prayer: "Fajr", text: "Dua of the Day and a library of 50 duas with the morning and evening adhkar"),
            Item(icon: "bell.badge.fill", prayer: "Maghrib", text: "Prayer alerts a week ahead, plus a pre-prayer reminder")
        ]),
        Section(title: "Everywhere", items: [
            Item(icon: "applewatch", prayer: "Isha", text: "An Apple Watch app with complications"),
            Item(icon: "square.grid.2x2.fill", prayer: "Dhuhr", text: "Today's prayers and the next prayer as widgets, in each prayer's colors"),
            Item(icon: "icloud.fill", prayer: "Sunrise", text: "Streak, bookmarks and reading position in iCloud")
        ]),
        Section(title: "Look and feel", items: [
            Item(icon: "sparkles", prayer: "Dhuhr", text: "A new Liquid Glass look with animations and haptics"),
            Item(icon: "globe", prayer: "Isha", text: "Right-to-left layout for Arabic and Urdu", languages: ["ar", "ur"])
        ])
    ]
    
    /// True when `seenVersion` is older than this page. Compares numerically, so "1.10" > "1.9".
    static func shouldShow(after seenVersion: String) -> Bool {
        seenVersion.isEmpty || seenVersion.compare(contentVersion, options: .numeric) == .orderedAscending
    }
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @State private var revealed = false
    
    private var visibleSections: [Section] {
        Self.sections.compactMap { section in
            let items = section.items.filter { $0.languages?.contains(appLanguage) ?? true }
            return items.isEmpty ? nil : Section(title: section.title, items: items)
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            BackgroundPatternView()
                .opacity(0.25)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        header
                            .entrance(0, shown: revealed)
                        
                        ForEach(Array(visibleSections.enumerated()), id: \.element.id) { index, section in
                            sectionCard(section)
                                .entrance(index + 1, shown: revealed)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 16)
                }
                
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Text(AppTranslations.translate("Continue", to: appLanguage))
                        .font(.custom("AvenirNext-Bold", size: 17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .glassEffect(.regular.tint(.teal).interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .onAppear { revealed = true }
    }
    
    // MARK: - Pieces
    
    private var header: some View {
        VStack(spacing: 10) {
            Group {
                if let icon = Bundle.main.icon {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.teal)
                        .frame(width: 72, height: 72)
                }
            }
            .shadow(color: .teal.opacity(0.4), radius: 22, x: 0, y: 8)
            
            Text(AppTranslations.translate("What's New", to: appLanguage))
                .font(.custom("AvenirNext-Bold", size: 30))
                .foregroundColor(.white)
            
            Text("\(AppTranslations.catalogString("Version", language: appLanguage)) \(Self.contentVersion)")
                .font(.custom("AvenirNext-DemiBold", size: 13))
                .foregroundColor(.teal)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .glassEffect(.regular, in: .capsule)
        }
    }
    
    private func sectionCard(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppTranslations.translate(section.title, to: appLanguage))
                .font(.custom("AvenirNext-Bold", size: 15))
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(PrayerPalette.palette(for: item.prayer).gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        
                        Text(AppTranslations.translate(item.text, to: appLanguage))
                            .font(.custom("AvenirNext-Medium", size: 14))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    
                    if index < section.items.count - 1 {
                        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1).padding(.leading, 62)
                    }
                }
            }
            .background(Material.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

#Preview {
    WhatsNewView()
}
