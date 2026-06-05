// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 27
// part: 4
// original_header: // liquidity check (MODULE 27)
// original_line_start: 1613
// original_line_end: 1637
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

// liquidity check (MODULE 27)    
  if (!global.liquidityFilter(price)) return null;    

  const trend = global.getTrend?.(price);    
  const momentum = global.getMomentum?.(price);    

  // avoid sideways market    
  if (trend === "SIDEWAYS") return null;    

  // momentum confirmation    
  if (signal.action === "LONG" && momentum < 0) return null;    
  if (signal.action === "SHORT" && momentum > 0) return null;    

  return {    
    action: signal.action,    
    strength: Math.abs(momentum || 0)    
  };    

} catch (e) {    
  console.log("❌ ENTRY ERROR:", e.message);    
  return null;    
}

};
