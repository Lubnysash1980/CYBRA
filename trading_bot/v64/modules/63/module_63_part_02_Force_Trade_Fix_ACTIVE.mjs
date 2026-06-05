// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 63
// part: 2
// original_header: console.log("⚡ MODULE 63: Force Trade Fix ACTIVE");
// original_line_start: 5864
// original_line_end: 5903
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("⚡ MODULE 63: Force Trade Fix ACTIVE");

global.normalizePrice = p => p;
global.priceNormalize = p => p;
if (global.tickSize === 0.1) global.tickSize = 0.00001;
if (CONFIG.cooldown) CONFIG.cooldown.ENABLED = false;
if (CONFIG.signal) {
CONFIG.signal.DEVIATION_THRESHOLD = 0.0002;
CONFIG.signal.VOLUME_THRESHOLD = 0.8;
}
if (global.antiReversalCheck) global.antiReversalCheck = () => true;
if (global.volatilityCheck) global.volatilityCheck = () => ({ action: "TRADE" });
if (global.balanceFilter) global.balanceFilter = s => s;

let realPrice = null;
setInterval(async () => {
try {
const res = await fetch(https://fapi.binance.com/fapi/v1/ticker/price?symbol=${CONFIG.ws.SYMBOL.toUpperCase()});
const data = await res.json();
realPrice = parseFloat(data.price);
} catch (e) {}
}, 1000);

setInterval(async () => {
if (state.status !== "IDLE") return;
if (!realPrice) return;
const prices = buffers.getPrices();
const lastPrice = prices.length ? prices[prices.length - 1] : realPrice;
const dev = (realPrice - lastPrice) / realPrice;
if (Math.abs(dev) < 0.0003) return;
const side = dev > 0 ? "short" : "long";
const qty = calcPositionSize(realPrice);
if (qty <= 0) return;
console.log(🔥 FORCE TRADE (63): ${side} ${qty} @ ${realPrice});
await placeOrder(side, qty, realPrice);
}, 8000);

console.log("✅ Force trade fix ready");
})();
