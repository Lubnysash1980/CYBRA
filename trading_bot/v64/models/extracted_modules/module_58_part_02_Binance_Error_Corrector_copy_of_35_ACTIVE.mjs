// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 58
// part: 2
// original_header: console.log("🛡️ MODULE 58: Binance Error Corrector (copy of 35) ACTIVE");
// original_line_start: 5311
// original_line_end: 5548
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🛡️ MODULE 58: Binance Error Corrector (copy of 35) ACTIVE");

const CFG = {
MAX_RETRIES: 3,
RETRY_DELAY_MS: 2000,
POSITION_RECOVERY_ATTEMPTS: 2,
MARGIN_CALL_THRESHOLD: 0.95,
LIQUIDATION_BUFFER: 0.05,
CORRECTION_FACTOR: 0.9,
EMERGENCY_COOLDOWN: 60000,
};

const binanceErrorCache = new Map();
let consecutiveBinanceErrors = 0;
let lastErrorTime = 0;
let emergencyRecoveryMode = false;

const errorHashLog = new Map();
function logError(errorCode, errorMsg, context) {
const key = crypto.createHash('sha256').update(${Date.now()}:${errorCode}:${errorMsg}).digest('hex');
if (errorHashLog.has(key)) {
errorHashLog.get(key).count++;
} else {
errorHashLog.set(key, { errorCode, errorMsg, context, count: 1, timestamp: Date.now() });
if (errorHashLog.size > 5000) {
const oldest = Array.from(errorHashLog.entries()).sort((a,b) => a[1].timestamp - b[1].timestamp)[0];
errorHashLog.delete(oldest[0]);
}
}
}

function analyzeBinanceError(error) {
const errorCode = error?.code || error?.data?.code || 'UNKNOWN';
const errorMsg = error?.msg || error?.message || String(error);

const categories = {    
  INSUFFICIENT_MARGIN: ['-2010', '-2011', '-1003', 'margin', 'balance', 'insufficient'],    
  PRICE_FILTER: ['-2010', 'PRICE_FILTER', 'price too high', 'price too low'],    
  LOT_SIZE: ['-2010', 'LOT_SIZE', 'step size', 'minQty', 'maxQty'],    
  POSITION_NOT_FOUND: ['-2013', 'Order does not exist', 'position not found'],    
  MARKET_CLOSED: ['-1002', 'Market closed', 'trading halted'],    
  RATE_LIMIT: ['-1003', 'Too many requests', 'rate limit'],    
  LIQUIDATION: ['-2010', 'Liquidation', 'force close'],    
  SERVER_BUSY: ['-1001', 'Internal error', 'timeout', 'busy']    
};    
    
let category = 'OTHER';    
for (const [cat, patterns] of Object.entries(categories)) {    
  if (patterns.some(p => errorMsg.includes(p) || (errorCode && errorCode.includes(p)))) {    
    category = cat;    
    break;    
  }    
}    
logError(errorCode, errorMsg, category);    
return { category, errorCode, errorMsg };

}

async function fixInsufficientMargin(originalParams) {
console.log("💰 AI Guard: Fixing insufficient margin...");
const newQuantity = Math.max(1, Math.floor(originalParams.quantity * CFG.CORRECTION_FACTOR));
console.log(   New quantity: ${newQuantity} (was ${originalParams.quantity}));
return { ...originalParams, quantity: newQuantity, fixed: true };
}

async function fixLotSize(originalParams) {
console.log("📏 AI Guard: Fixing lot size / step size...");
const stepSize = global.stepSize || 1;
let newQuantity = Math.floor(originalParams.quantity / stepSize) * stepSize;
if (newQuantity < 1) newQuantity = stepSize;
console.log(   New quantity: ${newQuantity} (step=${stepSize}));
return { ...originalParams, quantity: newQuantity, fixed: true };
}

async function fixPriceFilter(originalParams) {
console.log("💲 AI Guard: Fixing price filter...");
const tickSize = global.tickSize || 0.00001;
let newPrice = Math.floor(originalParams.price / tickSize) * tickSize;
if (newPrice <= 0) newPrice = tickSize;
console.log(   New price: ${newPrice} (tick=${tickSize}));
return { ...originalParams, price: newPrice, fixed: true };
}

async function fixRateLimit() {
console.log("⏳ AI Guard: Rate limit hit. Waiting 5 seconds...");
await new Promise(r => setTimeout(r, 5000));
return { action: 'retry', delay: 5000 };
}

async function fixLiquidation(originalParams) {
console.log("⚠️ AI Guard: Liquidation risk detected! Closing position...");
if (state.status === "IN_TRADE") {
const closeSide = state.side === "long" ? "sell" : "buy";
try {
const qty = calcPositionSize(originalParams.price);
await placeOrder(closeSide, qty, originalParams.price);
console.log("✅ AI Guard: Position closed due to liquidation risk");
state.status = "IDLE";
state.entry = null;
state.side = null;
} catch (e) {
console.error("❌ AI Guard: Failed to close position", e.message);
}
}
return { action: 'abort', reason: 'liquidation' };
}

