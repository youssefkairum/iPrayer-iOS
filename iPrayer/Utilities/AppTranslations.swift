
//
//  AppTranslations.swift
//  iPrayer
//
//  A shared, view-accessible translation helper for UI strings.
//

import Foundation

nonisolated struct AppTranslations {
    static func translate(_ text: String, to language: String) -> String {
        table[text]?[language] ?? text
    }
    
    /// Looks up a String Catalog key in the IN-APP language rather than the device language.
    /// `String(localized:)` and `NSLocalizedString` always follow the device, which mixed languages
    /// in notifications and a few labels whenever the two differed.
    static func catalogString(_ key: String, language: String, _ arguments: CVarArg...) -> String {
        let bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap { Bundle(path: $0) } ?? .main
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: Locale(identifier: language), arguments: arguments)
    }
    
    /// Translated format string for text that contains a minute count.
    /// Arabic takes the plural "دقائق" for 3 to 10 and the singular form "دقيقة" from 11 up,
    /// so one fixed string can't be correct for every reminder option.
    static func minutesFormat(_ key: String, minutes: Int, language: String) -> String {
        let format = translate(key, to: language)
        guard language == "ar", (3...10).contains(minutes) else { return format }
        return format.replacingOccurrences(of: "دقيقة", with: "دقائق")
    }
    
    // Built once. It used to be rebuilt on every call, and views call translate many times per render.
    private static let table: [String: [String: String]] = [
            // MARK: - Prayer Names
            "Fajr":    ["ar": "الفجر",   "ur": "فجر",           "fr": "Fajr",             "zh-Hans": "晨礼",   "de": "Fadschr",        "hi": "फज्र",         "tr": "İmsak",   "ru": "Фаджр"],
            "Sunrise": ["ar": "الشروق",  "ur": "طلوع آفتاب",   "fr": "Lever du soleil",  "zh-Hans": "日出",   "de": "Sonnenaufgang",  "hi": "सूर्योदय",    "tr": "Güneş",   "ru": "Восход"],
            "Dhuhr":   ["ar": "الظهر",   "ur": "ظہر",           "fr": "Dhuhr",            "zh-Hans": "晌礼",   "de": "Dhuhr",          "hi": "ज़ुहर",        "tr": "Öğle",    "ru": "Зухр"],
            "Asr":     ["ar": "العصر",   "ur": "عصر",           "fr": "Asr",              "zh-Hans": "晡礼",   "de": "Asr",            "hi": "असर",          "tr": "İkindi",  "ru": "Аср"],
            "Maghrib": ["ar": "المغرب",  "ur": "مغرب",          "fr": "Maghrib",          "zh-Hans": "昏礼",   "de": "Maghrib",        "hi": "मग़रिब",       "tr": "Akşam",   "ru": "Магриб"],
            "Isha":    ["ar": "العشاء",  "ur": "عشاء",          "fr": "Isha",             "zh-Hans": "宵礼",   "de": "Ischa",          "hi": "ईशा",          "tr": "Yatsı",   "ru": "Иша"],

            // MARK: - Prayer Detail View
            "Prayer Times":          ["ar": "مواقيت الصلاة",  "ur": "نماز کے اوقات",  "fr": "Horaires de prière", "zh-Hans": "祈祷时间",  "de": "Gebetszeiten",          "hi": "नमाज़ के वक्त",   "tr": "Namaz Vakitleri",  "ru": "Время молитв"],
            "Today's full schedule": ["ar": "جدول اليوم كامل", "ur": "آج کا مکمل شیڈول", "fr": "Programme complet du jour", "zh-Hans": "今日完整时间表", "de": "Vollständiger Tagesplan", "hi": "आज का पूरा शेड्यूल", "tr": "Bugünkü tam program", "ru": "Полное расписание на сегодня"],
            "Up next":               ["ar": "القادم",          "ur": "اگلی نماز",       "fr": "À venir",            "zh-Hans": "即将开始",  "de": "Als nächstes",          "hi": "अगला",             "tr": "Sıradaki",         "ru": "Следующее"],
            "Passed":                ["ar": "انتهى",           "ur": "گزر گئی",         "fr": "Passée",             "zh-Hans": "已过",      "de": "Vergangen",             "hi": "बीत गई",           "tr": "Geçti",            "ru": "Прошло"],
            "Tap to see all prayers":["ar": "اضغط لرؤية كل الصلوات", "ur": "تمام نمازیں دیکھنے کے لیے ٹیپ کریں", "fr": "Appuyer pour voir toutes les prières", "zh-Hans": "点击查看所有祈祷", "de": "Tippen für alle Gebete", "hi": "सभी नमाज़ें देखें", "tr": "Tüm namazları görmek için dokun", "ru": "Нажмите для всех молитв"],
            
            // MARK: - Duas Library
            "Library": ["ar": "المكتبة", "ur": "لائبریری", "fr": "Bibliothèque", "zh-Hans": "图书馆", "de": "Bibliothek", "hi": "पुस्तकालय", "tr": "Kütüphane", "ru": "Библиотека"],
            "Browse Authentic Islamic Duas": ["ar": "تصفح الأدعية الإسلامية الصحيحة", "ur": "مستند اسلامی دعائیں براؤز کریں", "fr": "Parcourir les Invocations Islamiques Authentiques", "zh-Hans": "浏览正统伊斯兰杜阿", "de": "Authentische Islamische Duas Durchsuchen", "hi": "प्रामाणिक इस्लामी दुआ ब्राउज़ करें", "tr": "Sahih İslami Dualara Göz At", "ru": "Просмотр достоверных исламских дуа"],
            "Privacy Policy": ["ar": "سياسة الخصوصية", "ur": "رازداری کی پالیسی", "fr": "Politique de confidentialité", "zh-Hans": "隐私政策", "de": "Datenschutzerklärung", "hi": "गोपनीयता नीति", "tr": "Gizlilik Politikası", "ru": "Политика конфиденциальности"],
            "Manage Notifications & Location": ["ar": "إدارة الإشعارات والموقع", "ur": "اطلاعات اور مقام کا نظم کریں", "fr": "Gérer les Notifications et la Localisation", "zh-Hans": "管理通知和位置", "de": "Benachrichtigungen & Standort verwalten", "hi": "सूचनाएं और स्थान प्रबंधित करें", "tr": "Bildirimleri ve Konumu Yönet", "ru": "Управление уведомлениями и геопозицией"],
            
            // MARK: - UI Elements
            "Starts in": ["ar": "يبدأ في", "ur": "شروع ہوتا ہے", "fr": "Commence dans", "zh-Hans": "开始于", "de": "Beginnt in", "hi": "में शुरू होता है", "tr": "Başlıyor", "ru": "Начнется через"],
            "NEXT": ["ar": "التالي", "ur": "اگلا", "fr": "SUIVANT", "zh-Hans": "下一个", "de": "NÄCHSTE", "hi": "अगला", "tr": "SONRAKİ", "ru": "СЛЕДУЮЩИЙ"],
            "Day Streak": ["ar": "أيام متتالية", "ur": "دن کی لکیر", "fr": "Jours de suite", "zh-Hans": "连胜天数", "de": "Tage in Folge", "hi": "दिन की लकीर", "tr": "Günlük Seri", "ru": "Дней подряд"],
            "Track today's prayers": ["ar": "تتبع صلوات اليوم", "ur": "آج کی نمازیں ٹریک کریں", "fr": "Suivre les prières d'aujourd'hui", "zh-Hans": "追踪今天的祈祷", "de": "Verfolge die heutigen Gebete", "hi": "आज की नमाज़ ट्रैक करें", "tr": "Bugünün namazlarını takip et", "ru": "Отслеживать сегодняшние молитвы"],
            "Verse of the Day": ["ar": "آية اليوم", "ur": "آج کی آیت", "fr": "Verset du jour", "zh-Hans": "今日经文", "de": "Vers des Tages", "hi": "आज की आयत", "tr": "Günün Ayeti", "ru": "Аят дня"],
            "Daily Dua": ["ar": "دعاء اليوم", "ur": "روزانہ کی دعا", "fr": "Dua quotidien", "zh-Hans": "每日祈祷", "de": "Tägliches Dua", "hi": "दैनिक दुआ", "tr": "Günlük Dua", "ru": "Ежедневное дуа"],
            "Cycles Completed: ": ["ar": "الدورات المكتملة: ", "ur": "مکمل چکر: ", "fr": "Cycles terminés : ", "zh-Hans": "完成周期: ", "de": "Abgeschlossene Zyklen: ", "hi": "पूरे किए गए चक्र: ", "tr": "Tamamlanan Döngüler: ", "ru": "Завершенные циклы: "],
            "Search Surah (e.g. Kahf, الكهف)": ["ar": "ابحث عن سورة (مثل: الكهف)", "ur": "سورہ تلاش کریں (مثال کے طور پر: الکہف)", "fr": "Rechercher une sourate (ex: Kahf)", "zh-Hans": "搜索苏拉 (例如: Kahf)", "de": "Suche Sure (z. B. Kahf)", "hi": "सुरा खोजें (उदा: कहफ़)", "tr": "Sure Ara (örn. Kehf)", "ru": "Поиск суры (напр. Кахф)"],
            "Good morning": ["ar": "صباح الخير", "ur": "صبح بخیر", "fr": "Bonjour", "zh-Hans": "早上好", "de": "Guten Morgen", "hi": "सुप्रभात", "tr": "Günaydın", "ru": "Доброе утро"],
            "Good afternoon": ["ar": "مساء الخير", "ur": "دوپہر بخیر", "fr": "Bon après-midi", "zh-Hans": "下午好", "de": "Guten Tag", "hi": "शुभ दोपहर", "tr": "Tünaydın", "ru": "Добрый день"],
            "Good evening": ["ar": "مساء الخير", "ur": "شام بخیر", "fr": "Bonsoir", "zh-Hans": "晚上好", "de": "Guten Abend", "hi": "शुभ संध्या", "tr": "İyi akşamlar", "ru": "Добрый вечер"],
            "Duas": ["ar": "الأدعية", "ur": "دعائیں", "fr": "Duas", "zh-Hans": "祈祷", "de": "Duas", "hi": "दुआएं", "tr": "Dualar", "ru": "Дуа"],
            "at": ["ar": "في", "ur": "پر", "fr": "à", "zh-Hans": "在", "de": "um", "hi": "पर", "tr": "saat", "ru": "в"],
            "Next Prayer": ["ar": "الصلاة القادمة", "ur": "اگلی نماز", "fr": "Prochaine prière", "zh-Hans": "下一个祈祷", "de": "Nächstes Gebet", "hi": "अगली प्रार्थना", "tr": "Sonraki Namaz", "ru": "Следующая молитва"],
            "Tomorrow's schedule": ["ar": "جدول الغد", "ur": "کل کا شیڈول", "fr": "Programme de demain", "zh-Hans": "明日时间表", "de": "Plan für morgen", "hi": "कल का शेड्यूल", "tr": "Yarının programı", "ru": "Расписание на завтра"],
            "Location access is needed to show prayer times.": ["ar": "يلزم الوصول إلى الموقع لعرض مواقيت الصلاة.", "ur": "نماز کے اوقات دکھانے کے لیے مقام تک رسائی درکار ہے۔", "fr": "L'accès à la localisation est nécessaire pour afficher les horaires de prière.", "zh-Hans": "需要位置权限才能显示祈祷时间。", "de": "Standortzugriff wird benötigt, um Gebetszeiten anzuzeigen.", "hi": "नमाज़ के वक्त दिखाने के लिए स्थान की अनुमति आवश्यक है।", "tr": "Namaz vakitlerini göstermek için konum erişimi gerekli.", "ru": "Для показа времени молитв нужен доступ к геопозиции."],
            "Now": ["ar": "الآن", "ur": "ابھی", "fr": "Maintenant", "zh-Hans": "现在", "de": "Jetzt", "hi": "अभी", "tr": "Şimdi", "ru": "Сейчас"],
            "Tap to open iPrayer": ["ar": "اضغط لفتح iPrayer", "ur": "iPrayer کھولنے کے لیے ٹیپ کریں", "fr": "Touchez pour ouvrir iPrayer", "zh-Hans": "点击打开 iPrayer", "de": "Tippen, um iPrayer zu öffnen", "hi": "iPrayer खोलने के लिए टैप करें", "tr": "iPrayer'ı açmak için dokun", "ru": "Нажмите, чтобы открыть iPrayer"],
            "Enable Location": ["ar": "تفعيل الموقع", "ur": "مقام فعال کریں", "fr": "Activer la localisation", "zh-Hans": "启用定位", "de": "Standort aktivieren", "hi": "स्थान सक्षम करें", "tr": "Konumu Etkinleştir", "ru": "Включить геопозицию"],
            "Not now": ["ar": "ليس الآن", "ur": "ابھی نہیں", "fr": "Pas maintenant", "zh-Hans": "以后再说", "de": "Nicht jetzt", "hi": "अभी नहीं", "tr": "Şimdi değil", "ru": "Не сейчас"],
            "Location Access": ["ar": "الوصول إلى الموقع", "ur": "مقام تک رسائی", "fr": "Accès à la localisation", "zh-Hans": "位置权限", "de": "Standortzugriff", "hi": "स्थान की अनुमति", "tr": "Konum Erişimi", "ru": "Доступ к геопозиции"],
            "iPrayer uses your location to calculate prayer times and the Qibla direction.": ["ar": "يستخدم iPrayer موقعك لحساب مواقيت الصلاة واتجاه القبلة.", "ur": "iPrayer نماز کے اوقات اور قبلہ کی سمت معلوم کرنے کے لیے آپ کا مقام استعمال کرتا ہے۔", "fr": "iPrayer utilise votre position pour calculer les horaires de prière et la direction de la Qibla.", "zh-Hans": "iPrayer 使用您的位置来计算祈祷时间和朝向。", "de": "iPrayer verwendet deinen Standort, um Gebetszeiten und die Qibla-Richtung zu berechnen.", "hi": "iPrayer नमाज़ के वक्त और क़िबला की दिशा जानने के लिए आपके स्थान का उपयोग करता है।", "tr": "iPrayer, namaz vakitlerini ve kıble yönünü hesaplamak için konumunuzu kullanır.", "ru": "iPrayer использует вашу геопозицию для расчёта времени молитв и направления киблы."],
            "Notifications": ["ar": "الإشعارات", "ur": "اطلاعات", "fr": "Notifications", "zh-Hans": "通知", "de": "Mitteilungen", "hi": "सूचनाएं", "tr": "Bildirimler", "ru": "Уведомления"],
            "Adhan Sound": ["ar": "صوت الأذان", "ur": "اذان کی آواز", "fr": "Son de l'adhan", "zh-Hans": "宣礼声", "de": "Adhan-Ton", "hi": "अज़ान की आवाज़", "tr": "Ezan Sesi", "ru": "Звук азана"],
            "Pre-Prayer Reminder": ["ar": "تذكير قبل الصلاة", "ur": "نماز سے پہلے یاد دہانی", "fr": "Rappel avant la prière", "zh-Hans": "祈祷前提醒", "de": "Erinnerung vor dem Gebet", "hi": "नमाज़ से पहले रिमाइंडर", "tr": "Namaz Öncesi Hatırlatma", "ru": "Напоминание перед молитвой"],
            "Off": ["ar": "إيقاف", "ur": "بند", "fr": "Désactivé", "zh-Hans": "关闭", "de": "Aus", "hi": "बंद", "tr": "Kapalı", "ru": "Выкл."],
            "%lld min before": ["ar": "قبل %lld دقيقة", "ur": "%lld منٹ پہلے", "fr": "%lld min avant", "zh-Hans": "提前 %lld 分钟", "de": "%lld Min. vorher", "hi": "%lld मिनट पहले", "tr": "%lld dk önce", "ru": "За %lld мин."],
            "%@ in %lld minutes": ["ar": "%@ بعد %lld دقيقة", "ur": "%@ %lld منٹ میں", "fr": "%@ dans %lld minutes", "zh-Hans": "%@ 将在 %lld 分钟后开始", "de": "%@ in %lld Minuten", "hi": "%@ %lld मिनट में", "tr": "%@ %lld dakika sonra", "ru": "%@ через %lld мин."],
            // MARK: - Quran reader
            "Verse": ["ar": "آية", "ur": "آیت", "fr": "Verset", "zh-Hans": "经文", "de": "Vers", "hi": "आयत", "tr": "Ayet", "ru": "Аят"],
            "Bookmarks": ["ar": "الإشارات المرجعية", "ur": "بُک مارکس", "fr": "Signets", "zh-Hans": "书签", "de": "Lesezeichen", "hi": "बुकमार्क", "tr": "Yer İmleri", "ru": "Закладки"],
            "Bookmark": ["ar": "إشارة مرجعية", "ur": "بُک مارک", "fr": "Signet", "zh-Hans": "书签", "de": "Lesezeichen", "hi": "बुकमार्क", "tr": "Yer İmi", "ru": "Закладка"],
            "Remove": ["ar": "إزالة", "ur": "ہٹائیں", "fr": "Supprimer", "zh-Hans": "移除", "de": "Entfernen", "hi": "हटाएं", "tr": "Kaldır", "ru": "Удалить"],
            "No results found": ["ar": "لا توجد نتائج", "ur": "کوئی نتیجہ نہیں ملا", "fr": "Aucun résultat", "zh-Hans": "未找到结果", "de": "Keine Ergebnisse", "hi": "कोई परिणाम नहीं मिला", "tr": "Sonuç bulunamadı", "ru": "Ничего не найдено"],
            "Copy": ["ar": "نسخ", "ur": "کاپی", "fr": "Copier", "zh-Hans": "复制", "de": "Kopieren", "hi": "कॉपी", "tr": "Kopyala", "ru": "Копировать"],
            "Copied": ["ar": "تم النسخ", "ur": "کاپی ہو گیا", "fr": "Copié", "zh-Hans": "已复制", "de": "Kopiert", "hi": "कॉपी हो गया", "tr": "Kopyalandı", "ru": "Скопировано"],
            "Share": ["ar": "مشاركة", "ur": "شیئر", "fr": "Partager", "zh-Hans": "分享", "de": "Teilen", "hi": "साझा करें", "tr": "Paylaş", "ru": "Поделиться"],
            "Text Size": ["ar": "حجم الخط", "ur": "متن کا سائز", "fr": "Taille du texte", "zh-Hans": "文字大小", "de": "Textgröße", "hi": "टेक्स्ट का आकार", "tr": "Yazı Boyutu", "ru": "Размер текста"],
            "Paper": ["ar": "ورقي", "ur": "کاغذ", "fr": "Papier", "zh-Hans": "纸张", "de": "Papier", "hi": "काग़ज़", "tr": "Kâğıt", "ru": "Бумага"],
            "Dark": ["ar": "داكن", "ur": "گہرا", "fr": "Sombre", "zh-Hans": "深色", "de": "Dunkel", "hi": "गहरा", "tr": "Koyu", "ru": "Тёмная"],
            "Meccan": ["ar": "مكية", "ur": "مکی", "fr": "Mecquoise", "zh-Hans": "麦加章", "de": "Mekkanisch", "hi": "मक्की", "tr": "Mekki", "ru": "Мекканская"],
            "Medinan": ["ar": "مدنية", "ur": "مدنی", "fr": "Médinoise", "zh-Hans": "麦地那章", "de": "Medinensisch", "hi": "मदनी", "tr": "Medeni", "ru": "Мединская"],
            "Open Settings": ["ar": "فتح الإعدادات", "ur": "سیٹنگز کھولیں", "fr": "Ouvrir les réglages", "zh-Hans": "打开设置", "de": "Einstellungen öffnen", "hi": "सेटिंग्स खोलें", "tr": "Ayarları Aç", "ru": "Открыть настройки"],

            "Duas Library": ["ar": "مكتبة الأدعية", "ur": "دعاؤں کی لائبریری", "fr": "Bibliothèque de Duas", "zh-Hans": "杜阿图书馆", "de": "Duas Bibliothek", "hi": "दुआ पुस्तकालय", "tr": "Dualar Kütüphanesi", "ru": "Библиотека дуа"],
            "Morning & Evening": ["ar": "الصباح والمساء", "ur": "صبح اور شام", "fr": "Matin et Soir", "zh-Hans": "早晨和晚上", "de": "Morgen & Abend", "hi": "सुबह और शाम", "tr": "Sabah ve Akşam", "ru": "Утро и вечер"],
            "After Prayer": ["ar": "بعد الصلاة", "ur": "نماز کے بعد", "fr": "Après la Prière", "zh-Hans": "祈祷后", "de": "Nach dem Gebet", "hi": "प्रार्थना के बाद", "tr": "Namazdan Sonra", "ru": "После молитвы"],
            "Anxiety & Sorrow": ["ar": "الهم والحزن", "ur": "پریشانی اور غم", "fr": "Anxiété et Chagrin", "zh-Hans": "焦虑与悲伤", "de": "Angst & Kummer", "hi": "चिंता और दुख", "tr": "Endişe ve Üzüntü", "ru": "Тревога и печаль"],
            "Travel": ["ar": "السفر", "ur": "سفر", "fr": "Voyage", "zh-Hans": "旅行", "de": "Reise", "hi": "यात्रा", "tr": "Seyahat", "ru": "Путешествие"],
            "Forgiveness": ["ar": "المغفرة", "ur": "مغفرت", "fr": "Pardon", "zh-Hans": "宽恕", "de": "Vergebung", "hi": "क्षमा", "tr": "Bağışlanma", "ru": "Прощение"],
            "Guidance": ["ar": "الهداية", "ur": "رہنمائی", "fr": "Guidance", "zh-Hans": "指导", "de": "Leitung", "hi": "मार्गदर्शन", "tr": "Hidayet", "ru": "Руководство"],
            "Parents": ["ar": "الوالدين", "ur": "والدین", "fr": "Parents", "zh-Hans": "父母", "de": "Eltern", "hi": "माता-पिता", "tr": "Anne-Baba", "ru": "Родители"],
            "Knowledge": ["ar": "العلم", "ur": "علم", "fr": "Savoir", "zh-Hans": "知识", "de": "Wissen", "hi": "ज्ञान", "tr": "İlim", "ru": "Знание"],
            
            // MARK: - References
            "Abu Dawud & Tirmidhi": ["ar": "أبو داود والترمذي", "ur": "ابو داؤد اور ترمذی", "fr": "Abu Dawud & Tirmidhi", "zh-Hans": "阿布·达乌德和提尔密济", "de": "Abu Dawud & Tirmidhi", "hi": "अबू दाऊद और तिर्मिज़ी", "tr": "Ebu Davud ve Tirmizi", "ru": "Абу Дауд и Тирмизи"],
            "Abu Dawud": ["ar": "أبو داود", "ur": "ابو داؤد", "fr": "Abu Dawud", "zh-Hans": "阿布·达乌德", "de": "Abu Dawud", "hi": "अबू दाऊद", "tr": "Ebu Davud", "ru": "Абу Дауд"],
            "Sahih Muslim": ["ar": "صحيح مسلم", "ur": "صحیح مسلم", "fr": "Sahih Muslim", "zh-Hans": "穆斯林圣训实录", "de": "Sahih Muslim", "hi": "सहीह मुस्लिम", "tr": "Sahih Müslim", "ru": "Сахих Муслим"],
            "Sahih Bukhari": ["ar": "صحيح البخاري", "ur": "صحیح بخاری", "fr": "Sahih Bukhari", "zh-Hans": "布哈里圣训实录", "de": "Sahih Bukhari", "hi": "सहीह बुखारी", "tr": "Sahih Buhari", "ru": "Сахих аль-Бухари"],
            "Quran 21:87": ["ar": "القرآن ٢١:٨٧", "ur": "قرآن 21:87", "fr": "Coran 21:87", "zh-Hans": "古兰经 21:87", "de": "Koran 21:87", "hi": "क़ुरान 21:87", "tr": "Kuran 21:87", "ru": "Коран 21:87"],
            "Quran 43:13-14": ["ar": "القرآن ٤٣:١٣-١٤", "ur": "قرآن 43:13-14", "fr": "Coran 43:13-14", "zh-Hans": "古兰经 43:13-14", "de": "Koran 43:13-14", "hi": "क़ुरान 43:13-14", "tr": "Kuran 43:13-14", "ru": "Коран 43:13-14"],
            "Quran 7:23": ["ar": "القرآن ٧:٢٣", "ur": "قرآن 7:23", "fr": "Coran 7:23", "zh-Hans": "古兰经 7:23", "de": "Koran 7:23", "hi": "क़ुरान 7:23", "tr": "Kuran 7:23", "ru": "Коран 7:23"],
            "Sunan an-Nasa'i": ["ar": "سنن النسائي", "ur": "Sunan an-Nasa'i", "fr": "Sunan an-Nasa'i", "zh-Hans": "Sunan an-Nasa'i", "de": "Sunan an-Nasa'i", "hi": "Sunan an-Nasa'i", "tr": "Sunan an-Nasa'i", "ru": "Sunan an-Nasa'i"],
            "Quran 3:173": ["ar": "القرآن ٣:١٧٣", "ur": "Quran 3:173", "fr": "Quran 3:173", "zh-Hans": "Quran 3:173", "de": "Quran 3:173", "hi": "Quran 3:173", "tr": "Quran 3:173", "ru": "Quran 3:173"],
            "Quran 2:201": ["ar": "القرآن ٢:٢٠١", "ur": "Quran 2:201", "fr": "Quran 2:201", "zh-Hans": "Quran 2:201", "de": "Quran 2:201", "hi": "Quran 2:201", "tr": "Quran 2:201", "ru": "Quran 2:201"],
            "Quran 3:8": ["ar": "القرآن ٣:٨", "ur": "Quran 3:8", "fr": "Quran 3:8", "zh-Hans": "Quran 3:8", "de": "Quran 3:8", "hi": "Quran 3:8", "tr": "Quran 3:8", "ru": "Quran 3:8"],
            "Quran 17:24": ["ar": "القرآن ١٧:٢٤", "ur": "Quran 17:24", "fr": "Quran 17:24", "zh-Hans": "Quran 17:24", "de": "Quran 17:24", "hi": "Quran 17:24", "tr": "Quran 17:24", "ru": "Quran 17:24"],
            "Quran 20:114": ["ar": "القرآن ٢٠:١١٤", "ur": "Quran 20:114", "fr": "Quran 20:114", "zh-Hans": "Quran 20:114", "de": "Quran 20:114", "hi": "Quran 20:114", "tr": "Quran 20:114", "ru": "Quran 20:114"],
            
            // MARK: - Dua Translations
            "In the Name of Allah with Whose Name there is protection against every kind of harm in the earth or in the heaven, and He is the All-Hearing and All-Knowing.": [
                "ar": "",
                "ur": "اللہ کے نام سے، جس کے نام کے ساتھ زمین و آسمان کی کوئی چیز نقصان نہیں پہنچا سکتی، اور وہ سب کچھ سننے والا، جاننے والا ہے۔",
                "fr": "Au nom d'Allah, avec le nom duquel rien sur terre ni au ciel ne peut nuire, et Il est l'Audient, l'Omniscient.",
                "zh-Hans": "奉安拉之名，借祂的名，天地间没有任何事物能造成伤害，祂是全聪的，全知的。",
                "de": "Im Namen Allahs, mit dessen Namen nichts auf der Erde noch im Himmel schaden kann, und Er ist der Allhörende, der Allwissende.",
                "hi": "अल्लाह के नाम से, जिसके नाम के साथ पृथ्वी या आकाश में कोई भी चीज़ नुकसान नहीं पहुँचा सकती, और वह सब कुछ सुनने वाला, सब कुछ जानने वाला है।",
                "tr": "İsmi sayesinde yerde ve gökte hiçbir şeyin zarar veremeyeceği Allah'ın adıyla. O her şeyi işitendir, bilendir.",
                "ru": "С именем Аллаха, с именем Которого ничто не причинит вреда ни на земле, ни на небесах, ведь Он — Слышащий, Знающий."
            ],
            "I am pleased with Allah as my Lord, with Islam as my religion and with Muhammad (peace and blessings be upon him) as my Prophet.": [
                "ar": "",
                "ur": "میں اللہ کے رب ہونے، اسلام کے دین ہونے اور محمد (صلی اللہ علیہ وسلم) کے نبی ہونے پر راضی ہوں۔",
                "fr": "J'accepte Allah comme mon Seigneur, l'Islam comme ma religion et Muhammad (paix et bénédictions sur lui) comme mon Prophète.",
                "zh-Hans": "我满意安拉为我的主，伊斯兰为我的宗教，穆罕默德（愿主福安之）为我的先知。",
                "de": "Ich bin zufrieden mit Allah als meinem Herrn, mit dem Islam als meiner Religion und mit Muhammad (Friede und Segen seien auf ihm) als meinem Propheten.",
                "hi": "मैं अल्लाह को अपना रब, इस्लाम को अपना धर्म और मुहम्मद (उन पर शांति और आशीर्वाद हो) को अपना पैगंबर मानकर प्रसन्न हूं।",
                "tr": "Rab olarak Allah'tan, din olarak İslam'dan ve peygamber olarak Muhammed'den (s.a.v) razı oldum.",
                "ru": "Я доволен Аллахом как Господом, исламом как религией и Мухаммадом (мир ему и благословение) как Пророком."
            ],
            "I ask Allah for forgiveness (three times).": [
                "ar": "",
                "ur": "میں اللہ سے بخشش مانگتا ہوں (تین بار)۔",
                "fr": "Je demande pardon à Allah (trois fois).",
                "zh-Hans": "我祈求安拉的宽恕（三次）。",
                "de": "Ich bitte Allah um Vergebung (dreimal).",
                "hi": "मैं अल्लाह से क्षमा मांगता हूं (तीन बार)।",
                "tr": "Allah'tan bağışlanma dilerim (üç kez).",
                "ru": "Я прошу прощения у Аллаха (три раза)."
            ],
            "O Allah, You are Peace and from You comes peace. Blessed are You, O Owner of majesty and honor.": [
                "ar": "",
                "ur": "اے اللہ! تو سلامتی والا ہے اور تیری طرف سے سلامتی ہے۔ اے جلال و اکرام والے، تو بڑی برکتوں والا ہے۔",
                "fr": "Ô Allah, Tu es la Paix et de Toi vient la paix. Béni sois-Tu, Ô Détenteur de la majesté et de la noblesse.",
                "zh-Hans": "主啊！您是和平的，和平源自您。愿您充满吉庆，威严与尊贵的主啊。",
                "de": "O Allah, Du bist der Frieden und von Dir kommt der Frieden. Segensreich bist Du, O Besitzer von Majestät und Ehre.",
                "hi": "हे अल्लाह, आप शांति हैं और शांति आपकी ओर से आती है। हे महिमा और सम्मान के स्वामी, आप धन्य हैं।",
                "tr": "Ey Allah'ım! Sen selamsın, selamet sendendir. Ey celal ve ikram sahibi, sen yücesin.",
                "ru": "О Аллах, Ты — Мир, и от Тебя — мир. Благословен Ты, Обладатель величия и почета."
            ],
            "O Allah, I seek refuge in You from anxiety and sorrow, weakness and laziness, miserliness and cowardice, the burden of debts and from being overpowered by men.": [
                "ar": "",
                "ur": "اے اللہ! میں تیری پناہ مانگتا ہوں فکر اور غم سے، عاجزی اور سستی سے، کنجوسی اور بزدلی سے، قرض کے بوجھ اور لوگوں کے غلبے سے۔",
                "fr": "Ô Allah, je cherche refuge auprès de Toi contre l'anxiété et le chagrin, la faiblesse et la paresse, l'avarice et la lâcheté, le fardeau des dettes et la domination des hommes.",
                "zh-Hans": "主啊！我求庇于您，免遭忧虑与悲伤、软弱与懒惰、吝啬与怯懦、债务重压及受人欺压。",
                "de": "O Allah, ich suche Zuflucht bei Dir vor Sorge und Traurigkeit, Schwäche und Faulheit, Geiz und Feigheit, der Last von Schulden und davor, von Männern überwältigt zu werden.",
                "hi": "हे अल्लाह, मैं चिंता और दुख, कमजोरी और आलस्य, कंजूसी और कायरता, कर्ज के बोझ और लोगों के दबदबे से आपकी शरण मांगता हूं।",
                "tr": "Ey Allah'ım! Üzüntüden ve kederden, acizlikten ve tembellikten, cimrilikten ve korkaklıktan, borç altında ezilmekten ve insanların kahrından sana sığınırım.",
                "ru": "О Аллах, я прибегаю к Тебе от тревоги и печали, от слабости и лени, от скупости и трусости, от бремени долгов и от притеснения людей."
            ],
            "There is no deity except You; exalted are You. Indeed, I have been of the wrongdoers.": [
                "ar": "",
                "ur": "تیرے سوا کوئی معبود نہیں، تو پاک ہے۔ بیشک میں ہی ظالموں میں سے تھا۔",
                "fr": "Il n'y a de divinité que Toi; Exalté sois-Tu. J'ai été vraiment du nombre des injustes.",
                "zh-Hans": "万物非主，唯有您；赞美您超绝万物。我确是行亏的。",
                "de": "Es gibt keinen Gott außer Dir; gepriesen seist Du. Wahrlich, ich gehörte zu den Ungerechten.",
                "hi": "आपके सिवा कोई पूज्य नहीं; आप महान हैं। वास्तव में, मैं ही गलत करने वालों में से रहा हूं।",
                "tr": "Senden başka ilah yoktur; sen yücesin. Gerçekten ben zalimlerden oldum.",
                "ru": "Нет божества, кроме Тебя; пречист Ты. Поистине, я был из числа несправедливых."
            ],
            "Glory be to Him who has subjected this to us, and we could not have otherwise subdued it. And indeed we, to our Lord, will [surely] return.": [
                "ar": "",
                "ur": "پاک ہے وہ ذات جس نے اسے ہمارے تابع کر دیا، ورنہ ہم اسے قابو کرنے کی طاقت نہیں رکھتے تھے۔ اور یقیناً ہم اپنے رب کی طرف لوٹنے والے ہیں۔",
                "fr": "Gloire à Celui qui a soumis cela pour nous, alors que nous n'étions pas capables de le dominer. Et c'est vers notre Seigneur que nous retournerons.",
                "zh-Hans": "赞美安拉，他为我们制服了这交通工具，否则我们无法控制它。我们必定要归于我们的主。",
                "de": "Preis sei Ihm, der uns dies dienstbar gemacht hat, und wir hätten es sonst nicht bezwingen können. Und wahrlich, zu unserem Herrn werden wir zurückkehren.",
                "hi": "उसकी महिमा हो जिसने इसे हमारे अधीन कर दिया, और हम इसे अन्यथा वश में नहीं कर सकते थे। और वास्तव में हम अपने रब की ओर लौटने वाले हैं।",
                "tr": "Bunu bizim hizmetimize veren Allah'ı tenzih ederiz, yoksa biz buna güç yetiremezdik. Şüphesiz biz Rabbimize döneceğiz.",
                "ru": "Пречист Тот, Кто подчинил нам это, ведь мы не могли это осилить. И, поистине, к нашему Господу мы вернемся."
            ],
            "O Allah, You are my Lord, there is none worthy of worship but You. You created me and I am Your slave. I keep Your covenant, and my pledge to You so far as I am able.": [
                "ar": "",
                "ur": "اے اللہ! تو میرا رب ہے، تیرے سوا کوئی عبادت کے لائق نہیں۔ تو نے مجھے پیدا کیا اور میں تیرا بندہ ہوں۔ میں اپنی طاقت کے مطابق تیرے عہد اور وعدے پر قائم ہوں۔",
                "fr": "Ô Allah, Tu es mon Seigneur, il n'y a de divinité digne d'adoration que Toi. Tu m'as créé et je suis Ton serviteur. Je respecte Ton alliance et ma promesse envers Toi autant que je le peux.",
                "zh-Hans": "主啊！您是我的主，除您之外绝无应受崇拜的。您创造了我，我是您的奴仆。我尽我所能遵守您的誓约和对您的承诺。",
                "de": "O Allah, Du bist mein Herr, es gibt keinen anbetungswürdigen Gott außer Dir. Du hast mich erschaffen und ich bin Dein Diener. Ich halte mich an Deinen Bund und mein Versprechen an Dich, soweit ich kann.",
                "hi": "हे अल्लाह, आप मेरे भगवान हैं, आपके सिवा कोई पूजा के योग्य नहीं है। आपने मुझे बनाया है और मैं आपका दास हूं। मैं अपनी क्षमता के अनुसार आपके वादे और प्रतिज्ञा का पालन करता हूं।",
                "tr": "Ey Allah'ım! Sen benim Rabbimsin, senden başka ibadete layık ilah yoktur. Beni sen yarattın ve ben senin kulunum. Gücüm yettiğince sana verdiğim söze ve ahde sadığım.",
                "ru": "О Аллах, Ты — мой Господь, нет божества, достойного поклонения, кроме Тебя. Ты создал меня, и я — Твой раб. И я верен Своему завету и обещанию Тебе, насколько это в моих силах."
            ],
            "Our Lord, we have wronged ourselves, and if You do not forgive us and have mercy upon us, we will surely be among the losers.": [
                "ar": "",
                "ur": "اے ہمارے رب! ہم نے اپنی جانوں پر ظلم کیا، اور اگر تو نے ہمیں معاف نہ کیا اور ہم پر رحم نہ فرمایا، تو یقیناً ہم خسارہ پانے والوں میں سے ہو جائیں گے۔",
                "fr": "Notre Seigneur, nous nous sommes fait du tort à nous-mêmes, et si Tu ne nous pardonnes pas et ne nous fais pas miséricorde, nous serons certainement parmi les perdants.",
                "zh-Hans": "我们的主啊！我们亏待了自己，如果您不宽恕我们，不怜悯我们，我们必定会成为失败者。",
                "de": "Unser Herr, wir haben uns selbst Unrecht getan, und wenn Du uns nicht vergibst und Dich unser nicht erbarmst, werden gewiss unter den Verlierern sein.",
                "hi": "हे हमारे रब, हमने अपने आप पर अत्याचार किया है, और यदि आप हमें क्षमा नहीं करते हैं और हम पर दया नहीं करते हैं, तो हम निश्चित रूप से हारने वालों में से होंगे।",
                "tr": "Rabbimiz! Biz kendimize zulmettik, eğer bizi bağışlamaz ve bize acımazsan muhakkak ziyana uğrayanlardan oluruz.",
                "ru": "Господь наш, мы поступили несправедливо по отношению к себе, и если Ты не простишь нас и не помилуешь нас, мы непременно окажемся в числе потерпевших убыток."
            ],
            "O Ever-Living, O Sustainer, in Your Mercy I seek relief. Rectify for me all of my affairs and do not leave me to myself, even for the blink of an eye.": ["ar": "", "ur": "O Ever-Living, O Sustainer, in Your Mercy I seek relief. Rectify for me all of my affairs and do not leave me to myself, even for the blink of an eye.", "fr": "O Ever-Living, O Sustainer, in Your Mercy I seek relief. Rectify for me all of my affairs and do not leave me to myself, even for the blink of an eye.", "zh-Hans": "O Ever-Living, O Sustainer, in Your Mercy I seek relief. Rectify for me all of my affairs and do not leave me to myself, even for the blink of an eye.", "de": "O Ever-Living, O Sustainer, in Your Mercy I seek relief. Rectify for me all of my affairs and do not leave me to myself, even for the blink of an eye.", "hi": "O Ever-Living, O Sustainer, in Your Mercy I seek relief. Rectify for me all of my affairs and do not leave me to myself, even for the blink of an eye.", "tr": "O Ever-Living, O Sustainer, in Your Mercy I seek relief. Rectify for me all of my affairs and do not leave me to myself, even for the blink of an eye.", "ru": "O Ever-Living, O Sustainer, in Your Mercy I seek relief. Rectify for me all of my affairs and do not leave me to myself, even for the blink of an eye."],
            "Sufficient for us is Allah, and [He is] the best Disposer of affairs.": ["ar": "", "ur": "Sufficient for us is Allah, and [He is] the best Disposer of affairs.", "fr": "Sufficient for us is Allah, and [He is] the best Disposer of affairs.", "zh-Hans": "Sufficient for us is Allah, and [He is] the best Disposer of affairs.", "de": "Sufficient for us is Allah, and [He is] the best Disposer of affairs.", "hi": "Sufficient for us is Allah, and [He is] the best Disposer of affairs.", "tr": "Sufficient for us is Allah, and [He is] the best Disposer of affairs.", "ru": "Sufficient for us is Allah, and [He is] the best Disposer of affairs."],
            "Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.": ["ar": "", "ur": "Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.", "fr": "Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.", "zh-Hans": "Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.", "de": "Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.", "hi": "Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.", "tr": "Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.", "ru": "Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire."],
            "Our Lord, let not our hearts deviate after You have guided us and grant us from Yourself mercy. Indeed, You are the Bestower.": ["ar": "", "ur": "Our Lord, let not our hearts deviate after You have guided us and grant us from Yourself mercy. Indeed, You are the Bestower.", "fr": "Our Lord, let not our hearts deviate after You have guided us and grant us from Yourself mercy. Indeed, You are the Bestower.", "zh-Hans": "Our Lord, let not our hearts deviate after You have guided us and grant us from Yourself mercy. Indeed, You are the Bestower.", "de": "Our Lord, let not our hearts deviate after You have guided us and grant us from Yourself mercy. Indeed, You are the Bestower.", "hi": "Our Lord, let not our hearts deviate after You have guided us and grant us from Yourself mercy. Indeed, You are the Bestower.", "tr": "Our Lord, let not our hearts deviate after You have guided us and grant us from Yourself mercy. Indeed, You are the Bestower.", "ru": "Our Lord, let not our hearts deviate after You have guided us and grant us from Yourself mercy. Indeed, You are the Bestower."],
            "My Lord, have mercy upon them as they brought me up [when I was] small.": ["ar": "", "ur": "My Lord, have mercy upon them as they brought me up [when I was] small.", "fr": "My Lord, have mercy upon them as they brought me up [when I was] small.", "zh-Hans": "My Lord, have mercy upon them as they brought me up [when I was] small.", "de": "My Lord, have mercy upon them as they brought me up [when I was] small.", "hi": "My Lord, have mercy upon them as they brought me up [when I was] small.", "tr": "My Lord, have mercy upon them as they brought me up [when I was] small.", "ru": "My Lord, have mercy upon them as they brought me up [when I was] small."],
            "My Lord, increase me in knowledge.": ["ar": "", "ur": "My Lord, increase me in knowledge.", "fr": "My Lord, increase me in knowledge.", "zh-Hans": "My Lord, increase me in knowledge.", "de": "My Lord, increase me in knowledge.", "hi": "My Lord, increase me in knowledge.", "tr": "My Lord, increase me in knowledge.", "ru": "My Lord, increase me in knowledge."],
        ]
}
