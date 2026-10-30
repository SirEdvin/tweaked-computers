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
| `getLimits()` | copied map | Reachable static limits; no electricity required |

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

## Queryable initial ceilings

| Limit | Value |
| --- | ---: |
| `keys` | 128 |
| `bytes` (sum of keys + string values + hash fields/values) | 16384 |
| `key_bytes` (also each hash field) | 256 |
| `value_bytes` | 8192 |
| `hash_fields` (per hash) | 128 |
| `hash_bytes` (sum of one hash's fields/values) | 8192 |
| `total_hash_fields` (whole database) | 256 |
| `command_arguments` | 128 |
| `peripheral_call_bytes` | 65536 |
| `peripheral_call_entries` | 4096 |
| `snapshot_bytes` (separate accounted structure reservation) | 65536 |
| `reclaim_keys_per_device` | 8 |
| `reclaim_devices_per_tick` | 2 |

These are initial alpha tuning, not measured graphical latency or a frozen
aggregate factory envelope. The whole sandbox's work/allocation limits still
apply to sequences of calls and defensive readback. The separate hash-byte cap
leaves room for full hash readback under the unchanged sandbox allocation cap.
There is no implicit unlimited capacity or automatic truncation on load.

The reserved snapshot accounting is content plus at most 80 units per key,
48 per hash field and 128 header units; this is independent of the live content
allowance. Snapshot limits describe our bounded plain structure, not JSON file
length or a compressed save size. At maximum accepted content, mining/save
metadata has room without deleting data or reducing the content cap.

Background reclamation starts only when a database's earliest deadline is due;
persistent-only databases and future deadlines cause no per-tick database/key
discovery visits. Each tick still reclaims at most eight indexed keys in each
of two admitted databases, using the existing reserved maintenance ledger rather
than guest callback credits. A refused database retains its original due tick
and key cursor without blocking a fitting peer. Commands update the deadline
membership atomically with their replacement contents. Mining removes the old
identity's membership; placement restores the original absolute deadlines under
the new identity. Ordinary save/load retains deadlines, cursors and counters.
Logical expiry remains exact even when physical cleanup is delayed.

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
function start(event)
  local db = peripheral.find("kv_database", "red")
  if not db then return end
  db.hset("machine", "status", "ready", "owner", computer.getID())
  db.expire("machine", 30)
  computer.after(60, "inspect")
end

function inspect(event)
  local db = peripheral.find("kv_database", "red")
  if not db then return end
  local fields = db.hgetall("machine")
  computer.log(fields.status or "expired")
  computer.log("TTL=" .. tostring(db.ttl("machine")))
end
```

The packaged fixture executes this source's Save/activation/start path through
the real native scheduler and KV bridge. Client typing/editor Save/Run remains
user-deferred and is not claimed by a host-driven fixture. Full shared telemetry
controller integration remains task 3.4, not this standalone KV milestone.
