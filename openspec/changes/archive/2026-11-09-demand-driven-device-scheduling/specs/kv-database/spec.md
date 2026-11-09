# kv-database delta

## MODIFIED Requirements

### Requirement: Simulation-time whole-key expiry
The peripheral SHALL implement `expire`, `ttl` and `persist` using saved simulation-tick deadlines. Expiration SHALL apply to the entire key, never individual hash fields. Pausing or closing the game SHALL not consume expiry time; the device requires no electricity and expiry SHALL continue while an accepted data-bearing item is carried.

#### Scenario: Reach an expiration boundary
- **WHEN** the current simulation tick equals or exceeds a key's deadline
- **THEN** every command observes that key as absent even if background cleanup has not visited it.

#### Scenario: Remove an expiry
- **WHEN** PERSIST succeeds on a live expiring key
- **THEN** the key remains available beyond its former deadline and TTL reports persistent.

#### Scenario: Nonpositive expiry
- **WHEN** EXPIRE receives a nonpositive integer duration for an existing key
- **THEN** the key is deleted immediately.

### Requirement: Complete read-only database browser
The KV inspector SHALL let an authorized player browse every live key and its type, every complete string value, and every field/value of each hash within accepted database limits. Scrolling, selection or pagination SHALL make all content reachable without silent truncation. The UI SHALL provide no edit, delete, clear, import or expiry-changing controls.

#### Scenario: Mixed database contents
- **WHEN** a database regardless of electrical coverage contains strings and hashes
- **THEN** the inspector lists each live key once with its type and lets the player inspect every string and hash field/value
- **AND** selecting or navigating entries leaves the stored data and deadlines unchanged.

#### Scenario: Maximum supported contents
- **WHEN** a database contains the accepted maximum key, field or value payload
- **THEN** all accepted content remains reachable through bounded browsing, including the last key, last hash field and full long values
- **AND** a shortened list preview does not replace access to the complete value.

## ADDED Requirements

### Requirement: Deadline-owned database reclamation
Background expiry cleanup SHALL run only for due expiry or unfinished reclamation work. Persistent-only databases and future deadlines SHALL not cause per-tick database/key discovery scans. Reads and writes SHALL still treat expired keys as absent at the exact simulation deadline, regardless of physical cleanup delay.

#### Scenario: Persistent keys and distant deadlines
- **WHEN** a database has only persistent keys or expiry deadlines in the future
- **THEN** it receives no per-tick reclamation visit; setting, replacing, deleting or persisting a deadline updates future eligibility without unbounded obsolete entries.

#### Scenario: Due cleanup under pressure
- **WHEN** a key expires while background maintenance is deferred
- **THEN** every command sees it as absent immediately; reclamation resumes fairly without resetting its deadline or touching unrelated databases.

#### Scenario: Item transfer and cold reload
- **WHEN** an expiring database is mined, restored or cold-loaded
- **THEN** the original deadlines and approved item contents survive; old identity/deadline records cannot delete a replacement or a key whose expiry was changed.

### Requirement: Electricity-independent database access
Authorized database operations and browsing SHALL require no electrical supply. Identity, selected-wire authority, data validation, storage limits and atomic mutation rules SHALL remain unchanged.

#### Scenario: Read and mutate without electricity
- **WHEN** a valid computer and database are wired outside electrical coverage
- **THEN** the documented read/write and expiry operations succeed under ordinary bounds; electrical changes do not reset values or manufacture E_UNPOWERED.
