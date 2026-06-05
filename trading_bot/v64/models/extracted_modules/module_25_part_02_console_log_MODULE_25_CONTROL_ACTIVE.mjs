// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 25
// part: 2
// original_header: console.log("🧠 MODULE 25 CONTROL ACTIVE");
// original_line_start: 1451
// original_line_end: 1566
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🧠 MODULE 25 CONTROL ACTIVE");

const queue = [];
let processing = false;

const timings = {
volatility: 0,
signal: 50,
risk: 100,
entry: 150,
manage: 200
};

function now() {
return Date.now();
}

function wait(ms) {
return new Promise(res => setTimeout(res, ms));
}

async function runPipeline(price, volume) {
if (processing) {
queue.push({ price, volume });
return;
}

processing = true;    

try {    
  // STEP 1: VOLATILITY    
  await wait(timings.volatility);    
  const vol = global.volatilityCheck?.(price);    
  if (!vol || vol.action !== "TRADE") {    
    processing = false;    
    return;    
  }    

  // STEP 2: AUTO ADAPT    
  await wait(10);    
  global.autoAdapt?.(price);    

  // STEP 3: ANTI REVERSAL    
  await wait(10);    
  if (global.antiReversalCheck && !global.antiReversalCheck(price)) {    
    processing = false;    
    return;    
  }    

  // STEP 4: SIGNAL    
  await wait(timings.signal);    
  let signal = global.smartTrade?.(price);    
  if (global.balanceFilter) signal = global.balanceFilter(signal);    
  if (!signal || signal.action === "HOLD" || signal.action === "WAIT") {    
    processing = false;    
    return;    
  }    

  // STEP 5: RISK CHECK    
  await wait(timings.risk);    

  if (global.lossControl && !global.lossControl("CHECK")) {    
    processing = false;    
    return;    
  }    

  // STEP 6: ENTRY    
  await wait(timings.entry);    

  if (signal.action === "LONG" || signal.action === "SHORT") {    
    global.openPosition?.(price, signal.action);    
    global.setEntry?.(price, signal.action);    

    const qty = await global.getPositionSize?.(price) || 0.001;    
    global.placeOrder?.(CONFIG.ws.SYMBOL, signal.action, qty);    
  }    

  // STEP 7: MANAGEMENT    
  await wait(timings.manage);    

  const result = global.managePosition?.(price);    
  if (result === "CLOSE") {    
    const pnlResult = global.closeTrade?.(price);    

    if (pnlResult && global.lossControl) {    
      global.lossControl(pnlResult);    
    }    

    if (global.logTrade) {    
      const pnl = global.calculatePnL?.(price) || 0;    
      global.logTrade(pnl);    
    }    
  }    

} catch (e) {    
  console.log("❌ CONTROL ERROR:", e.message);    
}    

processing = false;    

// process queue    
if (queue.length > 0) {    
  const next = queue.shift();    
  runPipeline(next.price, next.volume);    
}

}

// Зберігаємо попередній onTick і викликаємо його після виконання конвеєра, щоб не зламати оригінальну логіку
const previousOnTick = onTick;
onTick = async function(price, volume) {
await runPipeline(price, volume);
// Викликаємо оригінальний обробник, щоб зберегти базову логіку (deviation, volume spike тощо)
if (previousOnTick) await previousOnTick(price, volume);
};
