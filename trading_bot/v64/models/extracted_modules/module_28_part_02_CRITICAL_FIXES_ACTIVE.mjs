// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 28
// part: 2
// original_header: console.log("🔧 MODULE 28: CRITICAL FIXES ACTIVE");
// original_line_start: 1676
// original_line_end: 1694
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🔧 MODULE 28: CRITICAL FIXES ACTIVE");

// 1. Фікс розрахунку волатильності (нормалізація до відсотків) - вже зроблено в модулі 15
// 2. Фікс детектора фейкового пробою (збільшені пороги) - залишаємо як є
// 3. Обмеження частоти логів (не частіше ніж раз на 50 мс)
let lastLog = 0;
const originalConsoleLog = console.log;
console.log = function(...args) {
const now = Date.now();
if (now - lastLog > 50) {
lastLog = now;
originalConsoleLog.apply(console, args);
}
};

// 4. Додаткова перевірка для змінної state (запобігання помилкам)
if (!global.state) global.state = state;
})();
