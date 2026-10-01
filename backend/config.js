function boolEnv(name, fallback = false) {
  const raw = process.env[name];
  if (raw == null || raw === "") return fallback;
  return ["1", "true", "yes", "on"].includes(String(raw).toLowerCase());
}

module.exports = {
  port: Number(process.env.PORT || 5000),
  openAiModel: process.env.OPENAI_MODEL || "gpt-5.6-luna",
  supabaseUrl: process.env.SUPABASE_URL || "",
  supabaseAnonKey: process.env.SUPABASE_ANON_KEY || "",
  revenueCatSecretApiKey: process.env.REVENUECAT_SECRET_API_KEY || "",
  revenueCatEntitlementId: process.env.REVENUECAT_ENTITLEMENT_ID || "premium",
  allowDemoMode: boolEnv("ALLOW_DEMO_MODE", true),
  allowSimulatedPurchases: boolEnv("ALLOW_SIMULATED_PURCHASES", true),
  newsRefreshHours: Number(process.env.NEWS_REFRESH_HOURS || 6),
  cronSecret: process.env.CRON_SECRET || "",
  corsOrigin: process.env.CORS_ORIGIN || "*"
};
