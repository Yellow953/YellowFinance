const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const DAILY_LIMIT = 20;
const geminiApiKey = defineSecret('GEMINI_API_KEY');

/**
 * Callable function: analyzeFinances
 * Accepts: { userId, prompt }
 * - Checks daily rate limit
 * - Fetches last 90 days of transactions + portfolio
 * - Calls Gemini API with financial context + user prompt
 * - Returns { response: string }
 */
exports.analyzeFinances = onCall({ secrets: [geminiApiKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const { userId, prompt } = request.data;
  if (!userId || !prompt) {
    throw new HttpsError('invalid-argument', 'userId and prompt are required.');
  }
  if (request.auth.uid !== userId) {
    throw new HttpsError('permission-denied', 'Access denied.');
  }

  // Rate limit check
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const convSnap = await db
    .collection('users').doc(userId).collection('ai_conversations')
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(today))
    .get();
  if (convSnap.size >= DAILY_LIMIT) {
    throw new HttpsError('resource-exhausted', 'Daily AI limit reached.');
  }

  // Fetch last 90 days of transactions
  const since = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
  const txnSnap = await db
    .collection('users').doc(userId).collection('transactions')
    .where('date', '>=', admin.firestore.Timestamp.fromDate(since))
    .orderBy('date', 'desc')
    .limit(200)
    .get();

  const transactions = txnSnap.docs.map(d => d.data());
  const income = transactions.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
  const expense = transactions.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);

  // Category breakdown
  const categories = {};
  transactions.filter(t => t.type === 'expense').forEach(t => {
    categories[t.category] = (categories[t.category] || 0) + t.amount;
  });

  // Fetch portfolio
  const portfolioSnap = await db.collection('users').doc(userId).collection('portfolio').get();
  const portfolio = portfolioSnap.docs.map(d => d.data());

  const contextSummary = `
User's last 90 days financial summary (amounts in cents):
- Total income: ${income} cents ($${(income / 100).toFixed(2)})
- Total expenses: ${expense} cents ($${(expense / 100).toFixed(2)})
- Net: ${income - expense} cents ($${((income - expense) / 100).toFixed(2)})
- Top expense categories: ${Object.entries(categories).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([k, v]) => `${k}: $${(v / 100).toFixed(2)}`).join(', ')}
- Portfolio assets: ${portfolio.map(a => `${a.symbol} (${a.type}): qty ${a.quantity} @ avg $${a.avgBuyPrice}`).join(', ') || 'none'}
`;

  // Call Gemini API
  const { GoogleGenerativeAI } = require('@google/generative-ai');
  const genAI = new GoogleGenerativeAI(geminiApiKey.value());
  const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

  const fullPrompt = `You are a personal finance advisor. Here is the user's financial context:\n${contextSummary}\n\nUser question: ${prompt}\n\nProvide a helpful, concise, and actionable response.`;

  const result = await model.generateContent(fullPrompt);
  const response = result.response.text();

  return { response };
});
