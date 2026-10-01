const { financialData } = require("./financialContext");


function getTransactions(filters = {}) {
  const {
    startDate,
    endDate,
    category,
    type,
    merchant,
    minAmount,
    maxAmount
  } = filters;


  const results = financialData.transactions.filter((transaction) => {

    // Filter by starting date
    if (
      startDate &&
      transaction.date < startDate
    ) {
      return false;
    }


    // Filter by ending date
    if (
      endDate &&
      transaction.date > endDate
    ) {
      return false;
    }


    // Filter by category
    if (
      category &&
      transaction.category.toLowerCase() !==
        category.toLowerCase()
    ) {
      return false;
    }


    // Filter by income or expense
    if (
      type &&
      transaction.type.toLowerCase() !==
        type.toLowerCase()
    ) {
      return false;
    }


    // Filter by merchant
    if (
      merchant &&
      !transaction.merchant
        .toLowerCase()
        .includes(merchant.toLowerCase())
    ) {
      return false;
    }


    // Minimum transaction amount
    if (
      minAmount !== undefined &&
      transaction.amount < minAmount
    ) {
      return false;
    }


    // Maximum transaction amount
    if (
      maxAmount !== undefined &&
      transaction.amount > maxAmount
    ) {
      return false;
    }


    return true;
  });


  return results.sort((a, b) =>
    a.date.localeCompare(b.date)
  );
}

function getSpendingByCategory(filters = {}) {

  const transactions = getTransactions({
    ...filters,
    type: "expense"
  });

  const categories = {};

  for (const transaction of transactions) {

    const category = transaction.category;

    if (!categories[category]) {
      categories[category] = 0;
    }

    categories[category] += transaction.amount;
  }


  const results = Object.entries(categories).map(
    ([category, amount]) => ({
      category,
      amount
    })
  );


  return results.sort(
    (a, b) => b.amount - a.amount
  );
}

function getSpendingForPeriod(filters = {}) {

  const transactions = getTransactions({
    ...filters,
    type: "expense"
  });

  const total = transactions.reduce(
    (sum, transaction) => sum + transaction.amount,
    0
  );

  return {
    total,
    transactionCount: transactions.length,
    transactions
  };
}

function comparePeriods(periodA, periodB) {

  const spendingA = getSpendingForPeriod(periodA);
  const spendingB = getSpendingForPeriod(periodB);

  const categoriesA = getSpendingByCategory(periodA);
  const categoriesB = getSpendingByCategory(periodB);


  const categoryMapA = {};

  for (const item of categoriesA) {
    categoryMapA[item.category] = item.amount;
  }


  const categoryMapB = {};

  for (const item of categoriesB) {
    categoryMapB[item.category] = item.amount;
  }


  const allCategories = new Set([
    ...Object.keys(categoryMapA),
    ...Object.keys(categoryMapB)
  ]);


  const categoryChanges = [];


  for (const category of allCategories) {

    const amountA = categoryMapA[category] || 0;
    const amountB = categoryMapB[category] || 0;

    const change = amountB - amountA;

    let percentChange = null;

    if (amountA !== 0) {
      percentChange =
        ((amountB - amountA) / amountA) * 100;
    }


    categoryChanges.push({
      category,
      previousAmount: amountA,
      currentAmount: amountB,
      change,
      percentChange:
        percentChange === null
          ? null
          : Number(percentChange.toFixed(2))
    });
  }


  categoryChanges.sort(
    (a, b) =>
      Math.abs(b.change) - Math.abs(a.change)
  );


  const totalChange =
    spendingB.total - spendingA.total;


  let totalPercentChange = null;

  if (spendingA.total !== 0) {
    totalPercentChange =
      (totalChange / spendingA.total) * 100;
  }


  return {
    previousPeriod: {
      total: spendingA.total
    },

    currentPeriod: {
      total: spendingB.total
    },

    totalChange,

    totalPercentChange:
      totalPercentChange === null
        ? null
        : Number(totalPercentChange.toFixed(2)),

    categoryChanges
  };
}

