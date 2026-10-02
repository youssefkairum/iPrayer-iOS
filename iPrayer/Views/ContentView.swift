//
//  ContentView.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/23/25.
//

//
//  ContentView.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/23/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PrayerViewModel
    @State private var selectedTab: Tab = ContentView.initialTab
    /// Tabs that have been opened at least once. They stay in the hierarchy so their state
    /// (Quran search text and scroll position, Settings scroll) survives switching tabs.
    @State private var loadedTabs: Set<Tab> = [ContentView.initialTab]
    /// Bumped when a tab is requested from OUTSIDE (a deep link, a Siri intent), which rebuilds the
    /// navigation stack. Every push in this app is a `NavigationLink(destination:)` on one non-path stack,
    /// so there is no programmatic pop: without this, "open Tasbih" while a surah is on screen would switch
    /// the tab UNDERNEATH the reader and leave the reader showing. Tapping the tab bar never bumps it, so
    /// ordinary tab switches keep their scroll positions and search text exactly as before.
    @State private var navigationEpoch = 0
    
    private static var initialTab: Tab {
        #if DEBUG
        // Debug-only: `-debugInitialTab quran` as a launch argument opens that tab, for screenshots and UI checks
        switch UserDefaults.standard.string(forKey: "debugInitialTab") {
        case "quran": return .quran
        case "tasbih": return .tasbih
        case "qibla": return .qibla
        case "settings": return .settings
        default: break
        }
        #endif
        return .prayers
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. The Background
                LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
                
                // 2. The Views (Full Screen, extending behind the tab bar)
                persistentTab(.prayers) { PrayerListView() }
                persistentTab(.quran) { QuranView() }
                persistentTab(.tasbih) { TasbihView() }
                persistentTab(.settings) { SettingsView() }
                
                // The compass is deliberately NOT kept alive: it runs the magnetometer
                // and a repeating animation, which must stop when the tab is left.
                if selectedTab == .qibla {
                    QiblaCompassView()
                }
                
                // 3. The Custom Floating Tab Bar (Overlay)
                VStack {
                    Spacer()
                    CustomTabBar(selectedTab: $selectedTab)
                }
                .padding(.bottom, 5) // Minimal padding, safe area handles the rest
                .ignoresSafeArea(.keyboard, edges: .bottom) // Prevents it from moving with keyboard
            }
            .onChange(of: selectedTab) { _, newTab in
                loadedTabs.insert(newTab)
            }
            // iprayer://verse/2/255 (from the Verse of the Day widget) opens the reader at that verse;
            // the router turns it into a pending tab and verse, consumed just below.
            .onOpenURL { url in
                DeepLinkRouter.shared.handle(url)
            }
        }
        .id(navigationEpoch)
        // A @Published subscription replays its current value, so a request made before this view
        // existed (a Siri intent cold-launching the app) is honoured on first appearance.
        .onReceive(DeepLinkRouter.shared.$pendingTab) { tab in
            guard let tab else { return }
            // @Published publishes in willSet, so clearing it right here would be overwritten when
            // the assignment that called us completes, and a second window would replay the tab.
            DispatchQueue.main.async { DeepLinkRouter.shared.pendingTab = nil }
            // The compass has nothing pushed to pop and something to lose: rebuilt in place, the new
            // view's onAppear runs BEFORE the old one's onDisappear, and the shared view model is
            // left with the compass stopped.
            if !(tab == .qibla && selectedTab == .qibla) { navigationEpoch += 1 }
            loadedTabs.insert(tab)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = tab }
        }
    }
    
    /// Builds a tab lazily on first visit, then hides it instead of destroying it.
    @ViewBuilder
    private func persistentTab<Content: View>(_ tab: Tab, @ViewBuilder content: () -> Content) -> some View {
        if loadedTabs.contains(tab) || selectedTab == tab {
            let isSelected = selectedTab == tab
            content()
                .opacity(isSelected ? 1 : 0)
                .allowsHitTesting(isSelected)
                .accessibilityHidden(!isSelected)
        }
    }
}

// MARK: - Custom Floating Tab Bar Components
enum Tab: String, CaseIterable {
    case prayers = "clock.fill"
    case quran = "book.fill"
    case tasbih = "circle.grid.cross.fill"
    case qibla = "safari.fill"
    case settings = "gearshape.fill"
}

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    /// Bumped per tab when it is chosen, so only that icon bounces
    @State private var bounces: [Tab: Int] = [:]
    
    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                Spacer()
                Button(action: {
                    guard selectedTab != tab else { return }
                    Haptics.selection()
                    bounces[tab, default: 0] += 1
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    Image(systemName: tab.rawValue)
                        .font(.system(size: 24))
                        .symbolEffect(.bounce, value: bounces[tab, default: 0])
                        .foregroundColor(selectedTab == tab ? .teal : .gray.opacity(0.8))
                        .scaleEffect(selectedTab == tab ? 1.25 : 1.0)
                        // Glow effect for selected item
                        .shadow(color: selectedTab == tab ? .teal.opacity(0.5) : .clear, radius: 10, x: 0, y: 0)
                }
                Spacer()
            }
        }
        .frame(height: 70)
        // Liquid Glass (iOS 26). It refracts the content scrolling underneath and brings its own edge
        // highlight and shadow, so the old material, stroke and drop shadow are gone.
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.horizontal)
    }
}

// MARK: - Helper for Hex Colors
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