async function fixOtherError(originalParams) {
console.log("🔧 AI Guard: Unknown Binance error, applying generic fix...");
const newQuantity = Math.max(1, Math.floor(originalParams.quantity * 0.8));
await new Promise(r => setTimeout(r, 3000));
return { ...originalParams, quantity: newQuantity, fixed: true, delay: 3000 };
}

async function handleBinanceError(error, originalParams, retryCount = 0) {
const analysis = analyzeBinanceError(error);
console.log(⚠️ Binance error: [${analysis.errorCode}] ${analysis.errorMsg} (category: ${analysis.category}));

consecutiveBinanceErrors++;    
lastErrorTime = Date.now();    
    
if (consecutiveBinanceErrors > 5) {    
  console.log("🚨 Too many consecutive Binance errors. Entering emergency recovery mode.");    
  emergencyRecoveryMode = true;    
  setTimeout(() => { emergencyRecoveryMode = false; console.log("✅ Emergency recovery mode ended"); }, CFG.EMERGENCY_COOLDOWN);    
}    
    
if (retryCount >= CFG.MAX_RETRIES) {    
  console.log(`❌ Max retries (${CFG.MAX_RETRIES}) reached. Aborting order.`);    
  return { success: false, action: 'abort' };    
}    
    
let fixResult;    
switch (analysis.category) {    
  case 'INSUFFICIENT_MARGIN':    
    fixResult = await fixInsufficientMargin(originalParams);    
    break;    
  case 'LOT_SIZE':    
    fixResult = await fixLotSize(originalParams);    
    break;    
  case 'PRICE_FILTER':    
    fixResult = await fixPriceFilter(originalParams);    
    break;    
  case 'RATE_LIMIT':    
    fixResult = await fixRateLimit();    
    break;    
  case 'LIQUIDATION':    
    fixResult = await fixLiquidation(originalParams);    
    break;    
  default:    
    fixResult = await fixOtherError(originalParams);    
}    
    
if (fixResult.action === 'abort') {    
  return { success: false, action: 'abort' };    
}    
if (fixResult.action === 'retry') {    
  await new Promise(r => setTimeout(r, fixResult.delay || CFG.RETRY_DELAY_MS));    
  return { success: true, action: 'retry', params: originalParams };    
}    
if (fixResult.fixed) {    
  console.log(`🔄 Retrying with fixed params (attempt ${retryCount + 1}/${CFG.MAX_RETRIES})...`);    
  await new Promise(r => setTimeout(r, CFG.RETRY_DELAY_MS));    
  return { success: true, action: 'retry', params: fixResult };    
}    
return { success: false, action: 'abort' };

}

const originalPlaceOrder = global.placeOrder || placeOrder;
const orderRetryMap = new Map();

global.placeOrder = async function(side, quantity, currentPrice, context = {}) {
const orderKey = ${side}_${Date.now()}_${Math.random()};
let retries = orderRetryMap.get(orderKey) || 0;

const executeWithRetry = async (params) => {    
  try {    
    const result = await originalPlaceOrder(params.side, params.quantity, params.price);    
    consecutiveBinanceErrors = 0;    
    emergencyRecoveryMode = false;    
    orderRetryMap.delete(orderKey);    
    return result;    
  } catch (error) {    
    if (error?.msg || error?.code || error?.message?.includes('binance')) {    
      const handlerResult = await handleBinanceError(error, params, retries);    
      if (handlerResult.success && handlerResult.action === 'retry') {    
        retries++;    
        orderRetryMap.set(orderKey, retries);    
        return executeWithRetry(handlerResult.params);    
      }    
    }    
    console.error("❌ Unrecoverable order error:", error);    
    return null;    
  }    
};    
return executeWithRetry({ side, quantity, price: currentPrice });

};

async function checkAccountHealth() {
if (!CONFIG.trading.REAL_MODE) return;
try {
const balance = account.balance;
const usedMargin = account.balance * 0.1;
const usage = usedMargin / (account.balance || 1);
if (usage > CFG.MARGIN_CALL_THRESHOLD) {
console.log(⚠️ High margin usage: ${(usage*100).toFixed(1)}%. Reducing risk.);
CONFIG.risk.MAX_RISK_PER_TRADE = Math.max(0.5, CONFIG.risk.MAX_RISK_PER_TRADE * 0.8);
}
} catch (err) {
console.error("Health check error:", err.message);
}
}

setInterval(() => checkAccountHealth(), 30000);

let reconnectAttempts = 0;
const originalStartWebSocket = startWebSocket;
global.startWebSocket = function() {
console.log("🔌 AI Guard: Starting WebSocket with auto-recovery...");
originalStartWebSocket();
if (ws) {
ws.on('error', (err) => {
console.error("WebSocket error:", err.message);
reconnectAttempts++;
if (reconnectAttempts > 3) {
console.log("🔄 Multiple WebSocket errors, restarting connection...");
setTimeout(() => {
if (ws) ws.close();
startWebSocket();
}, 10000);
}
});
ws.on('open', () => { reconnectAttempts = 0; });
}
};
