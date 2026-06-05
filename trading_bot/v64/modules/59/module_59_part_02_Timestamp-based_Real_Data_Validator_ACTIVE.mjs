// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 59
// part: 2
// original_header: console.log("⏱️ MODULE 59: Timestamp-based Real Data Validator ACTIVE");
// original_line_start: 5556
// original_line_end: 5651
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("⏱️ MODULE 59: Timestamp-based Real Data Validator ACTIVE");

const CFG = {
MAX_ALLOWED_DELAY_MS: 5000,      // відкидати дані старіші за 5 секунд
MIN_INTERVAL_MS: 200,            // мінімальний інтервал між тиками (захист від спаму)
TIMESTAMP_TOLERANCE_MS: 1000,    // допустиме відхилення часу
MAX_CONSECUTIVE_INVALID: 5,      // після N невалідних даних – примусова синхронізація
};

let lastValidTimestamp = 0;
let lastTickTime = 0;
let invalidCount = 0;
let lastPrice = null;

// Отримуємо реальний час із сервера Binance (або локальний)
async function getRealTimestamp() {
try {
const res = await fetch('https://fapi.binance.com/fapi/v1/time');
const data = await res.json();
return data.serverTime;
} catch (e) {
return Date.now(); // fallback
}
}

// Функція перевірки даних
async function validateData(price, volume, receivedTimestamp = Date.now()) {
const now = Date.now();
const serverTime = await getRealTimestamp();
const timeDiff = Math.abs(serverTime - now);

// 1. Якщо різниця з серверним часом занадто велика – синхронізуємо    
if (timeDiff > CFG.TIMESTAMP_TOLERANCE_MS) {    
  console.log(`⚠️ Time drift detected: ${timeDiff}ms. Syncing...`);    
  return false;    
}    
    
// 2. Перевірка на застарілі дані    
if (receivedTimestamp < now - CFG.MAX_ALLOWED_DELAY_MS) {    
  console.log(`⏳ Stale data ignored (${now - receivedTimestamp}ms old)`);    
  return false;    
}    
    
// 3. Перевірка мінімального інтервалу (захист від спаму)    
if (now - lastTickTime < CFG.MIN_INTERVAL_MS && lastPrice === price) {    
  console.log(`🚫 Duplicate/spam tick ignored (${now - lastTickTime}ms)`);    
  return false;    
}    
    
// 4. Перевірка ціни на аномалії (стрибки більше 5% за один тік)    
if (lastPrice !== null && Math.abs((price - lastPrice) / lastPrice) > 0.05) {    
  console.log(`⚠️ Price spike ignored: ${lastPrice} → ${price}`);    
  invalidCount++;    
  if (invalidCount >= CFG.MAX_CONSECUTIVE_INVALID) {    
    console.log("🔄 Too many invalid ticks, forcing price sync...");    
    await global.validateCurrentPrice?.();    
    invalidCount = 0;    
  }    
  return false;    
}    
    
// Все добре    
lastValidTimestamp = now;    
lastTickTime = now;    
lastPrice = price;    
invalidCount = 0;    
return true;

}

// Перехоплюємо onTick – валідуємо дані перед передачею
const originalOnTick59 = onTick;
onTick = async function(price, volume) {
const isValid = await validateData(price, volume);
if (!isValid) return;
return originalOnTick59(price, volume);
};

// Функція примусової синхронізації (викликається зовні)
global.syncMarketData = async () => {
const realPrice = await global.validateCurrentPrice?.();
const realTime = await getRealTimestamp();
console.log(🔄 Manual sync: price=${realPrice}, time=${realTime});
lastValidTimestamp = realTime;
lastTickTime = realTime;
if (realPrice) lastPrice = realPrice;
};

// Періодична синхронізація кожні 30 секунд
setInterval(async () => {
await global.syncMarketData?.();
}, 30000);

console.log("✅ Real data validator active: stale/spoofed ticks will be ignored.");
})();
