# WealthPilot implementation status

## Implemented in code

### Free / Person 1

- Supabase Auth integration and one-time onboarding profile
- private profile storage for display name, age, budget and savings balance
- bank PDF upload from Flutter
- in-memory backend upload; original PDF is not persisted
- generic statement parsing for common date/currency layouts
- native PDF text extraction plus OCR fallback for scanned statements
- deterministic expense categorization
- review/edit/delete/manual-add transaction screen before import
- explicit approval required before transaction save
- private per-user transaction persistence in Supabase
- duplicate protection via per-user transaction fingerprint
- future logins read the saved structured transactions without requiring the same PDF again
- basic money snapshot and category breakdown
- responsive WealthPilot-style mobile dashboard

### Premium / Person 2

- all 12 existing financial intelligence functions preserved
- request-scoped per-user financial context
- GPT multi-tool reasoning using deterministic tool results
- OpenAI calls configured with `store: false`
- identity/account/merchant fields stripped from tool results before OpenAI reasoning
- recommendation/action scenarios grounded in tool outputs
- vacation-aware planning
- structured visualization planner based on actual tools used
- Flutter Assistant screen with animated sphere, 2.5D-style chart and haptics
- global foreground `Hey Assistant` voice wake phrase
- device speech-to-text and text-to-speech
- Goals screen
- AI can propose goal create/update/delete, but cannot apply it
- every goal mutation requires human confirmation + backend approval flag

### News

- public RSS ingest from configured sources
- invalid/non-HTTP source links rejected
- no synthetic replacement stories when feeds are unavailable
- factual overview derived from verified RSS source content
- AI limited to supplied-story selection + sector context
- market context limited to tailwind/headwind/mixed/uncertain
- exact original source link displayed and launchable
- optional voice guidance
- no automatic move to next story; next/previous only on explicit action/voice command
- disclaimer shown and spoken
- daily/on-demand refresh architecture

### Subscription / deployment

- 6-day premium trial
- free features remain accessible after trial
- RevenueCat `premium` entitlement architecture
- RevenueCat purchase + restore UI
- RevenueCat Test Store debug configuration path
- backend entitlement verification support
- Render deployment blueprint
- Supabase RLS schema
- responsive phone/tablet/foldable layouts
- light/dark/system themes

## Verification performed in this environment

- Node syntax check passes for backend server and new services.
- `statementParser.test.js` passes.
- Existing `intelligencetest.js` still passes the original 12-function expected values.
- PDF source file is never written by the statement endpoint; only memory upload is configured.

## Could not be compiled here

The Flutter SDK is not installed in this execution environment, so Android/iOS compilation and `flutter analyze` must be run on a development machine. `mobile/bootstrap_platforms.ps1` generates the official platform runner projects and required mobile permissions.

The added PDF/OCR Node packages also need `npm install` on the development/deployment machine.

## Important demo limitation

The parser is deliberately bank-agnostic and has OCR fallback, but no parser can guarantee perfect extraction from every arbitrary bank statement layout. WealthPilot therefore requires a transaction review screen before saving and lets the user correct/add rows. For tomorrow's demo, test the exact statement PDF you plan to show before presenting.

## Repeated / overlapping statement imports
- Users may upload statement PDFs as often as needed.
- Imports are append-only: previously saved matching transactions are not overwritten.
- New-only statements append all recognized new rows.
- Overlapping statements append only rows not already saved.
- Re-uploading the same statement adds zero duplicates.
- Deduplication excludes category from transaction identity, so a prior human category correction is preserved.
- Identical legitimate same-day/same-amount transactions are retained using an occurrence index (and running balance when available).
- Every import records extracted/saved/duplicate counts; the original PDF is still discarded after processing.
