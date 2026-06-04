import {
  Connection,
  Keypair,
  PublicKey
} from "@solana/web3.js";

import {
  getOrCreateAssociatedTokenAccount,
  mintTo,
  TOKEN_2022_PROGRAM_ID
} from "@solana/spl-token";

import fs from "fs";
import bs58 from "bs58";
import dns from "node:dns";
dns.setDefaultResultOrder("ipv4first");

// ===== НАЛАШТУВАННЯ =====
const RPC_URL = "https://api.mainnet-beta.solana.com";
const SECRET_FILE = "./mint_secret_base58.txt";
const MINT_ADDRESS = "tNKTSniyrizhKQSQNzQWE2vnrnGtUEYnh4LNrMCg8xA";
const RECEIVER_WALLET = "EPEhVVhY7AXzWqcJeidWNuBqNbGDjJF35JzPVFXEbYxv";

// ⚠️ кількість з урахуванням decimals = 9
// 1 токен = 1_000_000_000
const AMOUNT = 4900000000000000000000000000000n; // bigint!

(async () => {
  try {
    const connection = new Connection(RPC_URL, "confirmed");

    console.log("🔑 Завантаження mint authority...");
    const secret = fs.readFileSync(SECRET_FILE, "utf8").trim();
    const authority = Keypair.fromSecretKey(bs58.decode(secret));

    const mintPubkey = new PublicKey(MINT_ADDRESS);
    const receiverPubkey = new PublicKey(RECEIVER_WALLET);

    console.log("📦 Створюємо / перевіряємо ATA...");
    const ata = await getOrCreateAssociatedTokenAccount(
      connection,
      authority,               // payer
      mintPubkey,              // mint
      receiverPubkey,          // owner
      false,
      "confirmed",
      undefined,
      TOKEN_2022_PROGRAM_ID
    );

    console.log("✅ ATA:", ata.address.toBase58());

    console.log("🚀 Мінтимо токени...");
    const sig = await mintTo(
      connection,
      authority,               // payer
      mintPubkey,
      ata.address,
      authority,               // mint authority
      AMOUNT,
      [],
      undefined,
      TOKEN_2022_PROGRAM_ID
    );

    console.log("🎉 УСПІХ!");
    console.log("🔗 Tx:", sig);

    const bal = await connection.getTokenAccountBalance(
      ata.address,
      "confirmed"
    );

    console.log("📊 Баланс:", bal.value.uiAmountString);

  } catch (e) {
    console.error("❌ ПОМИЛКА:", e);
  }
})();