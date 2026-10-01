const crypto = require("node:crypto");

const CATEGORY_RULES = [
  ["Rent", /\b(rent|apartment|property management|landlord|housing)\b/i],
  ["Groceries", /\b(grocery|groceries|whole foods|trader joe|walmart grocery|kroger|safeway|aldi|costco|market)\b/i],
  ["Dining", /\b(restaurant|cafe|coffee|starbucks|doordash|uber eats|grubhub|mcdonald|chipotle|pizza|bar|bakery)\b/i],
  ["Transport", /\b(uber|lyft|metro|transit|gas station|shell|chevron|exxon|parking|toll|fuel)\b/i],
  ["Travel", /\b(airline|delta|united|american airlines|southwest|hotel|airbnb|booking\.com|expedia|flight|resort)\b/i],
  ["Shopping", /\b(amazon|target|best buy|apple store|nike|adidas|ebay|etsy|shop|store|mall)\b/i],
  ["Subscriptions", /\b(netflix|spotify|hulu|disney\+|youtube premium|icloud|dropbox|subscription|membership)\b/i],
  ["Utilities", /\b(electric|electricity|power|water|internet|comcast|xfinity|verizon|at&t|phone|utility|utilities)\b/i],
  ["Fitness", /\b(gym|fitness|planet fitness|equinox|peloton|yoga)\b/i],
  ["Healthcare", /\b(pharmacy|cvs|walgreens|doctor|hospital|clinic|medical|dental|health)\b/i],
  ["Education", /\b(tuition|university|college|course|udemy|coursera|bookstore|education)\b/i],
  ["Insurance", /\b(insurance|geico|progressive|allstate|state farm)\b/i],
  ["Income", /\b(payroll|salary|direct deposit|paycheck|wages|interest credit|dividend)\b/i]
];

const HEADER_WORDS = [
  "date",
  "description",
  "details",
  "transaction",
  "amount",
  "balance",
  "statement",
  "account summary",
  "beginning balance",
  "ending balance",
  "page"
];

function cleanWhitespace(value = "") {
  return String(value).replace(/\u00a0/g, " ").replace(/[\t ]+/g, " ").trim();
}

function inferStatementYear(text) {
  const currentYear = new Date().getUTCFullYear();
  const years = [...String(text).matchAll(/\b(20\d{2})\b/g)]
    .map((match) => Number(match[1]))
    .filter((year) => year >= 2000 && year <= currentYear + 1);
  if (!years.length) return currentYear;
  const counts = new Map();
  for (const year of years) counts.set(year, (counts.get(year) || 0) + 1);
  return [...counts.entries()].sort((a, b) => b[1] - a[1] || b[0] - a[0])[0][0];
}

const MONTHS = {
  jan: 1, january: 1,
  feb: 2, february: 2,
  mar: 3, march: 3,
  apr: 4, april: 4,
  may: 5,
  jun: 6, june: 6,
  jul: 7, july: 7,
  aug: 8, august: 8,
  sep: 9, sept: 9, september: 9,
  oct: 10, october: 10,
  nov: 11, november: 11,
  dec: 12, december: 12
};

