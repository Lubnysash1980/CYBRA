// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 55
// part: 2
// original_header: console.log("🔥 MODULE 55: Hard Entry Enforcer ACTIVE - bypassing all filters");
// original_line_start: 5220
// original_line_end: 5274
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🔥 MODULE 55: Hard Entry Enforcer ACTIVE - bypassing all filters");

// Вимкнути всі можливі блокування
if (CONFIG.cooldown) CONFIG.cooldown.ENABLED = false;
if (CONFIG.signal) {
CONFIG.signal.DEVIATION_THRESHOLD = 0.00001;
CONFIG.signal.VOLUME_THRESHOLD = 0.1;
CONFIG.signal.VOLATILITY_THRESHOLD = 0.00001;
}
if (global.antiReversalCheck) global.antiReversalCheck = () => true;
if (global.volatilityCheck) global.volatilityCheck = () => ({ action: "TRADE" });
if (global.balanceFilter) global.balanceFilter = (s) => s;
if (global.normalizePrice) global.normalizePrice = (p) => p;

// Перевизначаємо buildSignal - завжди генерує сигнал на основі простого тренду
global.buildSignal = function(price) {
const prices = buffers.getPrices();
if (prices.length < 5) return null;
const shortAvg = avg(prices.slice(-3));
const longAvg = avg(prices.slice(-5));
const side = shortAvg > longAvg ? "long" : "short";
return { side, dev: (shortAvg - longAvg) / longAvg, ts: Date.now(), hard: true };
};

// Примусовий вхід кожні 3 секунди, якщо немає позиції
let lastHardEntry = 0;
setInterval(async () => {
if (state.status !== "IDLE") return;
const now = Date.now();
if (now - lastHardEntry < 3000) return;
lastHardEntry = now;

const price = global.getTruthfulPrice ? global.getTruthfulPrice() : buffers.getPrices().slice(-1)[0];    
if (!price || price < 0.09 || price > 0.10) return;    
    
const signal = global.buildSignal(price);    
if (!signal || !signal.side) return;    
    
const qty = calcPositionSize(price);    
if (qty <= 0) return;    
    
console.log(`🔥 HARD ENTRY: ${signal.side} @ ${price.toFixed(8)}`);    
const order = await placeOrder(signal.side, qty, price);    
if (order) {    
  state.status = "IN_TRADE";    
  state.entry = price;    
  state.side = signal.side;    
  console.log("✅ HARD ENTRY SUCCESS");    
} else {    
  console.log("❌ HARD ENTRY FAILED - check placeOrder");    
}

}, 3000);
})();
