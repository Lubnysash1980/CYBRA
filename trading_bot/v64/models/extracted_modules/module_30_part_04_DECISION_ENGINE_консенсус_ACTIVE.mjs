// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 30
// part: 4
// original_header: console.log("🧠 MODULE 30: DECISION ENGINE (консенсус) ACTIVE");
// original_line_start: 1908
// original_line_end: 2043
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🧠 MODULE 30: DECISION ENGINE (консенсус) ACTIVE");

// Словник голосів модулів (заповнюється під час перевірок)
const votes = {
volatility: { weight: 1.5, lastVote: null },   // модуль 15
smartTrade: { weight: 1.2, lastVote: null },   // модуль 12
balanceFilter: { weight: 1.0, lastVote: null }, // модуль 13
antiReversal: { weight: 1.2, lastVote: null }, // модуль 17
lossControl: { weight: 2.0, lastVote: null },  // модуль 18
liquidity: { weight: 1.3, lastVote: null },    // модуль 27
// Додайте інші модулі за потреби
};

// Функція для збору голосів (викликається перед входом)
function collectVotes(price, side) {
let totalWeight = 0;
let positiveVotes = 0;

// 1. Модуль 15: волатильність    
if (global.volatilityCheck) {    
  const vol = global.volatilityCheck(price);    
  const vote = (vol && vol.action === "TRADE") ? 1 : 0;    
  votes.volatility.lastVote = vote;    
  totalWeight += votes.volatility.weight;    
  positiveVotes += vote * votes.volatility.weight;    
  console.log(`   📊 Volatility: ${vote === 1 ? "ALLOW" : "BLOCK"} (weight ${votes.volatility.weight})`);    
}    

// 2. Модуль 12: smartTrade    
if (global.smartTrade) {    
  const signal = global.smartTrade(price);    
  const vote = (signal && (signal.action === "LONG" || signal.action === "SHORT")) ? 1 : 0;    
  votes.smartTrade.lastVote = vote;    
  totalWeight += votes.smartTrade.weight;    
  positiveVotes += vote * votes.smartTrade.weight;    
  console.log(`   📊 SmartTrade: ${vote === 1 ? "ALLOW" : "BLOCK"} (weight ${votes.smartTrade.weight})`);    
}    

// 3. Модуль 13: balanceFilter (зазвичай блокує при овербайас)    
if (global.balanceFilter && global.smartTrade) {    
  const raw = global.smartTrade(price);    
  const filtered = global.balanceFilter(raw);    
  const vote = (filtered && filtered.action !== "HOLD") ? 1 : 0;    
  votes.balanceFilter.lastVote = vote;    
  totalWeight += votes.balanceFilter.weight;    
  positiveVotes += vote * votes.balanceFilter.weight;    
  console.log(`   📊 BalanceFilter: ${vote === 1 ? "ALLOW" : "BLOCK"} (weight ${votes.balanceFilter.weight})`);    
}    

// 4. Модуль 17: antiReversal    
if (global.antiReversalCheck) {    
  const vote = global.antiReversalCheck(price) ? 1 : 0;    
  votes.antiReversal.lastVote = vote;    
  totalWeight += votes.antiReversal.weight;    
  positiveVotes += vote * votes.antiReversal.weight;    
  console.log(`   📊 AntiReversal: ${vote === 1 ? "ALLOW" : "BLOCK"} (weight ${votes.antiReversal.weight})`);    
}    

// 5. Модуль 18: lossControl (блок при трьох збитках)    
if (global.lossControl) {    
  // Передаємо "CHECK" щоб отримати статус без зміни лічильника    
  const originalLossControl = global.lossControl;    
  let tempResult = true;    
  // Тимчасово підміняємо, щоб не змінювати стан    
  global.lossControl = (arg) => { if (arg === "CHECK") return tempResult; return originalLossControl(arg); };    
  tempResult = originalLossControl("CHECK");    
  global.lossControl = originalLossControl;    
  const vote = tempResult ? 1 : 0;    
  votes.lossControl.lastVote = vote;    
  totalWeight += votes.lossControl.weight;    
  positiveVotes += vote * votes.lossControl.weight;    
  console.log(`   📊 LossControl: ${vote === 1 ? "ALLOW" : "BLOCK"} (weight ${votes.lossControl.weight})`);    
}    

// 6. Модуль 27: liquidityFilter    
if (global.liquidityFilter) {    
  const vote = global.liquidityFilter(price) ? 1 : 0;    
  votes.liquidity.lastVote = vote;    
  totalWeight += votes.liquidity.weight;    
  positiveVotes += vote * votes.liquidity.weight;    
  console.log(`   📊 Liquidity: ${vote === 1 ? "ALLOW" : "BLOCK"} (weight ${votes.liquidity.weight})`);    
}    

const consensusRatio = totalWeight === 0 ? 0.5 : positiveVotes / totalWeight;    
console.log(`   🧠 Consensus ratio: ${(consensusRatio * 100).toFixed(1)}% (positive ${positiveVotes} / total ${totalWeight})`);    
return consensusRatio >= 0.55; // 55% позитивних голосів

}

// Перехоплюємо оригінальний onTick (але не ламаємо ланцюжок)
const previousOnTick = onTick;
onTick = async function(price, volume) {
// Спочатку виконуємо всі оригінальні перевірки (включно з блокуваннями)
await previousOnTick(price, volume);

// Якщо стан IDLE і ми не на кулдауні, але оригінальний onTick не створив сигнал (state все ще IDLE)    
if (state.status === "IDLE" && cooldownUntil <= Date.now()) {    
  // Шукаємо, чи є хоч один модуль, який дає сигнал (наприклад, smartTrade або buildSignal)    
  let externalSignal = null;    
  if (global.smartTrade) {    
    const stSignal = global.smartTrade(price);    
    if (stSignal && (stSignal.action === "LONG" || stSignal.action === "SHORT")) {    
      externalSignal = { side: stSignal.action === "LONG" ? "long" : "short", source: "smartTrade" };    
    }    
  }    
  if (!externalSignal && buildSignal) {    
    const rawSignal = buildSignal(price);    
    if (rawSignal && rawSignal.side) {    
      externalSignal = { side: rawSignal.side, source: "buildSignal" };    
    }    
  }    

  if (externalSignal) {    
    console.log(`🔔 DECISION ENGINE: отримано сигнал від ${externalSignal.source} (${externalSignal.side})`);    
    const consensus = collectVotes(price, externalSignal.side);    
    if (consensus) {    
      console.log(`✅ DECISION ENGINE: консенсус досягнуто. ВХІД ${externalSignal.side}`);    
      const qty = calcPositionSize(price);    
      if (qty > 0) {    
        const order = await placeOrder(externalSignal.side, qty, price);    
        if (order) {    
          state.status = "IN_TRADE";    
          state.entry = price;    
          state.side = externalSignal.side;    
          account.tradesToday++;    
        }    
      }    
    } else {    
      console.log(`❌ DECISION ENGINE: консенсусу немає. Вхід відхилено.`);    
    }    
  }    
}

};
})();
