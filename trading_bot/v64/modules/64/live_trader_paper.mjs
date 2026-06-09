import fetch from 'node-fetch';
import fs from 'fs';

const SYMBOL = 'BTCUSDT';
const QUANTITY = 0.001;
const STOP_LOSS_PERCENT = 1.0;
const TAKE_PROFIT_PERCENT = 1.5;

// Load paper mode
let paper = { enabled: true, virtual_balance: 1000, real_orders: false };
try {
  const p = JSON.parse(fs.readFileSync(process.env.HOME + '/CYBRA/.cybra_local_secret/paper_mode.json', 'utf8'));
  paper = { ...paper, ...p };
} catch(e) { console.log("⚠️ paper_mode.json not found, using defaults"); }

let position = null;
let virtualPnL = 0;
let virtualBalance = paper.virtual_balance;

async function getPrice() {
  const res = await fetch(`https://api.bybit.com/v5/market/tickers?category=linear&symbol=${SYMBOL}`);
  const data = await res.json();
  return parseFloat(data.result.list[0].lastPrice);
}

console.log("══════════════════════════════════════");
console.log("📄 CYBRA PAPER TRADER (SIMULATION)");
console.log("══════════════════════════════════════");
console.log(`📊 ${SYMBOL} | ${QUANTITY} BTC | SL:${STOP_LOSS_PERCENT}% | TP:${TAKE_PROFIT_PERCENT}%`);
console.log(`💰 Virtual Balance: ${virtualBalance} USDT`);
console.log("");

while (true) {
  try {
    const price = await getPrice();
    console.log(`[${new Date().toISOString()}] $${price}`);
    
    if (!position) {
      if (price < 63000) {
        console.log(`📄 PAPER BUY ${QUANTITY} BTC at $${price}`);
        const cost = QUANTITY * price;
        if (cost <= virtualBalance) {
          virtualBalance -= cost;
          position = { side: 'long', entryPrice: price, qty: QUANTITY };
          console.log(`✅ PAPER LONG OPENED | Remaining: $${virtualBalance.toFixed(2)}`);
        } else {
          console.log(`❌ Insufficient virtual balance: need $${cost.toFixed(2)}`);
        }
      } else if (price > 64500) {
        console.log(`📄 PAPER SELL ${QUANTITY} BTC at $${price}`);
        const cost = QUANTITY * price;
        virtualBalance += cost;
        position = { side: 'short', entryPrice: price, qty: QUANTITY };
        console.log(`✅ PAPER SHORT OPENED | Balance: $${virtualBalance.toFixed(2)}`);
      }
    } else if (position) {
      const pnl = position.side === 'long' 
        ? (price - position.entryPrice) * position.qty
        : (position.entryPrice - price) * position.qty;
      
      let closed = false;
      if (position.side === 'long') {
        if (price <= position.entryPrice * (1 - STOP_LOSS_PERCENT/100)) {
          virtualBalance += price * position.qty;
          console.log(`📄 PAPER CLOSE LONG | PnL: $${pnl.toFixed(2)} | Total: $${virtualBalance.toFixed(2)}`);
          position = null;
          closed = true;
        } else if (price >= position.entryPrice * (1 + TAKE_PROFIT_PERCENT/100)) {
          virtualBalance += price * position.qty;
          console.log(`🎯 TAKE PROFIT | PnL: $${pnl.toFixed(2)} | Total: $${virtualBalance.toFixed(2)}`);
          position = null;
          closed = true;
        }
      } else {
        if (price >= position.entryPrice * (1 + STOP_LOSS_PERCENT/100)) {
          virtualBalance -= price * position.qty;
          console.log(`📄 PAPER CLOSE SHORT | PnL: $${pnl.toFixed(2)} | Total: $${virtualBalance.toFixed(2)}`);
          position = null;
          closed = true;
        } else if (price <= position.entryPrice * (1 - TAKE_PROFIT_PERCENT/100)) {
          virtualBalance -= price * position.qty;
          console.log(`🎯 TAKE PROFIT | PnL: $${pnl.toFixed(2)} | Total: $${virtualBalance.toFixed(2)}`);
          position = null;
          closed = true;
        }
      }
      
      if (!closed) {
        console.log(`   Position: ${position.side.toUpperCase()} | Entry: $${position.entryPrice} | Current PnL: $${pnl.toFixed(2)}`);
      }
    }
    
    await new Promise(r => setTimeout(r, 10000));
  } catch(e) {
    console.error("❌", e.message);
    await new Promise(r => setTimeout(r, 5000));
  }
}
