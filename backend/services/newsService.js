const OpenAI = require("openai");
const config = require("../config");

const openai = process.env.OPENAI_API_KEY
  ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY })
  : null;

const DEFAULT_FEEDS = [
  { name: "BBC Business", url: "https://feeds.bbci.co.uk/news/business/rss.xml" },
  { name: "BBC Technology", url: "https://feeds.bbci.co.uk/news/technology/rss.xml" },
  { name: "NPR Business", url: "https://feeds.npr.org/1006/rss.xml" },
  { name: "CNBC Top News", url: "https://www.cnbc.com/id/100003114/device/rss/rss.html" },
  { name: "MarketWatch Top Stories", url: "https://feeds.marketwatch.com/marketwatch/topstories/" }
];

let cache = { generatedAt: null, items: [] };
let refreshPromise = null;
let schedulerStarted = false;

function decodeEntities(value = "") {
  return String(value)
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)));
}

function cleanText(value = "") {
  return decodeEntities(value)
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function tagValue(block, tag) {
  const match = block.match(new RegExp(`<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${tag}>`, "i"));
  return match ? match[1] : "";
}

function atomLink(block) {
  const match = block.match(/<link[^>]+href=["']([^"']+)["'][^>]*>/i);
  return match ? match[1] : "";
}

function parseXmlItems(xml, source) {
  const rssItems = xml.match(/<item\b[\s\S]*?<\/item>/gi) || [];
  const atomEntries = xml.match(/<entry\b[\s\S]*?<\/entry>/gi) || [];
  return [...rssItems, ...atomEntries].map((block) => {
    const title = cleanText(tagValue(block, "title"));
    const link = cleanText(tagValue(block, "link")) || atomLink(block);
    const publishedAt = cleanText(tagValue(block, "pubDate")) ||
      cleanText(tagValue(block, "published")) ||
      cleanText(tagValue(block, "updated")) || null;
    const sourceSummary = cleanText(
      tagValue(block, "description") ||
      tagValue(block, "summary") ||
      tagValue(block, "content:encoded") ||
      tagValue(block, "content")
    );
    return { title, source: source.name, link, publishedAt, sourceSummary };
  });
}

function feedList() {
  const custom = process.env.NEWS_RSS_FEEDS;
  if (!custom) return DEFAULT_FEEDS;
  return custom.split(",").map((entry, index) => ({
    name: `Source ${index + 1}`,
    url: entry.trim()
  })).filter((item) => item.url);
}

function validHttpUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
}

async function fetchFeed(source) {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12000);
    const response = await fetch(source.url, {
      signal: controller.signal,
      headers: { "User-Agent": "Ship-a-ton/1.0 financial-news-reader" }
    });
    clearTimeout(timeout);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const xml = await response.text();
    return parseXmlItems(xml, source).filter((item) => item.title && validHttpUrl(item.link));
  } catch (error) {
    console.warn(`News feed failed (${source.name}):`, error.message);
    return [];
  }
}

