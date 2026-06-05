// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 18
// part: 2
// original_header: console.log("🛑 MODULE 18 ACTIVE");
// original_line_start: 1291
// original_line_end: 1306
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🛑 MODULE 18 ACTIVE");
const lc = { losses: 0 };
global.lossControl = function(result) {
if (result === "LOSS") {
lc.losses++;
console.log("📉 LOSS COUNT:", lc.losses);
}
if (result === "PROFIT") lc.losses = 0;
if (lc.losses >= 3) {
console.log("🛑 STOP TRADING (LOSS LIMIT)");
return false;
}
return true;
};
})();