function findLargestTransactions(options = {}) {

  const {
    startDate,
    endDate,
    category,
    merchant,
    minAmount,
    maxAmount,
    limit = 5,
    excludeCategories = []
  } = options;


  let transactions = getTransactions({
    startDate,
    endDate,
    category,
    merchant,
    minAmount,
    maxAmount,
    type: "expense"
  });


  // Remove categories the user wants ignored
  if (excludeCategories.length > 0) {

    const excluded = excludeCategories.map(
      (category) => category.toLowerCase()
    );

    transactions = transactions.filter(
      (transaction) =>
        !excluded.includes(
          transaction.category.toLowerCase()
        )
    );
  }


  // Sort biggest to smallest
  transactions.sort(
    (a, b) => b.amount - a.amount
  );


  const largestTransactions =
    transactions.slice(0, limit);


  const totalSpending = transactions.reduce(
    (sum, transaction) =>
      sum + transaction.amount,
    0
  );


  const largestTransactionsTotal =
    largestTransactions.reduce(
      (sum, transaction) =>
        sum + transaction.amount,
      0
    );


  const shareOfSpending =
    totalSpending === 0
      ? 0
      : (
          largestTransactionsTotal /
          totalSpending
        ) * 100;


  return {
    largestTransactions,

    totalSpending,

    largestTransactionsTotal,

    shareOfSpending:
      Number(shareOfSpending.toFixed(2)),

    transactionCount:
      transactions.length
  };
}

function findRecurringExpenses(options = {}) {

  const {
    startDate,
    endDate,
    minOccurrences = 3,
    amountTolerance = 0.10
  } = options;


  const transactions = getTransactions({
    startDate,
    endDate,
    type: "expense"
  });


  // Group transactions by merchant
  const merchantGroups = {};


  for (const transaction of transactions) {

    const merchant = transaction.merchant;

    if (!merchantGroups[merchant]) {
      merchantGroups[merchant] = [];
    }

    merchantGroups[merchant].push(transaction);
  }


  const recurringExpenses = [];


  for (const merchant in merchantGroups) {

    const merchantTransactions =
      merchantGroups[merchant];


    // Must appear several times
    if (
      merchantTransactions.length <
      minOccurrences
    ) {
      continue;
    }


    const amounts =
      merchantTransactions.map(
        (transaction) =>
          transaction.amount
      );


    const totalAmount =
      amounts.reduce(
        (sum, amount) =>
          sum + amount,
        0
      );


    const averageAmount =
      totalAmount / amounts.length;


    const minAmount =
      Math.min(...amounts);


    const maxAmount =
      Math.max(...amounts);


    // How much does the amount vary?
    const variation =
      averageAmount === 0
        ? 0
        : (maxAmount - minAmount) /
          averageAmount;


    // Skip merchants whose charges
    // change too much
    if (variation > amountTolerance) {
      continue;
    }


    const months = [
      ...new Set(
        merchantTransactions.map(
          (transaction) =>
            transaction.date.slice(0, 7)
        )
      )
    ];


    // Require charges across
    // multiple different months
    if (months.length < minOccurrences) {
      continue;
    }


    recurringExpenses.push({

      merchant,

      category:
        merchantTransactions[0].category,

      averageAmount:
        Number(
          averageAmount.toFixed(2)
        ),

      occurrences:
        merchantTransactions.length,

      months,

      firstSeen:
        merchantTransactions[0].date,

      lastSeen:
        merchantTransactions[
          merchantTransactions.length - 1
        ].date,

      amountVariationPercent:
        Number(
          (variation * 100).toFixed(2)
        )
    });
  }


  recurringExpenses.sort(
    (a, b) =>
      b.averageAmount -
      a.averageAmount
  );


  const monthlyRecurringTotal =
    recurringExpenses.reduce(
      (sum, expense) =>
        sum + expense.averageAmount,
      0
    );


  return {

    recurringExpenses,

    recurringCount:
      recurringExpenses.length,

    monthlyRecurringTotal:
      Number(
        monthlyRecurringTotal.toFixed(2)
      ),

    estimatedAnnualCost:
      Number(
        (
          monthlyRecurringTotal * 12
        ).toFixed(2)
      )
  };
}

