const config = require("../config");

async function resolveUserFromToken(accessToken) {
  if (!config.supabaseUrl || !config.supabaseAnonKey) {
    return null;
  }

  const response = await fetch(`${config.supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: config.supabaseAnonKey,
      Authorization: `Bearer ${accessToken}`
    }
  });

  if (!response.ok) {
    return null;
  }

  return response.json();
}

async function requireAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization || "";
    const accessToken = authHeader.startsWith("Bearer ")
      ? authHeader.slice(7).trim()
      : "";

    if (accessToken) {
      const user = await resolveUserFromToken(accessToken);
      if (user?.id) {
        req.user = user;
        req.accessToken = accessToken;
        return next();
      }
    }

    if (config.allowDemoMode) {
      req.user = {
        id: "demo-user",
        email: "demo@local.invalid",
        isDemo: true
      };
      req.accessToken = null;
      return next();
    }

    return res.status(401).json({
      error: "Authentication required."
    });
  } catch (error) {
    console.error("Authentication error:", error);
    return res.status(401).json({
      error: "Could not verify authentication."
    });
  }
}

module.exports = {
  requireAuth,
  resolveUserFromToken
};
