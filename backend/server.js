const express = require("express");
const cors = require("cors");
const multer = require("multer");
require("dotenv").config();

const OpenAI = require("openai");
const config = require("./config");
const { requireAuth } = require("./middleware/auth");
const { withFinancialData } = require("./financialContext");
const { loadFinancialData, seedDemoData } = require("./services/financialDataService");
const { getAccessStatus, simulatePurchase } = require("./services/subscriptionService");
const { getTopNews, refreshNews, startNewsScheduler } = require("./services/newsService");
const { planVisualization } = require("./services/visualizationPlanner");
const { buildSuggestedActions } = require("./services/actionPlanner");
const { getProfile, updateProfile } = require("./services/profileService");
const {
  listGoals,
  createGoal,
  updateGoal,
  deleteGoal,
  resolveProposal,
  applyApprovedProposal
} = require("./services/goalService");
const { parseBankStatementPdf } = require("./services/pdfStatementService");
const { saveApprovedTransactions, previewTransactions } = require("./services/statementService");
const { financialToolDefinitions } = require("./financialToolDefinitions");
const { executeFinancialTool } = require("./financialTools");
const {
  getSpendingByCategory,
  calculateBudgetRemaining,
  calculateCashFlow
} = require("./financialIntelligence");

const openai = process.env.OPENAI_API_KEY
  ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY })
  : null;

const app = express();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 12 * 1024 * 1024, files: 1 },
  fileFilter: (_req, file, callback) => {
    const pdf = file.mimetype === "application/pdf" || file.originalname.toLowerCase().endsWith(".pdf");
    callback(pdf ? null : new Error("Only PDF statements are accepted."), pdf);
  }
});

app.set("trust proxy", 1);
app.use(cors({ origin: config.corsOrigin === "*" ? true : config.corsOrigin }));
app.use(express.json({ limit: "2mb" }));
app.use(express.static("public"));

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    service: "WealthPilot Wealth Assistant API",
    time: new Date().toISOString()
  });
});

app.get("/", (_req, res) => {
  res.send("WealthPilot — your AI Wealth Assistant backend is running.");
});

async function requirePremiumOrTrial(req, res, next) {
  try {
    const status = await getAccessStatus(req);
    req.accessStatus = status;
    if (!status.access) {
      return res.status(402).json({
        error: "Premium access required.",
        subscription: status
      });
    }
    return next();
  } catch (error) {
    console.error("Subscription check error:", error);
    return res.status(500).json({ error: "Could not verify subscription access." });
  }
}

app.get("/api/profile", requireAuth, async (req, res) => {
  try {
    res.json(await getProfile(req));
  } catch (error) {
    console.error("Profile load error:", error);
    res.status(500).json({ error: "Could not load profile." });
  }
});

app.put("/api/profile", requireAuth, async (req, res) => {
  try {
    res.json(await updateProfile(req, req.body || {}));
  } catch (error) {
    res.status(400).json({ error: error.message || "Could not update profile." });
  }
});

app.get("/api/subscription/status", requireAuth, async (req, res) => {
  try {
    res.json(await getAccessStatus(req));
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Could not load subscription status." });
  }
});

app.post("/api/subscription/simulate", requireAuth, async (req, res) => {
  try {
    const result = simulatePurchase(req, req.body?.active !== false);
    res.json({ ...result, ...(await getAccessStatus(req)) });
  } catch (error) {
    res.status(403).json({ error: error.message });
  }
});

app.post("/api/demo/seed", requireAuth, async (req, res) => {
  try {
    res.json(await seedDemoData(req));
  } catch (error) {
    console.error("Seed error:", error);
    res.status(500).json({ error: "Could not seed demo financial data." });
  }
});

app.post("/api/statements/parse", requireAuth, upload.single("statement"), async (req, res) => {
  try {
    if (!req.file?.buffer) return res.status(400).json({ error: "Choose a bank-statement PDF." });
    const parsed = await parseBankStatementPdf(req.file.buffer);
    const importPreview = await previewTransactions(req, parsed.transactions);
    return res.json({
      ...parsed,
      importPreview,
      originalFileStored: false,
      message: "Review the extracted transactions. Nothing will be saved until you approve the import."
    });
  } catch (error) {
    console.error("Statement parse error:", error);
    return res.status(422).json({ error: error.message || "Could not read this statement." });
  }
});