function detectSpendingChanges(
  previousPeriod,
  currentPeriod,
  options = {}
) {

  const {
    minDollarChange = 25,
    minPercentChange = 10
  } = options;


  const comparison = comparePeriods(
    previousPeriod,
    currentPeriod
  );


  const analyzedChanges =
    comparison.categoryChanges.map(
      (item) => {

        let direction = "unchanged";


        if (
          item.previousAmount === 0 &&
          item.currentAmount > 0
        ) {
          direction = "new";
        }

        else if (
          item.previousAmount > 0 &&
          item.currentAmount === 0
        ) {
          direction = "stopped";
        }

        else if (item.change > 0) {
          direction = "increased";
        }

        else if (item.change < 0) {
          direction = "decreased";
        }


        const largeDollarChange =
          Math.abs(item.change) >=
          minDollarChange;


        const largePercentChange =
          item.percentChange !== null &&
          Math.abs(item.percentChange) >=
            minPercentChange;


        const significant =
          largeDollarChange ||
          largePercentChange;


        let contributionToNetChange = null;


        if (comparison.totalChange !== 0) {

          contributionToNetChange =
            (
              item.change /
              comparison.totalChange
            ) * 100;
        }


        return {

          category: item.category,

          previousAmount:
            item.previousAmount,

          currentAmount:
            item.currentAmount,

          change:
            item.change,

          percentChange:
            item.percentChange,

          direction,

          significant,

          contributionToNetChange:
            contributionToNetChange === null
              ? null
              : Number(
                  contributionToNetChange.toFixed(2)
                )
        };
      }
    );


  const increases =
    analyzedChanges
      .filter(
        (item) => item.change > 0
      )
      .sort(
        (a, b) => b.change - a.change
      );


  const decreases =
    analyzedChanges
      .filter(
        (item) => item.change < 0
      )
      .sort(
        (a, b) => a.change - b.change
      );


  const significantChanges =
    analyzedChanges
      .filter(
        (item) =>
          item.significant &&
          item.change !== 0
      )
      .sort(
        (a, b) =>
          Math.abs(b.change) -
          Math.abs(a.change)
      );


  return {

    previousTotal:
      comparison.previousPeriod.total,

    currentTotal:
      comparison.currentPeriod.total,

    totalChange:
      comparison.totalChange,

    totalPercentChange:
      comparison.totalPercentChange,

    spendingDirection:
      comparison.totalChange > 0
        ? "increased"
        : comparison.totalChange < 0
          ? "decreased"
          : "unchanged",

    biggestIncrease:
      increases.length > 0
        ? increases[0]
        : null,

    biggestDecrease:
      decreases.length > 0
        ? decreases[0]
        : null,

    increases,

    decreases,

    significantChanges,

    allChanges:
      analyzedChanges
  };
}

