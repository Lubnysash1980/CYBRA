// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 24
// part: 2
// original_header: console.log("💸 MODULE 24 ACTIVE");
// original_line_start: 1432
// original_line_end: 1445
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("💸 MODULE 24 ACTIVE");
global.getPositionSize = async function(price) {
try {
const balance = 1000; // симуляція, можна замінити на реальний баланс
const use = balance * 0.95;
const qty = use / price;
return parseFloat(qty.toFixed(6));
} catch (e) {
console.log("❌ POSITION SIZE ERROR:", e.message);
return 0.001;
}
};
})();