app.post("/api/statements/commit", requireAuth, async (req, res) => {
  try {
    const result = await saveApprovedTransactions(req, req.body || {});
    return res.json({ ...result, originalFileStored: false });
  } catch (error) {
    console.error("Statement commit error:", error);
    return res.status(400).json({ error: error.message || "Could not save statement transactions." });
  }
});

function monthBoundsFromDate(dateText) {
  const match = String(dateText || "").match(/^(\d{4})-(\d{2})-\d{2}$/);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const startDate = `${match[1]}-${match[2]}-01`;
  const endDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return { startDate, endDate: `${match[1]}-${match[2]}-${String(endDay).padStart(2, "0")}` };
}

app.get("/api/dashboard", requireAuth, async (req, res) => {
  try {
    const data = await loadFinancialData(req);
    const latestDate = data.transactions.map((item) => item.date).sort().at(-1) || new Date().toISOString().slice(0, 10);
    const inferred = monthBoundsFromDate(latestDate);
    const startDate = req.query.startDate || inferred.startDate;
    const endDate = req.query.endDate || inferred.endDate;
    const periodTransactions = data.transactions.filter((item) => item.date >= startDate && item.date <= endDate);
    const income = periodTransactions.filter((item) => item.type === "income").reduce((sum, item) => sum + Number(item.amount || 0), 0);
    const expenses = periodTransactions.filter((item) => item.type === "expense").reduce((sum, item) => sum + Number(item.amount || 0), 0);

    const result = await withFinancialData(data, async () => {
      const categories = getSpendingByCategory({ startDate, endDate });
      return {
        period: { startDate, endDate, latestTransactionDate: latestDate },
        snapshot: {
          moneyIn: Number(income.toFixed(2)),
          moneyOut: Number(expenses.toFixed(2)),
          activityFound: periodTransactions.length,
          largestCategory: categories[0]?.category || "—"
        },
        categories,
        recentTransactions: [...periodTransactions]
          .sort((a, b) => b.date.localeCompare(a.date))
          .slice(0, 8)
          .map(({ id, ...item }) => item),
        budget: calculateBudgetRemaining({ startDate, endDate }),
        cashFlow: calculateCashFlow({ startDate, endDate, includeUpcomingBills: true })
      };
    });
    res.json(result);
  } catch (error) {
    console.error("Dashboard error:", error);
    res.status(500).json({ error: "Could not load dashboard." });
  }
});

app.get("/api/goals", requireAuth, requirePremiumOrTrial, async (req, res) => {
  try {
    res.json({ goals: await listGoals(req) });
  } catch (error) {
    console.error("Goal load error:", error);
    res.status(500).json({ error: "Could not load goals." });
  }
});

