# KV database Lua API v1

Normative companion to [spec.md](spec.md). Obtain with `peripheral.find("kv_database", "red")` or an explicit name/channel. Calls are dot-style; use [shared errors/types](../../api/common.md).

## Data and commands

Each physical peripheral has its own shared database. Keys, hash fields and values are bounded byte strings, including empty strings and embedded NUL. They are not automatically converted from numbers, booleans or tables. String and hash keys are distinct types. All argument lists must be validated before a mutation; duplicate field/key semantics below do not permit partial updates.

| Signature | Returns | Behavior |
| --- | --- | --- |
| `db.get(key)` | string or nil | Nil if absent/expired; E_WRONGTYPE for a live hash |
| `db.set(key, value)` | `"OK"` | Replace any existing type; clear its previous expiry; no option flags |
| `db.del(key, ...)` | integer | Number of existing keys removed; repeated names count once |
| `db.exists(key, ...)` | integer | Number of supplied key arguments that currently exist; repeated existing arguments count repeatedly, like Redis |
| `db.type(key)` | `"none"`, `"string"` or `"hash"` | Expired means none |
| `db.hget(key, field)` | string or nil | Nil for missing key/field; E_WRONGTYPE for a live string |
| `db.hset(key, field, value, ...)` | integer | Create absent hash; add/update pairs; return newly added distinct fields |
| `db.hdel(key, field, ...)` | integer | Remove fields; count each actual field once; delete key if last field removed |
| `db.hexists(key, field)` | 0 or 1 | Integer, not a Lua boolean; missing key gives 0 |
| `db.hgetall(key)` | string-keyed map | Missing key gives `{}`; independent snapshot; E_WRONGTYPE for a string |
| `db.hlen(key)` | integer | Missing key gives 0; E_WRONGTYPE for a string |
| `db.expire(key, seconds)` | 0 or 1 | Integer simulation seconds; 1 for accepted expiry/deletion of a live key, 0 if absent |
| `db.ttl(key)` | integer | -2 absent, -1 persistent; otherwise rounded remaining simulation seconds |
| `db.persist(key)` | 0 or 1 | 1 only when a live key's expiry was removed |
| `db.getLimits()` | table | `keys`, `bytes`, `key_bytes`, `value_bytes`, `hash_fields`, `command_arguments`, plus shared call limits |

`del`, `exists` and `hdel` require at least one key/field. `hset` requires at least one complete field/value pair; odd/missing arguments fail before any write. Repeated HSET fields resolve to the last supplied value; only fields absent before the command contribute once to the return count. HSET/HDEL of an existing hash preserve its deadline unless the key is deleted. `hgetall` snapshots are populated in bytewise field-name order; callers should use keys, not treat the result as an ordered array.

No `incr`, `hincrby`, `keys`, `scan`, `mget`, conditional SET, SET expiry options, transactions, scripting, lists, sets, streams, pub/sub, per-field expiry or external Redis connection is implied. Explicit future additions require a contract revision.

## Expiration

At successful `expire(key, seconds)`:

- Validate an integer duration and safe integer tick arithmetic before checking/publication. Nonpositive duration deletes a present key immediately.
- For a positive duration, save `deadline = current_tick + seconds * 60`.
- The key is logically absent at `current_tick >= deadline`; every command checks this before reading a live value/type. Background reclamation need not happen at that exact tick.
- For a still-live key, TTL uses `floor((deadline - current_tick + 30) / 60)`, matching Redis's nearest-second rounding at a simulation-tick resolution. A live key can report zero shortly before its deadline. Never confuse zero with -2.
- `set` clears TTL; mutation of hash fields preserves TTL; a successful new `expire` replaces its old deadline; `persist` removes it.
- Real-world time, game speed and server downtime do not directly enter the deadline. Game pause stops simulation time. A physically unavailable/mined database retains the deadline, so simulation time while carried still counts.

All expirations affect whole keys. A newly created hash after expiry has no inherited fields or deadline. On cold load the original absolute deadline remains, not a reset duration. An expired value is never returned merely because a maintenance sweep has not run.

Background cleanup is owned by the earliest retained deadline or unfinished due cleanup, not an ordinary database discovery sweep. Persistent-only and future-expiry databases have no per-tick key visits. Cancellation, replacement, mining and restored placement update the appropriate identity's membership without renewing expiry. Refused cleanup keeps its old due tick and key cursor while other fitting due databases may progress; guest-visible logical expiry is independent of that admission.

## Atomicity and errors

The command is the atomic boundary, not the entire callback. Validate total final capacity, per-command movement/copy cost, key type and all field/value inputs before committing. Overwrite/refusal retains the previous value and deadline; variadic HSET/HDEL cannot partially publish. Counts use the command's one simulation-tick observation.

Returning/copying a large hash consumes bounded service work. E_BUSY/E_LIMIT is not a successful empty hash. E_WRONGTYPE is catchable through `pcall`; missing keys are the normal return values listed above. The database needs no electricity. Active calls retain live physical authority checks; getLimits remains reachable static metadata.

Accepted content counts against a published live-content budget. Serialization metadata must have separately reserved room so maximum accepted databases can always be saved/mined. Maintenance may reclaim expired content incrementally but cannot resurrect it or silently truncate data to repair an accounting bug.

## Example: cache one machine's state

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

This is a contract example, not a deployed Redis service. The stored owner is a string identity, not a direct computer-message address.

## Required cases

All listed return types; empty/NUL strings; false/number/table refusal; duplicate variadic arguments; odd HSET arity; wrong-type reads and writes; SET replacing hashes/removing expiry; HSET retaining TTL; deleting the last hash field; zero/negative expiry; exact boundary and half-second TTL rounding; expired-but-unreclaimed capacity; copying snapshots; maximum accepted mining/save metadata; two computers observing one database; distinct databases; physical unavailability and cold reload without TTL renewal.
