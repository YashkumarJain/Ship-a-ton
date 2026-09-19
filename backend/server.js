const express = require("express");
const cors = require("cors");
require("dotenv").config();
const OpenAI = require("openai");

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

const {
  spendingByCategory,
  highestSpendingCategory,
  totalSpending,
  canAffordSavings,
  compareMonthlySpending
} = require("./financialAnalyzer");

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.static("public"));

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

app.get("/spending/compare", (req, res) => {
  const result = compareMonthlySpending();

  res.json({
    message:
      `Your spending increased mainly because Food increased by $${result.differences.Food} ` +
      `and Shopping increased by $${result.differences.Shopping}.`,
    details: result
  });
});

app.post("/ai/chat", async (req, res) => {
  try {
    const { message } = req.body;

    if (!message) {
      return res.status(400).json({
        error: "Message is required"
      });
    }

    const highest = highestSpendingCategory();
    const categories = spendingByCategory();
    const total = totalSpending();
    const savings = canAffordSavings(500);
    const comparison = compareMonthlySpending();

    const financialContext = {
      totalSpending: total,
      spendingByCategory: categories,
      highestSpendingCategory: highest,
      savingsAnalysis: savings,
      monthlyComparison: comparison
    };

    const response = await openai.responses.create({
      model: "gpt-5.6-luna",
      instructions: `
You are the Ship-a-ton AI Financial Assistant.

Answer the user's financial question using only the financial data provided.

Rules:
- Never invent transactions or numbers.
- If the data does not contain the answer, say you do not have enough information.
- Explain answers simply.
- Do not guarantee financial outcomes.
- Do not recommend specific stocks, crypto, or investments.
- Keep answers short and easy to understand.
      `,
      input: `
USER FINANCIAL DATA:
${JSON.stringify(financialContext, null, 2)}

USER QUESTION:
${message}
      `
    });

    res.json({
      answer: response.output_text
    });

  } catch (error) {
    console.error(error);

    res.status(500).json({
      error: "Something went wrong with the AI assistant"
    });
  }
});
 
const PORT = 5000;

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});