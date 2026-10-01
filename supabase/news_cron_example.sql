-- OPTIONAL: daily news refresh from Supabase Cron.
-- Replace both placeholders before running. Keep the cron secret private.
-- pg_net is used to make the HTTPS POST request.

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'wealthpilot-daily-news-refresh',
  '0 7 * * *',
  $$
  select net.http_post(
    url := 'https://YOUR_BACKEND_HOST/api/internal/news/refresh',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', 'YOUR_CRON_SECRET'
    ),
    body := '{}'::jsonb
  );
  $$
);
