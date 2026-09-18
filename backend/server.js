const express = require("express");
const cors = require("cors");
require("dotenv").config();

const {
  spendingByCategory,
  highestSpendingCategory,
  totalSpending,
  canAffordSavings
} = require("./financialAnalyzer");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.send("Ship-a-ton AI backend is running!");
});

app.get("/spending/highest", (req, res) => {
  const result = highestSpendingCategory();

  res.json({
    message: `You spent the most on ${result.category}: $${result.amount}`,
    category: result.category,
    amount: result.amount
  });
});

app.get("/spending/categories", (req, res) => {
  const totals = spendingByCategory();

  res.json({
    message: "Spending by category",
    categories: totals
  });
});

app.get("/spending/total", (req, res) => {
  const total = totalSpending();

  res.json({
    message: `You spent $${total} in total`,
    total: total
  });
});

app.get("/savings/can-afford", (req, res) => {
  const result = canAffordSavings(500);

  res.json({
    message: result.canAfford
      ? `Yes, you can afford to save $500. You would have $${result.remainingAfterSaving} left.`
      : `No, based on your current finances, saving $500 would leave you short.`,
    details: result
  });
});

const PORT = 5000;

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});