# KV database

Each physical `tc-kv` owns independent string/hash storage. Computers authorized
on either of its NETWORK colors share that one database. Obtain
`local db = peripheral.find("kv_database", "red")`, or wrap an exact name/color.
Use dot calls. Keys, fields and values are byte strings, including empty and NUL;
no number/boolean/table coercion. Missing scalar results are **one nil**, not zero
returns, false or empty string.

## Complete commands

| Signature | Returns | Behavior |
| --- | --- | --- |
| `db.get(key)` | string or nil | Missing/expired nil; live hash raises E_WRONGTYPE |
| `db.set(key, value)` | `"OK"` | Replace either type; clear old deadline |
| `db.del(key, ...)` | integer | At least one key; count each existing distinct key once |
| `db.exists(key, ...)` | integer | At least one key; repeated live arguments count repeatedly |
| `db.type(key)` | `"none"`, `"string"`, `"hash"` | Expired is none |
| `db.hget(key, field)` | string or nil | Missing key/field nil |
| `db.hset(key, field, value, ...)` | integer | At least one complete pair; last repeated field wins; count newly added distinct fields once |
| `db.hdel(key, field, ...)` | integer | At least one field; count each removed field once; final field deletes key |
| `db.hexists(key, field)` | 0 or 1 | Integer, not boolean |
| `db.hgetall(key)` | string-keyed map | Missing gives independent `{}`; not an ordered array |
| `db.hlen(key)` | integer | Missing gives 0 |
| `db.expire(key, seconds)` | 0 or 1 | Integer simulation seconds; absent 0, accepted live expiry/deletion 1 |
| `db.ttl(key)` | integer | -2 absent; -1 persistent; otherwise rounded remaining seconds |
| `db.persist(key)` | 0 or 1 | 1 only when removing a live existing deadline |
| `db.getLimits()` | copied map | Static reachable capacities, including while unpowered |

All hash commands reject a live string with `E_WRONGTYPE` (message contains
WRONGTYPE). HSET/HDEL preserve an existing hash deadline unless HDEL removes the
last field. Odd/missing HSET operands fail before publication. No condition flags,
increment, lists/sets, scan, pub/sub, external Redis, transactions or field expiry.

## Expiry

Positive expire stores `current_tick + seconds*60`; safe integer duration/arithmetic
validation happens even if the key is absent. Nonpositive duration deletes a live
key immediately. All commands treat a key absent at or beyond its deadline even
if incremental physical cleanup has not reached it.

For a live key TTL is nearest-second `floor((deadline-tick+30)/60)`, half seconds
up. Zero can still mean a live key, unlike -2. SET removes expiry, hash mutation
preserves it, EXPIRE replaces it, PERSIST removes it. A new hash after expiry has
no old fields or deadline. Pause/server downtime does not advance ticks; unpowered
or carried tagged items do consume ongoing simulation time. Cold load/replacement
does not renew TTL.

## Atomicity, errors and capacities

Each command validates all operands/types, work and final capacity before mutation.
A failed multi-field HSET/HDEL/DEL cannot publish a prefix or alter the deadline.
Earlier successful commands remain if later work fails. Readback is copied;
E_BUSY/E_LIMIT is not a successful empty map. Ordinary type/capacity/domain errors
are catchable; fatal shared callback/allocation exhaustion faults the run.

| Device limit key | Initial value |
| --- | ---: |
| keys | 128 |
| bytes (keys + string values + hash fields/values) | 16384 |
| key_bytes (also each field) | 256 |
| value_bytes | 8192 |
| hash_fields | 128 per hash |
| hash_bytes | 8192 per hash |
| total_hash_fields | 256 |
| command_arguments | 128 |
| snapshot_bytes | 65536 separately reserved accounting units |
| reclaim_keys_per_device | 8 |
| reclaim_devices_per_tick | 2 |

Common call bytes 65,536 / entries 4,096 and callback allocations/work still apply.
Metadata reservation is separate from content so a full accepted database can be
saved/mined. Reads count logical expiry immediately; bounded background reclamation
visits unpowered databases too and never resurrects expired values. Limits are
alpha safety ceilings, not real-time guarantees.

## Catch a wrong-type read safely

This complete program logs a string key or a catchable WRONGTYPE diagnostic without
assuming every error is a table. It leaves any existing key untouched.

```lua
function start(event)
  local db = peripheral.find("kv_database", "red")
  if not db then
    computer.log("Connect a database on red NETWORK")
    return
  end
  local ok, value = pcall(db.get, "counter")
  if ok then
    computer.log(value or "No counter yet")
  elseif type(value) == "table" then
    computer.log(value.code .. ": " .. value.message)
  else
    computer.log(tostring(value))
  end
end
```

## Mining and shared storage

Actual player/robot material mining carries a validated `tc_kv` tag in one item.
Replacement imports it under a new identity with old absolute deadlines. Blueprints,
ghost-only tags, clones and untagged items start empty. Destruction destroys data.
Malformed/unknown item data is refused/refunded, not normalized into empty storage;
unsupported retained data stays inert and unmineable for recovery.

Run [kv-program](../examples.md#kv-program) with one red NETWORK database to see a
30-second hash and delayed TTL read. Run [shared-telemetry](../examples.md#shared-telemetry)
with the [combined setup](../factory.md#second-computer-shared-and-private-data)
for two-computer sharing and a separate private database.

If a value appears missing, check which physical name/color you wrapped, type and
TTL. If WRONGTYPE occurs, use type/hgetall or deliberately replace with SET; do not
treat a hash as a serialized string. Missing after transport may be legitimate
expiry. No power means active calls fail, not empty results. See [troubleshooting](../troubleshooting.md).
