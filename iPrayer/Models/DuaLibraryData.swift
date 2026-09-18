import Foundation

struct AuthenticDua: Identifiable, Hashable {
    let category: String
    let arabicText: String
    let englishTranslation: String
    let reference: String
    /// How many times it is said, when the source specifies (shown as a badge)
    var repeatCount: Int? = nil
    /// The evening wording, for adhkar whose text changes between morning and evening
    var eveningText: String? = nil
    
    /// The Arabic text is unique, so it doubles as a stable identity across launches
    var id: String { arabicText }
    
    /// The Quran font draws the Arabic comma (U+060C) as a verse ornament, so cards show a plain comma
    /// instead. Copy and share keep the real text.
    var displayArabic: String { Self.display(arabicText) }
    var displayEvening: String? { eveningText.map(Self.display) }
    
    nonisolated static func display(_ text: String) -> String { text.replacingOccurrences(of: "\u{060C}", with: ",") }
}

class DuaLibraryData {
    static let shared = DuaLibraryData()
    
    let categories = [
        "Morning & Evening",
        "Sleep & Waking",
        "After Prayer",
        "Anxiety & Sorrow",
        "Protection",
        "Forgiveness",
        "Guidance",
        "Travel",
        "Home",
        "Food & Drink",
        "Parents",
        "Knowledge"
    ]
    
