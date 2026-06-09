#!/bin/bash
set -e
echo "🚀 CYBRA LIVE TRADER DEPLOY"
cd ~
git clone https://github.com/cybra-ai/cybra.git CYBRA 2>/dev/null || cd CYBRA && git pull
cd CYBRA
mkdir -p .cybra_local_secret/exchanges trading_bot/v64/modules/64 logs
cat > trading_bot/v64/modules/64/live_trader.mjs <<'BOT'
import fetch from 'node-fetch';
import crypto from 'crypto';
import fs from 'fs';
const SYMBOL = 'BTCUSDT';
const QTY = 0.001;
const SL = 1.0;
const TP = 1.5;
let keys, position = null;
try {
  keys = JSON.parse(fs.readFileSync(process.env.HOME + '/CYBRA/.cybra_local_secret/bybit.json', 'utf8'));
} catch(e) {
  console.log("❌ Create ~/CYBRA/.cybra_local_secret/bybit.json with {api_key,api_secret}");
  process.exit(1);
}
function sign(p) {
  const ts = Date.now().toString();
  const qs = new URLSearchParams(p).toString();
  const sig = crypto.createHmac('sha256', keys.api_secret).update(ts + keys.api_key + '20000' + qs).digest('hex');
  return { ts, sig };
}
async function req(endpoint, p = {}, method = 'GET') {
  const { ts, sig } = sign(p);
  const url = `https://api.bybit.com${endpoint}?${new URLSearchParams(p)}`;
  const res = await fetch(url, {
    method,
    headers: { 'X-BAPI-API-KEY': keys.api_key, 'X-BAPI-TIMESTAMP': ts, 'X-BAPI-SIGN': sig, 'X-BAPI-RECV-WINDOW': '20000' }
  });
  const data = await res.json();
  if (data.retCode !== 0) throw new Error(data.retMsg);
  return data.result;
}
async function price() {
  const res = await fetch(`https://api.bybit.com/v5/market/tickers?category=linear&symbol=${SYMBOL}`);
  return parseFloat((await res.json()).result.list[0].lastPrice);
}
async function balance() {
  try {
    const r = await req('/v5/account/wallet-balance', { accountType: 'UNIFIED', coin: 'USDT' });
    return parseFloat(r.list[0].coin[0].walletBalance);
  } catch(e) { return 0; }
}
async function order(side) {
  console.log(`📊 ${side} ${QTY} BTC`);
  return await req('/v5/order/create', { category: 'linear', symbol: SYMBOL, side, orderType: 'Market', qty: QTY.toString(), timeInForce: 'GTC' }, 'POST');
}
console.log("🚀 CYBRA LIVE");
let bal = await balance();
console.log(`💰 Balance: ${bal} USDT`);
while (true) {
  try {
    let p = await price();
    console.log(`[${new Date().toISOString()}] $${p}`);
    if (!position && bal > 10) {
      if (p < 63000) { await order('Buy'); position = 'long'; console.log("✅ LONG"); }
      else if (p > 64500) { await order('Sell'); position = 'short'; console.log("✅ SHORT"); }
    }
    await new Promise(r => setTimeout(r, 10000));
  } catch(e) { console.error(e.message); await new Promise(r => setTimeout(r, 5000)); }
}
BOT
echo "✅ Deployed. Create ~/CYBRA/.cybra_local_secret/bybit.json"
echo '{"api_key":"YOUR_KEY","api_secret":"YOUR_SECRET"}' > ~/CYBRA/.cybra_local_secret/bybit.json.example
echo ""
echo "══════════════════════════════════════"
echo "🚀 ЄДИНА КОМАНДА ЗАПУСКУ:"
echo "══════════════════════════════════════"
echo ""
echo "cd ~/CYBRA && node trading_bot/v64/modules/64/live_trader.mjs"
echo ""
