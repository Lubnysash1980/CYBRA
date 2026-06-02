# CYBRA Hash Module Test

Status: generated

Payload SHA256:
`0ce8d0389c66466459b0a662f25c847a65f549cd7170d5b72db9f68a131f58eb`

Payload Double SHA:
`fdd99c78f6224eb2efb398e8114fae6bbcdc5104443c6e1275ac2594ba3c7b41`

Root Double SHA:
`9cb141c1ad85784da150cccb937ef17a8ef6d800a66f44e9dfec61b48384b768`

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
