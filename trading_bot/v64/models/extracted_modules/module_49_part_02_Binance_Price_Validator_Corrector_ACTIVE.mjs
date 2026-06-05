// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 49
// part: 2
// original_header: console.log("💰 MODULE 49: Binance Price Validator & Corrector ACTIVE");
// original_line_start: 4723
// original_line_end: 4823
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("💰 MODULE 49: Binance Price Validator & Corrector ACTIVE");

// Конфігурація
const CFG = {
VALIDATION_INTERVAL_MS: 10000,      // перевіряти ціну кожні 10 секунд
MAX_DEVIATION_PERCENT: 1.0,         // максимальне відхилення 1% перед корекцією
DISABLE_AGGRESSIVE_NORMALIZATION: true,
FETCH_TIMEOUT_MS: 3000,
};

let lastValidPrice = null;
let lastValidationTime = 0;
let correctionCount = 0;

// Функція отримання поточної ціни з Binance REST API (symbol price ticker)
async function fetchRealPrice() {
const symbol = CONFIG.ws.SYMBOL.toUpperCase();
const url = https://fapi.binance.com/fapi/v1/ticker/price?symbol=${symbol};
try {
const controller = new AbortController();
const timeoutId = setTimeout(() => controller.abort(), CFG.FETCH_TIMEOUT_MS);
const res = await fetch(url, { signal: controller.signal });
clearTimeout(timeoutId);
const data = await res.json();
if (data && data.price) {
return parseFloat(data.price);
}
} catch (err) {
console.error("❌ Failed to fetch real price:", err.message);
}
return null;
}

// Корекція ціни, якщо відхилення занадто велике
async function validateAndCorrect(currentPrice) {
if (!currentPrice || currentPrice <= 0) return null;
const now = Date.now();
// Не перевіряти частіше ніж раз на 10 секунд
if (now - lastValidationTime < CFG.VALIDATION_INTERVAL_MS && lastValidPrice !== null) {
// Якщо відхилення від останньої відомої ціни менше 5%, повертаємо поточну
if (lastValidPrice && Math.abs((currentPrice - lastValidPrice) / lastValidPrice) * 100 < 5) {
return currentPrice;
}
}
const realPrice = await fetchRealPrice();
if (!realPrice) return currentPrice;
lastValidationTime = now;
const deviation = Math.abs((currentPrice - realPrice) / realPrice) * 100;
if (deviation > CFG.MAX_DEVIATION_PERCENT) {
console.log(⚠️ Price deviation detected: WS=${currentPrice.toFixed(8)}, REAL=${realPrice.toFixed(8)} (${deviation.toFixed(2)}%). Correcting to REAL.);
correctionCount++;
lastValidPrice = realPrice;
return realPrice;
}
lastValidPrice = currentPrice;
return currentPrice;
}

// Вимкнути агресивну нормалізацію (модуль 35)
if (CFG.DISABLE_AGGRESSIVE_NORMALIZATION && global.normalizePrice) {
const originalNormalize = global.normalizePrice;
global.normalizePrice = function(price) {
// Якщо ціна менше 0.01, не нормалізуємо до 0.1
if (price < 0.1 && price > 0.001) return price;
return originalNormalize ? originalNormalize(price) : price;
};
console.log("🔧 Aggressive price normalization disabled");
}

// Перехоплюємо onTick для валідації ціни
const originalOnTick49 = onTick;
onTick = async function(price, volume) {
const validatedPrice = await validateAndCorrect(price);
if (!validatedPrice) return originalOnTick49(price, volume);
if (validatedPrice !== price) {
console.log(🔧 Price corrected: ${price.toFixed(8)} → ${validatedPrice.toFixed(8)});
}
return originalOnTick49(validatedPrice, volume);
};

// Періодичне оновлення ціни навіть без тиків
setInterval(async () => {
const realPrice = await fetchRealPrice();
if (realPrice && lastValidPrice && Math.abs((realPrice - lastValidPrice) / lastValidPrice) * 100 > CFG.MAX_DEVIATION_PERCENT) {
console.log(🔧 Background price sync: ${lastValidPrice?.toFixed(8)} → ${realPrice.toFixed(8)});
lastValidPrice = realPrice;
} else if (realPrice) {
lastValidPrice = realPrice;
}
}, CFG.VALIDATION_INTERVAL_MS);

// Функція для ручного виклику
global.validateCurrentPrice = async () => {
const realPrice = await fetchRealPrice();
console.log(Current WS price: ${buffers.getPrices().slice(-1)[0]}, Real price: ${realPrice});
return realPrice;
};

console.log(✅ Price validator ready. Max deviation: ${CFG.MAX_DEVIATION_PERCENT}%, checking every ${CFG.VALIDATION_INTERVAL_MS/1000}s);
})();
