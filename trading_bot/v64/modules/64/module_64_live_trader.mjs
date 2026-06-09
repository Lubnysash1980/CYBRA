import fetch from 'node-fetch';
import crypto from 'crypto';
import fs from 'fs';

// ===== КОНФІГ =====
const SYMBOL = 'BTCUSDT';
const QUANTITY = 0.001; // 0.001 BTC ~ $63
const LEVERAGE = 1;
const STOP_LOSS_PERCENT = 1.0;
const TAKE_PROFIT_PERCENT = 1.5;

// Завантаження API ключів
const secrets = JSON.parse(fs.readFileSync(process.env.HOME + '/CYBRA/.cybra_local_secret/exchanges/binance_live.json', 'utf8'));
const API_KEY = secrets.api_key;
const API_SECRET = secrets.api_secret;

let position = null;
let lastPrice = 0;

// ===== ФУНКЦІЇ =====
function signRequest(params) {
  const queryString = new URLSearchParams(params).toString();
  const signature = crypto.createHmac('sha256', API_SECRET).update(queryString).digest('hex');
  return { queryString, signature };
}

async function binanceRequest(endpoint, params = {}, method = 'GET') {
  const timestamp = Date.now();
  params.timestamp = timestamp;
  params.recvWindow = 5000;
  
  const { queryString, signature } = signRequest(params);
  const url = `https://fapi.binance.com${endpoint}?${queryString}&signature=${signature}`;
  
  const response = await fetch(url, {
    method,
    headers: { 'X-MBX-APIKEY': API_KEY }
  });
  
  const data = await response.json();
  if (!response.ok) throw new Error(data.msg || JSON.stringify(data));
  return data;
}

async function getPrice() {
  const res = await fetch(`https://fapi.binance.com/fapi/v1/ticker/price?symbol=${SYMBOL}`);
  const data = await res.json();
  lastPrice = parseFloat(data.price);
  return lastPrice;
}

async function getBalance() {
  try {
    const account = await binanceRequest('/fapi/v2/account', {});
    const asset = account.assets.find(a => a.asset === 'USDT');
    return parseFloat(asset.walletBalance);
  } catch(e) {
    console.log("⚠️ Cannot get balance:", e.message);
    return 0;
  }
}

async function openLong(price) {
  console.log(`🔵 OPENING LONG at $${price}`);
  try {
    const order = await binanceRequest('/fapi/v1/order', {
      symbol: SYMBOL,
      side: 'BUY',
      type: 'MARKET',
      quantity: QUANTITY
    }, 'POST');
    
    position = {
      side: 'long',
      entryPrice: price,
      quantity: QUANTITY,
      stopLoss: price * (1 - STOP_LOSS_PERCENT / 100),
      takeProfit: price * (1 + TAKE_PROFIT_PERCENT / 100),
      orderId: order.orderId
    };
    
    console.log(`✅ LONG OPENED | Entry: $${price} | SL: $${position.stopLoss} | TP: $${position.takeProfit}`);
    return true;
  } catch(e) {
    console.log(`❌ Failed to open long: ${e.message}`);
    return false;
  }
}

async function openShort(price) {
  console.log(`🔴 OPENING SHORT at $${price}`);
  try {
    const order = await binanceRequest('/fapi/v1/order', {
      symbol: SYMBOL,
      side: 'SELL',
      type: 'MARKET',
      quantity: QUANTITY
    }, 'POST');
    
    position = {
      side: 'short',
      entryPrice: price,
      quantity: QUANTITY,
      stopLoss: price * (1 + STOP_LOSS_PERCENT / 100),
      takeProfit: price * (1 - TAKE_PROFIT_PERCENT / 100),
      orderId: order.orderId
    };
    
    console.log(`✅ SHORT OPENED | Entry: $${price} | SL: $${position.stopLoss} | TP: $${position.takeProfit}`);
    return true;
  } catch(e) {
    console.log(`❌ Failed to open short: ${e.message}`);
    return false;
  }
}

async function closePosition(price, reason) {
  if (!position) return;
  
  console.log(`🔒 CLOSING ${position.side.toUpperCase()} | Reason: ${reason} | Price: $${price}`);
  
  try {
    const side = position.side === 'long' ? 'SELL' : 'BUY';
    const order = await binanceRequest('/fapi/v1/order', {
      symbol: SYMBOL,
      side: side,
      type: 'MARKET',
      quantity: position.quantity
    }, 'POST');
    
    const pnl = position.side === 'long' 
      ? (price - position.entryPrice) * position.quantity
      : (position.entryPrice - price) * position.quantity;
    
    console.log(`✅ POSITION CLOSED | PnL: $${pnl.toFixed(2)} USDT`);
    position = null;
    return true;
  } catch(e) {
    console.log(`❌ Failed to close: ${e.message}`);
    return false;
  }
}

async function checkPosition() {
  if (!position) return;
  
  const price = lastPrice;
  
  if (position.side === 'long') {
    if (price <= position.stopLoss) {
      await closePosition(price, 'STOP LOSS');
    } else if (price >= position.takeProfit) {
      await closePosition(price, 'TAKE PROFIT');
    }
  } else {
    if (price >= position.stopLoss) {
      await closePosition(price, 'STOP LOSS');
    } else if (price <= position.takeProfit) {
      await closePosition(price, 'TAKE PROFIT');
    }
  }
}

async function simpleStrategy(price) {
  // Проста стратегія: RSI приблизний через зміну ціни
  const sma = []; // спрощено для демо
  
  if (!position) {
    // Купуємо при відскоку від підтримки
    if (price < 63000) {
      await openLong(price);
    }
    // Продаємо при зростанні до опору
    else if (price > 64500) {
      await openShort(price);
    }
  }
  
  await checkPosition();
}

// ===== MAIN LOOP =====
async function run() {
  console.log("══════════════════════════════════════");
  console.log("🚀 CYBRA LIVE TRADER STARTED");
  console.log("══════════════════════════════════════");
  console.log(`📊 Symbol: ${SYMBOL}`);
  console.log(`📊 Quantity: ${QUANTITY} BTC (~${QUANTITY * 63000} USDT)`);
  console.log(`📊 Stop Loss: ${STOP_LOSS_PERCENT}%`);
  console.log(`📊 Take Profit: ${TAKE_PROFIT_PERCENT}%`);
  console.log("");
  
  const balance = await getBalance();
  console.log(`💰 Balance: ${balance} USDT`);
  console.log("");
  
  while (true) {
    try {
      const price = await getPrice();
      console.log(`[${new Date().toISOString()}] ${SYMBOL}: $${price}`);
      
      await simpleStrategy(price);
      
      await new Promise(r => setTimeout(r, 10000)); // кожні 10 секунд
    } catch (err) {
      console.error("❌ Error:", err.message);
      await new Promise(r => setTimeout(r, 5000));
    }
  }
}

// Обробка завершення
process.on('SIGINT', async () => {
  console.log("\n🛑 Shutting down...");
  if (position) {
    await closePosition(lastPrice, 'MANUAL SHUTDOWN');
  }
  process.exit(0);
});

run().catch(console.error);
