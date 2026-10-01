const config = require("../config");

function isConfigured() {
  return Boolean(config.supabaseUrl && config.supabaseAnonKey);
}

async function request(path, { accessToken, method = "GET", body, headers = {} } = {}) {
  if (!isConfigured()) {
    throw new Error("Supabase is not configured");
  }

  const response = await fetch(`${config.supabaseUrl}/rest/v1/${path}`, {
    method,
    headers: {
      apikey: config.supabaseAnonKey,
      Authorization: `Bearer ${accessToken || config.supabaseAnonKey}`,
      "Content-Type": "application/json",
      ...headers
    },
    body: body === undefined ? undefined : JSON.stringify(body)
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Supabase ${method} ${path} failed (${response.status}): ${text}`);
  }

  if (response.status === 204) return null;
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

module.exports = {
  isConfigured,
  request
};
