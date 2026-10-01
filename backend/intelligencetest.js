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


console.log("\n=== SEPTEMBER EXPENSES ===");

const septemberExpenses = getTransactions({
  startDate: "2026-09-01",
  endDate: "2026-09-30",
  type: "expense"
});

console.table(septemberExpenses);


console.log("\n=== LARGE EXPENSES $500+ ===");

const largeExpenses = getTransactions({
  type: "expense",
  minAmount: 500
});

console.table(largeExpenses);


console.log("\n=== SHOPPING JULY-SEPTEMBER OVER $400 ===");

const largeShopping = getTransactions({
  startDate: "2026-07-01",
  endDate: "2026-09-30",
  category: "Shopping",
  type: "expense",
  minAmount: 400
});

console.table(largeShopping);

console.log("\n=== SEPTEMBER SPENDING BY CATEGORY ===");

const septemberCategories = getSpendingByCategory({
  startDate: "2026-09-01",
  endDate: "2026-09-30"
});

console.table(septemberCategories);


console.log("\n=== JUNE-AUGUST SPENDING BY CATEGORY ===");

const summerCategories = getSpendingByCategory({
  startDate: "2026-06-01",
  endDate: "2026-08-31"
});

console.table(summerCategories);

console.log("\n=== JULY TOTAL SPENDING ===");

const julySpending = getSpendingForPeriod({
  startDate: "2026-07-01",
  endDate: "2026-07-31"
});

console.log({
  total: julySpending.total,
  transactionCount: julySpending.transactionCount
});


console.log("\n=== AUGUST TOTAL SPENDING ===");

const augustSpending = getSpendingForPeriod({
  startDate: "2026-08-01",
  endDate: "2026-08-31"
});

console.log({
  total: augustSpending.total,
  transactionCount: augustSpending.transactionCount
});


console.log("\n=== SEPTEMBER TOTAL SPENDING ===");

const septemberSpending = getSpendingForPeriod({
  startDate: "2026-09-01",
  endDate: "2026-09-30"
});

console.log({
  total: septemberSpending.total,
  transactionCount: septemberSpending.transactionCount
});

console.log("\n=== JULY VS AUGUST COMPARISON ===");

const julyVsAugust = comparePeriods(
  {
    startDate: "2026-07-01",
    endDate: "2026-07-31"
  },
  {
    startDate: "2026-08-01",
    endDate: "2026-08-31"
  }
);

console.log({
  julyTotal: julyVsAugust.previousPeriod.total,
  augustTotal: julyVsAugust.currentPeriod.total,
  totalChange: julyVsAugust.totalChange,
  percentChange: julyVsAugust.totalPercentChange
});

console.log("\n=== CATEGORY CHANGES ===");

console.table(julyVsAugust.categoryChanges);

console.log(
  "\n=== BIGGEST AUGUST EXPENSES EXCLUDING RENT ==="
);

const biggestAugustExpenses =
  findLargestTransactions({
    startDate: "2026-08-01",
    endDate: "2026-08-31",
    limit: 3,
    excludeCategories: ["Rent"]
  });


console.table(
  biggestAugustExpenses.largestTransactions
);


console.log({
  totalSpending:
    biggestAugustExpenses.totalSpending,

  topThreeTotal:
    biggestAugustExpenses.largestTransactionsTotal,

  shareOfSpending:
    biggestAugustExpenses.shareOfSpending,

  transactionCount:
    biggestAugustExpenses.transactionCount
});

console.log(
  "\n=== RECURRING EXPENSES ==="
);

const recurringExpenses =
  findRecurringExpenses({
    startDate: "2026-04-01",
    endDate: "2026-09-30"
  });


console.table(
  recurringExpenses.recurringExpenses
);


console.log({
  recurringCount:
    recurringExpenses.recurringCount,

  monthlyRecurringTotal:
    recurringExpenses.monthlyRecurringTotal,

  estimatedAnnualCost:
    recurringExpenses.estimatedAnnualCost
});

console.log(
  "\n=== DETECT JULY TO AUGUST SPENDING CHANGES ==="
);

const spendingChanges = detectSpendingChanges(
  {
    startDate: "2026-07-01",
    endDate: "2026-07-31"
  },
  {
    startDate: "2026-08-01",
    endDate: "2026-08-31"
  }
);


console.log({
  previousTotal:
    spendingChanges.previousTotal,

  currentTotal:
    spendingChanges.currentTotal,

  totalChange:
    spendingChanges.totalChange,

  totalPercentChange:
    spendingChanges.totalPercentChange,

  spendingDirection:
    spendingChanges.spendingDirection
});


console.log("\n=== BIGGEST INCREASE ===");

console.log(
  spendingChanges.biggestIncrease
);


console.log("\n=== SIGNIFICANT CHANGES ===");

console.table(
  spendingChanges.significantChanges
);

console.log(
  "\n=== SEPTEMBER BUDGET REMAINING ==="
);

