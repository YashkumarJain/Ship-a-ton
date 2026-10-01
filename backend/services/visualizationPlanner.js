function money(value) {
  return Number(Number(value || 0).toFixed(2));
}

function toolMap(toolsUsed = []) {
  const map = new Map();
  for (const tool of toolsUsed) {
    if (tool?.name && tool.result !== undefined && !map.has(tool.name)) {
      map.set(tool.name, tool.result);
    }
  }
  return map;
}

function seriesFromChanges(changes = []) {
  return changes
    .filter((item) => Number(item.change || 0) !== 0)
    .slice(0, 7)
    .map((item) => ({
      label: item.category,
      value: money(item.change),
      secondaryValue: money(item.currentAmount),
      direction: item.change > 0 ? "up" : "down"
    }));
}

function spendingChanges(result) {
  const data = seriesFromChanges(result.significantChanges || result.allChanges || []);
  return data.length
    ? {
        type: "change_bar",
        title: "What changed",
        subtitle: "Category contribution to the spending change",
        series: data,
        highlightSequence: data.map((item) => item.label),
        meta: {
          previousTotal: money(result.previousTotal),
          currentTotal: money(result.currentTotal),
          totalChange: money(result.totalChange)
        }
      }
    : null;
}

function periodComparison(result) {
  const data = (result.categoryChanges || [])
    .filter((item) => Number(item.previousAmount || 0) !== 0 || Number(item.currentAmount || 0) !== 0)
    .slice(0, 7)
    .map((item) => ({
      label: item.category,
      value: money(item.previousAmount),
      secondaryValue: money(item.currentAmount)
    }));
  if (!data.length) return null;
  return {
    type: "comparison_bar",
    title: "Period comparison",
    subtitle: "Previous period vs current period",
    series: data,
    highlightSequence: data.map((item) => item.label)
  };
}

function categoryExcluded(message = "", category = "") {
  const q = String(message).toLowerCase();
  const name = String(category).trim().toLowerCase();

  if (!q || !name) return false;

  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

  const patterns = [
    // except rent / except for rent
    new RegExp(`\\bexcept(?:\\s+for)?\\s+${escaped}\\b`, "i"),

    // excluding rent
    new RegExp(`\\bexcluding\\s+${escaped}\\b`, "i"),

    // exclude rent
    new RegExp(`\\bexclude\\s+${escaped}\\b`, "i"),

    // without rent
    new RegExp(`\\bwithout\\s+${escaped}\\b`, "i"),

    // non-rent / non rent
    new RegExp(`\\bnon[-\\s]+${escaped}\\b`, "i"),

    // other than rent
    new RegExp(`\\bother\\s+than\\s+${escaped}\\b`, "i"),

    // anything but rent / anything except rent
    new RegExp(`\\banything\\s+(?:but|except)\\s+${escaped}\\b`, "i"),

    // everything but rent / everything except rent
    new RegExp(`\\beverything\\s+(?:but|except)\\s+${escaped}\\b`, "i")
  ];

  return patterns.some((pattern) => pattern.test(q));
}

function categoryBreakdown(result, userMessage = "") {
  const data = (Array.isArray(result) ? result : [])
    .filter(
      (item) =>
        !categoryExcluded(
          userMessage,
          item.category
        )
    )
    .slice(0, 8)
    .map((item) => ({
      label: item.category,
      value: money(item.amount)
    }));

  if (!data.length) return null;

  return {
    type: "donut",
    title: "Spending by category",
    series: data,
    highlightSequence: data.map(
      (item) => item.label
    )
  };
}

function largestTransactions(result) {
  const data = (result.largestTransactions || []).slice(0, 7).map((item, index) => ({
    label: item.category || `Purchase ${index + 1}`,
    value: money(item.amount),
    category: item.category
  }));
  if (!data.length) return null;
  return {
    type: "bar",
    title: "Largest purchases",
    series: data,
    highlightSequence: data.map((item) => item.label)
  };
}

function recurringExpenses(result) {
  const data = (result.recurringExpenses || []).slice(0, 7).map((item) => ({
    label: item.category || "Recurring",
    value: money(item.averageAmount),
    category: item.category
  }));
  if (!data.length) return null;
  return {
    type: "bar",
    title: "Recurring monthly costs",
    subtitle: "Average recurring charge by detected item",
    series: data,
    highlightSequence: data.map((item) => item.label)
  };
}

function monthlyProjection(result) {
  return {
    type: "progress",
    title: "Projected month-end spending",
    series: [
      { label: "Projected", value: money(result.projectedTotal) },
      { label: "Budget", value: money(result.budget) }
    ],
    highlightSequence: ["Projected", "Budget"],
    meta: { projectedOverBudget: Boolean(result.projectedOverBudget) }
  };
}

function budgetRemaining(result) {
  return {
    type: "bar",
    title: "Budget position",
    series: [
      { label: "Spent", value: money(result.spentSoFar) },
      { label: "Bills", value: money(result.upcomingBillsTotal) },
      { label: "Safe left", value: money(result.safeRemaining) }
    ],
    highlightSequence: ["Spent", "Bills", "Safe left"]
  };
}

