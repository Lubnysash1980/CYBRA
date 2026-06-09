// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 64
// part: 2
// original_header: console.log("🔥 MODULE 64: Ultimate Force Trade (no window) ACTIVE");
// original_line_start: 5908
// original_line_end: 5978
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🔥 MODULE 64: Ultimate Force Trade (no window) ACTIVE");

const identity = (x) => x;
if (global.normalizePrice) global.normalizePrice = identity;
if (global.priceNormalize) global.priceNormalize = identity;
if (global.tickSize === 0.1) global.tickSize = 0.00001;
if (global.stepSize === 0.001) global.stepSize = 1;
if (CONFIG.cooldown) CONFIG.cooldown.ENABLED = false;
if (CONFIG.signal) {
CONFIG.signal.DEVIATION_THRESHOLD = 0.0002;
CONFIG.signal.VOLUME_THRESHOLD = 0.8;
CONFIG.signal.VOLATILITY_THRESHOLD = 0.00005;
}
if (global.antiReversalCheck) global.antiReversalCheck = () => true;
if (global.volatilityCheck) global.volatilityCheck = () => ({ action: "TRADE" });
if (global.balanceFilter) global.balanceFilter = (s) => s;
if (global.liquidityFilter) global.liquidityFilter = () => true;
if (global.isFakeBreakout) global.isFakeBreakout = () => false;

let realPrice = null;
let lastFetch = 0;
const symbol = CONFIG.ws.SYMBOL.toUpperCase();
async function fetchRealPrice() {
const now = Date.now();
if (now - lastFetch < 1000) return realPrice;
lastFetch = now;
try {
const res = await fetch(https://fapi.binance.com/fapi/v1/ticker/price?symbol=${symbol});
const data = await res.json();
realPrice = parseFloat(data.price);
return realPrice;
} catch (e) { return realPrice; }
}
fetchRealPrice();
setInterval(fetchRealPrice, 1000);

const originalCalcPos = calcPositionSize;
global.calcPositionSize = function(price) {
if (account.balance < 10) return 5;
return originalCalcPos(price);
};

let lastForce = 0;
setInterval(async () => {
if (state.status !== "IDLE") return;
if (cooldownUntil > Date.now()) return;
if (Date.now() - lastForce < 8000) return;
lastForce = Date.now();
const price = await fetchRealPrice();
if (!price) return;
const prices = buffers.getPrices();
if (prices.length < 5) return;
const short = avg(prices.slice(-3));
const long = avg(prices.slice(-5));
const dev = (short - long) / long;
if (Math.abs(dev) < 0.0003) return;
const side = dev > 0 ? "long" : "short";
const qty = calcPositionSize(price);
if (qty <= 0) return;
console.log(🚀 FORCE ENTRY: ${side} ${qty} DOGE @ ${price});
const order = await placeOrder(side, qty, price);
if (order) {
state.status = "IN_TRADE";
state.entry = price;
state.side = side;
}
}, 8000);

console.log("✅ Ultimate force trade ready (no window)");
})();
