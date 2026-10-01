const transactions = [
  {
    merchant: "Chipotle",
    category: "Food",
    amount: 25
  },
  {
    merchant: "Target",
    category: "Shopping",
    amount: 100
  },
  {
    merchant: "Starbucks",
    category: "Food",
    amount: 15
  },
  {
    merchant: "Uber",
    category: "Transport",
    amount: 40
  },
  {
    merchant: "Walmart",
    category: "Shopping",
    amount: 75
  }
];

function spendingByCategory() {
  const totals = {};

  for (const transaction of transactions) {
    const category = transaction.category;
    const amount = transaction.amount;

    if (totals[category]) {
      totals[category] += amount;
    } else {
      totals[category] = amount;
    }
  }

  return totals;
}

function totalSpending() {
  const totals = spendingByCategory();

  let total = 0;

  for (const category in totals) {
    total += totals[category];
  }

  return total;
}

function highestSpendingCategory() {
  const totals = spendingByCategory();

  let highestCategory = "";
  let highestAmount = 0;

  for (const category in totals) {
    if (totals[category] > highestAmount) {
      highestCategory = category;
      highestAmount = totals[category];
    }
  }

  return {
    category: highestCategory,
    amount: highestAmount
  };
}

function canAffordSavings(targetAmount) {
  const monthlyIncome = 3000;
  const spending = totalSpending();
  const upcomingBills = 1200;

  const moneyLeft =
    monthlyIncome - spending - upcomingBills;

  const canAfford = moneyLeft >= targetAmount;

  return {
    monthlyIncome: monthlyIncome,
    spending: spending,
    upcomingBills: upcomingBills,
    moneyLeft: moneyLeft,
    targetAmount: targetAmount,
    canAfford: canAfford,
    remainingAfterSaving: moneyLeft - targetAmount
  };
}

function compareMonthlySpending() {
  const currentMonth = {
    Food: 600,
    Shopping: 400,
    Transport: 200
  };

  const lastMonth = {
    Food: 400,
    Shopping: 250,
    Transport: 180
  };

  const differences = {};

  for (const category in currentMonth) {
    const current = currentMonth[category];
    const previous = lastMonth[category] || 0;

    differences[category] = current - previous;
  }

  return {
    currentMonth,
    lastMonth,
    differences
  };
}

module.exports = {
  spendingByCategory,
  highestSpendingCategory,
  totalSpending,
  canAffordSavings,
  compareMonthlySpending
};