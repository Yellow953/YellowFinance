const { analyzeFinances } = require('./ai/analyzeFinances');
const { fetchPrices } = require('./market/fetchPrices');

exports.analyzeFinances = analyzeFinances;
exports.fetchPrices = fetchPrices;
