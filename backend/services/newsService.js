const OpenAI = require("openai");
const config = require("../config");

const openai = process.env.OPENAI_API_KEY
  ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY })
  : null;

const DEFAULT_FEEDS = [
  {
    name: "BBC Business",
    url: "https://feeds.bbci.co.uk/news/business/rss.xml"
  },
  {
    name: "BBC Technology",
    url: "https://feeds.bbci.co.uk/news/technology/rss.xml"
  },
  {
    name: "NPR Business",
    url: "https://feeds.npr.org/1006/rss.xml"
  },
  {
    name: "CNBC Top News",
    url: "https://www.cnbc.com/id/100003114/device/rss/rss.html"
  },
  {
    name: "MarketWatch Top Stories",
    url: "https://feeds.marketwatch.com/marketwatch/topstories/"
  }
];

let cache = {
  generatedAt: null,
  items: []
};

let refreshPromise = null;
let schedulerStarted = false;


// ------------------------------------------------------------
// TEXT / XML HELPERS
// ------------------------------------------------------------

function decodeEntities(value = "") {
  return String(value)
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(
      /&#(\d+);/g,
      (_, code) => String.fromCharCode(Number(code))
    );
}


function cleanText(value = "") {
  return decodeEntities(value)
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}


function tagValue(block, tag) {
  const match = block.match(
    new RegExp(
      `<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${tag}>`,
      "i"
    )
  );

  return match ? match[1] : "";
}


function atomLink(block) {
  const match = block.match(
    /<link[^>]+href=["']([^"']+)["'][^>]*>/i
  );

  return match ? match[1] : "";
}


function parseXmlItems(xml, source) {
  const rssItems =
    xml.match(/<item\b[\s\S]*?<\/item>/gi) || [];

  const atomEntries =
    xml.match(/<entry\b[\s\S]*?<\/entry>/gi) || [];

  return [...rssItems, ...atomEntries].map((block) => {
    const title = cleanText(
      tagValue(block, "title")
    );

    const link =
      cleanText(tagValue(block, "link")) ||
      atomLink(block);

    const publishedAt =
      cleanText(tagValue(block, "pubDate")) ||
      cleanText(tagValue(block, "published")) ||
      cleanText(tagValue(block, "updated")) ||
      null;

    const sourceSummary = cleanText(
      tagValue(block, "description") ||
      tagValue(block, "summary") ||
      tagValue(block, "content:encoded") ||
      tagValue(block, "content")
    );

    return {
      title,
      source: source.name,
      link,
      publishedAt,
      sourceSummary
    };
  });
}


// ------------------------------------------------------------
// FEEDS
// ------------------------------------------------------------

function feedList() {
  const custom = process.env.NEWS_RSS_FEEDS;

  if (!custom) {
    return DEFAULT_FEEDS;
  }

  return custom
    .split(",")
    .map((entry, index) => ({
      name: `Source ${index + 1}`,
      url: entry.trim()
    }))
    .filter((item) => item.url);
}


function validHttpUrl(value) {
  try {
    const url = new URL(value);

    return (
      url.protocol === "https:" ||
      url.protocol === "http:"
    );
  } catch {
    return false;
  }
}


async function fetchFeed(source) {
  try {
    const controller = new AbortController();

    const timeout = setTimeout(
      () => controller.abort(),
      12000
    );

    const response = await fetch(source.url, {
      signal: controller.signal,
      headers: {
        "User-Agent":
          "Ship-a-ton/1.0 financial-news-reader"
      }
    });

    clearTimeout(timeout);

    if (!response.ok) {
      throw new Error(
        `HTTP ${response.status}`
      );
    }

    const xml = await response.text();

    return parseXmlItems(xml, source)
      .filter(
        (item) =>
          item.title &&
          validHttpUrl(item.link)
      );
  } catch (error) {
    console.warn(
      `News feed failed (${source.name}):`,
      error.message
    );

    return [];
  }
}


// ------------------------------------------------------------
// DEDUPLICATION
// ------------------------------------------------------------

function dedupe(items) {
  const seen = new Set();

  return items.filter((item) => {
    const normalizedTitle = item.title
      .toLowerCase()
      .replace(/[^\w\s]/g, "")
      .replace(/\s+/g, " ")
      .trim();

    const key =
      `${normalizedTitle}|${item.link}`;

    if (seen.has(key)) {
      return false;
    }

    seen.add(key);
    return true;
  });
}


