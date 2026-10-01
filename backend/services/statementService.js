const crypto = require("node:crypto");
const supabase = require("./supabaseRest");
const { fingerprint } = require("./statementParser");

const demoImports = new Map();

function validateTransaction(input = {}) {
  const date = String(input.date || "").trim();
  const merchant = String(input.merchant || "").trim().slice(0, 160);
  const category = String(input.category || "Other").trim().slice(0, 60) || "Other";
  const amount = Number(input.amount);
  const type = input.type === "income" ? "income" : "expense";
  const sourceBalanceRaw = Number(input.sourceBalance);
  const sourceBalance = Number.isFinite(sourceBalanceRaw)
    ? Number(sourceBalanceRaw.toFixed(2))
    : null;
  const sourceOccurrence = Math.max(1, Math.min(100, Number.parseInt(input.sourceOccurrence, 10) || 1));

  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) throw new Error(`Invalid transaction date: ${date || "missing"}`);
  if (!merchant) throw new Error("Each transaction needs a merchant/description.");
  if (!Number.isFinite(amount) || amount <= 0 || amount > 100000000) throw new Error("Each transaction needs a valid positive amount.");

  const normalized = {
    date,
    merchant,
    category,
    amount: Number(amount.toFixed(2)),
    type,
    sourceBalance,
    sourceOccurrence
  };

  // Never trust the client fingerprint after review/editing. Recompute identity
  // from the approved financial fields. Category is intentionally excluded so
  // a corrected category never creates a duplicate transaction on re-import.
  return {
    ...normalized,
    source_fingerprint: fingerprint(normalized, sourceOccurrence)
  };
}

function getDemoData(userId) {
  if (!demoImports.has(userId)) demoImports.set(userId, { transactions: [], imports: [] });
  return demoImports.get(userId);
}

function buildSummary(received, saved) {
  return {
    received,
    saved,
    duplicatesSkipped: Math.max(0, received - saved),
    mergeMode: "append_new_only",
    message: saved
      ? `Added ${saved} new transaction${saved === 1 ? "" : "s"}; existing matches were left unchanged.`
      : "No new transactions were added; every recognized transaction was already saved."
  };
}

async function existingFingerprints(req, transactions) {
  if (!transactions.length) return new Set();
  if (req.user?.isDemo || !supabase.isConfigured() || !req.accessToken) {
    return new Set(getDemoData(req.user.id).transactions.map((item) => item.source_fingerprint));
  }

  const dates = transactions.map((item) => item.date).sort();
  const start = dates[0];
  const end = dates.at(-1);
  const rows = await supabase.request(
    `transactions?select=date,merchant,amount,type,source_balance,source_occurrence,source_fingerprint&date=gte.${start}&date=lte.${end}`,
    { accessToken: req.accessToken }
  );

  const set = new Set();
  for (const row of rows || []) {
    if (row.source_fingerprint) set.add(row.source_fingerprint);
    // Also calculate the current canonical fingerprint. This protects users who
    // imported data with an older app version whose fingerprint format differed.
    try {
      set.add(fingerprint({
        date: row.date,
        merchant: row.merchant,
        amount: Number(row.amount),
        type: row.type,
        sourceBalance: row.source_balance == null ? null : Number(row.source_balance),
        sourceOccurrence: Number(row.source_occurrence || 1)
      }, Number(row.source_occurrence || 1)));
    } catch (_) {}
  }
  return set;
}

async function saveApprovedTransactions(req, input = {}) {
  if (input.approved !== true) throw new Error("Review and approval are required before saving statement transactions.");
  const rawTransactions = Array.isArray(input.transactions) ? input.transactions : [];
  if (!rawTransactions.length) throw new Error("No transactions were supplied.");
  if (rawTransactions.length > 500) throw new Error("A single statement import is limited to 500 transactions.");
  const transactions = rawTransactions.map(validateTransaction);
  const received = transactions.length;
  const existing = await existingFingerprints(req, transactions);
  const newTransactions = transactions.filter((item) => !existing.has(item.source_fingerprint));

  if (req.user?.isDemo || !supabase.isConfigured() || !req.accessToken) {
    const store = getDemoData(req.user.id);
    for (const transaction of newTransactions) {
      store.transactions.push({
        id: crypto.randomUUID(),
        ...transaction,
        source_balance: transaction.sourceBalance,
        source_occurrence: transaction.sourceOccurrence,
        source: "statement"
      });
      existing.add(transaction.source_fingerprint);
    }
    store.transactions.sort((a, b) => a.date.localeCompare(b.date));
    store.imports.unshift({
      id: crypto.randomUUID(),
      transactionCount: received,
      savedCount: newTransactions.length,
      duplicateCount: received - newTransactions.length,
      createdAt: new Date().toISOString()
    });
    return buildSummary(received, newTransactions.length);
  }

  const rows = newTransactions.map((transaction) => ({
    user_id: req.user.id,
    date: transaction.date,
    merchant: transaction.merchant,
    category: transaction.category,
    amount: transaction.amount,
    type: transaction.type,
    source: "statement",
    source_balance: transaction.sourceBalance,
    source_occurrence: transaction.sourceOccurrence,
    source_fingerprint: transaction.source_fingerprint
  }));

  let insertedRows = [];
  if (rows.length) {
    insertedRows = await supabase.request("transactions?on_conflict=user_id,source_fingerprint&select=id", {
      accessToken: req.accessToken,
      method: "POST",
      headers: { Prefer: "resolution=ignore-duplicates,return=representation" },
      body: rows
    });
  }

  const saved = Array.isArray(insertedRows) ? insertedRows.length : 0;
  const firstDate = transactions.map((item) => item.date).sort()[0] || null;
  const lastDate = transactions.map((item) => item.date).sort().at(-1) || null;
  await supabase.request("statement_imports", {
    accessToken: req.accessToken,
    method: "POST",
    headers: { Prefer: "return=minimal" },
    body: [{
      user_id: req.user.id,
      transaction_count: received,
      extracted_transaction_count: received,
      saved_transaction_count: saved,
      duplicate_transaction_count: received - saved,
      first_transaction_date: firstDate,
      last_transaction_date: lastDate
    }]
  });

  return buildSummary(received, saved);
}

function demoTransactions(userId) {
  return getDemoData(userId).transactions.map((item) => ({ ...item }));
}

module.exports = { saveApprovedTransactions, demoTransactions };
