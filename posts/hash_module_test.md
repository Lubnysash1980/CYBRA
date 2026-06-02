# CYBRA Hash Module Test

Status: generated

Payload SHA256:
`a0fedbfecbddd881e5478bc4065d694e88a392cbde6791a2c5b33c36e3f58622`

Payload Double SHA:
`d5e2604dde75e6309eb79b44f23b4248d9def8b6adc742791b4c09282585fa97`

Root Double SHA:
`bfa5933a62f1529111059e7a51847c80224288a3d37df2820fc0a76d4e5afe26`

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
