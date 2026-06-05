// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 60
// part: 4
// original_header: console.log("🔥 MODULE 60: Real Trading Final Fix ACTIVE");
// original_line_start: 5719
// original_line_end: 5789
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🔥 MODULE 60: Real Trading Final Fix ACTIVE");

// 1. Вимикаємо нормалізацію ціни
if (global.normalizePrice) global.normalizePrice = p => p;
if (global.priceNormalize) global.priceNormalize = p => p;

// 2. Вимикаємо всі блокувальні фільтри
if (CONFIG.cooldown) CONFIG.cooldown.ENABLED = false;
if (CONFIG.signal) {
CONFIG.signal.DEVIATION_THRESHOLD = 0.0002;
CONFIG.signal.VOLUME_THRESHOLD = 0.8;
CONFIG.signal.VOLATILITY_THRESHOLD = 0.00005;
}
if (global.antiReversalCheck) global.antiReversalCheck = () => true;
if (global.volatilityCheck) global.volatilityCheck = () => ({ action: "TRADE" });
if (global.balanceFilter) global.balanceFilter = s => s;

// 3. Отримуємо реальну ціну через REST (кожну секунду)
let lastRealPrice = null;
async function updateRealPrice() {
try {
const res = await fetch(https://fapi.binance.com/fapi/v1/ticker/price?symbol=${CONFIG.ws.SYMBOL.toUpperCase()});
const data = await res.json();
lastRealPrice = parseFloat(data.price);
} catch(e) {}
}
updateRealPrice();
setInterval(updateRealPrice, 1000);

// 4. Перевизначаємо onTick – використовуємо REST price
const originalOnTick60 = onTick;
onTick = async function(wsPrice, volume) {
if (lastRealPrice && lastRealPrice > 0) {
return originalOnTick60(lastRealPrice, volume);
}
return originalOnTick60(wsPrice, volume);
};

// 5. Примусовий вхід, якщо довго немає позиції
let lastEntryAttempt = 0;
setInterval(async () => {
if (state.status !== "IDLE") return;
if (cooldownUntil > Date.now()) return;
if (!lastRealPrice) return;
if (Date.now() - lastEntryAttempt < 15000) return;
lastEntryAttempt = Date.now();

let signal = buildSignal(lastRealPrice);    
if (!signal) {    
  const dev = deviation(lastRealPrice);    
  if (Math.abs(dev) > 0.0003) {    
    signal = { side: dev > 0 ? "short" : "long", dev };    
  }    
}    
if (!signal) return;    

const qty = calcPositionSize(lastRealPrice);    
if (qty <= 0) return;    
console.log(`🔹 REAL TRADE: ${signal.side} @ ${lastRealPrice}`);    
const order = await placeOrder(signal.side, qty, lastRealPrice);    
if (order) {    
  state.status = "IN_TRADE";    
  state.entry = lastRealPrice;    
  state.side = signal.side;    
}

}, 15000);

console.log("✅ Real trading fix applied. Using REST price, filters disabled.");
})();
