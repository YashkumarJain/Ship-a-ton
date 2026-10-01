const {
  getTransactions,
  getSpendingByCategory,
  getSpendingForPeriod,
  comparePeriods,
  findLargestTransactions,
  findRecurringExpenses,
  detectSpendingChanges,
  calculateBudgetRemaining,
  projectMonthlySpending,
  calculateSavingsCapacity,
  simulateSavingsGoal,
  calculateCashFlow
} = require("./financialIntelligence");


function executeFinancialTool(name, args = {}) {

  switch (name) {

    case "get_transactions":
      return getTransactions(args);


    case "get_spending_by_category":
      return getSpendingByCategory(args);


    case "get_spending_for_period":
      return getSpendingForPeriod(args);


    case "compare_periods":
      return comparePeriods(
        args.periodA,
        args.periodB
      );


    case "find_largest_transactions":
      return findLargestTransactions(args);


    case "find_recurring_expenses":
      return findRecurringExpenses(args);


    case "detect_spending_changes":
      return detectSpendingChanges(
        args.previousPeriod,
        args.currentPeriod,
        {
          minDollarChange:
            args.minDollarChange ?? 25,

          minPercentChange:
            args.minPercentChange ?? 10
        }
      );


    case "calculate_budget_remaining":
      return calculateBudgetRemaining(args);


    case "project_monthly_spending":
      return projectMonthlySpending(args);


    case "calculate_savings_capacity":
      return calculateSavingsCapacity(args);


    case "simulate_savings_goal":
      return simulateSavingsGoal(args);


    case "calculate_cash_flow":
      return calculateCashFlow(args);


    default:
      throw new Error(
        `Unknown financial tool: ${name}`
      );
  }
}


module.exports = {
  executeFinancialTool
};