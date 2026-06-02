# CYBRA Hash Module Test

Status: generated

Payload SHA256:
`765dc78efa3f89435e0153fd4abda3aec1a0fce153e74c2310d6f6149191bbaa`

Payload Double SHA:
`763b1e7f6c141b968b0427f0c9821e2bd71e0ed284609670101fa64bd2b6944a`

Root Double SHA:
`ab6e7d7a482dc51e9b8e2f2c25e73879f313a648804f878b1f341d999a5ed62c`

Manifest:
`hash_storage/test/hash_module_test_manifest.json`

## Detected hash modules

- `gitcybrahash_double_backend.mjs`: True
- `hash_memory.py`: True
- `hash_daemon.mjs`: True
- `cybra_sha_core_manager.sh`: True
- `hash_storage/root_hash.json`: True


## Result

Hash module base pipeline works if:

- payload file exists;
- manifest file exists;
- proof file verifies;
- double SHA is generated;
- root double SHA is generated.
