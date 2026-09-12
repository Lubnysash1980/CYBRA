#!/usr/bin/env node

const { spawnSync } = require("child_process");
const path = require("path");

const ROOT = __dirname;
const BACKEND = path.join(ROOT, "gitcybrahash_double_backend.py");
const SNAPSHOT = path.join(ROOT, "cybra_snapshot.py");

const args = process.argv.slice(2);

function run(command, commandArgs) {
    const result = spawnSync(command, commandArgs, {
        cwd: ROOT,
        stdio: "inherit"
    });

    if (result.error) {
        console.error("[CYBRA NODE] command failed:", result.error.message);
        process.exit(1);
    }

    process.exit(result.status === null ? 1 : result.status);
}

if (args.length > 0) {
    switch (args[0]) {
        case "--snapshot-save":
            run("python3", [SNAPSHOT, "save"]);
            break;

        case "--snapshot-verify":
            run("python3", [SNAPSHOT, "verify"]);
            break;

        case "--snapshot-status":
            run("python3", [SNAPSHOT, "status"]);
            break;

        default:
            // Existing behavior: pass all arguments to the full Python backend.
            run("python3", [BACKEND, ...args]);
    }
}

// Existing default behavior.
run("python3", [BACKEND]);
