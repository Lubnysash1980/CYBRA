import fetch from 'node-fetch';
import crypto from 'crypto';
import fs from 'fs';

const SYMBOL = 'BTCUSDT';
const QUANTITY = 0.001;
const STOP_LOSS_PERCENT = 1.0;
const TAKE_PROFIT_PERCENT = 1.5;

// Завантаження API ключів
let API_KEY, API_SECRET;
try {
  const secrets = JSON.parse(fs.readFileSync(process.env.HOME + '/CYBRA/.cybra_local_secret/exchanges/bybit_live.json', 'utf8'));
  API_KEY = secrets.api_key;
  API_SECRET = secrets.api_secret;
  console.log("✅ API keys loaded");
} catch(e) {
  console.log("❌ API keys not found:", e.message);
  process.exit(1);
}

let position = null;
let lastPrice = 0;

function signRequest(params) {
  const timestamp = Date.now().toString();
  const queryString = new URLSearchParams(params).toString();
  const signature = crypto.createHmac('sha256', API_SECRET)
    .update(timestamp + API_KEY + '20000' + queryString)
    .digest('hex');
  return { timestamp, signature };
}

async function bybitRequest(endpoint, params = {}, method = 'GET') {
  const { timestamp, signature } = signRequest(params);
  const url = `https://api.bybit.com${endpoint}?${new URLSearchParams(params).toString()}`;
  
  const response = await fetch(url, {
    method,
    headers: {
      'X-BAPI-API-KEY': API_KEY,
      'X-BAPI-TIMESTAMP': timestamp,
      'X-BAPI-SIGN': signature,
      'X-BAPI-RECV-WINDOW': '20000'
    }
  });
  
  const data = await response.json();
  if (data.retCode !== 0) throw new Error(data.retMsg);
  return data.result;
}

async function getPrice() {
  const res = await fetch(`https://api.bybit.com/v5/market/tickers?category=linear&symbol=${SYMBOL}`);
  const data = await res.json();
  lastPrice = parseFloat(data.result.list[0].lastPrice);
  return lastPrice;
}

async function getBalance() {
  try {
    const result = await bybitRequest('/v5/account/wallet-balance', {
      accountType: 'UNIFIED',
      coin: 'USDT'
    });
    return parseFloat(result.list[0].coin[0].walletBalance);
  } catch(e) {
    return 0;
  }
}

async function placeOrder(side, qty) {
  console.log(`📊 ${side} ${qty} BTC`);
  const result = await bybitRequest('/v5/order/create', {
    category: 'linear',
    symbol: SYMBOL,
    side: side,
    orderType: 'Market',
    qty: qty.toString(),
    timeInForce: 'GTC'
  }, 'POST');
  return result;
}

async function run() {
  console.log("══════════════════════════════════════");
  console.log("🚀 CYBRA LIVE TRADER (BYBIT)");
  console.log("══════════════════════════════════════");
  console.log(`📊 ${SYMBOL} | ${QUANTITY} BTC | SL:${STOP_LOSS_PERCENT}% | TP:${TAKE_PROFIT_PERCENT}%`);
  
  const balance = await getBalance();
  console.log(`💰 Balance: ${balance} USDT`);
  
  while (true) {
    try {
      const price = await getPrice();
      console.log(`[${new Date().toISOString()}] $${price}`);
      
      if (!position) {
        if (price < 63000) {
          console.log(`🔵 OPEN LONG at $${price}`);
          const order = await placeOrder('Buy', QUANTITY);
          position = { side: 'long', entryPrice: price, quantity: QUANTITY };
          console.log(`✅ LONG OPENED`);
        } else if (price > 64500) {
          console.log(`🔴 OPEN SHORT at $${price}`);
          const order = await placeOrder('Sell', QUANTITY);
          position = { side: 'short', entryPrice: price, quantity: QUANTITY };
          console.log(`✅ SHORT OPENED`);
        }
      }
      
      await new Promise(r => setTimeout(r, 10000));
    } catch (err) {
      console.error("❌", err.message);
      await new Promise(r => setTimeout(r, 5000));
    }
  }
}

run().catch(console.error);
