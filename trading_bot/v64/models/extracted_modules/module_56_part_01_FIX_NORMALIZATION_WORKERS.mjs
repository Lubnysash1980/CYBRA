// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 56
// part: 1
// original_header: // ================== MODULE 56: FIX NORMALIZATION & WORKERS ==================
// original_line_start: 5275
// original_line_end: 5284
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

// ================== MODULE 56: FIX NORMALIZATION & WORKERS ==================
(function() {
// 1. Вбиваємо нормалізацію ціни (яка перетворює 0.093 на 0)
if (global.normalizePrice) global.normalizePrice = p => p;
if (global.priceNormalize) global.priceNormalize = p => p;
// 2. Тимчасово вимикаємо заміну хворих воркерів (щоб не спамило)
if (global.replaceSickWorker) global.replaceSickWorker = () => {};
console.log("✅ Price normalization killed, worker replacement disabled.");
})();
