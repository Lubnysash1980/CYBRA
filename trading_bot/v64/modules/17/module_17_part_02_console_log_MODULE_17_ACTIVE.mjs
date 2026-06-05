// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 17
// part: 2
// original_header: console.log("🔁 MODULE 17 ACTIVE");
// original_line_start: 1269
// original_line_end: 1286
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🔁 MODULE 17 ACTIVE");
const ar = { history: [] };
const arcfg = { window: 10, reversalThreshold: 0.002 };
global.antiReversalCheck = function(price) {
ar.history.push(price);
if (ar.history.length > arcfg.window) ar.history.shift();
if (ar.history.length < arcfg.window) return true;
const first = ar.history[0];
const last = ar.history[ar.history.length - 1];
const move = (last - first) / first;
if (Math.abs(move) > arcfg.reversalThreshold) {
console.log("⚠️ POSSIBLE REVERSAL");
return false;
}
return true;
};
})();
