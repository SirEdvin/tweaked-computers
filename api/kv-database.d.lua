---@meta

---Local string/hash database shared by every authorized computer and both wires
---of one physical device. Keys, fields and values are bounded byte strings,
---including empty strings and embedded NUL. Numbers/booleans/tables are not coerced.
---String and hash keys are distinct live types. The command is the atomic boundary,
---not the callback: validate every input, final capacity and copy/movement cost
---before committing. Refusal preserves old contents and deadlines; E_BUSY/E_LIMIT
---never means an empty successful hash. E_WRONGTYPE is ordinarily catchable.
---
---### Expiry and persistence
---Positive expiry saves absolute current_tick+seconds*60. At tick>=deadline every
---command treats the key as absent, even before background reclamation. Nonpositive
---expiry deletes a live key immediately. TTL rounds nearest simulation second:
---floor((deadline-current_tick+30)/60). A live key can have TTL zero; that is not -2.
---set clears expiry; existing-hash edits retain it unless the key is deleted;
---new expiry replaces it; persist removes it. All expiry is whole-key, never field.
---Pause stops simulation time; speed, real time and server downtime do not directly
---alter deadlines. Mining/unavailability retains the absolute deadline, so carried
---simulation time counts. Ordinary cold load never renews expiry or returns old
---expired fields. New hashes after expiry inherit neither fields nor deadline.
---
---Due maintenance follows retained deadlines/cursors, not every database each tick.
---Refused cleanup retains its cursor while other fitting due work may progress;
---logical expiry is independent of cleanup admission. Accepted content and separate
---save/item metadata reservations must survive maximum-content transfer. Accounting
---failure never authorizes silent truncation/resurrection. No electricity is needed;
---active calls still reprove physical authority and getLimits is reachable metadata.
---
---Only documented string/hash/key-expiry operations exist: no incr, scan, mget,
---conditional/expiry SET options, transactions, scripting, lists/sets/streams,
---pub/sub, field expiry, Redis server/protocol or external network connection.
---@class TC.KVDatabase
local Database = {}

---Read a live string; E_WRONGTYPE for a live hash. Expired keys are absent.
---@param key string Bounded byte-string key, including empty/NUL.
---@return string|nil value Exact stored bytes or exactly one nil when absent/expired.
function Database.get(key) end

---Atomically replace any prior type with a string and clear its previous expiry.
---No options/flags exist. Failed validation/capacity retains old value/deadline.
---@param key string Bounded byte-string key.
---@param value string Bounded byte-string value; no coercion.
---@return 'OK' result Exactly one literal success string.
function Database.set(key, value) end

---Delete supplied live keys. Repeated names count at most once; require at least
---one key and validate the entire variadic command before mutation.
---@param key string First required byte-string key.
---@param ... string Additional byte-string keys within command_arguments.
---@return integer removed Number of distinct live keys actually removed.
function Database.del(key, ...) end

---Count existing supplied key arguments at one simulation-tick observation.
---Repeated existing arguments count repeatedly, unlike del. At least one required.
---@param key string First required byte-string key.
---@param ... string Additional byte-string keys; duplicates count independently.
---@return integer count Number of supplied arguments naming live keys.
function Database.exists(key, ...) end

---Read the live value kind without coercing or exposing implementation records.
---@param key string Bounded byte-string key.
---@return 'none'|'string'|'hash' type Expired/missing means none.
function Database.type(key) end

---Read one hash field. E_WRONGTYPE for a live string key.
---@param key string Bounded byte-string hash key.
---@param field string Bounded byte-string field name.
---@return string|nil value Stored bytes or one nil for a missing key/field.
function Database.hget(key, field) end

---Atomically add/update hash field/value pairs, creating an absent hash. Require
---at least one complete pair; odd/missing arguments fail before writes. Repeated
---fields use the last value and count as new only once if absent before the call.
---Existing hash deadline is retained; live string key is E_WRONGTYPE.
---@param key string Bounded byte-string hash key.
---@param field string First required field name.
---@param value string First required string value.
---@param ... string Additional alternating field,value pairs; must have even width.
---@return integer added Newly added distinct fields, not the number of updates.
function Database.hset(key, field, value, ...) end

---Remove fields atomically, counting each actual field once. Delete the key when
---its last field disappears; otherwise preserve its deadline. Wrong type fails.
---@param key string Bounded byte-string hash key.
---@param field string First required field name.
---@param ... string Additional field names; duplicates count once.
---@return integer removed Number of distinct present fields removed.
function Database.hdel(key, field, ...) end

---Test a field; wrong live key type fails, missing key/field is ordinary absence.
---@param key string Bounded byte-string hash key.
---@param field string Bounded byte-string field name.
---@return 0|1 exists Integer one for present, zero otherwise; not a boolean.
function Database.hexists(key, field) end

---Read an independent complete field map. Populate in bytewise field-name order,
---but consumers use keys, not an ordered-array guarantee. E_WRONGTYPE for strings;
---copy refusal is not an empty result. Embedded NUL/empty strings are preserved.
---@param key string Bounded byte-string hash key.
---@return table<string,string> fields Detached map; empty map for missing key.
function Database.hgetall(key) end

---Count live hash fields; E_WRONGTYPE for a string.
---@param key string Bounded byte-string hash key.
---@return integer count Field count, zero for a missing hash.
function Database.hlen(key) end

---Replace a live key's deadline or immediately delete it for nonpositive seconds.
---Validate exact integer duration and safe tick arithmetic before publication.
---@param key string Bounded byte-string key of either live type.
---@param seconds integer Simulation seconds; positive saves deadline, nonpositive deletes.
---@return 0|1 accepted One for accepted expiry/deletion of a live key; zero if absent.
function Database.expire(key, seconds) end

---Read remaining simulation seconds using nearest-second rounding. A live key
---can report zero before deadline; do not confuse that with the absent sentinel.
---@param key string Bounded byte-string key.
---@return integer seconds -2 absent/expired, -1 persistent, otherwise rounded remaining seconds.
function Database.ttl(key) end

---Remove expiry without changing value/type. Already persistent/absent is harmless.
---@param key string Bounded byte-string key.
---@return 0|1 removed One only when a live key's deadline was removed.
function Database.persist(key) end

---Read exact effective database/content/transport limits as an independent map.
---@return TC.KVLimits limits Per-device storage and operation envelopes.
function Database.getLimits() end
