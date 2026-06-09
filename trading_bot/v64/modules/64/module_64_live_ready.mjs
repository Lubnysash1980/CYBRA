import fetch from 'node-fetch';

const SYMBOL = 'BTCUSDT';
console.log("🚀 CYBRA LIVE BOT RUNNING");
console.log("📈 Monitoring: " + SYMBOL);

while (true) {
  try {
    const res = await fetch(`https://fapi.binance.com/fapi/v1/ticker/price?symbol=${SYMBOL}`);
    const data = await res.json();
    console.log(`[${new Date().toISOString()}] ${SYMBOL}: $${data.price}`);
    await new Promise(r => setTimeout(r, 5000));
  } catch(e) {
    console.error("Error:", e.message);
    await new Promise(r => setTimeout(r, 1000));
  }
}
