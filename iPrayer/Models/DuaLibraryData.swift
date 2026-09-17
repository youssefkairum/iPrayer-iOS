import Foundation

struct AuthenticDua: Identifiable, Codable {
    var id = UUID()
    let category: String
    let arabicText: String
    let englishTranslation: String
    let reference: String
}

class DuaLibraryData {
    static let shared = DuaLibraryData()
    
    let categories = [
        "Morning & Evening",
        "After Prayer",
        "Anxiety & Sorrow",
        "Travel",
        "Forgiveness",
        "Guidance",
        "Parents",
        "Knowledge"
    ]
    
    let allDuas: [AuthenticDua] = [
        // Morning & Evening
        AuthenticDua(category: "Morning & Evening", arabicText: "بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ", englishTranslation: "In the Name of Allah with Whose Name there is protection against every kind of harm in the earth or in the heaven, and He is the All-Hearing and All-Knowing.", reference: "Abu Dawud & Tirmidhi"),
        AuthenticDua(category: "Morning & Evening", arabicText: "رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ نَبِيًّا", englishTranslation: "I am pleased with Allah as my Lord, with Islam as my religion and with Muhammad (peace and blessings be upon him) as my Prophet.", reference: "Abu Dawud"),
        AuthenticDua(category: "Morning & Evening", arabicText: "يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ", englishTranslation: "O Ever-Living, O Sustainer, in Your Mercy I seek relief. Rectify for me all of my affairs and do not leave me to myself, even for the blink of an eye.", reference: "Sunan an-Nasa'i"),
        
        // After Prayer
        AuthenticDua(category: "After Prayer", arabicText: "أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ", englishTranslation: "I ask Allah for forgiveness (three times).", reference: "Sahih Muslim"),
        AuthenticDua(category: "After Prayer", arabicText: "اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ", englishTranslation: "O Allah, You are Peace and from You comes peace. Blessed are You, O Owner of majesty and honor.", reference: "Sahih Muslim"),
        
        // Anxiety & Sorrow
        AuthenticDua(category: "Anxiety & Sorrow", arabicText: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ", englishTranslation: "O Allah, I seek refuge in You from anxiety and sorrow, weakness and laziness, miserliness and cowardice, the burden of debts and from being overpowered by men.", reference: "Sahih Bukhari"),
        AuthenticDua(category: "Anxiety & Sorrow", arabicText: "لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ", englishTranslation: "There is no deity except You; exalted are You. Indeed, I have been of the wrongdoers.", reference: "Quran 21:87"),
        AuthenticDua(category: "Anxiety & Sorrow", arabicText: "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ", englishTranslation: "Sufficient for us is Allah, and [He is] the best Disposer of affairs.", reference: "Quran 3:173"),
        
        // Travel
        AuthenticDua(category: "Travel", arabicText: "سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ، وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ", englishTranslation: "Glory be to Him who has subjected this to us, and we could not have otherwise subdued it. And indeed we, to our Lord, will [surely] return.", reference: "Quran 43:13-14"),
        
        // Forgiveness
        AuthenticDua(category: "Forgiveness", arabicText: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ", englishTranslation: "O Allah, You are my Lord, there is none worthy of worship but You. You created me and I am Your slave. I keep Your covenant, and my pledge to You so far as I am able.", reference: "Sahih Bukhari"),
        AuthenticDua(category: "Forgiveness", arabicText: "رَبَّنَا ظَلَمْنَا أَنْفُسَنَا وَإِنْ لَمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِرِينَ", englishTranslation: "Our Lord, we have wronged ourselves, and if You do not forgive us and have mercy upon us, we will surely be among the losers.", reference: "Quran 7:23"),
        AuthenticDua(category: "Forgiveness", arabicText: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ", englishTranslation: "Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.", reference: "Quran 2:201"),
        
        // Guidance
        AuthenticDua(category: "Guidance", arabicText: "رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِنْ لَدُنْكَ رَحْمَةً إِنَّكَ أَنْتَ الْوَهَّابُ", englishTranslation: "Our Lord, let not our hearts deviate after You have guided us and grant us from Yourself mercy. Indeed, You are the Bestower.", reference: "Quran 3:8"),
        
        // Parents
        AuthenticDua(category: "Parents", arabicText: "رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا", englishTranslation: "My Lord, have mercy upon them as they brought me up [when I was] small.", reference: "Quran 17:24"),
        
        // Knowledge
        AuthenticDua(category: "Knowledge", arabicText: "رَبِّ زِدْنِي عِلْمًا", englishTranslation: "My Lord, increase me in knowledge.", reference: "Quran 20:114")
    ]
    
    func duas(for category: String) -> [AuthenticDua] {
        return allDuas.filter { $0.category == category }
    }
}
