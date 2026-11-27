# CYBRA NEURO — guarded code evolution

NEURO is a staged code-writing agent. Generation never edits live source files.

## Requirements
- Python 3.10+
- OPENAI_API_KEY exported in Termux (never stored in this repository)
- CYBRA_NEURO_PARLIAMENT_AUTHOR set to an active Parliament member address
- CYBRA_NEURO_MODEL optional; defaults to gpt-4.1-mini
- Existing EVOLUTION baseline at modules/module_121_parlament/data/evolve/baseline.json
- An enabled process in config/pm_processes.json for the final explicit restart

## Workflow
1. Generate and stage a patch:
   python3 modules/module_500_neuro/neuro.py generate --task "Describe the exact code change" modules/module_121_parlament/evolve.py
2. Submit to Parliament:
   python3 modules/module_500_neuro/neuro.py propose PATCH_ID
3. Review and approve the upgrade proposal through the existing Parliament workflow. NEURO cannot self-approve.
   A narrowly validated NEURO proposal may be submitted while health is below 100%; voting and approval remain subject to the normal Parliament/Gate rules. This exception does not permit contracts, transfers, deployment, signing, or other proposal types.
4. Apply only after approval, naming the exact process:
   python3 modules/module_500_neuro/neuro.py apply PATCH_ID --restart PROCESS_NAME
5. List staged patches:
   python3 modules/module_500_neuro/neuro.py status

## Root isolation
- NEURO, EVOLUTION, Metrics, the Test Suite, and PM Supervisor resolve the same root from `CYBRA_ROOT` when set, otherwise from their own repository location.
- A worktree such as `~/CYBRA_NEURO` is a validation copy. NEURO `apply` is blocked there, and PM Supervisor start/stop actions are blocked there, so copied process configuration cannot operate on `~/CYBRA`.
- The branch does not contain an EVOLUTION baseline. The 3% gate must fail closed until a valid baseline is present in the selected root; NEURO must not create or lower it automatically.

## Apply guarantees
- Checks that source files have not changed since generation.
- Creates a per-patch Golden Dump with SHA-256 metadata before writes.
- Runs changed-file syntax checks and the existing full Test Suite.
- Compares EVOLUTION metrics with the existing baseline; any bad deviation beyond 3% blocks the patch. NEURO never rewrites the baseline.
- Restarts only the explicitly named enabled cybra-pm process.
- Runs tests and the 3% gate again after restart.
- On failure, restores the exact pre-change files from the verified dump and attempts to restart the restored process.

## Limits
- Only existing source files under modules/module_*/ can be edited.
- No secrets, configs, wallet files, user data, PM2 state, or arbitrary paths.
- No automatic merge to main.
- REWARD is not a token or financial payout.
- No 100% status is claimed unless independent checks pass.
