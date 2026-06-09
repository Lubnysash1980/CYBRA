import fs from 'fs';
import path from 'path';
import fetch from 'node-fetch';

// Завантаження конфігу
const config = JSON.parse(fs.readFileSync('./config/cybra_v70_config.json', 'utf8'));

console.log("══════════════════════════════════════");
console.log("🚀 CYBRA v70 BOT STARTED");
console.log("══════════════════════════════════════");

// Завантаження всіх модулів
const modulesDir = path.join(process.cwd(), 'trading_bot/v70/modules');
const dirs = fs.readdirSync(modulesDir);
let loaded = 0;
const modules = [];

for (const dir of dirs) {
    try {
        const modulePath = path.join(modulesDir, dir, `module_${dir}.mjs`);
        if (fs.existsSync(modulePath)) {
            const module = await import(`file://${modulePath}`);
            const id = parseInt(dir);
            modules.push({ id, module: module.default });
            console.log(`   ✅ Module ${id} loaded`);
            loaded++;
        }
    } catch(e) {
        console.log(`   ⚠️ Module ${dir}: ${e.message}`);
    }
}

console.log(`📦 Total modules loaded: ${loaded}/70`);
console.log("══════════════════════════════════════");
console.log("📈 STARTING TRADING ENGINE...");
console.log("══════════════════════════════════════");

// Торгові змінні
const SYMBOL = config.trading.symbol;
const QUANTITY = config.trading.position_size_btc;
const STOP_LOSS = config.safety.stop_loss_percent;
const TAKE_PROFIT = config.safety.take_profit_percent;
const LONG_ENTRY = config.trading.long_entry_below;
const SHORT_ENTRY = config.trading.short_entry_above;

let position = null;
let lastPrice = 0;

// Отримання ціни з Bybit
async function getPrice() {
    try {
        const res = await fetch(`https://api.bybit.com/v5/market/tickers?category=linear&symbol=${SYMBOL}`);
        const data = await res.json();
        lastPrice = parseFloat(data.result.list[0].lastPrice);
        return lastPrice;
    } catch(e) {
        console.error("❌ Price fetch error:", e.message);
        return lastPrice || 0;
    }
}

// Відкриття позиції (paper/logging)
async function openPosition(side, price) {
    console.log(`🔵 OPENING ${side} at $${price}`);
    position = {
        side: side,
        entryPrice: price,
        quantity: QUANTITY,
        stopLoss: side === 'LONG' ? price * (1 - STOP_LOSS/100) : price * (1 + STOP_LOSS/100),
        takeProfit: side === 'LONG' ? price * (1 + TAKE_PROFIT/100) : price * (1 - TAKE_PROFIT/100),
        openTime: new Date().toISOString()
    };
    console.log(`   Entry: $${price}`);
    console.log(`   Stop Loss: $${position.stopLoss.toFixed(2)} (${STOP_LOSS}%)`);
    console.log(`   Take Profit: $${position.takeProfit.toFixed(2)} (${TAKE_PROFIT}%)`);
}

// Закриття позиції
async function closePosition(price, reason) {
    if (!position) return;
    const pnl = position.side === 'LONG' 
        ? (price - position.entryPrice) * QUANTITY
        : (position.entryPrice - price) * QUANTITY;
    console.log(`🔒 CLOSING ${position.side} | Reason: ${reason}`);
    console.log(`   Exit: $${price} | PnL: $${pnl.toFixed(2)} USDT`);
    position = null;
}

// Перевірка позиції
async function checkPosition(price) {
    if (!position) return;
    
    if (position.side === 'LONG') {
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

// Головний торговий цикл
async function tradingLoop() {
    console.log(`📊 Trading config:`);
    console.log(`   Symbol: ${SYMBOL}`);
    console.log(`   Position size: ${QUANTITY} BTC`);
    console.log(`   LONG entry: < $${LONG_ENTRY}`);
    console.log(`   SHORT entry: > $${SHORT_ENTRY}`);
    console.log(`   Stop Loss: ${STOP_LOSS}% | Take Profit: ${TAKE_PROFIT}%`);
    console.log("");
    
    while (true) {
        try {
            const price = await getPrice();
            const now = new Date().toLocaleTimeString();
            
            if (position) {
                const pnl = position.side === 'LONG'
                    ? (price - position.entryPrice) * QUANTITY
                    : (position.entryPrice - price) * QUANTITY;
                console.log(`[${now}] $${price} | ${position.side} | PnL: $${pnl.toFixed(2)}`);
                await checkPosition(price);
            } else {
                console.log(`[${now}] $${price} | No position | Monitoring...`);
                
                // Сигнали на вхід
                if (price < LONG_ENTRY) {
                    console.log(`📡 SIGNAL: LONG at $${price} (< $${LONG_ENTRY})`);
                    await openPosition('LONG', price);
                } else if (price > SHORT_ENTRY) {
                    console.log(`📡 SIGNAL: SHORT at $${price} (> $${SHORT_ENTRY})`);
                    await openPosition('SHORT', price);
                }
            }
            
            await new Promise(r => setTimeout(r, 10000)); // кожні 10 секунд
        } catch(e) {
            console.error("❌ Loop error:", e.message);
            await new Promise(r => setTimeout(r, 5000));
        }
    }
}

// Запуск
tradingLoop().catch(console.error);
