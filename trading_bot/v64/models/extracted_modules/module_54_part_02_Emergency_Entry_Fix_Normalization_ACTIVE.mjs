// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 54
// part: 2
// original_header: console.log("🚨 MODULE 54: Emergency Entry & Fix Normalization ACTIVE");
// original_line_start: 5136
// original_line_end: 5215
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🚨 MODULE 54: Emergency Entry & Fix Normalization ACTIVE");

// 1. Вимкнути агресивну нормалізацію ціни (модуль 35)
if (global.normalizePrice) {
global.normalizePrice = (price) => price;
console.log("   ✅ Price normalization disabled");
}

// 2. Вимкнути anti-reversal (модуль 17)
if (global.antiReversalCheck) {
global.antiReversalCheck = () => true;
console.log("   ✅ Anti-reversal disabled");
}

// 3. Вимкнути volatility filter (модуль 15)
if (global.volatilityCheck) {
global.volatilityCheck = () => ({ action: "TRADE", volatility: 1 });
console.log("   ✅ Volatility filter disabled");
}

// 4. Вимкнути баланс фільтр (модуль 13)
if (global.balanceFilter) {
global.balanceFilter = (signal) => signal;
console.log("   ✅ Balance filter disabled");
}

// 5. Зменшити пороги входу до мінімуму
if (CONFIG.signal) {
CONFIG.signal.DEVIATION_THRESHOLD = 0.0001;   // 0.01%
CONFIG.signal.VOLUME_THRESHOLD = 1.0;
CONFIG.signal.VOLATILITY_THRESHOLD = 0.00005;
console.log("   ✅ Thresholds minimized");
}

// 6. Видалити обмеження кулдауну
if (CONFIG.cooldown) {
CONFIG.cooldown.ENABLED = false;
console.log("   ✅ Cooldown disabled");
}

// 7. Перевизначити buildSignal для генерації сигналів при малому відхиленні
const originalBuildSignal54 = buildSignal;
global.buildSignal = function(price) {
let signal = originalBuildSignal54(price);
if (!signal && price > 0) {
const dev = deviation(price);
if (Math.abs(dev) > 0.0003) { // 0.03% відхилення
signal = { side: dev > 0 ? "short" : "long", dev, ts: Date.now(), emergency: true };
console.log(🚨 Emergency signal: ${signal.side} deviation=${(dev*100).toFixed(3)}%);
}
}
return signal;
};

// 8. Примусовий таймер входу (кожні 5 секунд, якщо немає позиції)
let lastForceAttempt = 0;
const forceInterval = setInterval(async () => {
if (state.status !== "IDLE") return;
if (cooldownUntil > Date.now()) return;
const price = buffers.getPrices().slice(-1)[0];
if (!price || price < 0.09 || price > 0.11) return;
const dev = deviation(price);
if (Math.abs(dev) < 0.0003) return;
const side = dev > 0 ? "short" : "long";
const qty = calcPositionSize(price);
if (qty <= 0) return;
console.log(🚨 FORCE ENTRY: ${side} @ ${price});
const order = await placeOrder(side, qty, price);
if (order) {
state.status = "IN_TRADE";
state.entry = price;
state.side = side;
}
}, 5000);

// Збереження для можливого скидання
global.disableForceEntry = () => clearInterval(forceInterval);
console.log("✅ Emergency entry ready - bot will force entries every 5s if conditions met");
})();
