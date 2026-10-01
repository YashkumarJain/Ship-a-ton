const supabase = require("./supabaseRest");

const demoProfiles = new Map();

function cleanProfile(row = {}) {
  return {
    displayName: row.display_name || "",
    age: row.age == null ? null : Number(row.age),
    monthlyBudget: Number(row.monthly_budget || 0),
    savingsBalance: Number(row.savings_balance || 0),
    savingsGoal: Number(row.savings_goal || 0),
    themeMode: row.theme_mode || "system",
    onboardingComplete: Boolean(row.onboarding_complete),
    trialStartedAt: row.trial_started_at || null,
    trialEndsAt: row.trial_ends_at || null,
    subscriptionStatus: row.subscription_status || "trial"
  };
}

function validateProfile(input = {}) {
  const displayName = String(input.displayName || "").trim().slice(0, 60);
  const age = input.age === null || input.age === undefined || input.age === ""
    ? null
    : Number(input.age);
  if (!displayName) throw new Error("A name is required to finish onboarding.");
  if (age !== null && (!Number.isInteger(age) || age < 13 || age > 120)) {
    throw new Error("Age must be a whole number between 13 and 120.");
  }
  const monthlyBudget = Number(input.monthlyBudget || 0);
  const savingsBalance = Number(input.savingsBalance || 0);
  return {
    display_name: displayName,
    age,
    monthly_budget: Number.isFinite(monthlyBudget) && monthlyBudget >= 0 ? monthlyBudget : 0,
    savings_balance: Number.isFinite(savingsBalance) && savingsBalance >= 0 ? savingsBalance : 0,
    onboarding_complete: true,
    updated_at: new Date().toISOString()
  };
}

async function getProfile(req) {
  if (req.user?.isDemo || !supabase.isConfigured() || !req.accessToken) {
    const existing = demoProfiles.get(req.user.id) || {
      display_name: "",
      age: null,
      monthly_budget: 4200,
      savings_balance: 2500,
      savings_goal: 0,
      theme_mode: "system",
      onboarding_complete: false,
      trial_started_at: new Date().toISOString(),
      trial_ends_at: new Date(Date.now() + 6 * 86400000).toISOString(),
      subscription_status: "trial"
    };
    demoProfiles.set(req.user.id, existing);
    return cleanProfile(existing);
  }

  const rows = await supabase.request(
    "profiles?select=display_name,age,monthly_budget,savings_balance,savings_goal,theme_mode,onboarding_complete,trial_started_at,trial_ends_at,subscription_status&limit=1",
    { accessToken: req.accessToken }
  );
  return cleanProfile(rows?.[0] || {});
}

async function updateProfile(req, input) {
  const update = validateProfile(input);
  if (req.user?.isDemo || !supabase.isConfigured() || !req.accessToken) {
    const previous = demoProfiles.get(req.user.id) || {};
    const next = { ...previous, ...update };
    demoProfiles.set(req.user.id, next);
    return cleanProfile(next);
  }

  const rows = await supabase.request("profiles?user_id=eq." + encodeURIComponent(req.user.id), {
    accessToken: req.accessToken,
    method: "PATCH",
    headers: { Prefer: "return=representation" },
    body: update
  });
  return cleanProfile(rows?.[0] || update);
}

module.exports = { getProfile, updateProfile };
