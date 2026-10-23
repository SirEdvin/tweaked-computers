# KV database API v1

Each physical `tc-kv` owns an independent database. Authorized computers on the
same NETWORK wire channel share that database, not a global Redis server.

```lua
local db = peripheral.find("kv_database", "red")
if db then db.set("status", "ready") end
```

All methods use dot calls. Extra arguments are rejected except documented
varargs. Keys, fields and values are byte strings: empty strings and embedded
NUL are accepted. Numbers, booleans, tables and functions are never coerced.
Missing results are one returned nil, not zero returns or empty strings.

## Complete command inventory

| Call | Result | Behavior |
| --- | --- | --- |
| `get(key)` | string or nil | Missing/expired gives nil; a live hash throws `E_WRONGTYPE` |
| `set(key, value)` | `"OK"` | Replaces either type and removes the previous deadline |
| `del(key, ...)` | integer | At least one key; deletes each live distinct key once |
| `exists(key, ...)` | integer | At least one key; repeated live arguments count repeatedly |
| `type(key)` | `"none"`, `"string"`, `"hash"` | Expired keys are absent |
| `hget(key, field)` | string or nil | Missing key/field gives nil |
| `hset(key, field, value, ...)` | integer | At least one complete pair; last duplicate field wins; newly added distinct fields count once |
| `hdel(key, field, ...)` | integer | At least one field; duplicates count once; removing the final field deletes the key |
| `hexists(key, field)` | 0 or 1 | Integer, not boolean |
| `hgetall(key)` | map | Missing gives `{}`; independent copy populated in bytewise field-name order |
| `hlen(key)` | integer | Missing gives zero |
| `expire(key, seconds)` | 0 or 1 | Integer simulation seconds; absent gives zero; nonpositive deletes a live key immediately |
| `ttl(key)` | integer | Missing -2, persistent -1, otherwise rounded seconds |
| `persist(key)` | 0 or 1 | One only when an existing live deadline was removed |
| `getLimits()` | copied map | Reachable static limits, including while unpowered |

Every hash command rejects an existing live string with `E_WRONGTYPE`; the
message contains WRONGTYPE. HSET/HDEL retain an existing hash's deadline unless
HDEL removes its final field. A new hash after expiry has no old fields/TTL.

GET cannot serialize a hash. No conditional SET/options, numeric increment,
field expiry, transactions, lists, scan, pub/sub, messaging or external Redis
connection is provided.

## Time and atomic publication

A positive EXPIRE stores `current_tick + seconds * 60`. Safe integer arithmetic
and duration validation happen even when the key is absent. At or beyond the
absolute deadline every command treats the key as absent, even if its physical
entry remains in storage pending bounded cleanup.

For a live deadline, TTL is `floor((deadline - tick + 30) / 60)`: nearest-second
rounding, with half seconds rounding up. Thus a live key can report zero just
before expiry. Zero is not the missing sentinel -2. Implementation splits the
remaining quotient/remainder to avoid unsafe addition near the integer ceiling.

Simulation ticks advance expiry during an outage or while a tagged item is
carried. Pause/server downtime do not consume time. Cold reload does not renew
TTL. SET clears it; hash changes preserve it; EXPIRE replaces it; PERSIST removes
it.

A command validates all operands, type, required movement and complete final
capacity before publishing a replacement database. A refused HSET cannot publish
a prefix or modify the old deadline. DEL/HDEL use the same command-wide staging.
Earlier successful commands remain committed if a later command/callback faults.
Reads return immutable scalar strings or independent maps, never internal state.

Writers establish live capacity from the complete bounded index, excluding all
logically expired entries regardless of maintenance progress. This is not a
claim that unreclaimed content is live, nor an unbounded expiry flush. Guest
service work shares the existing native callback ledger; exhausted work/allocation
faults the run with its private fatal control and preserves prior data. Capacity,
wrong-type and argument errors remain catchable. Do not spin on busy/pending
admission failures; retry in another named event.

## Queryable storage policy

`getLimits()` reports effective runtime-global settings, not frozen constants:

