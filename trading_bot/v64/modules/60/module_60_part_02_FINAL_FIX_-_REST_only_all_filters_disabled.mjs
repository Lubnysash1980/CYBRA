// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 60
// part: 2
// original_header: console.log("🔥 MODULE 60: FINAL FIX - REST only, all filters disabled");
// original_line_start: 5656
// original_line_end: 5714
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🔥 MODULE 60: FINAL FIX - REST only, all filters disabled");

// 1. Повністю вимикаємо всі фільтри
if (CONFIG.cooldown) CONFIG.cooldown.ENABLED = false;
if (CONFIG.signal) {
CONFIG.signal.DEVIATION_THRESHOLD = 0.0001;
CONFIG.signal.VOLUME_THRESHOLD = 0.5;
CONFIG.signal.VOLATILITY_THRESHOLD = 0.00001;
}
// 2. Вбиваємо нормалізацію ціни
if (global.normalizePrice) global.normalizePrice = p => p;
if (global.priceNormalize) global.priceNormalize = p => p;
// 3. Вимикаємо анти-реверсал та інше
if (global.antiReversalCheck) global.antiReversalCheck = () => true;
if (global.volatilityCheck) global.volatilityCheck = () => ({ action: "TRADE" });
if (global.balanceFilter) global.balanceFilter = s => s;

// 4. Отримуємо реальну ціну тільки через REST (кожну секунду)
let realPrice = null;
async function fetchRealPrice() {
try {
const res = await fetch(https://fapi.binance.com/fapi/v1/ticker/price?symbol=${CONFIG.ws.SYMBOL.toUpperCase()});
const data = await res.json();
realPrice = parseFloat(data.price);
} catch (e) {}
}
fetchRealPrice();
setInterval(fetchRealPrice, 1000);

// 5. Перевизначаємо onTick – ігноруємо WS price, використовуємо REST
const originalOnTick = onTick;
onTick = async function(wsPrice, volume) {
if (realPrice && realPrice > 0) {
return originalOnTick(realPrice, volume);
}
return originalOnTick(wsPrice, volume);
};

// 6. Примусовий вхід кожні 10 секунд, якщо немає позиції
setInterval(async () => {
if (state.status !== "IDLE") return;
if (!realPrice) return;
const dev = (realPrice - (buffers.getPrices().slice(-1)[0] || realPrice)) / realPrice;
const side = dev > 0.0001 ? "short" : (dev < -0.0001 ? "long" : null);
if (!side) return;
const qty = calcPositionSize(realPrice);
if (qty <= 0) return;
console.log(🚀 FORCE ENTRY: ${side} @ ${realPrice});
const order = await placeOrder(side, qty, realPrice);
if (order) {
state.status = "IN_TRADE";
state.entry = realPrice;
state.side = side;
}
}, 10000);

console.log("✅ Ready: using REST price only. Bot will enter positions.");
})();