function calculateBudgetRemaining(options = {}) {

  const {
    startDate,
    endDate,
    budget = financialData.user.monthlyBudget,
    includeUpcomingBills = true
  } = options;


  const spending =
    getSpendingForPeriod({
      startDate,
      endDate
    });


  let upcomingBills = [];


  if (includeUpcomingBills) {

    upcomingBills =
      financialData.upcomingBills.filter(
        (bill) => {

          if (
            startDate &&
            bill.dueDate < startDate
          ) {
            return false;
          }

          if (
            endDate &&
            bill.dueDate > endDate
          ) {
            return false;
          }

          return true;
        }
      );
  }


  const upcomingBillsTotal =
    upcomingBills.reduce(
      (sum, bill) =>
        sum + bill.amount,
      0
    );


  const remainingBeforeBills =
    budget - spending.total;


  const safeRemaining =
    remainingBeforeBills -
    upcomingBillsTotal;


  const budgetUsedPercent =
    budget === 0
      ? 0
      : (
          spending.total /
          budget
        ) * 100;


  const safeRemainingPercent =
    budget === 0
      ? 0
      : (
          safeRemaining /
          budget
        ) * 100;


  return {

    budget,

    spentSoFar:
      spending.total,

    transactionCount:
      spending.transactionCount,

    upcomingBills,

    upcomingBillsTotal,

    remainingBeforeBills,

    safeRemaining,

    budgetUsedPercent:
      Number(
        budgetUsedPercent.toFixed(2)
      ),

    safeRemainingPercent:
      Number(
        safeRemainingPercent.toFixed(2)
      ),

    overBudget:
      safeRemaining < 0,

    amountOverBudget:
      safeRemaining < 0
        ? Math.abs(safeRemaining)
        : 0
  };
}

function projectMonthlySpending(options = {}) {

  const {
    startDate,
    endDate,
    asOfDate,
    budget = financialData.user.monthlyBudget
  } = options;


  if (!startDate || !endDate || !asOfDate) {
    throw new Error(
      "startDate, endDate, and asOfDate are required"
    );
  }


  const actualTransactions =
    getTransactions({
      startDate,
      endDate: asOfDate,
      type: "expense"
    });


  const asOfForHistory = new Date(asOfDate + "T00:00:00Z");
  const recurringHistoryStart = new Date(Date.UTC(
    asOfForHistory.getUTCFullYear(),
    asOfForHistory.getUTCMonth() - 5,
    1
  )).toISOString().slice(0, 10);

  const recurringData =
    findRecurringExpenses({
      startDate: recurringHistoryStart,
      endDate: asOfDate
    });


  const recurringMerchants =
    new Set(
      recurringData.recurringExpenses.map(
        (expense) => expense.merchant
      )
    );


  let fixedSpent = 0;
  let variableSpent = 0;


  for (const transaction of actualTransactions) {

    if (
      recurringMerchants.has(
        transaction.merchant
      )
    ) {
      fixedSpent += transaction.amount;
    }

    else {
      variableSpent += transaction.amount;
    }
  }


  const start = new Date(
    startDate + "T00:00:00"
  );

  const end = new Date(
    endDate + "T00:00:00"
  );

  const current = new Date(
    asOfDate + "T00:00:00"
  );


  const millisecondsPerDay =
    1000 * 60 * 60 * 24;


  const totalDays =
    Math.floor(
      (end - start) /
      millisecondsPerDay
    ) + 1;


  const daysElapsed =
    Math.floor(
      (current - start) /
      millisecondsPerDay
    ) + 1;


  const daysRemaining =
    Math.max(
      totalDays - daysElapsed,
      0
    );


  const variableDailyAverage =
    daysElapsed === 0
      ? 0
      : variableSpent /
        daysElapsed;


  const projectedFutureVariableSpending =
    variableDailyAverage *
    daysRemaining;


  const futureBills =
    financialData.upcomingBills.filter(
      (bill) =>
        bill.dueDate > asOfDate &&
        bill.dueDate <= endDate
    );


  const futureBillsTotal =
    futureBills.reduce(
      (sum, bill) =>
        sum + bill.amount,
      0
    );


  const projectedTotal =
    fixedSpent +
    variableSpent +
    projectedFutureVariableSpending +
    futureBillsTotal;


  const projectedBudgetDifference =
    budget - projectedTotal;


  return {

    asOfDate,

    totalDays,

    daysElapsed,

    daysRemaining,

    fixedSpent:
      Number(fixedSpent.toFixed(2)),

    variableSpent:
      Number(variableSpent.toFixed(2)),

    variableDailyAverage:
      Number(
        variableDailyAverage.toFixed(2)
      ),

    projectedFutureVariableSpending:
      Number(
        projectedFutureVariableSpending.toFixed(2)
      ),

    futureBills,

    futureBillsTotal,

    projectedTotal:
      Number(
        projectedTotal.toFixed(2)
      ),

    budget,

    projectedBudgetDifference:
      Number(
        projectedBudgetDifference.toFixed(2)
      ),

    projectedOverBudget:
      projectedTotal > budget
  };
}