    /// Authentic supplications from the Quran and the Sunnah, each with its source.
    let allDuas: [AuthenticDua] = [
        // Morning & Evening: the adhkar of Hisn al-Muslim, in the book's order
        AuthenticDua(category: "Morning & Evening", arabicText: "اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ، لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ، لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ، مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ، يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ، وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ، وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ، وَلَا يَئُودُهُ حِفْظُهُمَا، وَهُوَ الْعَلِيُّ الْعَظِيمُ", englishTranslation: "Allah, there is no deity except Him, the Ever-Living, the Sustainer of existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great. (Ayat al-Kursi)", reference: "Quran 2:255"),
        AuthenticDua(category: "Morning & Evening", arabicText: "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ، قُلْ هُوَ اللَّهُ أَحَدٌ، اللَّهُ الصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ", englishTranslation: "Say: He is Allah, the One. Allah, the Eternal Refuge. He neither begets nor is born, nor is there to Him any equivalent. (Surah Al-Ikhlas)", reference: "Quran 112", repeatCount: 3),
        AuthenticDua(category: "Morning & Evening", arabicText: "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ، قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ، مِنْ شَرِّ مَا خَلَقَ، وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ، وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ، وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ", englishTranslation: "Say: I seek refuge in the Lord of daybreak, from the evil of that which He created, and from the evil of darkness when it settles, and from the evil of the blowers in knots, and from the evil of an envier when he envies. (Surah Al-Falaq)", reference: "Quran 113", repeatCount: 3),
        AuthenticDua(category: "Morning & Evening", arabicText: "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ، قُلْ أَعُوذُ بِرَبِّ النَّاسِ، مَلِكِ النَّاسِ، إِلَهِ النَّاسِ، مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ، الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ، مِنَ الْجِنَّةِ وَالنَّاسِ", englishTranslation: "Say: I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer, who whispers in the breasts of mankind, from among the jinn and mankind. (Surah An-Nas)", reference: "Quran 114", repeatCount: 3),
        AuthenticDua(category: "Morning & Evening", arabicText: "أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ", englishTranslation: "We have entered the morning and the whole kingdom belongs to Allah. Praise is to Allah. There is no deity except Allah alone, without partner; His is the dominion and His is the praise, and He is able to do all things. My Lord, I ask You for the good of this day and the good of what follows it, and I seek refuge in You from the evil of this day and the evil of what follows it. My Lord, I seek refuge in You from laziness and the misery of old age. My Lord, I seek refuge in You from punishment in the Fire and punishment in the grave.", reference: "Sahih Muslim", eveningText: "أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ"),
        AuthenticDua(category: "Morning & Evening", arabicText: "اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ", englishTranslation: "O Allah, by You we enter the morning and by You we enter the evening, by You we live and by You we die, and to You is the resurrection.", reference: "Tirmidhi", eveningText: "اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ"),
        AuthenticDua(category: "Morning & Evening", arabicText: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ", englishTranslation: "O Allah, You are my Lord, there is no deity except You. You created me and I am Your servant, and I keep Your covenant and my pledge to You as far as I am able. I seek refuge in You from the evil of what I have done. I acknowledge Your favour upon me and I acknowledge my sin, so forgive me, for none forgives sins except You. (Sayyid al-Istighfar)", reference: "Sahih Bukhari"),
        AuthenticDua(category: "Morning & Evening", arabicText: "اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ", englishTranslation: "O Allah, I have entered the morning calling You to witness, and the bearers of Your Throne, Your angels and all Your creation, that You are Allah, there is no deity except You alone, without partner, and that Muhammad is Your servant and Messenger.", reference: "Abu Dawud", repeatCount: 4, eveningText: "اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ"),
        AuthenticDua(category: "Morning & Evening", arabicText: "اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ", englishTranslation: "O Allah, whatever blessing has come to me or to any of Your creation this morning is from You alone, without partner; so to You is all praise and to You is all thanks.", reference: "Abu Dawud", eveningText: "اللَّهُمَّ مَا أَمْسَى بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ"),
        AuthenticDua(category: "Morning & Evening", arabicText: "اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ", englishTranslation: "O Allah, grant my body health. O Allah, grant my hearing health. O Allah, grant my sight health. There is no deity except You.", reference: "Abu Dawud", repeatCount: 3),
        AuthenticDua(category: "Morning & Evening", arabicText: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لَا إِلَهَ إِلَّا أَنْتَ", englishTranslation: "O Allah, I seek refuge in You from disbelief and poverty, and I seek refuge in You from the punishment of the grave. There is no deity except You.", reference: "Abu Dawud", repeatCount: 3),
        AuthenticDua(category: "Morning & Evening", arabicText: "حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ", englishTranslation: "Allah is sufficient for me; there is no deity except Him. In Him I have placed my trust, and He is the Lord of the Mighty Throne.", reference: "Quran 9:129", repeatCount: 7),
        AuthenticDua(category: "Morning & Evening", arabicText: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي، اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي، وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي", englishTranslation: "O Allah, I ask You for pardon and well-being in this world and the Hereafter. O Allah, I ask You for pardon and well-being in my religion, my worldly life, my family and my wealth. O Allah, conceal my faults and calm my fears. O Allah, guard me from in front of me and behind me, from my right and my left, and from above me, and I seek refuge in Your greatness from being taken unaware from beneath me.", reference: "Abu Dawud & Ibn Majah"),
        AuthenticDua(category: "Morning & Evening", arabicText: "اللَّهُمَّ عَالِمَ الْغَيْبِ وَالشَّهَادَةِ فَاطِرَ السَّمَاوَاتِ وَالْأَرْضِ، رَبَّ كُلِّ شَيْءٍ وَمَلِيكَهُ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا أَنْتَ، أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي وَمِنْ شَرِّ الشَّيْطَانِ وَشِرْكِهِ، وَأَنْ أَقْتَرِفَ عَلَى نَفْسِي سُوءًا أَوْ أَجُرَّهُ إِلَى مُسْلِمٍ", englishTranslation: "O Allah, Knower of the unseen and the seen, Creator of the heavens and the earth, Lord and Sovereign of all things, I bear witness that there is no deity except You. I seek refuge in You from the evil of my soul, from the evil of Satan and his call to associate others with You, and from bringing harm upon myself or dragging it upon a Muslim.", reference: "Abu Dawud & Tirmidhi"),
        AuthenticDua(category: "Morning & Evening", arabicText: "بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ", englishTranslation: "In the Name of Allah with Whose Name there is protection against every kind of harm in the earth or in the heaven, and He is the All-Hearing and All-Knowing.", reference: "Abu Dawud & Tirmidhi", repeatCount: 3),
        AuthenticDua(category: "Morning & Evening", arabicText: "رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ نَبِيًّا", englishTranslation: "I am pleased with Allah as my Lord, with Islam as my religion and with Muhammad (peace and blessings be upon him) as my Prophet.", reference: "Abu Dawud", repeatCount: 3),
        AuthenticDua(category: "Morning & Evening", arabicText: "يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ", englishTranslation: "O Ever-Living, O Sustainer, in Your Mercy I seek relief. Rectify for me all of my affairs and do not leave me to myself, even for the blink of an eye.", reference: "Sunan an-Nasa'i"),
        AuthenticDua(category: "Morning & Evening", arabicText: "أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ", englishTranslation: "We have entered the morning upon the natural religion of Islam, the word of sincerity, the religion of our Prophet Muhammad (peace and blessings be upon him), and the way of our father Ibrahim, who was upright and a Muslim, and was not of those who associate others with Allah.", reference: "Musnad Ahmad", eveningText: "أَمْسَيْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ"),
        AuthenticDua(category: "Morning & Evening", arabicText: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", englishTranslation: "Glory be to Allah and praise be to Him.", reference: "Sahih Muslim", repeatCount: 100),
        AuthenticDua(category: "Morning & Evening", arabicText: "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", englishTranslation: "There is no deity except Allah alone, without partner. His is the dominion and His is the praise, and He is able to do all things.", reference: "Bukhari & Muslim", repeatCount: 10),
        AuthenticDua(category: "Morning & Evening", arabicText: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ", englishTranslation: "Glory be to Allah and praise be to Him, as many times as the number of His creation, as much as pleases Him, as much as the weight of His Throne, and as much as the ink of His words. (Morning)", reference: "Sahih Muslim", repeatCount: 3),
        AuthenticDua(category: "Morning & Evening", arabicText: "اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا", englishTranslation: "O Allah, I ask You for beneficial knowledge, good provision, and accepted deeds. (Morning)", reference: "Ibn Majah"),
        AuthenticDua(category: "Morning & Evening", arabicText: "أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ", englishTranslation: "I seek the forgiveness of Allah and repent to Him.", reference: "Bukhari & Muslim", repeatCount: 100),
        AuthenticDua(category: "Morning & Evening", arabicText: "اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ", englishTranslation: "O Allah, send prayers and peace upon our Prophet Muhammad.", reference: "Tabarani", repeatCount: 10),
        
        // Sleep & Waking
        AuthenticDua(category: "Sleep & Waking", arabicText: "بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا", englishTranslation: "In Your name, O Allah, I die and I live.", reference: "Sahih Bukhari"),
        AuthenticDua(category: "Sleep & Waking", arabicText: "الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ", englishTranslation: "All praise is for Allah who gave us life after having taken it from us, and unto Him is the resurrection.", reference: "Sahih Bukhari"),
        
        // After Prayer
        AuthenticDua(category: "After Prayer", arabicText: "أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ", englishTranslation: "I ask Allah for forgiveness (three times).", reference: "Sahih Muslim"),
        AuthenticDua(category: "After Prayer", arabicText: "اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ", englishTranslation: "O Allah, You are Peace and from You comes peace. Blessed are You, O Owner of majesty and honor.", reference: "Sahih Muslim"),
        AuthenticDua(category: "After Prayer", arabicText: "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ", englishTranslation: "O Allah, help me to remember You, to thank You, and to worship You well.", reference: "Abu Dawud"),
        
        // Anxiety & Sorrow
        AuthenticDua(category: "Anxiety & Sorrow", arabicText: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ", englishTranslation: "O Allah, I seek refuge in You from anxiety and sorrow, weakness and laziness, miserliness and cowardice, the burden of debts and from being overpowered by men.", reference: "Sahih Bukhari"),
        AuthenticDua(category: "Anxiety & Sorrow", arabicText: "لَا إِلَهَ إِلَّا اللَّهُ الْعَظِيمُ الْحَلِيمُ، لَا إِلَهَ إِلَّا اللَّهُ رَبُّ الْعَرْشِ الْعَظِيمِ، لَا إِلَهَ إِلَّا اللَّهُ رَبُّ السَّمَاوَاتِ وَرَبُّ الْأَرْضِ وَرَبُّ الْعَرْشِ الْكَرِيمِ", englishTranslation: "There is no deity except Allah, the Mighty, the Forbearing. There is no deity except Allah, Lord of the Mighty Throne. There is no deity except Allah, Lord of the heavens, Lord of the earth and Lord of the Noble Throne.", reference: "Bukhari & Muslim"),
        AuthenticDua(category: "Anxiety & Sorrow", arabicText: "اللَّهُمَّ رَحْمَتَكَ أَرْجُو فَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ، وَأَصْلِحْ لِي شَأْنِي كُلَّهُ، لَا إِلَهَ إِلَّا أَنْتَ", englishTranslation: "O Allah, I hope for Your mercy, so do not leave me to myself even for the blink of an eye, and rectify all my affairs. There is no deity except You.", reference: "Abu Dawud"),
        AuthenticDua(category: "Anxiety & Sorrow", arabicText: "لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ", englishTranslation: "There is no deity except You; exalted are You. Indeed, I have been of the wrongdoers.", reference: "Quran 21:87"),
        AuthenticDua(category: "Anxiety & Sorrow", arabicText: "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ", englishTranslation: "Sufficient for us is Allah, and [He is] the best Disposer of affairs.", reference: "Quran 3:173"),
        
        // Protection
        AuthenticDua(category: "Protection", arabicText: "أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ", englishTranslation: "I seek refuge in the perfect words of Allah from the evil of what He has created. (Evening)", reference: "Sahih Muslim", repeatCount: 3),
        AuthenticDua(category: "Protection", arabicText: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ", englishTranslation: "O Allah, I ask You for well-being in this world and the Hereafter.", reference: "Abu Dawud"),
        
        // Forgiveness
        AuthenticDua(category: "Forgiveness", arabicText: "رَبَّنَا ظَلَمْنَا أَنْفُسَنَا وَإِنْ لَمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِرِينَ", englishTranslation: "Our Lord, we have wronged ourselves, and if You do not forgive us and have mercy upon us, we will surely be among the losers.", reference: "Quran 7:23"),
        AuthenticDua(category: "Forgiveness", arabicText: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ", englishTranslation: "Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.", reference: "Quran 2:201"),
        
        // Guidance
        AuthenticDua(category: "Guidance", arabicText: "رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِنْ لَدُنْكَ رَحْمَةً إِنَّكَ أَنْتَ الْوَهَّابُ", englishTranslation: "Our Lord, let not our hearts deviate after You have guided us and grant us from Yourself mercy. Indeed, You are the Bestower.", reference: "Quran 3:8"),
        AuthenticDua(category: "Guidance", arabicText: "اللَّهُمَّ اهْدِنِي وَسَدِّدْنِي", englishTranslation: "O Allah, guide me and keep me on the straight path.", reference: "Sahih Muslim"),
        AuthenticDua(category: "Guidance", arabicText: "رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي", englishTranslation: "My Lord, expand for me my breast and ease for me my task.", reference: "Quran 20:25-26"),
        
        // Travel
        AuthenticDua(category: "Travel", arabicText: "سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ، وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ", englishTranslation: "Glory be to Him who has subjected this to us, and we could not have otherwise subdued it. And indeed we, to our Lord, will [surely] return.", reference: "Quran 43:13-14"),
        AuthenticDua(category: "Travel", arabicText: "اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَى، وَمِنَ الْعَمَلِ مَا تَرْضَى", englishTranslation: "O Allah, we ask You on this journey of ours for righteousness and piety, and for deeds that please You.", reference: "Sahih Muslim"),
        
        // Home
        AuthenticDua(category: "Home", arabicText: "بِسْمِ اللَّهِ تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ", englishTranslation: "In the name of Allah, I place my trust in Allah, and there is no might nor power except with Allah.", reference: "Abu Dawud & Tirmidhi"),
        
        // Food & Drink
        AuthenticDua(category: "Food & Drink", arabicText: "بِسْمِ اللَّهِ فِي أَوَّلِهِ وَآخِرِهِ", englishTranslation: "In the name of Allah at its beginning and at its end. (Said when one forgets to begin with Bismillah.)", reference: "Abu Dawud & Tirmidhi"),
        AuthenticDua(category: "Food & Drink", arabicText: "الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ", englishTranslation: "All praise is for Allah who fed me this and provided it for me without any might or power on my part.", reference: "Abu Dawud & Tirmidhi"),
        
        // Parents
        AuthenticDua(category: "Parents", arabicText: "رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا", englishTranslation: "My Lord, have mercy upon them as they brought me up [when I was] small.", reference: "Quran 17:24"),
        AuthenticDua(category: "Parents", arabicText: "رَبِّ أَوْزِعْنِي أَنْ أَشْكُرَ نِعْمَتَكَ الَّتِي أَنْعَمْتَ عَلَيَّ وَعَلَى وَالِدَيَّ وَأَنْ أَعْمَلَ صَالِحًا تَرْضَاهُ", englishTranslation: "My Lord, enable me to be grateful for Your favour which You have bestowed upon me and upon my parents, and to do righteousness of which You approve.", reference: "Quran 27:19"),
        
        // Knowledge
        AuthenticDua(category: "Knowledge", arabicText: "رَبِّ زِدْنِي عِلْمًا", englishTranslation: "My Lord, increase me in knowledge.", reference: "Quran 20:114"),
        AuthenticDua(category: "Knowledge", arabicText: "اللَّهُمَّ انْفَعْنِي بِمَا عَلَّمْتَنِي، وَعَلِّمْنِي مَا يَنْفَعُنِي، وَزِدْنِي عِلْمًا", englishTranslation: "O Allah, benefit me with what You have taught me, teach me what will benefit me, and increase me in knowledge.", reference: "Tirmidhi")
    ]
    
    func duas(for category: String) -> [AuthenticDua] {
        allDuas.filter { $0.category == category }
    }
    
    /// The day's dua: the whole library in turn, one per local calendar day, in step with the Verse of the Day
    func duaOfTheDay() -> AuthenticDua? {
        guard !allDuas.isEmpty else { return nil }
        return allDuas[VerseOfTheDay.dayNumber() % allDuas.count]
    }
}
