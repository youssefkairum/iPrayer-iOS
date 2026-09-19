# App Store release notes for 1.1.0 (build 6)

Everything App Store Connect asks for, ready to paste. Written 19 September 2026.

## Submission checklist

1. Merge the release PR, open the project in Xcode, confirm version 1.1.0 build 6 on every target.
2. Product > Archive with the iPrayer scheme (the watch app and both widget extensions archive with it).
3. Upload, then in App Store Connect: attach the build, paste the texts below, upload the screenshots from
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
(Apple's CoreLocation geocoder), audio requests to everyayah.com (a plain file URL per verse, no identifiers),
and iCloud key-value sync into the person's own iCloud (name, email, settings, progress). None of it reaches the
developer. The required-reason API declaration for UserDefaults is in `PrivacyInfo.xcprivacy` (CA92.1 and 1C8F.1).

## Screenshots

`docs/screenshots/` holds simulator captures in English: iPhone 6.9" (iPhone 18 Pro Max, 1320x2868) and
iPad 13" (iPad Pro 13-inch, 2064x2752): Home, Quran reader, Tasbih, Qibla, Settings. App Store Connect accepts
them as is; add device frames or captions in Keynote if wanted.

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
