//
//  WatchPages.swift
//  iPrayerWatch
//
//  Tasbih and Qibla pages.
//

import SwiftUI
import WatchKit

// MARK: - Tasbih

struct TasbihPage: View {
    @EnvironmentObject private var model: WatchModel
    @AppStorage(UDKey.tasbihCount.rawValue) private var count: Int = 0
    @AppStorage(UDKey.tasbihTarget.rawValue) private var target: Int = 33
    @State private var confirmReset = false
    
    private var progress: Double {
        target > 0 ? Double(count % target) / Double(target) : 0
    }
    private var cycles: Int { target > 0 ? count / target : 0 }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.teal, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.2), value: progress)
            
            VStack(spacing: 2) {
                Text("\(count % max(target, 1))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("\(AppTranslations.translate("of", to: model.language)) \(target)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if cycles > 0 {
                    Text("\(cycles) \(AppTranslations.translate("cycles", to: model.language))")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                }
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture { increment() }
        .navigationTitle(AppTranslations.translate("Tasbih", to: model.language))
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { confirmReset = true } label: { Image(systemName: "arrow.counterclockwise") }
                Spacer()
                // No Menu on watchOS: the button cycles through the usual targets
                Button {
                    let options = [33, 99, 100]
                    let index = options.firstIndex(of: target) ?? -1
                    target = options[(index + 1) % options.count]
                    WKInterfaceDevice.current().play(.click)
                    touched()
                } label: {
                    Text("\(target)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
            }
        }
        .confirmationDialog(AppTranslations.translate("Reset", to: model.language), isPresented: $confirmReset) {
            Button(AppTranslations.translate("Reset", to: model.language), role: .destructive) {
                count = 0
                WKInterfaceDevice.current().play(.success)
                touched()
            }
        }
    }
    
    private func increment() {
        count += 1
        if target > 0, count % target == 0 {
            WKInterfaceDevice.current().play(.success)
        } else {
            WKInterfaceDevice.current().play(.click)
        }
        touched()
    }
    
    /// Stamps the change so the phone knows the wrist is newer, then sends it
    private func touched() {
        UserDefaults.standard.set(Date(), forKey: UDKey.tasbihUpdatedAt.rawValue)
        WatchSync.shared.schedulePush()
    }
}

// MARK: - Qibla

struct QiblaPage: View {
    @EnvironmentObject private var model: WatchModel
    
    private var isFacingQibla: Bool {
        let difference = abs(model.currentHeading - model.qiblaDirection)
        return min(difference, 360 - difference) < 5
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) - 16
            ZStack {
                Circle()
                    .stroke(isFacingQibla ? Color.yellow.opacity(0.9) : Color.white.opacity(0.25), lineWidth: 3)
                    .frame(width: size, height: size)
                
                // Cardinal marks turn with the heading so north stays north
                ForEach(0..<12, id: \.self) { i in
                    VStack {
                        Circle()
                            .fill(i % 3 == 0 ? Color.white : Color.white.opacity(0.3))
                            .frame(width: i % 3 == 0 ? 5 : 3, height: i % 3 == 0 ? 5 : 3)
                        Spacer()
                    }
                    .frame(height: size - 10)
                    .rotationEffect(.degrees(Double(i) * 30))
                }
                .rotationEffect(.degrees(-model.currentHeading))
                .animation(.easeInOut(duration: 0.2), value: model.currentHeading)
                
                // Kaaba pointer
                VStack(spacing: 2) {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.caption2)
                        .foregroundStyle(isFacingQibla ? .yellow : .teal)
                    Text("🕋").font(.system(size: 22))
                    Spacer()
                }
                .frame(height: size + 10)
                .rotationEffect(.degrees(model.qiblaDirection - model.currentHeading))
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: model.currentHeading)
                
                VStack(spacing: 0) {
                    Text("\(Int(model.qiblaDirection))°")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                    Text(AppTranslations.translate(isFacingQibla ? "Facing Mecca" : "Qibla", to: model.language))
                        .font(.caption2)
                        .foregroundStyle(isFacingQibla ? .yellow : .secondary)
                }
                .offset(y: size * 0.28)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear { model.startCompass() }
        .onDisappear { model.stopCompass() }
        .onChange(of: isFacingQibla) { _, facing in
            if facing { WKInterfaceDevice.current().play(.success) }
        }
    }
}
