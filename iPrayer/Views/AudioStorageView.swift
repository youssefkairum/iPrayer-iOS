//
//  AudioStorageView.swift
//  iPrayer
//
//  Storage manager for downloaded recitations: every reciter with files on disk, each surah with its size,
//  and a way to delete one surah, one reciter, or everything.
//

import SwiftUI

struct AudioStorageView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @ObservedObject private var downloads = QuranAudioDownloads.shared
    
    @State private var surahs: [Int: SurahMetadata] = [:]
    @State private var pendingDeletion: Deletion?
    
    private enum Deletion: Identifiable {
        case surah(QuranAudioDownloads.StoredSurah)
        case reciter(QuranAudioDownloads.StoredReciter)
        case all
        
        var id: String {
            switch self {
            case .surah(let surah): return surah.id
            case .reciter(let reciter): return reciter.id
            case .all: return "all"
            }
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            BackgroundPatternView()
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Text(AppTranslations.translate("Downloaded Audio", to: appLanguage))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        summaryCard
                        
                        if downloads.stored.isEmpty {
                            Text(AppTranslations.translate("Download surahs from the reader to listen offline.", to: appLanguage))
                                .font(.custom("AvenirNext-Medium", size: 15))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                                .padding(.top, 20)
                        } else {
                            ForEach(downloads.stored) { reciter in
                                reciterCard(reciter)
                            }
                            
                            deleteAllButton
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { downloads.rescan() }
        .task {
            if let list = try? await QuranDataCache.shared.getSurahs() {
                surahs = Dictionary(uniqueKeysWithValues: list.map { ($0.number, $0) })
            }
        }
        .confirmationDialog(
            deletionTitle,
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { deletion in
            Button(AppTranslations.translate("Delete", to: appLanguage), role: .destructive) {
                Haptics.rigid()
                withAnimation {
                    switch deletion {
                    case .surah(let surah): downloads.remove(surah: surah.surah, reciter: surah.reciter)
                    case .reciter(let reciter): downloads.remove(reciter: reciter.reciter)
                    case .all: downloads.removeAll()
                    }
                }
            }
            Button(AppTranslations.translate("Cancel", to: appLanguage), role: .cancel) {}
        }
    }
    
    // MARK: - Sections
    
    private var summaryCard: some View {
        HStack(spacing: 15) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 26))
                .foregroundColor(.teal)
                .frame(width: 44, height: 44)
                .background(Color.teal.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text(AppTranslations.translate("Total", to: appLanguage))
                    .font(.custom("AvenirNext-Medium", size: 14))
                    .foregroundColor(.gray)
                Text(downloads.formattedTotalSize)
                    .font(.custom("AvenirNext-DemiBold", size: 22))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Material.ultraThinMaterial)
        .cornerRadius(25)
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private func reciterCard(_ reciter: QuranAudioDownloads.StoredReciter) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "person.wave.2.fill")
                    .foregroundColor(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(reciter.reciter.name(for: appLanguage))
                        .font(.custom("AvenirNext-DemiBold", size: 17))
                        .foregroundColor(.teal)
                        .lineLimit(1)
                    Text(ByteCountFormatter.string(fromByteCount: reciter.bytes, countStyle: .file))
                        .font(.custom("AvenirNext-Medium", size: 13))
                        .foregroundColor(.gray)
                }
                Spacer()
                Button {
                    pendingDeletion = .reciter(reciter)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .accessibilityLabel(AppTranslations.translate("Delete all from this reciter", to: appLanguage))
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            
            ForEach(reciter.surahs) { surah in
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 15)
                surahRow(surah)
            }
        }
        .background(Material.ultraThinMaterial)
        .cornerRadius(25)
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func surahRow(_ surah: QuranAudioDownloads.StoredSurah) -> some View {
        let state = downloads.state(for: surah.surah, reciter: surah.reciter)
        
        return HStack(spacing: 12) {
            Text("\(surah.surah)")
                .font(.custom("AvenirNext-DemiBold", size: 13))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(surahName(surah.surah))
                    .font(.custom("AvenirNext-Medium", size: 16))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if case .downloading(let fraction) = state {
                    HStack(spacing: 8) {
                        ProgressView(value: fraction)
                            .tint(.teal)
                            .frame(maxWidth: 120)
                        Text("\(Int(fraction * 100))%")
                            .font(.custom("AvenirNext-Medium", size: 12))
                            .foregroundColor(.gray)
                    }
                } else if !surah.isComplete {
                    Text(AppTranslations.translate("Incomplete", to: appLanguage))
                        .font(.custom("AvenirNext-Medium", size: 12))
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            Text(ByteCountFormatter.string(fromByteCount: surah.bytes, countStyle: .file))
                .font(.custom("AvenirNext-Medium", size: 14))
                .foregroundColor(.gray)
            
            if case .downloading = state {
                Button {
                    downloads.cancel(surah: surah.surah, reciter: surah.reciter)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(AppTranslations.translate("Cancel Download", to: appLanguage))
            } else {
                Button {
                    pendingDeletion = .surah(surah)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(AppTranslations.translate("Remove Download", to: appLanguage))
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
    }
    
    private var deleteAllButton: some View {
        Button(role: .destructive) {
            pendingDeletion = .all
        } label: {
            HStack {
                Spacer()
                Image(systemName: "trash")
                    .font(.system(size: 14))
                Text(AppTranslations.translate("Delete All Downloads", to: appLanguage))
                    .font(.custom("AvenirNext-DemiBold", size: 16))
                Spacer()
            }
            .foregroundColor(.red)
            .padding(.vertical, 14)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 25))
        }
        .padding(.top, 10)
    }
    
    // MARK: - Helpers
    
    private func surahName(_ number: Int) -> String {
        guard let surah = surahs[number] else { return "\(AppTranslations.translate("Surah", to: appLanguage)) \(number)" }
        return ["ar", "ur"].contains(appLanguage) ? surah.shortArabicName : surah.englishName
    }
    
    private var deletionTitle: String {
        switch pendingDeletion {
        case .surah(let surah):
            return "\(surahName(surah.surah)) · \(surah.reciter.name(for: appLanguage))"
        case .reciter(let reciter):
            return reciter.reciter.name(for: appLanguage)
        case .all, .none:
            return AppTranslations.translate("Delete All Downloads", to: appLanguage)
        }
    }
}
