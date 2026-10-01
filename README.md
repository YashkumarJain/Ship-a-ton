# WealthPilot — your AI Wealth Assistant

WealthPilot is the Ship-a-ton mobile project: a Flutter app for Android and iOS that combines a free statement-driven money snapshot with a premium voice AI financial assistant.

## Product split

### Free — Person 1 / Data + Dashboard

- Supabase email/password login
- one-time private onboarding profile
- upload a bank-statement PDF
- text extraction with OCR fallback for scanned PDFs
- automatic transaction parsing and expense categorization
- mandatory review/edit step before anything is saved
- original PDF is processed in memory and is **not retained**
- approved structured transactions are saved per user in Supabase
- future logins load saved transactions; the PDF does not need to be uploaded again
- duplicate statement rows are de-duplicated by a transaction fingerprint
- money-in, money-out, activity count, largest category, category breakdown and recent activity
- responsive dark/light/system UI inspired by the original WealthPilot prototype

PDF parsing is intentionally bank-agnostic rather than tied to one sample statement. It supports common text statement layouts, several date/currency formats, wrapped descriptions and scanned PDFs through OCR. Bank PDFs vary significantly, so every import requires human review and the review screen supports editing, deleting and manually adding a row before save.

### Premium — Person 2 / AI Wealth Assistant

The existing deterministic financial layer remains the numerical source of truth:

1. `getTransactions`
2. `getSpendingByCategory`
3. `getSpendingForPeriod`
4. `comparePeriods`
5. `findLargestTransactions`
6. `findRecurringExpenses`
7. `detectSpendingChanges`
8. `calculateBudgetRemaining`
9. `projectMonthlySpending`
10. `calculateSavingsCapacity`
11. `simulateSavingsGoal`
12. `calculateCashFlow`

GPT can autonomously call several tools for one question, combine their evidence, explain causes, build next-month scenarios and return a chart specification. The Flutter UI turns that specification into an animated visualization instead of asking the model to invent chart values.

Premium includes:

- AI assistant
- `Hey Assistant` wake phrase while the app is open
- global voice navigation from any app screen
- device speech-to-text and text-to-speech
- animated blue/purple AI sphere
- responsive 2.5D-style financial charts with highlighted data
- planning suggestions grounded in financial tool outputs
- goals, including vacation goals
- AI goal proposals that **never mutate data without explicit human approval**
- verified industry/business news with source links
- voice-guided news that remains on the selected story until the user explicitly chooses another story or says `next news`

## News integrity

News comes only from configured public RSS feeds. The server rejects entries without valid HTTP(S) source links and never asks the model to invent a headline, publisher, publication date or URL. The displayed factual overview comes from the source RSS description; AI is used only to select relevant supplied stories and add a bounded `tailwind`, `headwind`, `mixed` or `uncertain` sector-context label and rationale.

If verified feeds cannot be fetched, `/api/news/top` returns an error instead of creating replacement stories.

Every news view includes the original exact source link and the disclaimer:

> AI-generated news analysis for informational purposes only. It does not guarantee market performance and is not an investment recommendation.

## Privacy model

Supabase Auth + Row Level Security isolates every user's profile, transactions, statement imports, bills and goals.

The mobile app sends the bank PDF to the backend only for parsing. The backend uses memory upload storage and does not persist the source PDF. Only transactions explicitly approved by the user are saved.

For AI analysis, WealthPilot sends only the financial values needed for reasoning. Tool results are sanitized before being sent back to OpenAI; identity fields, IDs, account/card information, access tokens, transaction fingerprints and merchant names are excluded. OpenAI Responses calls use `store: false`.

Do not place OpenAI keys, Supabase service-role keys or RevenueCat secret keys in the Flutter app.

## Trial and subscription

- Premium trial: 6 days from profile creation
- intended subscription: `$4.99/month`
- RevenueCat entitlement: `premium`
- RevenueCat purchase + restore flow included
- RevenueCat Test Store supported for development/demo configuration
- free dashboard and statement import remain usable after premium access ends

## Mobile navigation

```text
Home / Snapshot    FREE
Assistant          PREMIUM
News               PREMIUM
Goals              PREMIUM
Settings           FREE
```

Layouts use available constraints rather than fixed device dimensions. Narrow phones use bottom navigation and stacked content; larger/foldable/tablet widths use expanded panels and NavigationRail.

## Repository

```text
backend/
  server.js
  financialIntelligence.js
  financialTools.js
  financialToolDefinitions.js
  services/
    statementParser.js
    pdfStatementService.js
    statementService.js
    profileService.js
    goalService.js
    newsService.js
    ...

mobile/
  lib/
    screens/
    services/
    widgets/
  pubspec.yaml
  bootstrap_platforms.ps1

supabase/
  schema.sql
  news_cron_example.sql

render.yaml
DEMO_CHECKLIST.md
```

## Run the backend locally

```powershell
cd backend
Copy-Item .env.example .env
# Fill in the required server-side values.
npm install
npm run check
npm start
```

Health check: `GET http://localhost:5000/health`

## Configure Supabase

1. Create the project.
2. Run `supabase/schema.sql` in the SQL Editor.
3. Enable Email/Password authentication.
4. Add the Supabase URL/public key to the Flutter build values and backend environment.
5. Keep Row Level Security enabled.

## Generate and run the Flutter app

The environment used for this handoff does not have the Flutter SDK, so generated `android/` and `ios/` runner folders are intentionally created on your development machine using Flutter's official generator.

```powershell
cd mobile
.\bootstrap_platforms.ps1
flutter pub get
flutter analyze
```

Then follow `mobile/README.md` for the `flutter run` command and required `--dart-define` values.

## Deploy

`render.yaml` describes the Node backend service. The mobile app must use its deployed HTTPS URL, not `localhost`, so it works independently from the developer laptop.

For daily news refresh, `supabase/news_cron_example.sql` can call the protected backend refresh route once per day. The news endpoint also refreshes stale data on demand.

## Required external setup

The source code is complete, but these account-specific values cannot be bundled safely:

- OpenAI API key — backend only
- Supabase URL/public key
- RevenueCat project and `premium` entitlement
- RevenueCat Test Store public key for debug testing
- production iOS/Android RevenueCat public keys and store products when publishing
- RevenueCat server secret key if server-side entitlement verification is enabled
- deployed Render/backend URL

See `DEMO_CHECKLIST.md` for the shortest path to tomorrow's demo.
