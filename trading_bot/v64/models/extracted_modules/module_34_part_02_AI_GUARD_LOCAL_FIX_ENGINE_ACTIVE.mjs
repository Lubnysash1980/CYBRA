// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 34
// part: 2
// original_header: console.log("🛡️ MODULE 34: AI GUARD LOCAL FIX ENGINE ACTIVE");
// original_line_start: 3018
// original_line_end: 3189
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🛡️ MODULE 34: AI GUARD LOCAL FIX ENGINE ACTIVE");

// ========== 1. ОТРИМАННЯ ТОЧНОСТІ СИМВОЛА (КЕШ) ==========
let symbolPrecision = null;
let stepSize = null;
let minQty = null;
let tickSize = null;
let pricePrecision = null;

async function fetchSymbolPrecision() {
const symbol = CONFIG.ws.SYMBOL.toUpperCase();
try {
const res = await fetch(https://fapi.binance.com/fapi/v1/exchangeInfo?symbol=${symbol});
const data = await res.json();
const symbolInfo = data.symbols[0];

const lotSizeFilter = symbolInfo.filters.find(f => f.filterType === 'LOT_SIZE');    
  const priceFilter = symbolInfo.filters.find(f => f.filterType === 'PRICE_FILTER');    
      
  if (lotSizeFilter) {    
    stepSize = parseFloat(lotSizeFilter.stepSize);    
    minQty = parseFloat(lotSizeFilter.minQty);    
    // Визначаємо кількість десяткових знаків для quantity    
    const stepStr = stepSize.toString();    
    const dotIndex = stepStr.indexOf('.');    
    symbolPrecision = dotIndex === -1 ? 0 : stepStr.length - dotIndex - 1;    
  }    
      
  if (priceFilter) {    
    tickSize = parseFloat(priceFilter.tickSize);    
    const tickStr = tickSize.toString();    
    const dotIndex = tickStr.indexOf('.');    
    pricePrecision = dotIndex === -1 ? 0 : tickStr.length - dotIndex - 1;    
  }    
      
  console.log(`🎯 Precision cache: stepSize=${stepSize}, minQty=${minQty}, qtyDecimals=${symbolPrecision}, tickSize=${tickSize}, priceDecimals=${pricePrecision}`);    
} catch (err) {    
  console.error("Failed to fetch precision, using defaults for DOGE:", err.message);    
  // Дефолтні значення для DOGE    
  stepSize = 1;    
  minQty = 1;    
  symbolPrecision = 0;    
  tickSize = 0.00001;    
  pricePrecision = 5;    
}

}

// ========== 2. НОРМАЛІЗАЦІЯ КІЛЬКОСТІ (quantity) ==========
function normalizeQuantity(quantity) {
if (!stepSize) return Math.floor(Math.max(1, quantity));

let normalized = Math.floor(quantity / stepSize) * stepSize;    
if (normalized < minQty) normalized = minQty;    
if (normalized < 1) normalized = 1;    
    
// Округлення до потрібної точності    
if (symbolPrecision === 0) {    
  normalized = Math.floor(normalized);    
} else {    
  normalized = parseFloat(normalized.toFixed(symbolPrecision));    
}    
    
return normalized;

}

// ========== 3. НОРМАЛІЗАЦІЯ ЦІНИ (price) ==========
function normalizePrice(price) {
if (!tickSize) return price;
let normalized = Math.floor(price / tickSize) * tickSize;
if (pricePrecision !== null) {
normalized = parseFloat(normalized.toFixed(pricePrecision));
}
return normalized;
}

// ========== 4. ПЕРЕВИЗНАЧЕННЯ calcPositionSize (вбудована нормалізація) ==========
const originalCalcPositionSize = global.calcPositionSize || calcPositionSize;
global.calcPositionSize = function(price) {
let qty = originalCalcPositionSize(price);
if (!qty || qty <= 0) qty = 1;
const normalized = normalizeQuantity(qty);
if (normalized !== qty) {
console.log(🔧 AI Guard: quantity ${qty} → ${normalized});
}
return normalized;
};

// ========== 5. ПЕРЕВИЗНАЧЕННЯ placeOrder (локальна нормалізація без зайвих запитів) ==========
const originalPlaceOrder = global.placeOrder || placeOrder;
global.placeOrder = async function(side, quantity, currentPrice) {
// Нормалізуємо quantity та price ДО відправки на біржу
const fixedQuantity = normalizeQuantity(quantity);
const fixedPrice = normalizePrice(currentPrice);

if (fixedQuantity !== quantity) {    
  console.log(`🔧 AI Guard: quantity corrected BEFORE order: ${quantity} → ${fixedQuantity}`);    
}    
if (fixedPrice !== currentPrice) {    
  console.log(`🔧 AI Guard: price corrected BEFORE order: ${currentPrice} → ${fixedPrice}`);    
}    
    
// Викликаємо оригінальну функцію з виправленими параметрами    
return originalPlaceOrder(side, fixedQuantity, fixedPrice);

};

// ========== 6. ПЕРЕВИЗНАЧЕННЯ checkExit (виправлення TP/SL цін) ==========
const originalCheckExit = global.checkExit || checkExit;
global.checkExit = function(price) {
if (state.status !== "IN_TRADE") return null;

// Нормалізуємо ціну виходу    
const normalizedPrice = normalizePrice(price);    
    
// Оригінальна логіка з нормалізованою ціною    
const tpPrice = state.side === "long"    
  ? state.entry * (1 + CONFIG.risk.TAKE_PROFIT / 100)    
  : state.entry * (1 - CONFIG.risk.TAKE_PROFIT / 100);    
const slPrice = state.side === "long"    
  ? state.entry * (1 - CONFIG.risk.STOP_LOSS / 100)    
  : state.entry * (1 + CONFIG.risk.STOP_LOSS / 100);    
    
const normalizedTp = normalizePrice(tpPrice);    
const normalizedSl = normalizePrice(slPrice);    
    
let exit = null;    
if (state.side === "long") {    
  if (normalizedPrice >= normalizedTp) exit = "TP";    
  if (normalizedPrice <= normalizedSl) exit = "SL";    
} else {    
  if (normalizedPrice <= normalizedTp) exit = "TP";    
  if (normalizedPrice >= normalizedSl) exit = "SL";    
}    
    
if (exit) {    
  console.log(`🔧 AI Guard: exit at ${normalizedPrice} (${exit})`);    
}    
    
return exit;

};

// ========== 7. ПЕРЕВИЗНАЧЕННЯ buildSignal (виправлення ціни входу) ==========
const originalBuildSignal = global.buildSignal || buildSignal;
global.buildSignal = function(price) {
const normalizedPrice = normalizePrice(price);
const signal = originalBuildSignal(normalizedPrice);
if (signal) {
signal.originalPrice = price;
signal.normalizedPrice = normalizedPrice;
}
return signal;
};

// ========== 8. ПЕРЕВИЗНАЧЕННЯ onTick (виправлення ціни на вході) ==========
const originalOnTick = onTick;
onTick = async function(price, volume) {
const normalizedPrice = normalizePrice(price);
if (normalizedPrice !== price && Math.random() < 0.01) {
console.log(🔧 AI Guard: price normalized ${price} → ${normalizedPrice});
}
return originalOnTick(normalizedPrice, volume);
};

// ========== 9. ЗАПУСК ОТРИМАННЯ ТОЧНОСТІ ==========
fetchSymbolPrecision().catch(err => console.error("Precision fetch error:", err));

console.log("✅ AI GUARD: local fix engine ready. No extra Binance requests for error correction.");
})();
