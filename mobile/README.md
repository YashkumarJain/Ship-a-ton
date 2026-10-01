# WealthPilot Flutter app

The `mobile/` directory is the Android/iOS client for WealthPilot.

## Screens

- **Home / Snapshot — free:** onboarding result, statement PDF upload, review/import, money-in, money-out, activity, largest category, category totals and recent transactions.
- **Assistant — premium:** voice/text AI, animated sphere, evidence-driven graph, suggestions and human-approved goal proposals.
- **News — premium:** top verified RSS stories, exact source link, optional voice guidance, selected-story reading and explicit next/previous commands.
- **Goals — premium:** savings/vacation/emergency/purchase goals. Create, edit and delete actions require confirmation.
- **Settings — free:** light/dark/system theme, wake phrase, subscription access and sign out.

The app uses responsive constraints rather than a fixed phone size. It switches between stacked layouts, wider panels, bottom navigation and NavigationRail for narrow phones, landscape, tablets and unfolded/foldable screens.

## Voice behavior

`Hey Wealth Assistant` is listened for only while WealthPilot is in the foreground. The same shared voice service is available from every screen.

Examples:

- `Hey Wealth Assistant, open news`
- `Hey Wealth Assistant, why did my spending increase?`
- `Hey Wealth Assistant, open goals`
- while reading news: `read this`, `open source`, `next news`, `previous news`

News never auto-advances to the next story.

## 1. Install Flutter and generate Android/iOS runners

On Windows PowerShell:

```powershell
cd mobile
.\bootstrap_platforms.ps1
flutter pub get
flutter analyze
```

The script uses `flutter create` to generate official Android/iOS runner folders, applies the WealthPilot app label and inserts microphone/speech-recognition permissions.

## 2. Run against a deployed backend

```powershell
flutter run `
  --dart-define=API_BASE_URL=https://YOUR-API-HOST `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY `
  --dart-define=REVENUECAT_TEST_API_KEY=YOUR_TEST_STORE_PUBLIC_KEY
```

Use the deployed HTTPS backend for the final demo so the app works anywhere. For an Android emulator only, a local backend can be reached through `http://10.0.2.2:5000`.

## 3. RevenueCat

Create an entitlement named `premium` and a current Offering containing the monthly package intended for `$4.99/month`.

For a debug hackathon test, pass the RevenueCat Test Store public SDK key. For release builds, pass the platform-specific public SDK key and do not ship the Test Store key.

The app uses the Supabase user UUID as RevenueCat `appUserID`.

## 4. Production examples

Android:

```powershell
flutter build appbundle --release `
  --dart-define=API_BASE_URL=https://YOUR-API-HOST `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY `
  --dart-define=REVENUECAT_ANDROID_API_KEY=YOUR_ANDROID_PUBLIC_KEY
```

iOS on a Mac with Xcode:

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://YOUR-API-HOST \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY \
  --dart-define=REVENUECAT_IOS_API_KEY=YOUR_IOS_PUBLIC_KEY
```

## PDF statement import

The user chooses a PDF locally. The app uploads the bytes to `/api/statements/parse`; the backend attempts native PDF text extraction first and OCR if necessary. The user must review the extracted transaction table and explicitly approve before `/api/statements/commit` stores structured rows.

The source PDF is not retained by the backend. Because banks use many incompatible layouts, the review screen is a deliberate safety layer: rows can be edited, removed or manually added before approval.
