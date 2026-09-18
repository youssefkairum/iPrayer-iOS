//
//  SplashScreenView.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/26/25.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 30
    @State private var textOpacity: Double = 0.0
    @State private var glowPulse: CGFloat = 1.0
    @State private var footerOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // 1. Background
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            // 2. Rotating Geometric Pattern
            BackgroundPatternView()
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                // 3. App Icon & Name
                VStack(spacing: 20) {
                    ZStack {
                        // Breathing Glow
                        Circle()
                            .fill(Color.teal.opacity(0.4))
                            .frame(width: 150, height: 150)
                            .blur(radius: 40)
                            .scaleEffect(glowPulse)
                        
                        // Fetch the actual App Icon from the Bundle
                        if let icon = Bundle.main.icon {
                            Image(uiImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        } else {
                            Image(systemName: "moon.stars.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .foregroundColor(.teal)
                                .frame(width: 120, height: 120)
                                .background(Material.ultraThinMaterial)
                                .cornerRadius(25)
                        }
                    }
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                    
                    Text("iPrayer")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 5)
                        .offset(y: textOffset)
                        .opacity(textOpacity)
                }
                
                Spacer()
                
                // 4. Copyright Footer
                let year = Calendar.current.component(.year, from: Date())
                Text("© \(String(year)) Youssef Keram. All rights reserved.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.bottom, 40)
                    .opacity(footerOpacity)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // 1. Icon spring entrance
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        // 2. Continuous breathing glow
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowPulse = 1.3
        }
        
        // 3. Staggered text reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.8)) {
                textOffset = 0
                textOpacity = 1.0
            }
        }
        
        // 4. Footer fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 1.0)) {
                footerOpacity = 1.0
            }
        }
    }
}

struct BackgroundPatternView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        GeometryReader { geo in
            let size: CGFloat = 80
            // Calculate enough columns and rows to cover the screen even when rotated
            let cols = Int(geo.size.width / size) + 4
            let rows = Int(geo.size.height / size) + 4
            
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<cols, id: \.self) { col in
                            ZStack {
                                Rectangle()
                                    .stroke(Color(hex: "D4AF37").opacity(0.08), lineWidth: 1)
                                    .frame(width: size * 0.7, height: size * 0.7)
                                Rectangle()
                                    .stroke(Color(hex: "D4AF37").opacity(0.08), lineWidth: 1)
                                    .frame(width: size * 0.7, height: size * 0.7)
                                    .rotationEffect(.degrees(45))
                            }
                            .frame(width: size, height: size)
                        }
                    }
                }
            }
            .frame(width: geo.size.width * 1.5, height: geo.size.height * 1.5)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }
}

// MARK: - Helper to Fetch Default App Icon
extension Bundle {
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}
