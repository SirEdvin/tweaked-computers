# kv-database Specification

## Purpose

Provide a shared, durable database in each physical KV peripheral using a small Redis-inspired Lua API for byte strings, string-valued hashes and whole-key simulation-time expiry.

## Requirements

### Requirement: Per-device databases and bounded data
Each physical KV peripheral SHALL own an independent database shared by all authorized computers. Keys, string values and hash fields/values SHALL be byte strings. Capacity and per-operation payload limits SHALL be explicit and queryable.

#### Scenario: Separate devices are not one database
- **WHEN** a computer writes a key to one database peripheral
- **THEN** another database peripheral remains unchanged even when both are on the same wire network.

#### Scenario: Reject nonstring values
- **WHEN** a program attempts to store a number, boolean, table or function directly as a Redis value
- **THEN** the operation reports an argument error without coercion or mutation.

### Requirement: Minimal string and key commands
The peripheral SHALL implement `get`, `set`, `del`, `exists` and `type` exactly as documented in `lua-api.md`. Missing values SHALL remain distinguishable from empty strings. SET SHALL replace a previous string or hash and remove its existing TTL.

#### Scenario: Overwrite an expiring hash
- **WHEN** SET succeeds on an expiring hash key
- **THEN** that key becomes the supplied string and becomes persistent.

#### Scenario: Wrong key type
- **WHEN** GET addresses an existing hash
- **THEN** it reports WRONGTYPE instead of serializing or returning the hash.

### Requirement: Minimal hash commands
The peripheral SHALL implement `hget`, `hset`, `hdel`, `hexists`, `hgetall` and `hlen`. HSET SHALL create an absent hash, preserve an existing hash TTL and report newly added fields. Removing its final field SHALL delete the hash key and TTL.

#### Scenario: Update an expiring hash
- **WHEN** HSET updates an existing field of an expiring hash
- **THEN** its deadline remains unchanged and the field-addition result excludes that existing field.

#### Scenario: Delete the final field
- **WHEN** HDEL removes the last remaining field
- **THEN** TYPE reports none and TTL reports the missing-key sentinel.

### Requirement: Simulation-time whole-key expiry
The peripheral SHALL implement `expire`, `ttl` and `persist` using saved simulation-tick deadlines. Expiration SHALL apply to the entire key, never individual hash fields. Pausing or closing the game SHALL not consume expiry time; loss of device power SHALL not stop simulation-time expiry.

#### Scenario: Reach an expiration boundary
- **WHEN** the current simulation tick equals or exceeds a key's deadline
- **THEN** every command observes that key as absent even if background cleanup has not visited it.

#### Scenario: Remove an expiry
- **WHEN** PERSIST succeeds on a live expiring key
- **THEN** the key remains available beyond its former deadline and TTL reports persistent.

#### Scenario: Nonpositive expiry
- **WHEN** EXPIRE receives a nonpositive integer duration for an existing key
- **THEN** the key is deleted immediately.

### Requirement: Exact return and failure distinctions
The Lua contract SHALL define missing-key results, WRONGTYPE failures, count results, successful SET acknowledgement and TTL sentinels/rounding. The API MUST NOT silently add conditional SET flags, transactions, lists, pub/sub, numeric increments or hash-field expiry.

#### Scenario: Missing and persistent TTLs differ
- **WHEN** a caller asks TTL for an absent key and then for a live persistent key
- **THEN** the results are -2 and -1 respectively.

### Requirement: Command-level atomicity and defensive reads
Each command SHALL fully validate arguments, types, capacity and required work before publishing its mutation. Returned hashes SHALL be independent copies. Failed commands MUST NOT partially add fields, clear previous content or renew/remove existing deadlines.

#### Scenario: Multi-field write exceeds capacity
- **WHEN** a multi-field HSET would exceed a database limit
- **THEN** none of its field updates is published and the original TTL is retained.

#### Scenario: Mutate hash readback
- **WHEN** a caller changes the table returned by HGETALL
- **THEN** the stored database remains unchanged.

### Requirement: Durable and portable database contents
Save/load and ordinary mining/replacement SHALL preserve accepted contents and absolute simulation deadlines. Blueprints and clones SHALL start with empty databases. Destruction SHALL destroy that peripheral's data rather than attach it to a replacement identity.

#### Scenario: Carry a database while its key expires
- **WHEN** a mined database is replaced after a saved key's simulation deadline passed
- **THEN** that key is absent on first access, not granted a fresh TTL.

### Requirement: Bounded reclamation without semantic delay
Background expiry and memory reclamation SHALL be bounded independently of guest callback budgets. Delayed physical cleanup MUST NOT resurrect expired values or incorrectly count reclaimed capacity as live data when a command is admitted.

#### Scenario: Cleanup has a backlog
- **WHEN** many keys expire on the same tick
- **THEN** reads still return absent at the exact deadline while reclamation progresses within its published maintenance budget.

### Requirement: Complete read-only database browser
The KV inspector SHALL let an authorized player browse every live key and its type, every complete string value, and every field/value of each hash within accepted database limits. Scrolling, selection or pagination SHALL make all content reachable without silent truncation. The UI SHALL provide no edit, delete, clear, import or expiry-changing controls.

#### Scenario: Mixed database contents
- **WHEN** a powered database contains strings and hashes
- **THEN** the inspector lists each live key once with its type and lets the player inspect every string and hash field/value
- **AND** selecting or navigating entries leaves the stored data and deadlines unchanged.

#### Scenario: Maximum supported contents
- **WHEN** a database contains the accepted maximum key, field or value payload
- **THEN** all accepted content remains reachable through bounded browsing, including the last key, last hash field and full long values
- **AND** a shortened list preview does not replace access to the complete value.

### Requirement: Byte-safe and unambiguous KV presentation
The browser SHALL present keys, fields and values as literal byte-string data, with an unambiguous escaped representation for bytes the native GUI cannot safely display. Empty strings SHALL differ visibly from missing entries. Stored rich-text syntax SHALL NOT become markup, icons or interactive content, and formatting SHALL NOT modify persisted bytes.

#### Scenario: Empty and non-text strings
- **WHEN** keys or values contain empty strings, NUL, newlines, backslashes, invalid UTF-8 or rich-text-looking brackets
- **THEN** their displayed representation distinguishes the original bytes without crashing the GUI or interpreting the content
- **AND** the original stored strings remain byte-identical.

### Requirement: Expiry-aware inspection snapshots
The browser SHALL update automatically while open through existing bounded scheduler admission, without a Refresh control or numeric snapshot tick. Each successful snapshot SHALL exclude keys whose deadlines have passed at that tick, even before reclamation. Refresh SHALL preserve selected keys/fields that still exist and clearly report expired, deleted or changed selections. Unsupported database representations SHALL report unavailable without repair or mutation.

#### Scenario: Expired key awaits reclamation
- **WHEN** a new inspection snapshot is taken at or after a retained key's deadline
- **THEN** that key is absent from the live-key list and count even if background cleanup has not removed its storage entry.

#### Scenario: Program changes the viewed key
- **WHEN** a program updates, deletes or changes the type of the selected key after an inspection snapshot
- **THEN** the next admitted automatic observation replaces the old view without manual intervention
- **AND** a successful refresh shows the new value/type or a clear no-longer-present state without altering the database.

#### Scenario: Unsupported retained database
- **WHEN** the database representation is unsupported or fails its existing integrity checks
- **THEN** the inspector reports that contents are unavailable and preserves recoverable data rather than replacing it with an empty database.
