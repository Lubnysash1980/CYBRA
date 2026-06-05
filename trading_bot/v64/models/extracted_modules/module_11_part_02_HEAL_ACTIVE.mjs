// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 11
// part: 2
// original_header: console.log("🧠 MODULE 11 SELF-HEAL ACTIVE");
// original_line_start: 1052
// original_line_end: 1082
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🧠 MODULE 11 SELF-HEAL ACTIVE");

const healState = { errors: 0, lastFix: null };

global.safeRun = async function(fn, context = "unknown") {
try {
return await fn();
} catch (err) {
console.log(⚠️ ERROR in ${context}:, err.message);
healState.errors++;
const msg = err.message || "";
if (msg.includes("fs")) console.log("🔧 Fix: fs-related issue");
else if (msg.includes("undefined")) console.log("🔧 Fix: undefined value");
else if (msg.includes("ECONNRESET")) console.log("🔧 Fix: network issue");
if (healState.errors > 5) {
console.log("⚠️ Too many errors → throttling");
healState.errors = 0;
}
console.log("✅ Fix applied:", healState.lastFix);
return null;
}
};

process.on("uncaughtException", (err) => {
console.log("❌ Uncaught Exception:", err.message);
});
process.on("unhandledRejection", (reason) => {
console.log("❌ Unhandled Rejection:", reason);
});

setInterval(() => {
