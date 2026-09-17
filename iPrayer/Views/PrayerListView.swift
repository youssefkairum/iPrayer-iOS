//
//  PrayerListView.swift
//  iPrayer
//

import SwiftUI
import Combine

struct PrayerListView: View {
    @EnvironmentObject var viewModel: PrayerViewModel
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @State private var timeRemaining: String = "00:00:00"
    @StateObject private var accountManager = AccountManager.shared
    
    // Grid layout for the home widgets
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    // Timer to update the countdown every second
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
        
        NavigationView {
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
                                    icon: nextPrayer.icon,
                                    timeRemaining: timeRemaining
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
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
            }
            .background(Color.clear)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onReceive(timer) { _ in
            updateCountdown()
        }
        .onAppear {
            updateCountdown()
        }
    }
    
    func updateCountdown() {
        guard let nextPrayer = viewModel.prayerTimes.first(where: { $0.isNext }) else { return }
        
        let diff = nextPrayer.time.timeIntervalSinceNow
        
        if diff > 0 {
            let hours = Int(diff) / 3600
            let minutes = (Int(diff) % 3600) / 60
            let seconds = Int(diff) % 60
            timeRemaining = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            timeRemaining = "00:00:00"
            if diff < -60 { viewModel.refreshPrayers() }
        }
    }
}

// MARK: - Subviews

struct HeroCard: View {
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    let prayerName: String
    let prayerTime: Date
    let icon: String
    let timeRemaining: String
    
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
                        
                        Text("\(AppTranslations.translate("at", to: appLanguage)) \(prayerTime.formatted(date: .omitted, time: .shortened))")
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
                        Text(timeRemaining)
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
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
}

struct TimelineRow: View {
    let prayer: PrayerItem
    
    var isPast: Bool {
        return !prayer.isNext && prayer.time < Date()
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // Timeline Node
            ZStack {
                Circle()
                    .fill(prayer.isNext ? PrayerTheme.theme(for: prayer.name).shadowColor : (isPast ? Color.gray.opacity(0.3) : Color.white.opacity(0.1)))
                    .frame(width: 40, height: 40)
                
                Image(systemName: prayer.icon)
                    .foregroundColor(prayer.isNext ? .white : (isPast ? .gray : .white))
                    .font(.system(size: 14))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(prayer.name))
                    .font(.custom("AvenirNext-DemiBold", size: 18))
                    .foregroundColor(isPast ? .gray : .white)
                
                if prayer.isNext {
                    Text("Upcoming")
                        .font(.caption)
                        .foregroundColor(PrayerTheme.theme(for: prayer.name).shadowColor)
                }
            }
            
            Spacer()
            
            Text(prayer.time, style: .time)
                .font(.system(size: 16, weight: prayer.isNext ? .bold : .medium, design: .monospaced))
                .foregroundColor(prayer.isNext ? PrayerTheme.theme(for: prayer.name).shadowColor : (isPast ? .gray : .white))
        }
        .padding()
        .background(Material.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(prayer.isNext ? PrayerTheme.theme(for: prayer.name).shadowColor.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
        )
        .opacity(isPast ? 0.7 : 1.0)
    }
}
