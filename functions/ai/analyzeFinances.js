const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const geminiApiKey = defineSecret('GEMINI_API_KEY');

// ── Helpers ────────────────────────────────────────────────────────────────

function categorySummary(transactions) {
  const map = {};
  transactions.filter(t => t.type === 'expense').forEach(t => {
    map[t.category] = (map[t.category] || 0) + t.amount;
  });
  return Object.entries(map)
    .sort((a, b) => b[1] - a[1])
    .map(([k, v]) => `${k}: $${(v / 100).toFixed(2)}`)
    .join(', ');
}

function periodSummary(transactions, label) {
  const income = transactions
    .filter(t => t.type === 'income')
    .reduce((s, t) => s + t.amount, 0);
  const expense = transactions
    .filter(t => t.type === 'expense')
    .reduce((s, t) => s + t.amount, 0);
  return `${label}: income $${(income / 100).toFixed(2)}, expenses $${(expense / 100).toFixed(2)}, net $${((income - expense) / 100).toFixed(2)}, top expense categories: [${categorySummary(transactions) || 'none'}]`;
}

// ── Context builders ───────────────────────────────────────────────────────

async function buildSpendingComparisonContext(userId) {
  const now = new Date();
  const startOfThisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);

  const [thisSnap, lastSnap] = await Promise.all([
    db.collection('users').doc(userId).collection('transactions')
      .where('date', '>=', admin.firestore.Timestamp.fromDate(startOfThisMonth))
      .get(),
    db.collection('users').doc(userId).collection('transactions')
      .where('date', '>=', admin.firestore.Timestamp.fromDate(startOfLastMonth))
      .where('date', '<', admin.firestore.Timestamp.fromDate(startOfThisMonth))
      .get(),
  ]);

  const thisTxns = thisSnap.docs.map(d => d.data());
  const lastTxns = lastSnap.docs.map(d => d.data());

  return `Monthly spending comparison:
- ${periodSummary(thisTxns, 'This month (current)')}
- ${periodSummary(lastTxns, 'Last month')}`;
}

async function buildMarketAnalysisContext(userId) {
  const portfolioSnap = await db.collection('users').doc(userId).collection('portfolio').get();
  const portfolio = portfolioSnap.docs.map(d => d.data());

  const pricesSnap = await db.collection('market_prices').get();
  const prices = pricesSnap.docs.map(d => ({ symbol: d.id, ...d.data() }));

  let ctx = '';

  if (prices.length > 0) {
    ctx += `Known asset prices (fetched periodically):\n`;
    ctx += prices.map(p => `${p.symbol}: $${p.price}`).join(', ') + '\n\n';
  }

  if (portfolio.length > 0) {
    ctx += `User already holds: ${portfolio.map(a => `${a.symbol} (${a.type})`).join(', ')}\n`;
  }

  return ctx || null;
}

// ── System prompts ─────────────────────────────────────────────────────────

const SYSTEM_PROMPTS = {
  general: 'You are a friendly AI assistant inside YellowFinance, a personal finance app. Have natural conversations and answer general finance questions. Do NOT volunteer analysis of the user\'s personal data unless they explicitly ask. Keep replies concise.',
  spending_comparison: 'You are a personal finance advisor. Be brief and direct. Max 4 bullet points: the biggest spending change, one area of concern, and one specific action to cut costs. No long paragraphs.',
  market_analysis: 'You are a financial investment advisor. Reply in this exact format, nothing more:\n\n**[TICKER]** — [Asset name]\n[2 sentences max: why this asset, why now.]\nEntry: [lump sum or DCA]\n\nOne pick only. No disclaimers, no extra paragraphs. If uncertain, pick VOO.',
  asset_analysis: 'You are a financial analyst. The user is viewing a specific asset\'s price chart. Using the chart data provided, give a concise analysis in exactly 3 bullet points: (1) current momentum/trend, (2) key levels based on the period high/low, (3) short-term outlook. Be specific with numbers. No disclaimers, no extra paragraphs.',
};

/**
 * Callable function: analyzeFinances
 * Accepts: { userId, prompt, analysisType?, history?, assetContext? }
 * Returns: { response: string }
 */
exports.analyzeFinances = onCall(
  { secrets: [geminiApiKey], invoker: 'public' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }

    const { userId, prompt, analysisType = 'general', assetContext = null, history = [] } = request.data;
    if (!userId || !prompt) {
      throw new HttpsError('invalid-argument', 'userId and prompt are required.');
    }
    if (request.auth.uid !== userId) {
      throw new HttpsError('permission-denied', 'Access denied.');
    }

    // Rate limit: 20 AI calls per user per calendar day.
    const today = new Date().toISOString().slice(0, 10); // "YYYY-MM-DD"
    const limitRef = db.collection('users').doc(userId).collection('ai_usage').doc(today);
    const limitSnap = await limitRef.get();
    const callCount = limitSnap.exists ? (limitSnap.data().count || 0) : 0;
    if (callCount >= 20) {
      throw new HttpsError('resource-exhausted', 'Daily AI call limit reached. Try again tomorrow.');
    }
    await limitRef.set({ count: callCount + 1 }, { merge: true });

    // Build financial context for the first turn / system instruction.
    let contextStr = null;
    if (analysisType === 'spending_comparison') {
      contextStr = await buildSpendingComparisonContext(userId);
    } else if (analysisType === 'market_analysis') {
      contextStr = await buildMarketAnalysisContext(userId);
    } else if (analysisType === 'asset_analysis' && assetContext) {
      contextStr = assetContext;
    }

    const baseSystemPrompt = SYSTEM_PROMPTS[analysisType] || SYSTEM_PROMPTS.general;
    const systemInstruction = contextStr
      ? `${baseSystemPrompt}\n\nFinancial context:\n${contextStr}`
      : baseSystemPrompt;

    const { GoogleGenerativeAI } = require('@google/generative-ai');
    const genAI = new GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({
      model: 'gemini-2.5-flash',
      systemInstruction,
    });

    // Convert Flutter history ({role, content}) to Gemini format.
    // Flutter uses 'assistant', Gemini expects 'model'.
    const geminiHistory = history.map(m => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: m.content }],
    }));

    const chat = model.startChat({ history: geminiHistory });
    const result = await chat.sendMessage(prompt);

    return { response: result.response.text() };
  }
);
