// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 14
// part: 2
// original_header: console.log("📈 MODULE 14 ACTIVE");
// original_line_start: 1215
// original_line_end: 1237
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("📈 MODULE 14 ACTIVE");
const at = { entry: null, peak: 0, direction: null };
global.adaptiveTrade = function(price, action) {
if (action === "LONG" || action === "SHORT") {
at.entry = price;
at.peak = 0;
at.direction = action;
console.log("🚀 ENTRY:", action, price);
return;
}
if (!at.entry) return;
let profit = 0;
if (at.direction === "LONG") profit = (price - at.entry) / at.entry;
else profit = (at.entry - price) / at.entry;
if (profit > at.peak) at.peak = profit;
if (profit < at.peak - 0.003) {
console.log("💰 ADAPTIVE CLOSE:", profit);
at.entry = null; at.peak = 0;
return "CLOSE";
}
};
})();
