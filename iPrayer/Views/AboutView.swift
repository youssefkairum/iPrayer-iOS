import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            // Background Effect
            BackgroundPatternView()
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading, spacing: 0) {
                // Top Custom Nav Bar
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Title
                Text("About")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // App Icon and Version
                        VStack(spacing: 15) {
                            if let icon = Bundle.main.icon {
                                Image(uiImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 5)
                            } else {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white)
                                    .frame(width: 120, height: 120)
                                    .background(Color.teal)
                                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                                    .shadow(color: .teal.opacity(0.5), radius: 15, x: 0, y: 5)
                            }
                            
                            VStack(spacing: 5) {
                                Text("iPrayer")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("\(AppTranslations.catalogString("Version", language: appLanguage)) \(appVersion)")
                                    .font(.system(size: 18))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 30)
                        
                        // Resources Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Resources")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 5)
                            
                            VStack(spacing: 0) {
                                LinkRow(title: "Terms of Use", icon: "doc.text.fill", url: "https://x3roe.com/iprayer-terms.html")
                                Divider().background(Color.white.opacity(0.15)).padding(.leading, 50)
                                LinkRow(title: "Privacy Policy", icon: "hand.raised.fill", url: "https://x3roe.com/iprayer-privacy.html")
                                Divider().background(Color.white.opacity(0.15)).padding(.leading, 50)
                                LinkRow(title: "Developer Website", icon: "safari.fill", url: "https://x3roe.com/")
                            }
                            .background(Material.ultraThinMaterial)
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                        
                        Text("© 2026 Youssef Keram. All rights reserved.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 120) // Space for TabBar
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct LinkRow: View {
    let title: String
    let icon: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .foregroundColor(.teal)
                    .font(.system(size: 20))
                    .frame(width: 24)
                
                Text(LocalizedStringKey(title))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.teal)
                
                Spacer()
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    AboutView()
}
