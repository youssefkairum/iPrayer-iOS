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
    @State private var selectedTab: Tab = .prayers
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. The Background
                LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
            
            // 2. The Views (Full Screen)
            // FIX: Removed the .padding(.bottom, 80) here.
            // Now the views extend all the way down behind the tab bar.
            Group {
                switch selectedTab {
                case .prayers:
                    PrayerListView()
                case .quran:
                    QuranView()
                case .tasbih:
                    TasbihView()
                case .qibla:
                    QiblaCompassView()
                case .settings:
                    SettingsView()
                }
            }
            
            // 3. The Custom Floating Tab Bar (Overlay)
            VStack {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab)
            }
            .padding(.bottom, 5) // Minimal padding, safe area handles the rest
            .ignoresSafeArea(.keyboard, edges: .bottom) // Prevents it from moving with keyboard
        }
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
    
    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    Image(systemName: tab.rawValue)
                        .font(.system(size: 24))
                        .foregroundColor(selectedTab == tab ? .teal : .gray.opacity(0.8))
                        .scaleEffect(selectedTab == tab ? 1.25 : 1.0)
                        // Glow effect for selected item
                        .shadow(color: selectedTab == tab ? .teal.opacity(0.5) : .clear, radius: 10, x: 0, y: 0)
                }
                Spacer()
            }
        }
        .frame(height: 70)
        .background(Material.ultraThinMaterial)
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
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

