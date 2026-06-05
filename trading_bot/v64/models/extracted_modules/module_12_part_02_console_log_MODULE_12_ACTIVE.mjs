// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 12
// part: 2
// original_header: console.log("🧠 MODULE 12 ACTIVE");
// original_line_start: 1091
// original_line_end: 1142
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🧠 MODULE 12 ACTIVE");

const cfg = {
impulse: 0.004,
fakeThreshold: 0.002,
minMove: 0.003
};
const st = { lastPrice: null, lastHigh: null, lastLow: null, direction: null, entry: null, peak: 0 };

global.smartTrade = function(price) {
if (!st.lastPrice) {
st.lastPrice = price;
st.lastHigh = price;
st.lastLow = price;
return { action: "WAIT" };
}
const change = (price - st.lastPrice) / st.lastPrice;
if (price > st.lastHigh) st.lastHigh = price;
if (price < st.lastLow) st.lastLow = price;
const fakeUp = price < st.lastHigh * (1 - cfg.fakeThreshold);
const fakeDown = price > st.lastLow * (1 + cfg.fakeThreshold);
if (fakeUp || fakeDown) {
console.log("🚫 FAKE BREAKOUT");
return { action: "HOLD", reason: "fake" };
}
if (Math.abs(change) < cfg.impulse) return { action: "HOLD", reason: "no_impulse" };
const direction = change > 0 ? "LONG" : "SHORT";
console.log("📊 SIGNAL:", direction, change);
st.lastPrice = price;
return { action: direction, confidence: Math.abs(change) };
};

global.managePosition = function(price) {
if (!st.entry) return;
const profit = (price - st.entry) / st.entry;
if (profit > st.peak) st.peak = profit;
if (profit < st.peak - 0.002) {
console.log("💰 TAKE PROFIT (dynamic)");
st.entry = null; st.peak = 0;
return "CLOSE";
}
return "HOLD";
};

global.openPosition = function(price, direction) {
st.entry = price;
st.direction = direction;
st.peak = 0;
console.log("🚀 OPEN", direction, "at", price);
};
})();
