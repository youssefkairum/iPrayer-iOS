import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @AppStorage(UDKey.hasSeenOnboarding.rawValue) private var hasSeenOnboarding: Bool = false
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @StateObject private var accountManager = AccountManager.shared
    @State private var currentTab = 0
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            // Background Effect
            BackgroundPatternView()
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            TabView(selection: $currentTab) {
                // MARK: - Slide 1: Welcome
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.teal)
                        .shadow(color: .teal.opacity(0.5), radius: 20, x: 0, y: 0)
                    
                    VStack(spacing: 15) {
                        Text("Welcome to iPrayer")
                            .font(.custom("AvenirNext-Bold", size: 36))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Your premium companion for daily prayers, Tasbih, and Quran reading.")
                            .font(.custom("AvenirNext-Medium", size: 18))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation { currentTab = 1 }
                    }) {
                        Text("Next")
                            .font(.custom("AvenirNext-Bold", size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.teal)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
                .tag(0)
                
                // MARK: - Slide 2: Features
                VStack(spacing: 30) {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 35) {
                        FeatureRow(icon: "clock.fill", title: "Accurate Prayers", description: "Get precise prayer times based on your location and calculation method.")
                        FeatureRow(icon: "circle.grid.cross.fill", title: "Tasbih Counter", description: "Keep track of your daily Dhikr with a beautiful, haptic-enabled counter.")
                        FeatureRow(icon: "book.fill", title: "The Holy Quran", description: "Read the entire Quran and seamlessly save your reading progress.")
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation { currentTab = 2 }
                    }) {
                        Text("Next")
                            .font(.custom("AvenirNext-Bold", size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.teal)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
                .tag(1)
                
                // MARK: - Slide 3: Secure Sign In
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .shadow(color: .blue.opacity(0.5), radius: 20, x: 0, y: 0)
                    
                    VStack(spacing: 15) {
                        Text("Secure Cloud Sync")
                            .font(.custom("AvenirNext-Bold", size: 36))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Sign in with Apple to securely back up your Tasbih counts and bookmarks across all your devices. We never share your data.")
                            .font(.custom("AvenirNext-Medium", size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 15) {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    
                                    // Start iCloud Sync FIRST, so that any new name/email we get from Apple is pushed UP to iCloud
                                    CloudSyncManager.shared.startSyncing()
                                    
                                    accountManager.appleUserId = appleIDCredential.user
                                    accountManager.isLoggedIn = true
                                    
                                    if let fullName = appleIDCredential.fullName {
                                        let given = fullName.givenName ?? ""
                                        let family = fullName.familyName ?? ""
                                        let name = "\(given) \(family)".trimmingCharacters(in: .whitespaces)
                                        if !name.isEmpty {
                                            accountManager.userName = name
                                        }
                                    }
                                    if let email = appleIDCredential.email {
                                        accountManager.userEmail = email
                                    }
                                    
                                    finishOnboarding()
                                }
                            case .failure(let error):
                                print("Sign in failed: \(error.localizedDescription)")
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        
                        Button(action: {
                            finishOnboarding()
                        }) {
                            Text("Skip for now")
                                .font(.custom("AvenirNext-Medium", size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            
            // Language Selector Floating Top Right
            VStack {
                HStack {
                    Spacer()
                    Menu {
                        Picker("Language", selection: $appLanguage) {
                            Text("🇺🇸 English").tag("en")
                            Text("🇸🇦 العربية (Arabic)").tag("ar")
                            Text("🇫🇷 Français (French)").tag("fr")
                            Text("🇩🇪 Deutsch (German)").tag("de")
                            Text("🇮🇳 हिन्दी (Hindi)").tag("hi")
                            Text("🇷🇺 Русский (Russian)").tag("ru")
                            Text("🇹🇷 Türkçe (Turkish)").tag("tr")
                            Text("🇵🇰 اردو (Urdu)").tag("ur")
                            Text("🇨🇳 中文 (Chinese)").tag("zh-Hans")
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(flag(for: appLanguage))
                                .font(.title2)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(20)
                    }
                    .padding(.top, 50)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
            .zIndex(10)
        }
    }
    
    private func flag(for lang: String) -> String {
        switch lang {
        case "en": return "🇺🇸"
        case "ar": return "🇸🇦"
        case "fr": return "🇫🇷"
        case "de": return "🇩🇪"
        case "hi": return "🇮🇳"
        case "ru": return "🇷🇺"
        case "tr": return "🇹🇷"
        case "ur": return "🇵🇰"
        case "zh-Hans": return "🇨🇳"
        default: return "🇺🇸"
        }
    }
    
    private func finishOnboarding() {
        withAnimation(.easeInOut(duration: 0.8)) {
            hasSeenOnboarding = true
        }
    }
}

// MARK: - Subcomponents
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.teal)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedStringKey(title))
                    .font(.custom("AvenirNext-Bold", size: 20))
                    .foregroundColor(.white)
                
                Text(LocalizedStringKey(description))
                    .font(.custom("AvenirNext-Medium", size: 14))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
