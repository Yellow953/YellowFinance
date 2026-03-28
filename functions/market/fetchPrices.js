const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const https = require('https');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

/**
 * Scheduled function: fetchPrices
 * Runs every 15 minutes.
 * - Collects all unique symbols from all user portfolios
 * - Fetches prices from CoinGecko (crypto) or a stocks API
 * - Writes to market_prices/{symbol} collection
 */
exports.fetchPrices = onSchedule('every 15 minutes', async () => {
  // Collect all unique symbols from all portfolios
  const portfolioSnap = await db.collectionGroup('portfolio').get();
  const symbolMap = {};
  portfolioSnap.docs.forEach(doc => {
    const { symbol, type } = doc.data();
    if (symbol) symbolMap[symbol.toUpperCase()] = type;
  });

  const symbols = Object.keys(symbolMap);
  if (symbols.length === 0) return null;

  const cryptoSymbols = symbols.filter(s =>
    ['crypto'].includes(symbolMap[s])
  );

  // Fetch crypto prices from CoinGecko
  if (cryptoSymbols.length > 0) {
    const ids = cryptoSymbols.map(s => s.toLowerCase()).join(',');
    const url = `https://api.coingecko.com/api/v3/simple/price?ids=${ids}&vs_currencies=usd`;

    await new Promise((resolve, reject) => {
      https.get(url, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', async () => {
          try {
            const prices = JSON.parse(data);
            const batch = db.batch();
            for (const [id, priceData] of Object.entries(prices)) {
              const symbol = id.toUpperCase();
              batch.set(db.collection('market_prices').doc(symbol), {
                price: priceData.usd,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
            await batch.commit();
            resolve();
          } catch (e) {
            reject(e);
          }
        });
      }).on('error', reject);
    });
  }

  return null;
});
