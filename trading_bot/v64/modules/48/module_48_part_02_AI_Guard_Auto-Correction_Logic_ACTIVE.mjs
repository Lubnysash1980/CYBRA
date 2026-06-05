// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 48
// part: 2
// original_header: console.log("🔄 MODULE 48: AI Guard Auto-Correction Logic ACTIVE");
// original_line_start: 4610
// original_line_end: 4718
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🔄 MODULE 48: AI Guard Auto-Correction Logic ACTIVE");

// Конфігурація
const CFG = {
CHECK_INTERVAL_MS: 30000,           // перевірка кожні 30 секунд
NO_TRADE_TIMEOUT_MS: 120000,        // 2 хвилини без трейду – тривога
CRITICAL_NO_TRADE_MS: 300000,       // 5 хвилин – жорстка корекція
MAX_CORRECTION_STEPS: 5,
CORRECTION_FACTOR: 0.8,             // зменшення порогів на 20% за крок
LOG_EVERY: 1,
};

let lastTradeTime = Date.now();
let correctionStep = 0;
let originalConfig = null;

// Зберігаємо оригінальні значення при старті
function saveOriginalConfig() {
originalConfig = {
deviation: CONFIG.signal.DEVIATION_THRESHOLD,
volume: CONFIG.signal.VOLUME_THRESHOLD,
volatility: CONFIG.signal.VOLATILITY_THRESHOLD,
cooldownEnabled: CONFIG.cooldown.ENABLED,
};
console.log("📝 Original config saved for auto-correction");
}

// Функція корекції – зменшує пороги або вимикає фільтри
function applyCorrection() {
if (correctionStep >= CFG.MAX_CORRECTION_STEPS) {
console.log("⚠️ Max correction steps reached. Forcing entry mode...");
// Примусове вимкнення всіх фільтрів
CONFIG.signal.DEVIATION_THRESHOLD = 0.0001;
CONFIG.signal.VOLUME_THRESHOLD = 1.0;
CONFIG.signal.VOLATILITY_THRESHOLD = 0.00005;
CONFIG.cooldown.ENABLED = false;
if (global.antiReversalCheck) global.antiReversalCheck = () => true;
if (global.volatilityCheck) global.volatilityCheck = () => ({ action: "TRADE", volatility: 1 });
return;
}

correctionStep++;    
const factor = Math.pow(CFG.CORRECTION_FACTOR, correctionStep);    
const newDeviation = originalConfig.deviation * factor;    
const newVolume = originalConfig.volume * factor;    
const newVolatility = originalConfig.volatility * factor;    

CONFIG.signal.DEVIATION_THRESHOLD = Math.max(0.0001, newDeviation);    
CONFIG.signal.VOLUME_THRESHOLD = Math.max(1.0, newVolume);    
CONFIG.signal.VOLATILITY_THRESHOLD = Math.max(0.00005, newVolatility);    
    
console.log(`🔧 Auto-correction step ${correctionStep}: deviation=${CONFIG.signal.DEVIATION_THRESHOLD.toFixed(5)}, volume=${CONFIG.signal.VOLUME_THRESHOLD.toFixed(2)}, volatility=${CONFIG.signal.VOLATILITY_THRESHOLD.toFixed(5)}`);

}

// Функція скидання корекції після успішного трейду
function resetCorrection() {
if (correctionStep === 0) return;
correctionStep = 0;
if (originalConfig) {
CONFIG.signal.DEVIATION_THRESHOLD = originalConfig.deviation;
CONFIG.signal.VOLUME_THRESHOLD = originalConfig.volume;
CONFIG.signal.VOLATILITY_THRESHOLD = originalConfig.volatility;
CONFIG.cooldown.ENABLED = originalConfig.cooldownEnabled;
console.log("✅ Auto-correction reset after successful trade");
}
}

// Відстежуємо час останнього трейду через перехоплення onTick
const originalOnTick = onTick;
onTick = async function(price, volume) {
const result = await originalOnTick(price, volume);
// Якщо був вхід у позицію, оновлюємо час
if (state.status === "IN_TRADE") {
lastTradeTime = Date.now();
}
return result;
};

// Перехоплюємо закриття позиції для скидання корекції
const originalCheckExit = checkExit;
checkExit = function(price) {
const exitResult = originalCheckExit(price);
if (exitResult === 'TP' || exitResult === 'SL') {
// Після виходу скидаємо корекцію (але через невелику затримку)
setTimeout(() => resetCorrection(), 1000);
}
return exitResult;
};

// Періодична перевірка активності
setInterval(() => {
const now = Date.now();
const idleTime = now - lastTradeTime;
if (idleTime > CFG.NO_TRADE_TIMEOUT_MS && state.status === "IDLE") {
console.log(⚠️ No trade for ${Math.floor(idleTime/1000)}s. Applying auto-correction.);
applyCorrection();
}
if (idleTime > CFG.CRITICAL_NO_TRADE_MS) {
console.log(🚨 CRITICAL: No trade for ${Math.floor(idleTime/1000)}s. Forcing entry mode.);
applyCorrection(); // це викличе форсований режим після досягнення максимуму
}
}, CFG.CHECK_INTERVAL_MS);

// Зберігаємо оригінальні параметри при запуску
saveOriginalConfig();
console.log("✅ Auto-correction logic ready. Will adjust thresholds if no trades detected.");
})();