| Field | Setting | Default |
| --- | --- | ---: |
| `keys` | `tc-kv-keys` | 128 |
| `bytes` (keys plus content) | `tc-kv-bytes` | 16384 |
| `key_bytes` (also hash fields) | `tc-kv-key-bytes` | 256 |
| `value_bytes` | `tc-kv-value-bytes` | 8192 |
| `hash_fields` | `tc-kv-hash-fields` | 128 |
| `hash_bytes` | `tc-kv-hash-bytes` | 8192 |
| `total_hash_fields` | `tc-kv-total-hash-fields` | 256 |
| `command_arguments` | `tc-kv-command-arguments` | 128 |
| `command_bytes` / `peripheral_call_bytes` | `tc-kv-command-bytes` | 65536 |
| `snapshot_bytes` | `tc-kv-snapshot-bytes` | 65536 |

The result also contains `policy_version=2` and a defensive `resources` map
with setting names, units, scope, limits and rejection behavior. `usage` reports
retained inventory, peak key/value/hash dimensions and `over_limit`; it includes
expired entries until reclamation. `snapshot_metadata_bytes` is the current
metadata reservation. `effective_bytes` is the content allowance for that
inventory after reserving metadata, not a promise that a new key or field fits.
The removed shared `peripheral_call_entries` and fixed reclamation batch fields
are no longer advertised.

Each growing dimension must fit its setting. Lowering settings does not make
accepted data corrupt: existing addresses remain readable and deletable,
non-growing value/hash updates remain possible, and absolute expiry persists.
A minimal recovery command remains available even when its necessary argument
count exceeds a lowered command limit; larger batches must be split. Its input
bytes may use the retained database byte footprint. New growth still uses the
configured command limits. Refusals report the resource, setting, used/requested
accounting and limit without publishing any part of the candidate.

Before a write commits, snapshot admission reserves content plus 80 units per
key, 48 per hash field and 128 header units. A smaller snapshot setting can
therefore reduce effective write capacity. This is logical structure accounting,
not native heap, JSON length or compressed save size. Existing over-limit
snapshots remain exportable/importable; metadata limits never strand data that
was already accepted. Shared runtime work/allocation admission still applies;
see the storage validation report for outstanding shared-core integration gates.

Background reclamation uses paid constant-size steps on persisted fair device/key
cursors, rather than fixed eight-key/two-device batches. It also visits unpowered
databases. Per-command logical expiry is independent of sweep progress; ordinary
save/load retains the cursors and accounting.

## Mining, placement and recovery

Player/robot mining writes a validated versioned `tc_kv` tag onto the single
`item-with-tags` result before removing the old identity/owned port. Native
material-item placement imports it defensively and gives the database a new
identity, preserving absolute deadlines. Duplicate build events never replay a
snapshot over newer writes. Untagged placement, blueprints, ghost-only tags and
clones start empty. Only an actually consumed material item carries contents;
destruction intentionally destroys this database.

Unknown/malformed snapshots are rejected before publication. Import checks
header/schema, bounded dense arrays, unique keys/fields, exact string/type and
integer deadline domains, content/field limits and metadata space. Failed
placement removes staged ownership and refunds the original tagged item; no
malformed item is silently normalized into an empty database. Unsupported retained
database headers preserve recovery data and disable mining instead of resetting
it. Initialization/upgrades run only in synchronized init/configuration, never
on_load.

The fixed host adapter lives at `lifecycle.register_item_adapter("kv", ...)`;
player programs cannot register services or access the snapshot/import entry
points.

## Example

`examples/kv-program.lua` contains the native source document for this example:

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      local db = peripheral.find("kv_database", "red")
      if not db then return end
      db.hset("machine", "status", "ready", "owner", computer.getID())
      db.expire("machine", 30)
      computer.after(60, "inspect")
    end,
    inspect = function(event)
      local db = peripheral.find("kv_database", "red")
      if not db then return end
      local fields = db.hgetall("machine")
      computer.log(fields.status or "expired")
      computer.log("TTL=" .. tostring(db.ttl("machine")))
    end
  }
}
```

The packaged fixture executes this source's Save/activation/start path through
the real native scheduler and KV bridge. Client typing/editor Save/Run remains
user-deferred and is not claimed by a host-driven fixture. Full shared telemetry
controller integration remains task 3.4, not this standalone KV milestone.
