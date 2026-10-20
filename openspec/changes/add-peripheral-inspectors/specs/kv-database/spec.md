# Spec Delta

## ADDED Requirements

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
The browser SHALL label its snapshot tick and provide an explicit refresh. Each successful snapshot SHALL exclude keys whose deadlines have passed at that tick, even before reclamation. Refresh SHALL preserve selected keys/fields that still exist and clearly report expired, deleted or changed selections. Unsupported database representations SHALL report unavailable without repair or mutation.

#### Scenario: Expired key awaits reclamation
- **WHEN** a new inspection snapshot is taken at or after a retained key's deadline
- **THEN** that key is absent from the live-key list and count even if background cleanup has not removed its storage entry.

#### Scenario: Program changes the viewed key
- **WHEN** a program updates, deletes or changes the type of the selected key after an inspection snapshot
- **THEN** the old view remains explicitly a snapshot until refresh
- **AND** a successful refresh shows the new value/type or a clear no-longer-present state without altering the database.

#### Scenario: Unsupported retained database
- **WHEN** the database representation is unsupported or fails its existing integrity checks
- **THEN** the inspector reports that contents are unavailable and preserves recoverable data rather than replacing it with an empty database.
