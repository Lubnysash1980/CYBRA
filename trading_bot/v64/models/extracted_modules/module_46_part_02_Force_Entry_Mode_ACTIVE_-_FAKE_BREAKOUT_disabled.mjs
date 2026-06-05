// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 46
// part: 2
// original_header: console.log("🔥 MODULE 46: Force Entry Mode ACTIVE - FAKE BREAKOUT disabled");
// original_line_start: 4527
// original_line_end: 4558
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🔥 MODULE 46: Force Entry Mode ACTIVE - FAKE BREAKOUT disabled");

// Повністю вимикаємо функцію isFakeBreakout, якщо вона існує
if (typeof isFakeBreakout !== 'undefined') {
global.isFakeBreakout = () => false;
}
// Також перевизначаємо будь-яке можливе посилання на isFakeBreakout всередині модулів
if (global.isFakeBreakout) global.isFakeBreakout = () => false;

// Перевизначаємо buildSignal, ігноруючи FAKE BREAKOUT
const originalBuildSignal = global.buildSignal || buildSignal;
global.buildSignal = function(price) {
// Тимчасово підміняємо, щоб оригінальна функція не заблокувала
const originalFake = global.isFakeBreakout;
global.isFakeBreakout = () => false;
let signal = originalBuildSignal(price);
if (originalFake) global.isFakeBreakout = originalFake;
return signal;
};

// Вимикаємо логування FAKE BREAKOUT (щоб не спамило)
const originalLog = console.log;
console.log = function(...args) {
if (args[0] && typeof args[0] === 'string' && args[0].includes('FAKE BREAKOUT')) {
return;
}
originalLog.apply(console, args);
};

console.log("✅ FAKE BREAKOUT detector completely disabled. Bot will now attempt entries based on deviation/volume.");
})();