app.post("/api/goals", requireAuth, requirePremiumOrTrial, async (req, res) => {
  try {
    if (req.body?.approved !== true) return res.status(409).json({ error: "Human approval is required before creating a goal." });
    res.json({ goal: await createGoal(req, req.body) });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.put("/api/goals/:id", requireAuth, requirePremiumOrTrial, async (req, res) => {
  try {
    if (req.body?.approved !== true) return res.status(409).json({ error: "Human approval is required before changing a goal." });
    res.json({ goal: await updateGoal(req, req.params.id, req.body) });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.delete("/api/goals/:id", requireAuth, requirePremiumOrTrial, async (req, res) => {
  try {
    if (req.query.approved !== "true") return res.status(409).json({ error: "Human approval is required before deleting a goal." });
    res.json(await deleteGoal(req, req.params.id));
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.post("/api/goals/apply-proposal", requireAuth, requirePremiumOrTrial, async (req, res) => {
  try {
    res.json(await applyApprovedProposal(req, req.body || {}));
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.post("/api/internal/news/refresh", async (req, res) => {
  if (!config.cronSecret || req.headers["x-cron-secret"] !== config.cronSecret) {
    return res.status(401).json({ error: "Unauthorized." });
  }
  try {
    const result = await refreshNews();
    return res.json({ generatedAt: result.generatedAt, count: result.items.length });
  } catch (error) {
    console.error("Cron news refresh error:", error);
    return res.status(503).json({ error: "News refresh failed." });
  }
});

app.get("/api/news/top", requireAuth, requirePremiumOrTrial, async (req, res) => {
  try {
    const news = await getTopNews({ force: req.query.refresh === "true" });
    res.json({
      ...news,
      disclaimer: "AI-generated news analysis for informational purposes only. It does not guarantee market performance and is not an investment recommendation."
    });
  } catch (error) {
    console.error("News error:", error);
    res.status(503).json({
      error: "Verified news is temporarily unavailable. No unverified stories were generated."
    });
  }
});

function sanitizeFinancialResult(value) {
  if (Array.isArray(value)) return value.map(sanitizeFinancialResult);
  if (!value || typeof value !== "object") return value;
  const blocked = new Set([
    "id", "user_id", "userId", "email", "phone", "merchant",
    "accountNumber", "cardNumber", "accessToken", "source_fingerprint"
  ]);
  return Object.fromEntries(
    Object.entries(value)
      .filter(([key]) => !blocked.has(key))
      .map(([key, item]) => [key, sanitizeFinancialResult(item)])
  );
}

function sanitizeGoalContext(goalContext) {
  if (!goalContext || typeof goalContext !== "object" || Array.isArray(goalContext)) return null;
  const allowed = ["goalType", "targetAmount", "targetDate", "months"];
  const clean = {};
  for (const key of allowed) {
    if (goalContext[key] !== undefined) clean[key] = goalContext[key];
  }
  return Object.keys(clean).length ? clean : null;
}

function sanitizeConversationHistory(history) {
  if (!Array.isArray(history)) return [];
  return history
    .slice(-10)
    .map((item) => {
      const role = item?.role === "assistant" ? "assistant" : "user";
      const content = String(item?.content || "").trim().slice(0, 1800);
      return content ? { role, content } : null;
    })
    .filter(Boolean);
}

const goalProposalToolDefinition = {
  type: "function",
  name: "propose_financial_goal",
  description: "Use only when the user explicitly asks to create, change, or delete a financial goal. This tool NEVER saves anything. It creates a proposal that the app must show for human approval before any database change.",
  strict: false,
  parameters: {
    type: "object",
    properties: {
      action: { type: "string", enum: ["create", "update", "delete"] },
      goalNumber: { type: "integer", description: "For update/delete, prefer the numbered goal from EXISTING GOALS when the user did not state an exact goal name." },
      goalName: { type: "string", description: "Required for create. For update/delete, use the exact user-stated name only when available." },
      goalType: { type: "string", description: "Examples: vacation, savings, emergency_fund, purchase." },
      targetAmount: { type: "number" },
      targetDate: { type: "string", description: "YYYY-MM-DD when known." }
    },
    required: ["action"],
    additionalProperties: false
  }
};

const now = new Date();

const localToday =
  `${now.getFullYear()}-` +
  `${String(now.getMonth() + 1).padStart(2, "0")}-` +
  `${String(now.getDate()).padStart(2, "0")}`;

function assistantInstructions(goalContext = null, isDemo = false, existingGoals = []) {
  const goalSummary = existingGoals.map((goal, index) => ({
    goalNumber: index + 1,
    goalType: goal.goalType,
    targetAmount: goal.targetAmount,
    targetDate: goal.targetDate,
    isActive: goal.isActive
  }));
  return `
You are WealthPilot's AI Wealth Assistant, a financial decision assistant.

Your purpose is to investigate the user's anonymous financial values with tools, explain what matters, and turn evidence into useful planning scenarios. The deterministic financial tools are the source of truth for amounts. Do not invent personal financial values when a tool can provide them.

RULES:
1. Use financial tools whenever the answer depends on personal financial data.
2. Complex questions should use multiple tools when that materially improves the answer.
3. Never invent balances, transactions, income, bills, categories, projections, savings capacity, or percentages.
4. Clearly distinguish recorded history from forecasts and planning scenarios.
5. Distinguish budget remaining, cash flow, projected month-end spending, and savings capacity.
6. Explain causes using category-level evidence from tools. Merchant names and account identifiers are intentionally withheld from you for privacy.
7. After analysis, provide practical next-month options when relevant. Tie suggestions to evidence and quantify them when tools support the amount.
8. If the user is planning a vacation/trip, connect savings suggestions to that goal. Otherwise focus on saving, cash-flow stability, recurring-cost cleanup, and sustainable wealth habits.
9. Do not guarantee savings outcomes, market returns, or future financial results.
10. Be concise enough to be spoken aloud. Prefer a short answer with key numbers and 2-4 concrete actions over a long essay.
11. Never ask for or expose names, emails, account numbers, card details, transaction IDs, or user IDs.
12. This assistant provides financial education and planning support, not individualized investment, tax, or legal advice.
13. NEVER create, edit, or delete a goal directly. If the user explicitly asks you to do one of those things, call propose_financial_goal. The app will ask for human approval. If updating/deleting an existing goal, use its goalNumber from EXISTING GOALS whenever the user did not provide an exact name. If the user is merely discussing a hypothetical goal, do not call it.

DATE CONTEXT:
Current server date: ${localToday}.
${isDemo ? 'This request may use bundled demonstration data when no imported statement exists. Recorded demo September data runs through 2026-09-16.' : 'This request uses the signed-in user\'s private dataset. Resolve relative dates against the current server date and dates present in the user data.'}

EXISTING GOALS (safe planning fields only):
${JSON.stringify(goalSummary)}

OPTIONAL USER GOAL CONTEXT (not a source of transaction facts):
${goalContext ? JSON.stringify(goalContext) : "No explicit goal context supplied."}
`;
}

app.post("/api/ai/chat", requireAuth, requirePremiumOrTrial, async (req, res) => {
  if (!openai) {
    return res.status(503).json({ error: "OPENAI_API_KEY is not configured on the server." });
  }

  const { message, goalContext = null, history = [] } = req.body || {};
  if (!message || typeof message !== "string" || !message.trim()) {
    return res.status(400).json({ error: "A message is required." });
  }
  if (message.length > 4000) {
    return res.status(400).json({ error: "Message is too long." });
  }

  try {
    const [userData, existingGoals] = await Promise.all([
      loadFinancialData(req),
      listGoals(req).catch(() => [])
    ]);

    const payload = await withFinancialData(userData, async () => {
      const instructions = assistantInstructions(
        sanitizeGoalContext(goalContext),
        Boolean(req.user?.isDemo),
        existingGoals
      );
      const tools = [...financialToolDefinitions, goalProposalToolDefinition];
      let turnInput = [
        ...sanitizeConversationHistory(history),
        { role: "user", content: message.trim() }
      ];
      let response = await openai.responses.create({
        model: config.openAiModel,
        instructions,
        input: turnInput,
        tools,
        tool_choice: "auto",
        parallel_tool_calls: true,
        store: false
      });

      const toolsUsed = [];
      let rawGoalProposal = null;
      const MAX_TOOL_ROUNDS = 8;

      for (let round = 0; round < MAX_TOOL_ROUNDS; round += 1) {
        const toolCalls = (response.output || []).filter((item) => item.type === "function_call");
        if (toolCalls.length === 0) {
          const answer = response.output_text || "I could not generate an answer.";
          return {
            answer,
            toolsUsed,
            visualization: planVisualization(toolsUsed, message),
            suggestedActions: buildSuggestedActions(toolsUsed, message),
            goalProposal: rawGoalProposal ? await resolveProposal(req, rawGoalProposal) : null,
            subscription: req.accessStatus
          };
        }

        const toolOutputs = [];
        for (const toolCall of toolCalls) {
          let args = {};
          try {
            args = JSON.parse(toolCall.arguments || "{}");
          } catch {
            throw new Error(`Invalid arguments from AI for ${toolCall.name}`);
          }

          console.log(`AI requested tool: ${toolCall.name}`, args);
          let result;
          if (toolCall.name === "propose_financial_goal") {
            rawGoalProposal = args;
            result = {
              status: "proposal_created",
              requiresHumanApproval: true,
              databaseChanged: false
            };
          } else {
            const rawResult = executeFinancialTool(toolCall.name, args);
            result = sanitizeFinancialResult(rawResult);
          }
          toolsUsed.push({ name: toolCall.name, arguments: args, result });
          toolOutputs.push({
            type: "function_call_output",
            call_id: toolCall.call_id,
            output: JSON.stringify(result)
          });
        }

        turnInput = [...turnInput, ...(response.output || []), ...toolOutputs];
        response = await openai.responses.create({
          model: config.openAiModel,
          instructions,
          input: turnInput,
          tools,
          tool_choice: "none",
          parallel_tool_calls: true,
          store: false
        });
      }

      throw new Error("The AI used too many financial-analysis steps.");
    });

    return res.json(payload);
  } catch (error) {
    console.error("AI financial assistant error:", error);
    return res.status(500).json({
      error: "Something went wrong with the AI financial assistant."
    });
  }
});

app.use((error, _req, res, next) => {
  if (!error) return next();
  if (error instanceof multer.MulterError) {
    return res.status(400).json({ error: error.code === "LIMIT_FILE_SIZE" ? "PDF must be 12 MB or smaller." : error.message });
  }
  if (error.message?.includes("Only PDF")) return res.status(400).json({ error: error.message });
  return next(error);
});

startNewsScheduler();

app.listen(config.port, () => {
  console.log(`WealthPilot backend running on port ${config.port}`);
});