function calculateSavingsCapacity(options = {}) {

  const {
    startDate,
    endDate,
    asOfDate,
    reserveAmount = 0
  } = options;


  if (!startDate || !endDate || !asOfDate) {
    throw new Error(
      "startDate, endDate, and asOfDate are required"
    );
  }


  // Find income received during the month
  const incomeTransactions =
    getTransactions({
      startDate,
      endDate,
      type: "income"
    });


  const totalIncome =
    incomeTransactions.reduce(
      (sum, transaction) =>
        sum + transaction.amount,
      0
    );


  // Predict total month-end spending
  const projection =
    projectMonthlySpending({
      startDate,
      endDate,
      asOfDate
    });


  const projectedExpenses =
    projection.projectedTotal;


  // Money expected to remain after expenses
  const projectedSurplus =
    totalIncome -
    projectedExpenses;


  // Keep any requested cash reserve untouched
  const savingsCapacity =
    projectedSurplus -
    reserveAmount;


  const safeSavingsCapacity =
    Math.max(
      savingsCapacity,
      0
    );


  const savingsRate =
    totalIncome === 0
      ? 0
      : (
          safeSavingsCapacity /
          totalIncome
        ) * 100;


  return {

    totalIncome,

    projectedExpenses:
      Number(
        projectedExpenses.toFixed(2)
      ),

    projectedSurplus:
      Number(
        projectedSurplus.toFixed(2)
      ),

    reserveAmount,

    savingsCapacity:
      Number(
        safeSavingsCapacity.toFixed(2)
      ),

    savingsRatePercent:
      Number(
        savingsRate.toFixed(2)
      ),

    canSave:
      safeSavingsCapacity > 0,

    deficit:
      projectedSurplus < 0
        ? Number(
            Math.abs(
              projectedSurplus
            ).toFixed(2)
          )
        : 0,

    projection
  };
}

function simulateSavingsGoal(options = {}) {

  const {
    targetSavingsBalance,
    months,
    startDate,
    endDate,
    asOfDate,
    currentSavings =
      financialData.user.savingsBalance
  } = options;


  if (
    targetSavingsBalance === undefined ||
    !months ||
    !startDate ||
    !endDate ||
    !asOfDate
  ) {
    throw new Error(
      "targetSavingsBalance, months, startDate, endDate, and asOfDate are required"
    );
  }


  const savingsAnalysis =
    calculateSavingsCapacity({
      startDate,
      endDate,
      asOfDate
    });


  const amountStillNeeded =
    Math.max(
      targetSavingsBalance -
      currentSavings,
      0
    );


  const requiredMonthlySavings =
    months === 0
      ? amountStillNeeded
      : amountStillNeeded / months;


  const currentMonthlyCapacity =
    savingsAnalysis.savingsCapacity;


  const projectedMonthlySurplus =
    savingsAnalysis.projectedSurplus;


  const projectedAdditionalSavings =
    currentMonthlyCapacity *
    months;


  const projectedSavingsAtDeadline =
    currentSavings +
    projectedAdditionalSavings;


  const goalShortfall =
    Math.max(
      targetSavingsBalance -
      projectedSavingsAtDeadline,
      0
    );


  const monthlySavingsGap =
    Math.max(
      requiredMonthlySavings -
      currentMonthlyCapacity,
      0
    );


  /*
    If projected cash flow is negative,
    the user must first eliminate the deficit,
    then create enough extra room for the
    required monthly savings.
  */

  const requiredMonthlySpendingReduction =
    Math.max(
      requiredMonthlySavings -
      projectedMonthlySurplus,
      0
    );


  return {

    currentSavings:

      Number(
        currentSavings.toFixed(2)
      ),

    targetSavingsBalance:

      Number(
        targetSavingsBalance.toFixed(2)
      ),

    months,

    amountStillNeeded:

      Number(
        amountStillNeeded.toFixed(2)
      ),

    requiredMonthlySavings:

      Number(
        requiredMonthlySavings.toFixed(2)
      ),

    currentMonthlyCapacity:

      Number(
        currentMonthlyCapacity.toFixed(2)
      ),

    projectedMonthlySurplus:

      Number(
        projectedMonthlySurplus.toFixed(2)
      ),

    projectedSavingsAtDeadline:

      Number(
        projectedSavingsAtDeadline.toFixed(2)
      ),

    goalShortfall:

      Number(
        goalShortfall.toFixed(2)
      ),

    monthlySavingsGap:

      Number(
        monthlySavingsGap.toFixed(2)
      ),

    requiredMonthlySpendingReduction:

      Number(
        requiredMonthlySpendingReduction.toFixed(2)
      ),

    achievableAtCurrentPace:

      projectedSavingsAtDeadline >=
      targetSavingsBalance,

    assumptions: [
      "Current month's projected income and spending pattern continues.",
      "No major unexpected income or expenses occur.",
      "This is a planning estimate, not a guarantee."
    ],

    savingsAnalysis
  };
}

