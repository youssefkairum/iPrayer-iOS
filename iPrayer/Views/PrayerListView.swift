//
//  PrayerListView.swift
//  iPrayer
//

import SwiftUI
import Combine

struct PrayerListView: View {
    @EnvironmentObject var viewModel: PrayerViewModel
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @StateObject private var accountManager = AccountManager.shared
    @Environment(\.openURL) private var openURL
    
    // Grid layout for the home widgets
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    // Coarse timer used only to recalculate once the next prayer has passed.
    // The per-second countdown lives inside HeroCard so it doesn't re-render this whole screen.
    private let refreshTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    
    var islamicDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }
    
    private var timeGreetingString: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 17 { return "Good afternoon" }
        else { return "Good evening" }
    }
    
    var body: some View {
        let name = accountManager.userName.trimmingCharacters(in: .whitespaces)
        let firstName = name.components(separatedBy: " ").first ?? name
        
        // No inner NavigationView: pushes go through the NavigationStack in ContentView,
        // whose gradient background would otherwise be hidden by the navigation container.
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                
                // 1. DASHBOARD HEADER
                VStack(alignment: .leading, spacing: 5) {
                    Text(islamicDate)
                        .font(.custom("AvenirNext-Medium", size: 16))
                        .foregroundColor(.gray)
                    
                    HStack(alignment: .top) {
                        if !firstName.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 0) {
                                    Text(AppTranslations.translate(timeGreetingString, to: appLanguage))
                                    Text(",")
                                }
                                Text(firstName)
                            }
                            .font(.custom("AvenirNext-Bold", size: 34))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        } else {
                            Text(AppTranslations.translate(timeGreetingString, to: appLanguage))
                                .font(.custom("AvenirNext-Bold", size: 34))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        
                        Spacer()
                        
                        // Location Pill
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.teal)
                            Text(viewModel.locationName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
                
                // 2. HERO CARD (Next Prayer) — Tappable
                if let nextPrayer = viewModel.prayerTimes.first(where: { $0.isNext }) {
                    NavigationLink(destination: PrayerDetailView(nextPrayerName: nextPrayer.name)
                        .environmentObject(viewModel)
                    ) {
                        HeroCard(
                            prayerName: nextPrayer.name,
                            prayerTime: nextPrayer.time,
                            icon: nextPrayer.icon
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                } else if let error = viewModel.locationError {
                    LocationErrorCard(
                        message: AppTranslations.translate(error, to: appLanguage),
                        buttonTitle: AppTranslations.translate("Open Settings", to: appLanguage)
                    ) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    Text("Loading Prayers...")
                        .foregroundColor(.white)
                        .padding(.top, 50)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // 3. WIDGETS GRID
                LazyVGrid(columns: columns, spacing: 10) {
                    StreakWidgetView()
                    NavigationLink(destination: DuaLibraryView()) {
                        DuasLibraryWidgetView()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
            }
            .padding(.top, 20)
            .padding(.bottom, 100) // Clear the floating tab bar
        }
        .navigationBarHidden(true)
        .onReceive(refreshTimer) { _ in
            if let nextPrayer = viewModel.prayerTimes.first(where: { $0.isNext }),
               nextPrayer.time.timeIntervalSinceNow < -60 {
                viewModel.refreshPrayers()
            }
        }
    }
}

// MARK: - Subviews

struct HeroCard: View {
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    let prayerName: String
    let prayerTime: Date
    let icon: String
    
    var theme: PrayerTheme {
        PrayerTheme.theme(for: prayerName)
    }
    
    var body: some View {
        ZStack {
            // Dynamic Background inside the card
            theme.gradient
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.white)
                    Spacer()
                    Text(AppTranslations.translate("NEXT", to: appLanguage))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(AppTranslations.translate(prayerName, to: appLanguage))
                            .font(.custom("AvenirNext-Bold", size: 38))
                            .foregroundColor(.white)
                        
                        Text("\(AppTranslations.translate("at", to: appLanguage)) \(prayerTime.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: appLanguage))))")
                            .font(.custom("AvenirNext-Medium", size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(AppTranslations.translate("Starts in", to: appLanguage))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        // TimelineView redraws only this text once per second
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(countdown(at: context.date))
                                .font(.system(size: 26, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(18)
        }
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: theme.shadowColor.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    private func countdown(at date: Date) -> String {
        let diff = max(0, Int(prayerTime.timeIntervalSince(date)))
        return String(format: "%02d:%02d:%02d", diff / 3600, (diff % 3600) / 60, diff % 60)
    }
}

/// Shown in place of the hero card when location access has been denied.
struct LocationErrorCard: View {
    let message: String
    let buttonTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 34))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.custom("AvenirNext-Medium", size: 16))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: action) {
                Text(buttonTitle)
                    .font(.custom("AvenirNext-Bold", size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.teal)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Material.ultraThinMaterial)
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
