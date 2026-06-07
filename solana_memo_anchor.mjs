import fs from "fs";
import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  TransactionInstruction,
  sendAndConfirmTransaction,
  clusterApiUrl
} from "@solana/web3.js";

const [,, keypairPath, clusterArg, memo] = process.argv;

if (!keypairPath || !clusterArg || !memo) {
  console.error("Usage: node solana_memo_anchor.mjs KEYPAIR.json mainnet-beta MEMO");
  process.exit(1);
}

const secret = JSON.parse(fs.readFileSync(keypairPath, "utf8"));
const payer = Keypair.fromSecretKey(Uint8Array.from(secret));

const endpoint = clusterArg.startsWith("http")
  ? clusterArg
  : clusterApiUrl(clusterArg);

const connection = new Connection(endpoint, "confirmed");

const memoProgram = new PublicKey("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");
const ix = new TransactionInstruction({
  keys: [],
  programId: memoProgram,
  data: Buffer.from(memo, "utf8")
});

const tx = new Transaction().add(ix);
const sig = await sendAndConfirmTransaction(connection, tx, [payer], {
  commitment: "confirmed"
});

const out = {
  status: "KIBRA_BLOCKCHAIN_ANCHOR_TX_SENT",
  chain: "solana",
  cluster: clusterArg,
  payer: payer.publicKey.toBase58(),
  memo,
  signature: sig,
  explorer: `https://solscan.io/tx/${sig}${clusterArg === "devnet" ? "?cluster=devnet" : ""}`,
  timestamp: new Date().toISOString()
};

fs.mkdirSync("feeds", { recursive: true });
fs.mkdirSync("data/kibra_blockchain_market_proof/reports", { recursive: true });

fs.writeFileSync("feeds/kibra_blockchain_anchor_tx.json", JSON.stringify(out, null, 2));
fs.writeFileSync("data/kibra_blockchain_market_proof/reports/latest_anchor_tx.json", JSON.stringify(out, null, 2));

console.log(JSON.stringify(out, null, 2));
