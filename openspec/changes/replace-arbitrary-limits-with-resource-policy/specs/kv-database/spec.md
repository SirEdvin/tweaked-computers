## MODIFIED Requirements

### Requirement: Per-device databases and bounded data
Each physical KV peripheral SHALL own an independent database shared by all authorized computers. Keys, string values and hash fields/values SHALL be byte strings. KV-specific key, byte, field, value, argument and snapshot/payload limits SHALL be retained as configurable runtime-global settings with explicit queryable effective values. Defaults SHALL preserve current KV capacities; hard refusals SHALL be recoverable.

#### Scenario: Separate devices are not one database
- **WHEN** a computer writes a key to one database peripheral
- **THEN** another database peripheral remains unchanged even when both are on the same wire network.

#### Scenario: Reject nonstring values
- **WHEN** a program attempts to store a number, boolean, table or function directly as a Redis value
- **THEN** the operation reports an argument error without coercion or mutation.

### Requirement: Command-level atomicity and defensive reads
Each command SHALL fully validate arguments, types, capacity and required resource admission before publishing its mutation; work preparation SHALL resume across ticks and revalidate current contents before commit. Returned hashes SHALL be independent copies. Failed commands MUST NOT partially add fields, clear previous content or renew/remove existing deadlines.

#### Scenario: Multi-field write exceeds capacity
- **WHEN** a multi-field HSET would exceed a database limit
- **THEN** none of its field updates is published and the original TTL is retained.

#### Scenario: Mutate hash readback
- **WHEN** a caller changes the table returned by HGETALL
- **THEN** the stored database remains unchanged.

## ADDED Requirements

### Requirement: KV setting decreases are non-destructive
Lowered KV limits SHALL constrain new growth, not erase or invalidate previously accepted contents. Reads, inspection, expiry, deletion and capacity-reducing updates SHALL remain available. Mining/replacement SHALL preserve accepted data and absolute deadlines even when current settings are lower than existing usage.

#### Scenario: Lower bytes below a populated database
- **WHEN** the player reduces capacity below stored contents and cold-reloads
- **THEN** all unexpired data remains readable, additional growth refuses atomically, and deletion or raising the setting restores capacity without resetting the database.

#### Scenario: Transfer above current settings
- **WHEN** a previously admitted database is mined and replaced after limits are lowered
- **THEN** its data is neither truncated nor refused merely because it now exceeds new-growth settings, and the new device reports over-limit usage.