// ------------------------------------------------------------
// STOCK-MARKET RELEVANCE
// ------------------------------------------------------------

function marketRelevanceScore(item) {
  const text =
    `${item.title} ${item.sourceSummary}`
      .toLowerCase();

  const highImpactTerms = [
    "federal reserve",
    "fed ",
    "interest rate",
    "interest rates",
    "rate cut",
    "rate cuts",
    "rate hike",
    "rate hikes",

    "inflation",
    "consumer price index",
    "cpi",
    "pce",
    "jobs report",
    "payroll",
    "unemployment",
    "gdp",
    "recession",

    "earnings",
    "quarterly results",
    "revenue",
    "profit",
    "profits",
    "guidance",
    "forecast",
    "outlook",

    "merger",
    "acquisition",
    "takeover",
    "ipo",
    "initial public offering",

    "sec ",
    "securities and exchange commission",
    "antitrust",
    "regulator",
    "regulatory",

    "tariff",
    "tariffs",
    "sanction",
    "sanctions",

    "oil prices",
    "crude oil",
    "opec",
    "natural gas",

    "bond yield",
    "bond yields",
    "treasury yield",
    "treasury yields"
  ];

  const marketTerms = [
    "stock",
    "stocks",
    "share price",
    "shares",
    "equity",
    "equities",

    "s&p 500",
    "s&p",
    "nasdaq",
    "dow",
    "dow jones",
    "wall street",

    "market",
    "markets",
    "investor",
    "investors",

    "semiconductor",
    "semiconductors",
    "chip",
    "chips",

    "artificial intelligence",
    " ai ",
    "cloud",

    "bank",
    "banks",
    "banking",

    "technology",
    "energy",
    "pharma",
    "biotech",

    "automaker",
    "automotive",
    "airline",

    "retail",
    "consumer spending",

    "bitcoin",
    "crypto",
    "gold",
    "commodity",
    "commodities"
  ];

  const lowValueTerms = [
    "celebrity",
    "lifestyle",
    "recipe",
    "travel tips",
    "shopping guide",
    "gift guide",
    "how to save money",
    "personal finance tips",
    "best credit card",
    "mortgage tips"
  ];

  let score = 0;

  for (const term of highImpactTerms) {
    if (text.includes(term)) {
      score += 3;
    }
  }

  for (const term of marketTerms) {
    if (text.includes(term)) {
      score += 1;
    }
  }

  for (const term of lowValueTerms) {
    if (text.includes(term)) {
      score -= 4;
    }
  }

  return score;
}


// ------------------------------------------------------------
// SAFE FALLBACK ANALYSIS
// Used if OpenAI is unavailable or analysis fails.
// ------------------------------------------------------------

function fallbackAnalysis(item) {
  const text =
    `${item.title} ${item.sourceSummary}`
      .toLowerCase();

  const sectors = [
    [
      "Technology",
      [
        "artificial intelligence",
        "ai",
        "chip",
        "semiconductor",
        "software",
        "cloud",
        "cyber"
      ]
    ],

    [
      "Energy",
      [
        "oil",
        "gas",
        "energy",
        "solar",
        "wind",
        "battery",
        "opec"
      ]
    ],

    [
      "Financials",
      [
        "bank",
        "interest rate",
        "federal reserve",
        "fed",
        "credit",
        "loan",
        "treasury"
      ]
    ],

    [
      "Healthcare",
      [
        "drug",
        "health",
        "pharma",
        "biotech",
        "medical"
      ]
    ],

    [
      "Consumer",
      [
        "retail",
        "consumer",
        "restaurant",
        "shopping"
      ]
    ],

    [
      "Industrials",
      [
        "manufacturing",
        "factory",
        "airline",
        "shipping",
        "construction"
      ]
    ]
  ];

  const sector =
    sectors.find(([, words]) =>
      words.some((word) =>
        text.includes(word)
      )
    )?.[0] ||
    "Broad market";

  const positive = [
    "growth",
    "rise",
    "rises",
    "record",
    "beat",
    "beats",
    "expands",
    "strong",
    "surge",
    "surges",
    "approval",
    "raises guidance"
  ];

  const negative = [
    "fall",
    "falls",
    "decline",
    "declines",
    "cuts",
    "layoff",
    "layoffs",
    "slump",
    "weak",
    "warning",
    "tariff",
    "recall",
    "misses",
    "miss"
  ];

  const pos =
    positive.filter((word) =>
      text.includes(word)
    ).length;

  const neg =
    negative.filter((word) =>
      text.includes(word)
    ).length;

  const marketSignal =
    pos > neg
      ? "tailwind"
      : neg > pos
        ? "headwind"
        : "uncertain";

  const overview = item.sourceSummary
    ? item.sourceSummary.slice(0, 320)
    : `Verified headline from ${item.source}: ${item.title}`;

  const rationale =
    marketSignal === "uncertain"
      ? "The verified story may be relevant to financial markets, but the supplied information does not establish a clear directional effect."
      : `The reported development could be a ${marketSignal} for parts of the ${sector.toLowerCase()} sector, while actual market performance depends on many other factors.`;

  return {
    sector,
    marketSignal,
    overview,
    rationale
  };
}


