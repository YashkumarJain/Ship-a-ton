# Supabase setup for WealthPilot

1. Create a Supabase project.
2. Open **SQL Editor** and run `schema.sql`.
3. Enable Email/Password under Authentication.
4. Copy the project URL and public anon/publishable key into the backend environment and Flutter `--dart-define` values.
5. Keep Row Level Security enabled. Policies restrict every protected row to `auth.uid() = user_id`.
6. Profiles begin a 6-day premium trial when the auth user is created.
7. Approved statement transactions are stored in `transactions`; source PDFs are not stored.
8. Users can upload statements repeatedly. `source_fingerprint` is based on transaction identity (not category), so overlapping old rows are skipped and only new transactions are appended. Existing saved categories/data are never overwritten by a later statement import.
9. Identical legitimate same-day purchases are retained using a source occurrence index; a running balance is also used when the statement exposes one.
9. Goals are stored in `financial_goals`; app/backend code additionally require explicit human approval before mutations.
10. Optional: configure `news_cron_example.sql` after replacing the backend URL and cron secret.

For a judge/demo account, `POST /api/demo/seed` can copy the bundled demonstration data into only that signed-in account when demo mode is enabled.

**Never put a Supabase service-role/secret key inside the Flutter application.**
