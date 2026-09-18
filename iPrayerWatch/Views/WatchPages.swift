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
    @State private var crown: Double = 0
    @State private var crownBase: Double = 0
    @State private var pulse = false
    
    private var safeTarget: Int { max(target, 1) }
    private var progress: Double { Double(count % safeTarget) / Double(safeTarget) }
    private var cycles: Int { count / safeTarget }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(pulse ? Color.yellow : Color.teal, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.2), value: progress)
                .animation(.easeOut(duration: 0.4), value: pulse)
            
            VStack(spacing: 2) {
                Text("\(count % safeTarget == 0 && count > 0 ? safeTarget : count % safeTarget)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: count)
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
        // The Digital Crown counts too: one bead per detent
        .focusable()
        .digitalCrownRotation($crown, from: 0, through: 100_000, by: 1, sensitivity: .medium,
                              isContinuous: true, isHapticFeedbackEnabled: false)
        .onChange(of: crown) { _, value in
            let steps = Int((value - crownBase).rounded(.towardZero))
            guard steps >= 1 else { return }
            crownBase = value
            for _ in 0..<min(steps, 5) { increment() }
        }
        .navigationTitle(AppTranslations.translate("Tasbih", to: model.language))
        .containerBackground(for: .tabView) { watchNightGradient }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { confirmReset = true } label: { Image(systemName: "arrow.counterclockwise") }
                    .disabled(count == 0)
                    .accessibilityLabel(AppTranslations.translate("Reset", to: model.language))
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
        .confirmationDialog(AppTranslations.translate("Reset the count?", to: model.language), isPresented: $confirmReset) {
            Button(AppTranslations.translate("Reset", to: model.language), role: .destructive) {
                count = 0
                WKInterfaceDevice.current().play(.success)
                touched()
            }
        }
        .accessibilityLabel("\(AppTranslations.translate("Tasbih", to: model.language)) \(count)")
    }
    
    private func increment() {
        count += 1
        if count % safeTarget == 0 {
            WKInterfaceDevice.current().play(.success)
            pulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pulse = false }
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
    
    private var offset: Double {
        var delta = (model.qiblaDirection - model.currentHeading).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }
    private var isFacingQibla: Bool { abs(offset) < 5 }
    
    private var distanceText: String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter.string(from: Measurement(value: model.distanceToKaabaMetres, unit: UnitLength.meters))
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
                            .fill(i == 0 ? Color.red : (i % 3 == 0 ? Color.white : Color.white.opacity(0.3)))
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
                .rotationEffect(.degrees(offset))
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: model.currentHeading)
                
                VStack(spacing: 0) {
                    Text("\(Int(model.qiblaDirection.rounded()))°")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                    Text(model.headingAvailable
                         ? AppTranslations.translate(isFacingQibla ? "Facing Mecca" : "Qibla", to: model.language)
                         : AppTranslations.translate("Compass unavailable", to: model.language))
                        .font(.caption2)
                        .foregroundStyle(isFacingQibla ? .yellow : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if model.distanceToKaabaMetres > 0 {
                        Text(distanceText)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .offset(y: size * 0.26)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .containerBackground(for: .tabView) { watchNightGradient }
        .onAppear { model.startCompass() }
        .onDisappear { model.stopCompass() }
        .onChange(of: isFacingQibla) { _, facing in
            if facing { WKInterfaceDevice.current().play(.success) }
        }
        .accessibilityLabel("\(AppTranslations.translate("Qibla", to: model.language)) \(Int(model.qiblaDirection.rounded()))°")
    }
}
