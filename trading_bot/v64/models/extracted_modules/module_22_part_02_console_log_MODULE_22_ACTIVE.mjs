// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 22
// part: 2
// original_header: console.log("⚡ MODULE 22 ACTIVE");
// original_line_start: 1388
// original_line_end: 1409
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("⚡ MODULE 22 ACTIVE");
const streams = ["btcusdt@trade", "ethusdt@trade", "solusdt@trade"];
const wsMulti = new WebSocket(wss://stream.binance.com:9443/stream?streams=${streams.join("/")});
const prices = {};
wsMulti.on("message", (data) => {
try {
const json = JSON.parse(data.toString());
const stream = json.stream;
if (!json.data || typeof json.data.p === 'undefined') return;
const price = parseFloat(json.data.p);
const symbol = stream.split("@")[0].toUpperCase();
prices[symbol] = price;
if (global.runMultiSymbol) global.runMultiSymbol(prices);
} catch (e) { console.log("❌ WS PARSE ERROR:", e.message); }
});
wsMulti.on("error", (err) => console.log("❌ WS ERROR:", err.message));
wsMulti.on("close", () => {
console.log("🔄 WS CLOSED → RECONNECT...");
setTimeout(() => initModule22(), 3000);
});
})();
