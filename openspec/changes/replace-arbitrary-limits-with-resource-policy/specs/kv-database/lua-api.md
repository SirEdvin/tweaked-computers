# kv-database resource-policy Lua API amendment

Proposed normative amendment to the existing [API](../../../../specs/kv-database/lua-api.md), with unchanged details retained there unless explicitly replaced below. Shared execution, status and errors: [api-contract.md](../../api-contract.md).

All current string/hash/key/TTL methods and exact return values are preserved. `getLimits()` keeps KV `keys`, `bytes`, `key_bytes`, `value_bytes`, `hash_fields`, `hash_bytes`, `total_hash_fields`, `command_arguments`, command-payload and snapshot fields, now reflecting runtime-global settings; it also exposes policy version 2 resource metadata. Removed shared per-table/node ceilings must not undercut an otherwise valid configured KV request.

`set`, `hset` and other mutations remain command-atomic. Work preparation can suspend, but the candidate must be based on current live contents at commit, not overwrite an intervening writer. Expiry is evaluated at the actual service observation/commit tick and absolute deadlines remain unchanged on refusal.

Capacity errors are catchable and include setting/resource details. A lowered limit never makes existing keys unreadable or blocks deletion, expiry or non-growing replacement solely because old usage exceeds the new setting. Mining and replacement preserve all previously accepted bytes/deadlines, including over-limit contents. `snapshot_bytes` limits new admission/transfer reservation, not restoration or export of already accepted data; implementation must derive safe effective write capacity so an accepted database remains portable.
