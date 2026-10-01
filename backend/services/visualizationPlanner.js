function money(value) {
  return Number(Number(value || 0).toFixed(2));
}

function seriesFromChanges(changes = []) {
  return changes
    .filter((item) => item.change !== 0)
    .slice(0, 7)
    .map((item) => ({
      label: item.category,
      value: money(item.change),
      secondaryValue: money(item.currentAmount),
      direction: item.change > 0 ? "up" : "down"
    }));
}

function planVisualization(toolsUsed = []) {
  const find = (name) => toolsUsed.find((tool) => tool.name === name && tool.result);

  const changes = find("detect_spending_changes");
  if (changes) {
    const data = seriesFromChanges(changes.result.significantChanges || changes.result.allChanges);
    return {
      type: "change_bar",
      title: "What changed",
      subtitle: "Category contribution to the spending change",
      series: data,
      highlightSequence: data.map((item) => item.label),
      meta: {
        previousTotal: money(changes.result.previousTotal),
        currentTotal: money(changes.result.currentTotal),
        totalChange: money(changes.result.totalChange)
      }
    };
  }

const largest = find("find_largest_transactions");
if (largest) {
  const data = (largest.result.largestTransactions || []).map(
    (item, index) => ({
      label: item.category || `Purchase ${index + 1}`,
      value: money(item.amount),
      category: item.category
    })
  );

  return {
    type: "bar",
    title: "Largest purchases",
    series: data,
    highlightSequence: data.map((item) => item.label)
  };
}

  const categories = find("get_spending_by_category");
  if (categories) {
    const data = (categories.result || []).slice(0, 8).map((item) => ({
      label: item.category,
      value: money(item.amount)
    }));
    return {
      type: "donut",
      title: "Spending by category",
      series: data,
      highlightSequence: data.map((item) => item.label)
    };
  }

  const comparison = find("compare_periods");
  if (comparison) {
    const data = (comparison.result.categoryChanges || []).slice(0, 7).map((item) => ({
      label: item.category,
      value: money(item.previousAmount),
      secondaryValue: money(item.currentAmount)
    }));
    return {
      type: "comparison_bar",
      title: "Period comparison",
      series: data,
      highlightSequence: data.map((item) => item.label)
    };
  }

  const projection = find("project_monthly_spending");
  if (projection) {
    const r = projection.result;
    return {
      type: "progress",
      title: "Projected month-end spending",
      series: [
        { label: "Projected", value: money(r.projectedTotal) },
        { label: "Budget", value: money(r.budget) }
      ],
      highlightSequence: ["Projected", "Budget"],
      meta: { projectedOverBudget: Boolean(r.projectedOverBudget) }
    };
  }

  const goal = find("simulate_savings_goal");
  if (goal) {
    const r = goal.result;
    return {
      type: "goal",
      title: "Savings goal path",
      series: [
        { label: "Current savings", value: money(r.currentSavings) },
        { label: "Projected", value: money(r.projectedSavingsAtDeadline) },
        { label: "Goal", value: money(r.targetSavingsBalance) }
      ],
      highlightSequence: ["Current savings", "Projected", "Goal"],
      meta: {
        achievableAtCurrentPace: Boolean(r.achievableAtCurrentPace),
        monthlyGap: money(r.monthlySavingsGap)
      }
    };
  }

  const cashFlow = find("calculate_cash_flow");
  if (cashFlow) {
    const r = cashFlow.result;
    return {
      type: "cash_flow",
      title: "Cash flow",
      series: [
        { label: "Income", value: money(r.totalIncome) },
        { label: "Expenses", value: money(r.totalExpenses) },
        { label: "Net", value: money(r.netCashFlow) }
      ],
      highlightSequence: ["Income", "Expenses", "Net"]
    };
  }

  

  return null;
}

module.exports = { planVisualization };
