const express = require("express");
const cors = require("cors");
require("dotenv").config();

const {
  highestSpendingCategory
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

const PORT = 5000;

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});