function calculateCashFlow(options = {}) {

  const {
    startDate,
    endDate,
    includeUpcomingBills = false
  } = options;


  if (!startDate || !endDate) {
    throw new Error(
      "startDate and endDate are required"
    );
  }


  // -------------------------
  // Income
  // -------------------------

  const incomeTransactions =
    getTransactions({
      startDate,
      endDate,
      type: "income"
    });


  const totalIncome =
    incomeTransactions.reduce(
      (sum, transaction) =>
        sum + transaction.amount,
      0
    );


  // -------------------------
  // Expenses
  // -------------------------

  const expenseTransactions =
    getTransactions({
      startDate,
      endDate,
      type: "expense"
    });


  const totalExpenses =
    expenseTransactions.reduce(
      (sum, transaction) =>
        sum + transaction.amount,
      0
    );


  // -------------------------
  // Upcoming bills
  // -------------------------

  let upcomingBills = [];


  if (includeUpcomingBills) {

    upcomingBills =
      financialData.upcomingBills.filter(
        (bill) =>
          bill.dueDate >= startDate &&
          bill.dueDate <= endDate
      );
  }


  const upcomingBillsTotal =
    upcomingBills.reduce(
      (sum, bill) =>
        sum + bill.amount,
      0
    );


  // -------------------------
  // Net cash flow
  // -------------------------

  const netCashFlow =
    totalIncome -
    totalExpenses -
    upcomingBillsTotal;


  const expenseToIncomePercent =
    totalIncome === 0
      ? 0
      : (
          totalExpenses /
          totalIncome
        ) * 100;


  const netCashFlowPercent =
    totalIncome === 0
      ? 0
      : (
          netCashFlow /
          totalIncome
        ) * 100;


  return {

    period: {
      startDate,
      endDate
    },

    totalIncome:
      Number(
        totalIncome.toFixed(2)
      ),

    totalExpenses:
      Number(
        totalExpenses.toFixed(2)
      ),

    upcomingBills,

    upcomingBillsTotal:
      Number(
        upcomingBillsTotal.toFixed(2)
      ),

    netCashFlow:
      Number(
        netCashFlow.toFixed(2)
      ),

    expenseToIncomePercent:
      Number(
        expenseToIncomePercent.toFixed(2)
      ),

    netCashFlowPercent:
      Number(
        netCashFlowPercent.toFixed(2)
      ),

    cashFlowStatus:
      netCashFlow > 0
        ? "positive"
        : netCashFlow < 0
          ? "negative"
          : "break-even",

    incomeTransactionCount:
      incomeTransactions.length,

    expenseTransactionCount:
      expenseTransactions.length
  };
}

module.exports = {
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
};