const septemberBudget =
  calculateBudgetRemaining({
    startDate: "2026-09-01",
    endDate: "2026-09-30"
  });


console.log({
  budget:
    septemberBudget.budget,

  spentSoFar:
    septemberBudget.spentSoFar,

  upcomingBillsTotal:
    septemberBudget.upcomingBillsTotal,

  remainingBeforeBills:
    septemberBudget.remainingBeforeBills,

  safeRemaining:
    septemberBudget.safeRemaining,

  budgetUsedPercent:
    septemberBudget.budgetUsedPercent,

  safeRemainingPercent:
    septemberBudget.safeRemainingPercent,

  overBudget:
    septemberBudget.overBudget
});


console.log("\n=== UPCOMING BILLS ===");

console.table(
  septemberBudget.upcomingBills
);

console.log(
  "\n=== SEPTEMBER MONTH-END PROJECTION ==="
);

const septemberProjection =
  projectMonthlySpending({
    startDate: "2026-09-01",
    endDate: "2026-09-30",
    asOfDate: "2026-09-16"
  });


console.log({
  asOfDate:
    septemberProjection.asOfDate,

  daysElapsed:
    septemberProjection.daysElapsed,

  daysRemaining:
    septemberProjection.daysRemaining,

  fixedSpent:
    septemberProjection.fixedSpent,

  variableSpent:
    septemberProjection.variableSpent,

  variableDailyAverage:
    septemberProjection.variableDailyAverage,

  projectedFutureVariableSpending:
    septemberProjection.projectedFutureVariableSpending,

  futureBillsTotal:
    septemberProjection.futureBillsTotal,

  projectedTotal:
    septemberProjection.projectedTotal,

  budget:
    septemberProjection.budget,

  projectedBudgetDifference:
    septemberProjection.projectedBudgetDifference,

  projectedOverBudget:
    septemberProjection.projectedOverBudget
});


console.log("\n=== FUTURE BILLS ===");

console.table(
  septemberProjection.futureBills
);

console.log(
  "\n=== SEPTEMBER SAVINGS CAPACITY ==="
);

const septemberSavings =
  calculateSavingsCapacity({
    startDate: "2026-09-01",
    endDate: "2026-09-30",
    asOfDate: "2026-09-16"
  });


console.log({
  totalIncome:
    septemberSavings.totalIncome,

  projectedExpenses:
    septemberSavings.projectedExpenses,

  projectedSurplus:
    septemberSavings.projectedSurplus,

  savingsCapacity:
    septemberSavings.savingsCapacity,

  savingsRatePercent:
    septemberSavings.savingsRatePercent,

  canSave:
    septemberSavings.canSave,

  deficit:
    septemberSavings.deficit
});

console.log(
  "\n=== SAVINGS GOAL SIMULATION ==="
);

const tripGoal =
  simulateSavingsGoal({
    targetSavingsBalance: 4000,
    months: 6,
    startDate: "2026-09-01",
    endDate: "2026-09-30",
    asOfDate: "2026-09-16"
  });


console.log({
  currentSavings:
    tripGoal.currentSavings,

  targetSavingsBalance:
    tripGoal.targetSavingsBalance,

  amountStillNeeded:
    tripGoal.amountStillNeeded,

  months:
    tripGoal.months,

  requiredMonthlySavings:
    tripGoal.requiredMonthlySavings,

  currentMonthlyCapacity:
    tripGoal.currentMonthlyCapacity,

  projectedMonthlySurplus:
    tripGoal.projectedMonthlySurplus,

  projectedSavingsAtDeadline:
    tripGoal.projectedSavingsAtDeadline,

  goalShortfall:
    tripGoal.goalShortfall,

  monthlySavingsGap:
    tripGoal.monthlySavingsGap,

  requiredMonthlySpendingReduction:
    tripGoal.requiredMonthlySpendingReduction,

  achievableAtCurrentPace:
    tripGoal.achievableAtCurrentPace
});

console.log(
  "\n=== SEPTEMBER CASH FLOW ==="
);

const septemberCashFlow =
  calculateCashFlow({
    startDate: "2026-09-01",
    endDate: "2026-09-30",
    includeUpcomingBills: true
  });


console.log({
  totalIncome:
    septemberCashFlow.totalIncome,

  totalExpenses:
    septemberCashFlow.totalExpenses,

  upcomingBillsTotal:
    septemberCashFlow.upcomingBillsTotal,

  netCashFlow:
    septemberCashFlow.netCashFlow,

  expenseToIncomePercent:
    septemberCashFlow.expenseToIncomePercent,

  netCashFlowPercent:
    septemberCashFlow.netCashFlowPercent,

  cashFlowStatus:
    septemberCashFlow.cashFlowStatus
});


console.log("\n=== CASH FLOW UPCOMING BILLS ===");

console.table(
  septemberCashFlow.upcomingBills
);