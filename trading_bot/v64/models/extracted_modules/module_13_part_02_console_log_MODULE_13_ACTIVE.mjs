// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 13
// part: 2
// original_header: console.log("⚖️ MODULE 13 ACTIVE");
// original_line_start: 1147
// original_line_end: 1161
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("⚖️ MODULE 13 ACTIVE");
const bs = { lastTrade: null, streak: 0 };
global.balanceFilter = function(signal) {
if (!signal || signal.action === "HOLD") return signal;
if (bs.lastTrade === signal.action) bs.streak++;
else bs.streak = 0;
if (bs.streak >= 2) {
console.log("⚖️ BLOCKED OVERBIAS:", signal.action);
return { action: "HOLD", reason: "overbias" };
}
bs.lastTrade = signal.action;
return signal;
};
})();
