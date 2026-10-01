function dollars(value) {
  return Number(Number(value || 0).toFixed(2));
}

function buildSuggestedActions(toolsUsed = [], userMessage = "") {
  const lower = userMessage.toLowerCase();
  const vacationIntent = /vacation|holiday|trip|travel plan|honeymoon/.test(lower);
  const actions = [];

  const changes = toolsUsed.find((tool) => tool.name === "detect_spending_changes")?.result;
  if (changes?.increases?.length) {
    const discretionary = changes.increases
      .filter((item) => !["Rent", "Utilities", "Insurance"].includes(item.category))
      .slice(0, 3);
    for (const item of discretionary) {
      const targetReduction = Math.max(0, item.currentAmount - item.previousAmount);
      if (targetReduction > 0) {
        actions.push({
          title: `Reset ${item.category} toward its previous level`,
          monthlyImpact: dollars(targetReduction),
          reason: `${item.category} increased by $${dollars(item.change)} in the compared period.`
        });
      }
    }
  }

  const recurring = toolsUsed.find((tool) => tool.name === "find_recurring_expenses")?.result;
  if (recurring?.recurringExpenses?.length) {
    const subscriptions = recurring.recurringExpenses
      .filter((item) => String(item.category).toLowerCase().includes("subscription"))
      .slice(0, 3);
    const amount = subscriptions.reduce((sum, item) => sum + Number(item.averageAmount || 0), 0);
    if (amount > 0) {
      actions.push({
        title: "Review recurring subscriptions",
        monthlyImpact: dollars(amount),
        reason: "Only cancel services you no longer use; this amount is the recurring spend identified, not guaranteed savings."
      });
    }
  }

  const goal = toolsUsed.find((tool) => tool.name === "simulate_savings_goal")?.result;
  if (goal && goal.monthlySavingsGap > 0) {
    actions.unshift({
      title: vacationIntent ? "Close the monthly vacation-goal gap" : "Close the monthly savings gap",
      monthlyImpact: dollars(goal.monthlySavingsGap),
      reason: `The current analysis shows a monthly savings gap of $${dollars(goal.monthlySavingsGap)}.`
    });
  }

  return {
    goalType: vacationIntent ? "vacation" : "general_savings",
    actions: actions.slice(0, 4),
    disclaimer: "These are planning scenarios based on recorded data and assumptions, not guaranteed outcomes."
  };
}

module.exports = { buildSuggestedActions };