function dedupe(items) {
  const seen = new Set();
  return items.filter((item) => {
    const key = `${item.title.toLowerCase()}|${item.link}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function fallbackAnalysis(item) {
  const text = `${item.title} ${item.sourceSummary}`.toLowerCase();
  const sectors = [
    ["Technology", ["ai", "chip", "software", "cloud", "semiconductor", "cyber"]],
    ["Energy", ["oil", "gas", "energy", "solar", "wind", "battery"]],
    ["Financials", ["bank", "interest rate", "fed", "credit", "loan"]],
    ["Healthcare", ["drug", "health", "pharma", "biotech", "medical"]],
    ["Consumer", ["retail", "consumer", "restaurant", "shopping"]],
    ["Industrials", ["manufacturing", "factory", "airline", "shipping", "construction"]]
  ];
  const sector = sectors.find(([, words]) => words.some((word) => text.includes(word)))?.[0] || "Broad market";
  const positive = ["growth", "rise", "record", "beat", "expands", "strong", "surge", "approval"];
  const negative = ["fall", "decline", "cuts", "layoff", "slump", "weak", "warning", "tariff", "recall"];
  const pos = positive.filter((word) => text.includes(word)).length;
  const neg = negative.filter((word) => text.includes(word)).length;
  const marketSignal = pos > neg ? "tailwind" : neg > pos ? "headwind" : "uncertain";
  return {
    sector,
    marketSignal,
    overview: item.sourceSummary
      ? item.sourceSummary.slice(0, 320)
      : `Verified headline from ${item.source}: ${item.title}`,
    rationale: marketSignal === "uncertain"
      ? "The verified headline does not establish a clear directional market effect on its own."
      : `The reported development could be a ${marketSignal} for parts of the ${sector.toLowerCase()} sector, while actual market performance depends on many other factors.`
  };
}

async function analyzeWithAi(items) {
  if (!openai || items.length === 0) {
    return items.slice(0, 10).map((item) => ({ ...item, ...fallbackAnalysis(item) }));
  }

  const indexed = items.slice(0, 30).map((item, index) => ({
    index,
    title: item.title,
    source: item.source,
    publishedAt: item.publishedAt,
    sourceSummary: item.sourceSummary.slice(0, 500)
  }));

  const prompt = `
Select important business and industry news for a financial education app.
Use ONLY the supplied stories. Never invent a headline, source, publication time, or URL.
Return valid JSON only: an array with at most 10 objects.
Each object: index (integer from list), sector, marketSignal, rationale.
Do not write a new factual news summary. The app will display the verified RSS summary verbatim/trimmed.
marketSignal must be one of: tailwind, headwind, mixed, uncertain.
The signal is context, not a prediction or investment recommendation.
Favor broad economic/industry importance and avoid duplicates.
Stories: ${JSON.stringify(indexed)}
`;

  try {
    const response = await openai.responses.create({
      model: config.openAiModel,
      input: prompt,
      store: false
    });
    const raw = (response.output_text || "").trim()
      .replace(/^```json\s*/i, "")
      .replace(/```$/i, "")
      .trim();
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) throw new Error("AI news response was not an array");

    const validSignals = new Set(["tailwind", "headwind", "mixed", "uncertain"]);
    const used = new Set();
    const selected = [];
    for (const analysis of parsed) {
      const index = Number(analysis.index);
      if (!Number.isInteger(index) || index < 0 || index >= indexed.length || used.has(index)) continue;
      used.add(index);
      const source = items[index];
      selected.push({
        ...source,
        overview: fallbackAnalysis(source).overview,
        sector: cleanText(analysis.sector).slice(0, 80) || "Broad market",
        marketSignal: validSignals.has(analysis.marketSignal) ? analysis.marketSignal : "uncertain",
        rationale: cleanText(analysis.rationale).slice(0, 420) || fallbackAnalysis(source).rationale
      });
      if (selected.length === 10) break;
    }
    return selected.length
      ? selected
      : items.slice(0, 10).map((item) => ({ ...item, ...fallbackAnalysis(item) }));
  } catch (error) {
    console.warn("AI news analysis failed; using safe fallback:", error.message);
    return items.slice(0, 10).map((item) => ({ ...item, ...fallbackAnalysis(item) }));
  }
}

async function refreshNews() {
  if (refreshPromise) return refreshPromise;
  refreshPromise = (async () => {
    const chunks = await Promise.all(feedList().map(fetchFeed));
    const candidates = dedupe(chunks.flat()).sort(
      (a, b) => new Date(b.publishedAt || 0) - new Date(a.publishedAt || 0)
    );
    if (candidates.length === 0) {
      throw new Error("No verified RSS stories could be fetched");
    }
    const items = await analyzeWithAi(candidates);
    cache = { generatedAt: new Date().toISOString(), items };
    return cache;
  })().finally(() => {
    refreshPromise = null;
  });
  return refreshPromise;
}

async function getTopNews({ force = false } = {}) {
  const ageMs = cache.generatedAt
    ? Date.now() - new Date(cache.generatedAt).getTime()
    : Infinity;
  const stale = ageMs > config.newsRefreshHours * 60 * 60 * 1000;
  if (force || stale || cache.items.length === 0) return refreshNews();
  return cache;
}

function startNewsScheduler() {
  if (schedulerStarted) return;
  schedulerStarted = true;
  const interval = 24 * 60 * 60 * 1000;
  const timer = setInterval(() => {
    refreshNews().catch((error) => console.error("Scheduled news refresh failed:", error.message));
  }, interval);
  if (typeof timer.unref === "function") timer.unref();
}

module.exports = { getTopNews, refreshNews, startNewsScheduler };
