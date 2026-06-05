// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 29
// part: 2
// original_header: console.log("🚀 MODULE 29 V2 ACTIVE");
// original_line_start: 1699
// original_line_end: 1781
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🚀 MODULE 29 V2 ACTIVE");

let lastTradeTime = Date.now();
const FORCE_INTERVAL = 15000;

function isMarketValid() {
const prices = buffers.getPrices();
if (prices.length < 10) return false;

const max = Math.max(...prices);    
const min = Math.min(...prices);    

if (min <= 0) return false;    

const range = ((max - min) / min) * 100;    

// ❌ якщо знову баг    
if (range > 10) return false;    

return true;

}

function getDirection() {
const prices = buffers.getPrices();
if (prices.length < 5) return null;

const p1 = prices.at(-1);    
const p5 = prices.at(-5);    

const change = (p1 - p5) / p5;    

if (change > 0.0005) return "long";    
if (change < -0.0005) return "short";    

return Math.random() > 0.5 ? "long" : "short";

}

async function forceEntry(price) {
if (!isMarketValid()) {
console.log("🚫 FORCE BLOCK: BAD MARKET");
return;
}

if (state.status !== "IDLE") return;    

const side = getDirection();    
if (!side) return;    

const qty = calcPositionSize(price);    
if (qty <= 0) return;    

console.log("🚀 FORCE ENTRY:", side);    

const order = await placeOrder(side, qty, price);    
if (!order) return;    

state.status = "IN_TRADE";    
state.entry = price;    
state.side = side;    

account.tradesToday++;    
lastTradeTime = Date.now();

}

const previousOnTick = onTick;
onTick = async function(price, volume) {
if (previousOnTick) await previousOnTick(price, volume);

const now = Date.now();    
if (    
  state.status === "IDLE" &&    
  now - lastTradeTime > FORCE_INTERVAL &&    
  cooldownUntil < now    
) {    
  await forceEntry(price);    
}

};
})();
