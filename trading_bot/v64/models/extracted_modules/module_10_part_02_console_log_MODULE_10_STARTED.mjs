// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 10
// part: 2
// original_header: console.log("🛠 MODULE 10 STARTED");
// original_line_start: 1007
// original_line_end: 1042
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🛠 MODULE 10 STARTED");

if (!fs.existsSync("package.json")) {
console.log("📦 Creating package.json...");
const pkg = {
name: "auto-bot",
version: "1.0.0",
main: "bot.js",
type: "commonjs",
scripts: { start: "node bot.js" }
};
fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2));
}

console.log("📦 Installing dependencies...");
runCmd("npm install");

const dirs = ["logs", "data", "modules"];
dirs.forEach((dir) => {
if (!fs.existsSync(dir)) {
fs.mkdirSync(dir, { recursive: true });
console.log(📁 Created: ${dir});
}
});

console.log("🔍 Checking PM2...");
runCmd("pm2 -v");

process.on("uncaughtException", (err) => {
console.log("❌ UNCaught:", err.message);
});
process.on("unhandledRejection", (err) => {
console.log("❌ Unhandled:", err);
});

setInterval(() => {
