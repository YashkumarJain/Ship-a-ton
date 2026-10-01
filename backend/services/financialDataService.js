const { defaultFinancialData } = require("../financialContext");
const supabase = require("./supabaseRest");
const { demoTransactions } = require("./statementService");
const { getProfile } = require("./profileService");

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function toCamelProfile(row = {}) {
  return {
    monthlyBudget: Number(row.monthly_budget || 0),
    savingsBalance: Number(row.savings_balance || 0),
    savingsGoal: Number(row.savings_goal || 0)
  };
}

async function loadFinancialData(req) {
  if (req.user?.isDemo || !supabase.isConfigured() || !req.accessToken) {
    const imported = demoTransactions(req.user?.id || "demo-user");
    if (imported.length) {
      const profile = await getProfile(req);
      return {
        user: {
          monthlyBudget: Number(profile.monthlyBudget || 0),
          savingsBalance: Number(profile.savingsBalance || 0),
          savingsGoal: Number(profile.savingsGoal || 0)
        },
        transactions: imported.map((row) => ({
          id: row.id,
          date: row.date,
          merchant: row.merchant,
          category: row.category,
          amount: Number(row.amount),
          type: row.type
        })),
        upcomingBills: []
      };
    }
    return clone(defaultFinancialData);
  }

  const [profiles, transactions, bills] = await Promise.all([
    supabase.request("profiles?select=monthly_budget,savings_balance,savings_goal&limit=1", {
      accessToken: req.accessToken
    }),
    supabase.request("transactions?select=id,date,merchant,category,amount,type&order=date.asc", {
      accessToken: req.accessToken
    }),
    supabase.request("upcoming_bills?select=id,due_date,merchant,category,amount&order=due_date.asc", {
      accessToken: req.accessToken
    })
  ]);

  const profile = profiles?.[0] || {};

  return {
    user: toCamelProfile(profile),
    transactions: (transactions || []).map((row) => ({
      id: row.id,
      date: row.date,
      merchant: row.merchant,
      category: row.category,
      amount: Number(row.amount),
      type: row.type
    })),
    upcomingBills: (bills || []).map((row) => ({
      id: row.id,
      dueDate: row.due_date,
      merchant: row.merchant,
      category: row.category,
      amount: Number(row.amount)
    }))
  };
}

async function seedDemoData(req) {
  if (req.user?.isDemo || !supabase.isConfigured() || !req.accessToken) {
    return { seeded: false, reason: "Demo/local mode already uses bundled data." };
  }

  const data = clone(defaultFinancialData);

  await supabase.request("profiles?on_conflict=user_id", {
    accessToken: req.accessToken,
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
    body: [{
      user_id: req.user.id,
      monthly_budget: data.user.monthlyBudget,
      savings_balance: data.user.savingsBalance,
      savings_goal: data.user.savingsGoal
    }]
  });

  if (data.transactions.length) {
    await supabase.request("transactions", {
      accessToken: req.accessToken,
      method: "POST",
      headers: { Prefer: "return=minimal" },
      body: data.transactions.map(({ id, ...transaction }) => ({
        user_id: req.user.id,
        ...transaction,
        source: "demo"
      }))
    });
  }

  if (data.upcomingBills?.length) {
    await supabase.request("upcoming_bills", {
      accessToken: req.accessToken,
      method: "POST",
      headers: { Prefer: "return=minimal" },
      body: data.upcomingBills.map(({ id, dueDate, ...bill }) => ({
        user_id: req.user.id,
        due_date: dueDate,
        ...bill
      }))
    });
  }

  return { seeded: true };
}

module.exports = {
  loadFinancialData,
  seedDemoData
};