function isoDate(year, month, day) {
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) return null;
  return `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function parseDateFromLine(line, fallbackYear) {
  const patterns = [
    {
      regex: /\b(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b/,
      parse: (m) => isoDate(Number(m[1]), Number(m[2]), Number(m[3]))
    },
    {
      regex: /\b(\d{1,2})[-/.](\d{1,2})[-/.](20\d{2})\b/,
      parse: (m) => {
        const first = Number(m[1]);
        const second = Number(m[2]);
        // Prefer US MM/DD, but automatically accept DD/MM when the first
        // number cannot be a month.
        return first > 12
          ? isoDate(Number(m[3]), second, first)
          : isoDate(Number(m[3]), first, second);
      }
    },
    {
      regex: /\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2})\b/,
      parse: (m) => isoDate(2000 + Number(m[3]), Number(m[1]), Number(m[2]))
    },
    {
      regex: /\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(\d{1,2})(?:,?\s+(20\d{2}))?\b/i,
      parse: (m) => isoDate(Number(m[3] || fallbackYear), MONTHS[m[1].toLowerCase()], Number(m[2]))
    },
    {
      regex: /\b(\d{1,2})\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)(?:\s+(20\d{2}))?\b/i,
      parse: (m) => isoDate(Number(m[3] || fallbackYear), MONTHS[m[2].toLowerCase()], Number(m[1]))
    }
  ];

  for (const pattern of patterns) {
    const match = line.match(pattern.regex);
    if (!match) continue;
    const date = pattern.parse(match);
    if (date) return { date, raw: match[0], index: match.index || 0 };
  }
  return null;
}

function parseMoneyToken(token) {
  let raw = cleanWhitespace(token).replace(/[£€$]/g, "");
  const marker = raw.match(/\b(CR|DR)\b/i)?.[1]?.toUpperCase();
  raw = raw.replace(/\b(CR|DR)\b/ig, "").trim();
  const paren = raw.startsWith("(") && raw.endsWith(")");
  raw = raw.replace(/[(),]/g, "").replace(/\s+/g, "");
  const number = Number(raw);
  if (!Number.isFinite(number)) return null;
  let signed = paren ? -Math.abs(number) : number;
  if (marker === "DR") signed = -Math.abs(number);
  if (marker === "CR") signed = Math.abs(number);
  return { value: signed, marker };
}

function amountTokens(lineWithoutDate) {
  const regex = /(?:[$£€]\s*)?\(?[+-]?(?:\d{1,3}(?:,\d{3})+|\d+)\.\d{2}\)?(?:\s*(?:CR|DR))?/gi;

  const values = [];
  let match;
  while ((match = regex.exec(lineWithoutDate)) !== null) {
    const parsed = parseMoneyToken(match[0]);
    if (!parsed) continue;
    values.push({ ...parsed, raw: match[0], index: match.index });
  }
  return values;
}

function looksLikeHeader(
  line,
  fallbackYear = new Date().getUTCFullYear()
) {
  const lower = line.toLowerCase();

  // A dated line containing money is almost certainly
  // a real transaction, even if it says "credit" or "deposit".
  const parsedDate = parseDateFromLine(line, fallbackYear);

  if (parsedDate) {
    const withoutDate = line.replace(parsedDate.raw, " ");

    if (amountTokens(withoutDate).length > 0) {
      return false;
    }
  }

  // Strong combinations that actually resemble table headers.
  if (
    /\bdate\b.*\b(description|details|transaction)\b/i.test(line)
  ) {
    return true;
  }

  if (
    /\b(description|details|transaction)\b.*\b(amount|balance)\b/i.test(line)
  ) {
    return true;
  }

  if (/\bdebit\b.*\bcredit\b/i.test(line)) {
    return true;
  }

  if (
    /\b(account summary|beginning balance|ending balance)\b/i.test(line)
  ) {
    return true;
  }

  if (/^page\s+\d+/i.test(line.trim())) {
    return true;
  }

  const matches = HEADER_WORDS.filter(
    (word) => lower.includes(word)
  ).length;

  return matches >= 3;
}

function inferType(line, signedAmount, marker) {
  const lower = line.toLowerCase();
  if (marker === "CR") return "income";
  if (marker === "DR") return "expense";
  if (signedAmount < 0) return "expense";

  const incomeWords = [
    "payroll", "salary", "direct deposit", "deposit", "paycheck", "wages",
    "interest credit", "dividend", "refund", "reimbursement", "transfer in",
    "credit received", "payment received", "ach credit", "zelle from", "deposit from"
  ];
  const expenseWords = [
    "purchase", "pos", "debit", "withdrawal", "atm", "fee", "bill pay",
    "payment to", "card purchase", "check", "transfer out"
  ];

  if (incomeWords.some((word) => lower.includes(word))) return "income";
  if (expenseWords.some((word) => lower.includes(word))) return "expense";
  return "expense";
}

function categorize(merchant, type) {
  if (type === "income") return "Income";
  for (const [category, regex] of CATEGORY_RULES) {
    if (category === "Income") continue;
    if (regex.test(merchant)) return category;
  }
  return "Other";
}

function cleanMerchant(line, dateRaw, amountMatches) {
  let merchant = line;
  if (dateRaw) merchant = merchant.replace(dateRaw, " ");
  for (const match of [...amountMatches].sort((a, b) => b.index - a.index)) {
    merchant = merchant.replace(match.raw, " ");
  }
  merchant = merchant
    .replace(/\b(?:debit|credit|withdrawal|deposit|balance|amount|posted|pending)\b/ig, " ")
    .replace(/\b(?:visa|mastercard|amex)\s*\*?\d{0,4}\b/ig, " ")
    .replace(/\b(?:pos|ach)\b[:\-]?/ig, " ")
    .replace(/\s{2,}/g, " ")
    .replace(/^[\-–—|:]+|[\-–—|:]+$/g, "")
    .trim();
  return merchant.slice(0, 160);
}

function buildLogicalLines(text, fallbackYear) {
  const rawLines = String(text)
    .replace(/\r/g, "\n")
    .split(/\n+/)
    .map(cleanWhitespace)
    .filter(Boolean);

  const logical = [];
  let current = "";
  for (const line of rawLines) {
    const hasDate = Boolean(parseDateFromLine(line, fallbackYear));
    if (hasDate) {
      if (current) logical.push(current);
      current = line;
      continue;
    }

    if (current && !looksLikeHeader(line, fallbackYear) && line.length <= 140) {
      current = `${current} ${line}`;
    } else {
      if (current) logical.push(current);
      current = line;
    }
  }
  if (current) logical.push(current);
  return logical;
}

function normalizeMerchantIdentity(value = "") {
  return cleanWhitespace(value)
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
}

function fingerprint(
  transaction,
  occurrence = transaction.sourceOccurrence || 1
) {
  return crypto
    .createHash("sha256")
    .update([
      transaction.date,
      normalizeMerchantIdentity(transaction.merchant),
      Number(transaction.amount).toFixed(2),
      transaction.type,
      Number(occurrence || 1)
    ].join("|"))
    .digest("hex");
}

function parseStatementText(text, { maxTransactions = 500 } = {}) {
  const normalized = String(text || "").replace(/\u0000/g, " ");
  const fallbackYear = inferStatementYear(normalized);
  const logicalLines = buildLogicalLines(normalized, fallbackYear);
  const transactions = [];
  const occurrences = new Map();

  for (const line of logicalLines) {
    if (transactions.length >= maxTransactions) break;
    if (looksLikeHeader(line, fallbackYear)) continue;

    const parsedDate = parseDateFromLine(line, fallbackYear);
    if (!parsedDate) continue;

    const withoutDate =
  line.replace(parsedDate.raw, " ");

// Ignore statement-period rows such as:
// 09/01/2026 - 09/15/2026
// They are not transactions.
if (parseDateFromLine(withoutDate, fallbackYear)) {
  continue;
}

const amounts = amountTokens(withoutDate);
    if (!amounts.length) continue;

    // In common bank layouts the first monetary column is the transaction amount
    // and a later value is the running balance. For single-column card statements,
    // this naturally selects the only value.
    const chosen = amounts[0];
    const merchant = cleanMerchant(line, parsedDate.raw, amounts);
    if (!merchant || merchant.length < 2) continue;

    const type = inferType(line, chosen.value, chosen.marker);
    const amount = Math.abs(chosen.value);
    if (!Number.isFinite(amount) || amount <= 0 || amount > 100000000) continue;

    const sourceBalance = amounts.length > 1
      ? Number(amounts[amounts.length - 1].value.toFixed(2))
      : null;
    const transaction = {
      date: parsedDate.date,
      merchant,
      category: categorize(merchant, type),
      amount: Number(amount.toFixed(2)),
      type,
      sourceBalance,
      confidence: Number((0.72 + (amounts.length === 1 ? 0.12 : 0) + (merchant.length > 4 ? 0.08 : 0)).toFixed(2))
    };

    // Multiple legitimate purchases can have the same date, merchant and amount.
    // Keep them all, but give each identical canonical row a stable occurrence
    // number so re-uploading the same/overlapping statement remains idempotent.
    const baseKey = [
      transaction.date,
      normalizeMerchantIdentity(transaction.merchant),
      transaction.amount.toFixed(2),
      transaction.type,
      sourceBalance == null ? "" : sourceBalance.toFixed(2)
    ].join("|");
    const occurrence = (occurrences.get(baseKey) || 0) + 1;
    occurrences.set(baseKey, occurrence);
    transaction.sourceOccurrence = occurrence;
    transaction.fingerprint = fingerprint(transaction, occurrence);
    transactions.push(transaction);
  }

  transactions.sort((a, b) => a.date.localeCompare(b.date));
  const warnings = [];
  if (!transactions.length) {
    warnings.push("No transaction rows could be recognized automatically. Review the PDF quality or try another statement.");
  } else if (transactions.some((transaction) => transaction.confidence < 0.8)) {
    warnings.push("Some rows were extracted with lower confidence. Please review them before saving.");
  }
  if (transactions.length >= maxTransactions) {
    warnings.push(`Only the first ${maxTransactions} recognized transactions were included.`);
  }

  return {
    transactions,
    warnings,
    metadata: {
      inferredYear: fallbackYear,
      recognizedCount: transactions.length,
      firstDate: transactions[0]?.date || null,
      lastDate: transactions[transactions.length - 1]?.date || null
    }
  };
}

module.exports = {
  parseStatementText,
  parseDateFromLine,
  categorize,
  fingerprint,
  normalizeMerchantIdentity
};
