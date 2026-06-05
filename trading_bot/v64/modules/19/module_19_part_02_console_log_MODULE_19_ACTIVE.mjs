// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 19
// part: 2
// original_header: console.log("💰 MODULE 19 ACTIVE");
// original_line_start: 1311
// original_line_end: 1330
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("💰 MODULE 19 ACTIVE");
const rp = { entry: null, direction: null };
global.setEntry = function(price, direction) { rp.entry = price; rp.direction = direction; };
global.calculatePnL = function(price) {
if (!rp.entry || !rp.direction) return null;
let pnl = 0;
if (rp.direction === "LONG") pnl = (price - rp.entry) / rp.entry;
else pnl = (rp.entry - price) / rp.entry;
return pnl;
};
global.closeTrade = function(price) {
const pnl = global.calculatePnL(price);
if (pnl === null) return null;
console.log("💰 PnL:", (pnl * 100).toFixed(3) + "%");
const result = pnl > 0 ? "PROFIT" : "LOSS";
rp.entry = null; rp.direction = null;
return result;
};
})();