function savingsGoal(result) {
  return {
    type: "goal",
    title: "Savings goal path",
    series: [
      { label: "Current", value: money(result.currentSavings) },
      { label: "Projected", value: money(result.projectedSavingsAtDeadline) },
      { label: "Goal", value: money(result.targetSavingsBalance) }
    ],
    highlightSequence: ["Current", "Projected", "Goal"],
    meta: {
      achievableAtCurrentPace: Boolean(result.achievableAtCurrentPace),
      monthlyGap: money(result.monthlySavingsGap)
    }
  };
}

function savingsCapacity(result) {
  return {
    type: "bar",
    title: "Savings capacity",
    series: [
      { label: "Income", value: money(result.totalIncome) },
      { label: "Projected expenses", value: money(result.projectedExpenses) },
      { label: "Can save", value: money(result.savingsCapacity) }
    ],
    highlightSequence: ["Income", "Projected expenses", "Can save"]
  };
}

function cashFlow(result) {
  return {
    type: "cash_flow",
    title: "Cash flow",
    series: [
      { label: "Income", value: money(result.totalIncome) },
      { label: "Expenses", value: money(result.totalExpenses) },
      { label: "Net", value: money(result.netCashFlow) }
    ],
    highlightSequence: ["Income", "Expenses", "Net"]
  };
}

function periodSpend(result) {
  return {
    type: "bar",
    title: "Spending total",
    series: [{ label: "Spent", value: money(result.total) }],
    highlightSequence: ["Spent"]
  };
}

function chooseIntent(message = "", available) {
  const q = String(message).toLowerCase();
  const has = (name) => available.has(name);

  if (/(goal|target|save .* by|reach .* savings|vacation|trip)/.test(q) && has("simulate_savings_goal")) {
    return "simulate_savings_goal";
  }
  if (/(safe to spend|budget remaining|left in .*budget|remaining budget|how much .*left)/.test(q) && has("calculate_budget_remaining")) {
    return "calculate_budget_remaining";
  }
  if (/(project|forecast|month[- ]end|end of (the )?month|on track)/.test(q) && has("project_monthly_spending")) {
    return "project_monthly_spending";
  }
  if (/(cash flow|income vs|income versus|income and expenses|net cash)/.test(q) && has("calculate_cash_flow")) {
    return "calculate_cash_flow";
  }
  if (/(saving capacity|how much can i save|can i save)/.test(q) && has("calculate_savings_capacity")) {
    return "calculate_savings_capacity";
  }
  if (/(recurring|subscription|monthly charges|fixed costs)/.test(q) && has("find_recurring_expenses")) {
    return "find_recurring_expenses";
  }
  if (/(why|what changed|increase|increased|decrease|decreased|change lately|went up|went down)/.test(q) && has("detect_spending_changes")) {
    return "detect_spending_changes";
  }
  if (/(compare| vs\b| versus |last month|previous month)/.test(q) && has("compare_periods")) {
    return "compare_periods";
  }
  if (/(category|categories|breakdown|where .*money|where .*spend|spending mix)/.test(q) && has("get_spending_by_category")) {
    return "get_spending_by_category";
  }
  if (/(largest|biggest|large purchase|big purchase|top purchase|expensive)/.test(q) && has("find_largest_transactions")) {
    return "find_largest_transactions";
  }
  if (/(how much .*spend|how much .*spent|total spending|spending total)/.test(q) && has("get_spending_for_period")) {
    return "get_spending_for_period";
  }

  const fallback = [
    "simulate_savings_goal",
    "calculate_budget_remaining",
    "project_monthly_spending",
    "calculate_savings_capacity",
    "calculate_cash_flow",
    "detect_spending_changes",
    "compare_periods",
    "get_spending_by_category",
    "find_largest_transactions",
    "find_recurring_expenses",
    "get_spending_for_period"
  ];
  return fallback.find(has) || null;
}

function planVisualization(toolsUsed = [], userMessage = "") {
  const available = toolMap(toolsUsed);
  const intent = chooseIntent(userMessage, available);
  const result = intent ? available.get(intent) : null;
  if (!intent || result == null) return null;

  switch (intent) {
    case "detect_spending_changes":
      return spendingChanges(result);
    case "compare_periods":
      return periodComparison(result);
   case "get_spending_by_category":
  return categoryBreakdown(
    result,
    userMessage
  );
    case "find_largest_transactions":
      return largestTransactions(result);
    case "find_recurring_expenses":
      return recurringExpenses(result);
    case "project_monthly_spending":
      return monthlyProjection(result);
    case "calculate_budget_remaining":
      return budgetRemaining(result);
    case "simulate_savings_goal":
      return savingsGoal(result);
    case "calculate_savings_capacity":
      return savingsCapacity(result);
    case "calculate_cash_flow":
      return cashFlow(result);
    case "get_spending_for_period":
      return periodSpend(result);
    default:
      return null;
  }
}

module.exports = { planVisualization, chooseIntent };
