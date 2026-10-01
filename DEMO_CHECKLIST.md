# WealthPilot — deadline demo checklist

Use this order. Do not spend time polishing animations until the end-to-end path works.

## A. Backend

1. Open the final project and go to `backend`.
2. Copy `.env.example` to `.env` and add the real server-side values.
3. Run:

```powershell
npm install
npm run check
node statementParser.test.js
node intelligencetest.js
npm start
```

4. Confirm `http://localhost:5000/health` returns `ok: true`.

## B. Supabase

1. Create/open the Supabase project.
2. Run `supabase/schema.sql` in SQL Editor.
3. Enable Email/Password authentication.
4. Record the project URL and public anon/publishable key.
5. Never put a service-role key in Flutter.

## C. Deploy backend

1. Connect the repository to Render using `render.yaml`.
2. Add server environment values shown in `backend/.env.example`.
3. Set production safety values:
   - `ALLOW_DEMO_MODE=false`
   - `ALLOW_SIMULATED_PURCHASES=false`
4. Deploy and test `https://YOUR-HOST/health`.
5. Put that HTTPS URL in Flutter's `API_BASE_URL`.

## D. Flutter

1. Install Flutter and Android Studio/SDK.
2. From `mobile` run:

```powershell
.\bootstrap_platforms.ps1
flutter pub get
flutter analyze
```

3. Run on Android with the deployed backend:

```powershell
flutter run `
  --dart-define=API_BASE_URL=https://YOUR-HOST `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY `
  --dart-define=REVENUECAT_TEST_API_KEY=YOUR_TEST_STORE_PUBLIC_KEY
```

## E. RevenueCat

1. Create/select RevenueCat project.
2. Entitlement name: `premium`.
3. Create a current Offering and monthly package.
4. Configure Test Store for the hackathon debug demo.
5. Verify purchase and Restore Purchases unlock Assistant, News and Goals.
6. Confirm Home/statement import still works when premium is not active.

## F. PDF demo

Before the presentation:

1. Use the exact PDF you will show.
2. Upload it.
3. Verify transaction dates, types and amounts.
4. Correct any unusual row in the review screen.
5. Approve import.
6. Close/reopen the app and confirm the snapshot loads without re-uploading the PDF.

## G. AI demo path

Recommended short story:

1. Sign in.
2. Show saved statement snapshot.
3. Say: `Hey Assistant, why did my spending increase?`
4. Show the tool-grounded answer and changing chart.
5. Ask: `What can I change next month to save for a vacation?`
6. Ask the AI to create a vacation goal.
7. Show the proposal and **human approval dialog** before saving it.
8. Open News.
9. Show all verified headlines first.
10. Select one story, show the exact source link and use `Read overview aloud`.
11. Demonstrate that it stays on the same story until `next news` is explicitly requested.
12. Show the RevenueCat paywall/restore path.

## H. Final submission checks

- no `.env` or secret keys committed
- no sample financial PDF committed unless intentionally public/demo-safe
- app branding says `WealthPilot` compactly
- source links open correctly
- privacy statement is visible/explainable
- trial/paywall works
- Android demo build launches without a laptop-local backend
- record a backup demo video in case venue networking is poor
