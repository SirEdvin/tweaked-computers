---@meta

---Every authorized computer and both wires of one physical device share this local string/hash database.
---Keys, fields and values are bounded byte strings, which include empty strings and embedded NUL.
---The database does not coerce numbers, booleans or tables.
---String and hash keys have distinct live types.
---
---The command is the atomic boundary, not the callback.
---Before commit, the command validates every input, final capacity and copy/movement cost.
---Refusal preserves the old contents and deadlines.
---E_BUSY and E_LIMIT never indicate an empty successful hash.
---E_WRONGTYPE is usually catchable.
---
---### Expiry and persistence
---Positive expiry saves the absolute deadline current_tick+seconds*60.
---At tick>=deadline, every command treats the key as absent, even before background reclamation.
---Nonpositive expiry deletes a live key immediately.
---TTL rounds to the nearest simulation second: floor((deadline-current_tick+30)/60).
---A live key can have TTL zero, which is not -2.
---
---set clears expiry.
---Edits to an existing hash retain its expiry unless they delete the key.
---New expiry replaces the deadline.
---persist removes expiry.
---Expiry always applies to the whole key, never a field.
---
---Pause stops simulation time.
---Speed, real time and server downtime do not directly change deadlines.
---Mining and unavailability retain the absolute deadline, so simulation time counts while the device is carried.
---Ordinary cold load never renews expiry or returns old expired fields.
---New hashes after expiry inherit neither fields nor the deadline.
---
---Due maintenance follows retained deadlines and cursors, not every database each tick.
---Refused cleanup retains its cursor while other due work that fits can continue.
---Logical expiry is independent of cleanup admission.
---Accepted content and separate reservations for save/item metadata must survive a transfer at maximum content capacity.
---Accounting failure never permits silent truncation or resurrection.
---
---The database needs no electricity.
---Active calls still prove physical authority again.
---getLimits is reachable metadata.
---
---Only the documented string, hash and key-expiry operations exist.
---There is no incr, scan, mget, conditional/expiry SET option, transaction or scripting support.
---There are no lists, sets, streams, pub/sub, field expiry, Redis server/protocol or external network connection.
---@class TC.KVDatabase
local Database = {}

---Read a live string.
---A live hash causes E_WRONGTYPE.
---Expired keys are absent.
---@param key string Bounded byte-string key, which can be empty or contain NUL.
---@return string|nil value Exact stored bytes or exactly one nil for an absent or expired key.
function Database.get(key) end

---Atomically replace any previous type with a string and clear its previous expiry.
---No options or flags exist.
---Validation or capacity failure retains the old value and deadline.
---@param key string Bounded byte-string key.
---@param value string Bounded byte-string value; no coercion.
---@return 'OK' result Exactly one literal success string.
function Database.set(key, value) end

---Delete the supplied live keys.
---Repeated names count at most once.
---At least one key is necessary.
---The entire variadic command passes validation before any mutation.
---@param key string First required byte-string key.
---@param ... string Additional byte-string keys within command_arguments.
---@return integer removed Number of distinct live keys that the command removed.
function Database.del(key, ...) end

---Count the supplied key arguments that exist at one simulation-tick observation.
---Repeated arguments for existing keys count repeatedly, unlike del.
---At least one key argument is necessary.
---@param key string First required byte-string key.
---@param ... string Additional byte-string keys; duplicates count independently.
---@return integer count Number of supplied arguments that name live keys.
function Database.exists(key, ...) end

---Read the live value kind without coercion or access to implementation records.
---@param key string Bounded byte-string key.
---@return 'none'|'string'|'hash' type An expired or missing key gives none.
function Database.type(key) end

---Read one hash field.
---A live string key causes E_WRONGTYPE.
---@param key string Bounded byte-string hash key.
---@param field string Bounded byte-string field name.
---@return string|nil value Stored bytes or one nil for a missing key or field.
function Database.hget(key, field) end

---Atomically add or update hash field/value pairs.
---The command creates the hash if it is absent.
---At least one complete pair is necessary.
---An odd argument count or missing arguments cause failure before writes.
---Repeated fields use the last value and count as new only once if absent before the call.
---
---An existing hash retains its deadline.
---A live string key causes E_WRONGTYPE.
---@param key string Bounded byte-string hash key.
---@param field string First required field name.
---@param value string First required string value.
---@param ... string Additional alternating field,value pairs. The number of arguments must be even.
---@return integer added Newly added distinct fields, not the number of updates.
function Database.hset(key, field, value, ...) end

---Remove fields atomically.
---Each removed field counts once.
---The command deletes the key when it removes the last field.
---Otherwise, the key retains its deadline.
---The wrong type causes failure.
---@param key string Bounded byte-string hash key.
---@param field string First required field name.
---@param ... string Additional field names; duplicates count once.
---@return integer removed Number of distinct present fields removed.
function Database.hdel(key, field, ...) end

---Check whether a field exists.
---The wrong live key type causes failure.
---A missing key or field is ordinary absence.
---@param key string Bounded byte-string hash key.
---@param field string Bounded byte-string field name.
---@return 0|1 exists Integer one if present, zero otherwise. This is not a boolean.
function Database.hexists(key, field) end

---Read an independent complete field map.
---The command fills the map in bytewise field-name order.
---Use keys to read the map, not an ordered-array guarantee.
---String keys cause E_WRONGTYPE.
---Copy refusal is not an empty result.
---The map preserves embedded NUL and empty strings.
---@param key string Bounded byte-string hash key.
---@return table<string,string> fields Detached map; empty map for missing key.
function Database.hgetall(key) end

---Count live hash fields.
---A string key causes E_WRONGTYPE.
---@param key string Bounded byte-string hash key.
---@return integer count Field count, zero for a missing hash.
function Database.hlen(key) end

---Replace the deadline of a live key.
---For nonpositive seconds, the command immediately deletes the key instead.
---Before publication, the command validates the exact integer duration and safe tick arithmetic.
---@param key string Bounded byte-string key of either live type.
---@param seconds integer Simulation seconds. A positive value saves the deadline. A nonpositive value deletes the key.
---@return 0|1 accepted One for accepted expiry or deletion of a live key. Zero if the key is absent.
function Database.expire(key, seconds) end

---Read the remaining simulation seconds with nearest-second rounding.
---A live key can report zero before its deadline.
---Zero is not the absent sentinel.
---@param key string Bounded byte-string key.
---@return integer seconds -2 for an absent or expired key, -1 for a persistent key, otherwise rounded remaining seconds.
function Database.ttl(key) end

---Remove expiry without a change to the value or type.
---An already persistent or absent key causes no harm.
---@param key string Bounded byte-string key.
---@return 0|1 removed One only when the command removed the deadline of a live key.
function Database.persist(key) end

---Read the exact effective database, content and transport limits as an independent map.
---@return TC.KVLimits limits Per-device storage and operation envelopes.
function Database.getLimits() end
