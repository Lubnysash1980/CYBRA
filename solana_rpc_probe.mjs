import dns from "node:dns";
import fs from "node:fs";

dns.setDefaultResultOrder("ipv4first");

const endpoints = [
  process.env.SOLANA_RPC_URL,
  process.env.RPC_URL,
  "https://api.mainnet-beta.solana.com",
  "https://solana-rpc.publicnode.com",
  "https://api.devnet.solana.com"
].filter(Boolean);

const account = process.env.SOLANA_TEST_ACCOUNT || "5WSJNhe6ChKAQWdJ9aSbEDJAict8msL5R7rRyejs8E6T";

async function rpc(endpoint, method, params = []) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12000);

  try {
    const r = await fetch(endpoint, {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method,
        params
      }),
      signal: controller.signal
    });

    const text = await r.text();
    clearTimeout(timeout);

    let json = null;
    try { json = JSON.parse(text); } catch {}

    return {
      ok: r.ok,
      http: r.status,
      text: text.slice(0, 500),
      json
    };
  } catch (e) {
    clearTimeout(timeout);
    return {
      ok: false,
      error: e.message,
      cause: e.cause ? String(e.cause) : null
    };
  }
}

async function main() {
  fs.mkdirSync("data/solana_rpc", {recursive: true});

  const results = [];
  let selected = null;

  for (const endpoint of endpoints) {
    console.log("\nRPC TEST:", endpoint);

    const health = await rpc(endpoint, "getHealth");
    console.log("getHealth:", health.ok ? "OK" : "FAIL", health.http || "", health.error || "");

    const blockhash = await rpc(endpoint, "getLatestBlockhash");
    console.log("getLatestBlockhash:", blockhash.ok ? "OK" : "FAIL", blockhash.http || "", blockhash.error || "");

    const acct = await rpc(endpoint, "getAccountInfo", [account, {"encoding": "base64"}]);
    console.log("getAccountInfo:", acct.ok ? "OK" : "FAIL", acct.http || "", acct.error || "");

    const good = blockhash.ok && !blockhash.error && blockhash.json && !blockhash.json.error;

    results.push({
      endpoint,
      health,
      blockhash,
      account,
      account_info_ok: acct.ok,
      good
    });

    if (!selected && good) {
      selected = endpoint;
    }
  }

  const report = {
    status: selected ? "rpc_found" : "rpc_not_found",
    selected_rpc: selected,
    account,
    time: Date.now(),
    results
  };

  fs.writeFileSync("data/solana_rpc/rpc_probe_report.json", JSON.stringify(report, null, 2));

  if (selected) {
    fs.writeFileSync("data/solana_rpc/selected_rpc.local", selected + "\n");
    console.log("\n✅ SELECTED_RPC:", selected);
    process.exit(0);
  } else {
    console.log("\n❌ NO WORKING RPC FOUND");
    console.log("Try another internet/VPN/private RPC.");
    process.exit(1);
  }
}

main();
