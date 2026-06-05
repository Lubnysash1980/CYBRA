// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 21
// part: 2
// original_header: console.log("🌐 MODULE 21 ACTIVE");
// original_line_start: 1351
// original_line_end: 1383
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🌐 MODULE 21 ACTIVE");
const symbols = ["BTCUSDT", "ETHUSDT", "SOLUSDT"];
global.runMultiSymbol = function(prices) {
for (const symbol of symbols) {
const price = prices[symbol];
if (!price) continue;
if (global.autoAdapt) global.autoAdapt(price);
if (global.volatilityCheck) {
const vol = global.volatilityCheck(price);
if (vol.action !== "TRADE") continue;
}
if (global.antiReversalCheck && !global.antiReversalCheck(price)) continue;
let signal = global.smartTrade ? global.smartTrade(price) : null;
if (global.balanceFilter) signal = global.balanceFilter(signal);
if (signal && (signal.action === "LONG" || signal.action === "SHORT")) {
if (global.openPosition) global.openPosition(price, signal.action);
if (global.setEntry) global.setEntry(price, signal.action);
if (global.placeOrder) global.placeOrder(symbol, signal.action, 0.001);
}
if (global.adaptiveTrade) {
const result = global.adaptiveTrade(price, signal ? signal.action : null);
if (result === "CLOSE") {
const tradeResult = global.closeTrade ? global.closeTrade(price) : null;
if (tradeResult && global.lossControl && !global.lossControl(tradeResult)) {
console.log("🛑 STOP ALL SYMBOLS");
return;
}
}
}
}
};
})();
