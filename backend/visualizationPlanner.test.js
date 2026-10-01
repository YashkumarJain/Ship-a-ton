const assert = require("node:assert/strict");
const { planVisualization, chooseIntent } = require("./services/visualizationPlanner");

const tools = [
  {
    name: "detect_spending_changes",
    result: {
      previousTotal: 1000,
      currentTotal: 1200,
      totalChange: 200,
      significantChanges: [{ category: "Dining", change: 200, currentAmount: 400 }]
    }
  },
  {
    name: "get_spending_by_category",
    result: [
      { category: "Rent", amount: 1500 },
      { category: "Dining", amount: 400 }
    ]
  },
  {
    name: "compare_periods",
    result: {
      categoryChanges: [
        { category: "Dining", previousAmount: 200, currentAmount: 400 }
      ]
    }
  },
  {
    name: "calculate_budget_remaining",
    result: { spentSoFar: 2200, upcomingBillsTotal: 300, safeRemaining: 700 }
  }
];

assert.equal(chooseIntent("Where did my money go by category?", new Map(tools.map((x) => [x.name, x.result]))), "get_spending_by_category");
assert.equal(planVisualization(tools, "Where did my money go by category?").type, "donut");
assert.equal(planVisualization(tools, "Why did my spending increase?").type, "change_bar");
assert.equal(planVisualization(tools, "Compare this month versus last month").type, "comparison_bar");
assert.equal(planVisualization(tools, "How much is safe to spend from my remaining budget?").title, "Budget position");

console.log("visualization planner test passed");
