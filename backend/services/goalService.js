const crypto = require("node:crypto");
const supabase = require("./supabaseRest");

const demoGoals = new Map();

function cleanGoal(row = {}) {
  return {
    id: row.id,
    name: row.name,
    goalType: row.goal_type || "savings",
    targetAmount: Number(row.target_amount || 0),
    targetDate: row.target_date || null,
    isActive: row.is_active !== false,
    createdAt: row.created_at || null
  };
}

function validateGoal(input = {}) {
  const name = String(input.name || input.goalName || "").trim().slice(0, 80);
  const goalType = String(input.goalType || "savings").trim().slice(0, 40) || "savings";
  const targetAmount = Number(input.targetAmount);
  const targetDate = input.targetDate ? String(input.targetDate) : null;
  if (!name) throw new Error("Goal name is required.");
  if (!Number.isFinite(targetAmount) || targetAmount < 0) throw new Error("Target amount must be zero or greater.");
  if (targetDate && !/^\d{4}-\d{2}-\d{2}$/.test(targetDate)) throw new Error("Target date must use YYYY-MM-DD.");
  return { name, goal_type: goalType, target_amount: targetAmount, target_date: targetDate, is_active: true };
}

async function listGoals(req) {
  if (req.user?.isDemo || !supabase.isConfigured() || !req.accessToken) {
    return (demoGoals.get(req.user.id) || []).map(cleanGoal);
  }
  const rows = await supabase.request("financial_goals?select=id,name,goal_type,target_amount,target_date,is_active,created_at&order=created_at.desc", {
    accessToken: req.accessToken
  });
  return (rows || []).map(cleanGoal);
}

async function createGoal(req, input) {
  const goal = validateGoal(input);
  if (req.user?.isDemo || !supabase.isConfigured() || !req.accessToken) {
    const list = demoGoals.get(req.user.id) || [];
    const row = { id: crypto.randomUUID(), ...goal, created_at: new Date().toISOString() };
    list.unshift(row);
    demoGoals.set(req.user.id, list);
    return cleanGoal(row);
  }
  const rows = await supabase.request("financial_goals", {
    accessToken: req.accessToken,
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: [{ user_id: req.user.id, ...goal }]
  });
  return cleanGoal(rows?.[0] || goal);
}

async function updateGoal(req, id, input) {
  const goal = validateGoal(input);
  if (req.user?.isDemo || !supabase.isConfigured() || !req.accessToken) {
    const list = demoGoals.get(req.user.id) || [];
    const index = list.findIndex((item) => item.id === id);
    if (index < 0) throw new Error("Goal not found.");
    list[index] = { ...list[index], ...goal };
    demoGoals.set(req.user.id, list);
    return cleanGoal(list[index]);
  }
  const rows = await supabase.request(`financial_goals?id=eq.${encodeURIComponent(id)}`, {
    accessToken: req.accessToken,
    method: "PATCH",
    headers: { Prefer: "return=representation" },
    body: goal
  });
  if (!rows?.length) throw new Error("Goal not found.");
  return cleanGoal(rows[0]);
}

async function deleteGoal(req, id) {
  if (req.user?.isDemo || !supabase.isConfigured() || !req.accessToken) {
    const list = demoGoals.get(req.user.id) || [];
    demoGoals.set(req.user.id, list.filter((item) => item.id !== id));
    return { deleted: true };
  }
  await supabase.request(`financial_goals?id=eq.${encodeURIComponent(id)}`, {
    accessToken: req.accessToken,
    method: "DELETE",
    headers: { Prefer: "return=minimal" }
  });
  return { deleted: true };
}

async function resolveProposal(req, proposal) {
  if (!proposal || typeof proposal !== "object") return null;
  const action = ["create", "update", "delete"].includes(proposal.action) ? proposal.action : "create";
  const goals = await listGoals(req);
  const requestedName = String(proposal.goalName || "").trim();
  let match = goals.find((goal) => goal.name.toLowerCase() === requestedName.toLowerCase());
  if (!match && proposal.goalType) {
    const sameType = goals.filter((goal) => goal.goalType === String(proposal.goalType));
    if (sameType.length === 1) match = sameType[0];
  }
  return {
    action,
    goalId: action === "create" ? null : match?.id || null,
    goalName: requestedName,
    goalType: String(proposal.goalType || match?.goalType || "savings"),
    targetAmount: Number(proposal.targetAmount ?? match?.targetAmount ?? 0),
    targetDate: proposal.targetDate || match?.targetDate || null,
    requiresApproval: true,
    canApply: action === "create" || Boolean(match)
  };
}

async function applyApprovedProposal(req, proposal) {
  if (proposal?.approved !== true) throw new Error("Human approval is required before changing a goal.");
  const action = proposal.action;
  if (action === "create") {
    return { action, goal: await createGoal(req, proposal) };
  }
  if (!proposal.goalId) throw new Error("The goal to change could not be identified.");
  if (action === "update") {
    return { action, goal: await updateGoal(req, proposal.goalId, proposal) };
  }
  if (action === "delete") {
    await deleteGoal(req, proposal.goalId);
    return { action, deleted: true };
  }
  throw new Error("Unsupported goal action.");
}

module.exports = {
  listGoals,
  createGoal,
  updateGoal,
  deleteGoal,
  resolveProposal,
  applyApprovedProposal
};