// ------------------------------------------------------------
// AI MARKET-NEWS ANALYSIS
// ------------------------------------------------------------

async function analyzeWithAi(items) {
  if (!openai || items.length === 0) {
    return items
      .slice(0, 10)
      .map((item) => ({
        ...item,
        ...fallbackAnalysis(item)
      }));
  }

  const indexed = items
    .slice(0, 30)
    .map((item, index) => ({
      index,
      title: item.title,
      source: item.source,
      publishedAt: item.publishedAt,
      sourceSummary:
        String(item.sourceSummary || "")
          .slice(0, 500)
    }));

  const prompt = `
You are selecting MARKET-MOVING financial news for a stock-market
awareness section inside a financial education app.

Use ONLY the supplied verified RSS stories.

Your job is to choose stories that could materially affect:

- individual publicly traded companies
- stock-market sectors
- major stock indexes
- interest-rate expectations
- bond yields
- commodities
- investor sentiment
- the broader economy in ways relevant to financial markets

PRIORITIZE:

1. Earnings reports, revenue, profit, guidance, or major forecasts
2. Federal Reserve decisions and interest-rate expectations
3. Inflation, CPI, PCE, jobs, unemployment, GDP, and recession data
4. Major stock-price or index-relevant company developments
5. Mergers, acquisitions, IPOs, and major corporate restructurings
6. SEC, antitrust, regulatory, tariff, or sanctions developments
7. Semiconductor, AI, cloud, and major technology developments
8. Oil, energy, commodity, and supply shocks
9. Banking and credit-market developments
10. Geopolitical events with a clear financial-market connection

AVOID:

- lifestyle stories
- generic technology news with no clear financial-market relevance
- personal finance tips
- celebrity or business-personality stories
- minor product announcements
- general-interest news with no plausible market effect
- duplicate versions of the same event

IMPORTANT:

Do not assume that a news event guarantees a stock-price move.

Use:

- "tailwind" when the supplied story describes factors that could
  reasonably support a company, sector, asset, or market

- "headwind" when the supplied story describes factors that could
  reasonably pressure a company, sector, asset, or market

- "mixed" when meaningful positive and negative implications coexist

- "uncertain" when direction cannot responsibly be inferred

Return VALID JSON ONLY.

Return an array containing at most 10 objects.

Each object must contain exactly:

{
  "index": 0,
  "sector": "Affected company, sector, asset class, or Broad market",
  "marketSignal": "tailwind",
  "rationale": "One concise explanation of why this verified event could matter to financial markets."
}

The index must correspond to a supplied story.

marketSignal must be exactly one of:

tailwind
headwind
mixed
uncertain

Never invent:

- a headline
- company
- event
- source
- publication time
- financial result
- stock movement
- URL

The market signal is context only.
It is NOT a prediction.
It is NOT an investment recommendation.

Choose the most financially consequential stories first.

Stories:

${JSON.stringify(indexed)}
`;

  try {
    const response =
      await openai.responses.create({
        model: config.openAiModel,
        input: prompt,
        store: false
      });

    const raw =
      (response.output_text || "")
        .trim()
        .replace(/^```json\s*/i, "")
        .replace(/^```\s*/i, "")
        .replace(/```$/i, "")
        .trim();

    const parsed = JSON.parse(raw);

    if (!Array.isArray(parsed)) {
      throw new Error(
        "AI news response was not an array"
      );
    }

    const validSignals =
      new Set([
        "tailwind",
        "headwind",
        "mixed",
        "uncertain"
      ]);

    const used = new Set();
    const selected = [];

    for (const analysis of parsed) {
      const index =
        Number(analysis.index);

      if (
        !Number.isInteger(index) ||
        index < 0 ||
        index >= indexed.length ||
        used.has(index)
      ) {
        continue;
      }

      used.add(index);

      const source =
        items[index];

      const fallback =
        fallbackAnalysis(source);

      selected.push({
        ...source,

        overview:
          fallback.overview,

        sector:
          cleanText(
            analysis.sector
          ).slice(0, 80) ||
          "Broad market",

        marketSignal:
          validSignals.has(
            analysis.marketSignal
          )
            ? analysis.marketSignal
            : "uncertain",

        rationale:
          cleanText(
            analysis.rationale
          ).slice(0, 420) ||
          fallback.rationale
      });

      if (selected.length === 10) {
        break;
      }
    }

    return selected.length
      ? selected
      : items
          .slice(0, 10)
          .map((item) => ({
            ...item,
            ...fallbackAnalysis(item)
          }));
  } catch (error) {
    console.warn(
      "AI news analysis failed; using safe fallback:",
      error.message
    );

    return items
      .slice(0, 10)
      .map((item) => ({
        ...item,
        ...fallbackAnalysis(item)
      }));
  }
}


// ------------------------------------------------------------
// NEWS REFRESH
// ------------------------------------------------------------

async function refreshNews() {
  if (refreshPromise) {
    return refreshPromise;
  }

  refreshPromise = (async () => {
    const chunks =
      await Promise.all(
        feedList().map(fetchFeed)
      );

    const allStories =
      dedupe(chunks.flat());

    const candidates =
      allStories
        .map((item) => ({
          ...item,
          relevanceScore:
            marketRelevanceScore(item)
        }))

        // Remove stories with no meaningful
        // detected market relevance.
        .filter(
          (item) =>
            item.relevanceScore > 0
        )

        // Market relevance first,
        // freshness second.
        .sort((a, b) => {
          if (
            b.relevanceScore !==
            a.relevanceScore
          ) {
            return (
              b.relevanceScore -
              a.relevanceScore
            );
          }

          return (
            new Date(
              b.publishedAt || 0
            ) -
            new Date(
              a.publishedAt || 0
            )
          );
        });

    if (allStories.length === 0) {
      throw new Error(
        "No verified RSS stories could be fetched"
      );
    }

    /*
     * If our keyword filter happens to be too
     * restrictive on a particular news cycle,
     * fall back to the freshest verified stories
     * and allow the AI analysis to select them.
     */
    const analysisPool =
      candidates.length > 0
        ? candidates
        : allStories.sort(
            (a, b) =>
              new Date(
                b.publishedAt || 0
              ) -
              new Date(
                a.publishedAt || 0
              )
          );

    const items =
      await analyzeWithAi(
        analysisPool
      );

    cache = {
      generatedAt:
        new Date().toISOString(),

      items
    };

    return cache;
  })().finally(() => {
    refreshPromise = null;
  });

  return refreshPromise;
}


// ------------------------------------------------------------
// PUBLIC API
// ------------------------------------------------------------

async function getTopNews({
  force = false
} = {}) {
  const ageMs =
    cache.generatedAt
      ? Date.now() -
        new Date(
          cache.generatedAt
        ).getTime()
      : Infinity;

  const stale =
    ageMs >
    config.newsRefreshHours *
      60 *
      60 *
      1000;

  if (
    force ||
    stale ||
    cache.items.length === 0
  ) {
    return refreshNews();
  }

  return cache;
}


// ------------------------------------------------------------
// SCHEDULER
// ------------------------------------------------------------

function startNewsScheduler() {
  if (schedulerStarted) {
    return;
  }

  schedulerStarted = true;

  const interval =
    24 * 60 * 60 * 1000;

  const timer =
    setInterval(() => {
      refreshNews().catch(
        (error) =>
          console.error(
            "Scheduled news refresh failed:",
            error.message
          )
      );
    }, interval);

  if (
    typeof timer.unref ===
    "function"
  ) {
    timer.unref();
  }
}


// ------------------------------------------------------------
// EXPORTS
// ------------------------------------------------------------

module.exports = {
  getTopNews,
  refreshNews,
  startNewsScheduler
};