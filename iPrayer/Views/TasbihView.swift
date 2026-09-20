//
//  TasbihView.swift
//  iPrayer
//
//  A bead counter for dhikr. Pick the phrase and the cycle length, then tap the disc (or anywhere
//  around it) to count. Cycles complete with a heavier tap and a pulse of the ring.
//

import SwiftUI

/// The phrases people count most. Arabic is drawn with the Quran font; the meaning follows the app language.
nonisolated struct Dhikr: Identifiable, Equatable {
    let id: String
    let arabic: String
    let meaning: String
    
    static let all: [Dhikr] = [
        Dhikr(id: "subhanallah", arabic: "سُبْحَانَ اللَّهِ", meaning: "Glory be to Allah"),
        Dhikr(id: "alhamdulillah", arabic: "الْحَمْدُ لِلَّهِ", meaning: "Praise be to Allah"),
        Dhikr(id: "allahuakbar", arabic: "اللَّهُ أَكْبَرُ", meaning: "Allah is the Greatest"),
        Dhikr(id: "lailahaillallah", arabic: "لَا إِلَهَ إِلَّا اللَّهُ", meaning: "There is no deity but Allah"),
        Dhikr(id: "astaghfirullah", arabic: "أَسْتَغْفِرُ اللَّهَ", meaning: "I seek Allah's forgiveness"),
        Dhikr(id: "salawat", arabic: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ", meaning: "O Allah, send blessings upon Muhammad")
    ]
    
    static func with(id: String) -> Dhikr { all.first { $0.id == id } ?? all[0] }
}

struct TasbihView: View {
    @AppStorage(UDKey.tasbihCount.rawValue) private var count: Int = 0
    @AppStorage(UDKey.tasbihTarget.rawValue) private var cycleTarget: Int = 33
    @AppStorage(UDKey.tasbihDhikr.rawValue) private var dhikrID: String = Dhikr.all[0].id
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    
    @State private var ripples: [UUID] = []
    @State private var syncTask: Task<Void, Never>?
    @State private var confirmReset = false
    @State private var cyclePulse = false
    
    private let ringSize: CGFloat = 230
    private let discSize: CGFloat = 260
    private let targets = [33, 99, 100]
    
    private var dhikr: Dhikr { Dhikr.with(id: dhikrID) }
    private var target: Int { max(cycleTarget, 1) }
    private var inCycle: Int { count % target }
    private var completedCycles: Int { count / target }
    
    /// One dash per bead, sized so the ring always holds exactly `target` beads
    private var dashArray: [CGFloat] {
        let circumference = ringSize * .pi
        let gap = (circumference / CGFloat(target)) - 1
        return [1, max(gap, 0.1)]
    }
    
    /// Trim halfway into the gap after the current bead so the next one never lights up early
    private var progressTrim: CGFloat {
        if count == 0 { return 0 }
        if inCycle == 0 { return 1 }
        return (CGFloat(inCycle) - 0.5) / CGFloat(target)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 14) {
                header
                dhikrChips
                
                Spacer(minLength: 0)
                
                phrase
                counter
                
                Spacer(minLength: 0)
                
                targetChips
                    .padding(.bottom, 108) // clear the floating tab bar
            }
        }
        .onChange(of: count) { _, newValue in
            // Debounce: every tap would otherwise write to the iCloud key-value store immediately
            syncTask?.cancel()
            syncTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                CloudSyncManager.shared.sync(key: UDKey.tasbihCount.rawValue, value: newValue)
            }
            markTouched()
        }
        .onChange(of: cycleTarget) { _, newValue in
            CloudSyncManager.shared.sync(key: UDKey.tasbihTarget.rawValue, value: newValue)
            markTouched()
        }
        .onAppear {
            if cycleTarget == 0 { cycleTarget = 33 }
        }
        .confirmationDialog(AppTranslations.translate("Reset the count?", to: appLanguage), isPresented: $confirmReset, titleVisibility: .visible) {
            Button(AppTranslations.translate("Reset", to: appLanguage), role: .destructive) { resetCounter() }
            Button(AppTranslations.translate("Cancel", to: appLanguage), role: .cancel) {}
        }
    }
    
    // MARK: - Pieces
    
    private var header: some View {
        HStack {
            Text(AppTranslations.translate("Tasbih", to: appLanguage))
                .font(.custom("AvenirNext-Bold", size: 34))
                .foregroundColor(.white)
            Spacer()
            Button {
                guard count > 0 else { return }
                Haptics.tap()
                confirmReset = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white.opacity(count > 0 ? 0.9 : 0.35))
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    /// Which phrase is being counted. Changing it keeps the count: many people run one count across phrases.
    private var dhikrChips: some View {
        // ScrollViewReader, not a scroll anchor. A horizontal ScrollView opens at content offset 0, which
        // is the LEFT edge whatever the layout direction — so in Arabic, where the row is laid out
        // right-to-left, the first chip and the SELECTED one both started off-screen and the row looked
        // like nothing was chosen. Scrolling to the selection by identity is direction-agnostic, and it
        // also helps English once the list is longer than the screen.
        ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(Dhikr.all) { item in
                        let selected = item.id == dhikrID
                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dhikrID = item.id }
                        } label: {
                            Text(item.arabic)
                                .font(.custom("KFGQPC Uthmanic Script HAFS", size: 15))
                                .foregroundColor(selected ? .black : .white)
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .glassEffect(selected ? .regular.tint(.teal).interactive() : .regular.interactive(), in: .capsule)
                        }
                        .id(item.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            // One run-loop turn: the row has to be laid out before it can be scrolled.
            DispatchQueue.main.async { proxy.scrollTo(dhikrID, anchor: .center) }
        }
        }
    }
    
    private var phrase: some View {
        VStack(spacing: 4) {
            Text(dhikr.arabic)
                .font(.custom("KFGQPC Uthmanic Script HAFS", size: 30))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(AppTranslations.translate(dhikr.meaning, to: appLanguage))
                .font(.custom("AvenirNext-Medium", size: 14))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 24)
        .id(dhikrID)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .animation(.easeInOut(duration: 0.25), value: dhikrID)
    }
    
    private var counter: some View {
        ZStack {
            ForEach(ripples, id: \.self) { _ in RippleEffect() }
            
            Circle()
                .fill(Color.teal.opacity(cyclePulse ? 0.35 : 0.12))
                .frame(width: discSize + 30, height: discSize + 30)
                .blur(radius: 24)
                .animation(.easeOut(duration: 0.5), value: cyclePulse)
            
            // Interactive Liquid Glass: it shimmers and flexes under the finger on every count
            Circle()
                .fill(Color.clear)
                .frame(width: discSize, height: discSize)
                .glassEffect(.regular.interactive(), in: .circle)
            
            // Beads: the faint full ring and the lit ones so far this cycle
            Circle()
                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 12, lineCap: .round, dash: dashArray))
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
            Circle()
                .trim(from: 0, to: progressTrim)
                .stroke(AngularGradient(gradient: Gradient(colors: [.teal.opacity(0.55), .teal]), center: .center),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round, dash: dashArray))
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: count)
            
            VStack(spacing: 2) {
                Text("\(inCycle == 0 && count > 0 ? target : inCycle)")
                    .font(.system(size: 68, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: count)
                Text("\(AppTranslations.translate("of", to: appLanguage)) \(target)")
                    .font(.custom("AvenirNext-DemiBold", size: 13))
                    .foregroundColor(.teal)
                if completedCycles > 0 {
                    Text("\(completedCycles) \(AppTranslations.translate("cycles", to: appLanguage)) · \(count)")
                        .font(.custom("AvenirNext-Medium", size: 12))
                        .foregroundColor(.white.opacity(0.55))
                        .padding(.top, 4)
                        .contentTransition(.numericText())
                }
            }
        }
        // The whole band around the disc counts, not just the disc: thumbs miss
        .frame(maxWidth: .infinity)
        .frame(height: discSize + 60)
        .contentShape(Rectangle())
        .onTapGesture { incrementCounter() }
    }
    
    private var targetChips: some View {
        HStack(spacing: 10) {
            ForEach(targets, id: \.self) { value in
                let selected = value == cycleTarget
                Button {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { cycleTarget = value }
                } label: {
                    Text("\(value)")
                        .font(.custom("AvenirNext-DemiBold", size: 15))
                        .foregroundColor(selected ? .black : .white)
                        .frame(width: 64, height: 36)
                        .glassEffect(selected ? .regular.tint(.teal).interactive() : .regular.interactive(), in: .capsule)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    /// Stamps the change so the watch knows the phone is newer, then sends it
    private func markTouched() {
        UserDefaults.standard.set(Date(), forKey: UDKey.tasbihUpdatedAt.rawValue)
        PhoneWatchSync.shared.schedulePush()
    }
    
    private func incrementCounter() {
        let ripple = UUID()
        ripples.append(ripple)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ripples.removeAll { $0 == ripple }
        }
        
        count += 1
        
        if count % target == 0 {
            // Cycle complete: heavier tap and a pulse of the ring
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            cyclePulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { cyclePulse = false }
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    private func resetCounter() {
        Haptics.success()
        withAnimation { count = 0 }
    }
}

// Ripple Animation View
struct RippleEffect: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.6
    
    var body: some View {
        Circle()
            .stroke(Color.teal.opacity(opacity), lineWidth: 4)
            .frame(width: 260, height: 260)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    scale = 1.3
                    opacity = 0
                }
            }
    }
}

// Custom Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
