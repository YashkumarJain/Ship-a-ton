const config = require("../config");
const supabase = require("./supabaseRest");

const simulatedPremiumUsers = new Set();

function sixDaysFrom(date) {
  return new Date(date.getTime() + 6 * 24 * 60 * 60 * 1000);
}

async function getProfile(req) {
  if (req.user?.isDemo || !supabase.isConfigured() || !req.accessToken) {
    const startedAt = new Date();
    return {
      trial_started_at: startedAt.toISOString(),
      trial_ends_at: sixDaysFrom(startedAt).toISOString(),
      subscription_status: "trial"
    };
  }

  const rows = await supabase.request(
    "profiles?select=trial_started_at,trial_ends_at,subscription_status&limit=1",
    { accessToken: req.accessToken }
  );
  return rows?.[0] || null;
}

async function checkRevenueCat(userId) {
  if (!config.revenueCatSecretApiKey || !userId || userId === "demo-user") {
    return { configured: false, active: false };
  }

  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
    {
      headers: {
        Authorization: `Bearer ${config.revenueCatSecretApiKey}`,
        "Content-Type": "application/json"
      }
    }
  );

  if (!response.ok) {
    return { configured: true, active: false };
  }

  const payload = await response.json();
  const entitlement = payload?.subscriber?.entitlements?.[config.revenueCatEntitlementId];
  if (!entitlement) return { configured: true, active: false };

  const expiresAt = entitlement.expires_date ? new Date(entitlement.expires_date) : null;
  return {
    configured: true,
    active: !expiresAt || expiresAt.getTime() > Date.now(),
    expiresAt: expiresAt?.toISOString() || null
  };
}

async function getAccessStatus(req) {
  if (simulatedPremiumUsers.has(req.user.id)) {
    return {
      access: true,
      source: "simulated",
      status: "premium",
      entitlement: config.revenueCatEntitlementId
    };
  }

  const revenueCat = await checkRevenueCat(req.user.id);
  if (revenueCat.active) {
    return {
      access: true,
      source: "revenuecat",
      status: "premium",
      entitlement: config.revenueCatEntitlementId,
      expiresAt: revenueCat.expiresAt
    };
  }

  const profile = await getProfile(req);
  const trialEndsAt = profile?.trial_ends_at ? new Date(profile.trial_ends_at) : null;
  const trialActive = Boolean(trialEndsAt && trialEndsAt.getTime() > Date.now());

  return {
    access: trialActive,
    source: trialActive ? "trial" : "none",
    status: trialActive ? "trial" : "expired",
    trialEndsAt: trialEndsAt?.toISOString() || null,
    revenueCatConfigured: revenueCat.configured
  };
}

function simulatePurchase(req, active = true) {
  if (!config.allowSimulatedPurchases) {
    throw new Error("Simulated purchases are disabled on this server.");
  }
  if (active) simulatedPremiumUsers.add(req.user.id);
  else simulatedPremiumUsers.delete(req.user.id);
  return { active };
}

module.exports = {
  getAccessStatus,
  simulatePurchase
};
