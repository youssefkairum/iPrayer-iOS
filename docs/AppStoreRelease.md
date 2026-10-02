# App Store release notes for 1.1.0 (build 13)

The release-specific texts for App Store Connect, ready to paste: What's New, review notes, privacy answers
and screenshots. The listing fields (subtitle, promotional text, keywords, description, and What's New as
bullets, in English and Arabic) are in `docs/AppStoreListing.md`. Written 19 September 2026, updated
2 October 2026 for build 13.

## Submission checklist

1. DONE — everything is merged to `main` and 1.1.0 (13) is already archived at
   `~/Library/Developer/Xcode/Archives/2026-10-02/iPrayer 1.1.0 (13).xcarchive`. Do NOT upload build 12:
   it crashes at launch on phones set to the Hijri calendar. Only redo steps 1 and 2 if
   the code changes; otherwise try Siri on a real iPhone first (HANDOFF §6: say each phrase in English and
   Arabic), then start at step 3.
2. DONE for build 13 — Product > Archive with the iPrayer scheme (the watch app and both widget extensions archive with it).
3. Upload, then in App Store Connect: attach build 13 (Xcode's record shows a 1.1.0 build 3
   was uploaded on 18 September; if it is still listed, do not select it), paste the texts below, upload the screenshots from
   `docs/screenshots/`, answer the privacy questions as listed, and submit.
4. Export compliance is already answered in the Info.plist (`ITSAppUsesNonExemptEncryption` = NO).

## What's New (release notes, en-US)

Quran recitation from six reciters, downloadable per surah for offline listening, and full tajweed marks in the
Quran text. Verse of the Day and Today's Prayers widgets in each prayer's colours. A library of 50 duas with the
morning and evening adhkar, and a Dua of the Day on Home. A rebuilt Tasbih with six dhikr phrases and a Qibla
compass with turn guidance. An Apple Watch app with complications and two-way sync. A new Liquid Glass look with
animations and haptics, a one-screen Home, and a Sign out and delete my data option in Settings.

## App Review notes

- iPrayer works without an account. Sign in with Apple is optional and only turns on iCloud key-value sync; no
  developer server exists. Account deletion is in Settings > Account > "Sign out and delete my data" (guideline
  5.1.1 v): it removes the profile and every synced value from iCloud and signs out.
- Background mode "audio": Quran recitation keeps playing with the screen off. Background mode "fetch": prayer-time
  notifications are re-scheduled for the next seven days.
- Location is used for prayer times and the Qibla direction only, asked on an onboarding slide, never at launch.
  If the reviewer's device has no location, Home shows a card to enable it and the rest of the app works.
- Recitation audio streams from everyayah.com (per verse) under its non-commercial licence; the app is free with
  no ads or purchases. Downloaded audio is stored excluded from backups.
- The Apple Watch app is a companion: it calculates its own prayer times from the watch's location and syncs
  settings and the Tasbih with the phone. Opening the iPhone app once after install activates the link.
- What's New shows once to people updating from 1.0; a fresh install goes through onboarding instead.

## App Privacy answers

"Data Not Collected". Nothing leaves the device except: reverse geocoding of the coordinates for the city name
(Apple's own geocoder: MapKit on the iPhone, CoreLocation on the watch), audio requests to everyayah.com (a plain file URL per verse, no identifiers),
and iCloud key-value sync into the person's own iCloud (name, email, settings, progress). None of it reaches the
developer. The required-reason API declaration for UserDefaults is in `PrivacyInfo.xcprivacy` (CA92.1 and 1C8F.1).

## Screenshots

`docs/screenshots/` holds 32 simulator captures, each screen in BOTH English and Arabic:

| set | device | size | screens |
|---|---|---|---|
| `iphone69-*` | iPhone 18 Pro Max | 1320x2868 | home, Quran light, Quran dark, duas, tasbih, qibla, onboarding watch step |
| `ipad13-*` | iPad Pro 13-inch | 2064x2752 | the same six; NO watch step, an iPad cannot pair a watch |
| `watch44-*` | Apple Watch SE 3 (44mm) | 368x448 | next prayer, tasbih, qibla |

Named `<device>-<en|ar>-<NN>-<screen>.png`. The 44mm watch is used rather than the Ultra because it gives
368x448, a size the App Store lists, where the Ultra gives 422x514.

`docs/screenshots/captioned/` holds the SAME 32 at the SAME sizes with a marketing headline drawn above the
screen, on the app's own gradient. **App Store Connect has no caption field** — a caption has to be part of
the image, which is what these are for. Upload either set; the plain one if you would rather add frames and
text yourself.

Suggested order, since search results usually show only the first three: home, Quran, qibla, tasbih, duas,
Quran dark, watch step.

## Audio rights email to EveryAyah (draft, not sent)

To: the contact address on everyayah.com

Subject: Permission request: iPrayer, a free iOS app, streaming EveryAyah recitations

Assalamu alaikum,

I am the developer of iPrayer, a free iOS prayer-times and Quran app with no ads or purchases. The app streams
per-verse recitation files from everyayah.com for six reciters, and lets people download a surah for offline
listening. It keeps to at most two connections at a time, as your About page asked, and credits EveryAyah in its
acknowledgements.

Your archived About page states the recitations are shared under Creative Commons BY-NC 2.5 Canada. I would like
to confirm that this use (non-commercial streaming and personal offline copies in a free app) is acceptable to
you, and whether you would prefer a different attribution text or a lower connection limit.

Jazakum Allahu khairan,
Youssef Keram
