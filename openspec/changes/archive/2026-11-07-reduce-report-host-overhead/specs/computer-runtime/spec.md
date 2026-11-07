## MODIFIED Requirements

### Requirement: Program print uses the computer Console
`print(...)` SHALL append one entry to the current computer's bounded Console, converting arguments with the existing safe `tostring`, joining them with tabs, and returning no values. Zero arguments SHALL append an empty entry. `computer.log(text)` SHALL retain its string-only input, exact program argument count, and zero-result contract. Both routes SHALL use bounded local-output and host-work admission. Program printing SHALL NOT emit Factorio chat, host stdout or host log output. In a saved-program callback, admitted entries SHALL be published in call order when the callback ends; Console commands SHALL publish immediately.

#### Scenario: Print false and nil in position
- **WHEN** a saved callback evaluates `print("value", false, nil, 3, nil)`
- **THEN** one raw Console entry contains `value\tfalse\tnil\t3\tnil`, with no added trailing newline
- **AND** the displayed snapshot follows the existing tab-to-space presentation rule without altering stored bytes.

#### Scenario: Preserve print return arity and empty output
- **WHEN** a saved callback evaluates `select("#", print())`
- **THEN** the result is zero and exactly one empty print entry is appended
- **AND** no fabricated nil result or duplicate entry is produced.

#### Scenario: Keep reference descriptions safe
- **WHEN** a callback prints a plain table, guest function or authentic API facade
- **THEN** the corresponding existing safe `tostring` description is emitted
- **AND** no host address, internal field traversal or recursive serialization occurs.

#### Scenario: Admit a complete entry before publishing
- **WHEN** conversion, host-work admission or the complete entry byte bound refuses a print invocation
- **THEN** that invocation publishes no partial print entry and performs no print-driven eviction
- **AND** ordinary diagnostics and already completed earlier output retain their existing behavior.

#### Scenario: Existing retention and failure semantics apply
- **WHEN** a callback successfully prints and subsequently faults, or later output fills the rolling Console
- **THEN** the successful entry is not rolled back and is subject only to the existing retention policy
- **AND** Follow-off keeps output live without automatic scrolling, under the Console's accepted changed-text selection-reset and existing eviction rules.

#### Scenario: Empty entries remain bounded
- **WHEN** a program repeatedly appends empty entries
- **THEN** the existing Console entry bound applies even when the retained text uses no bytes
- **AND** the byte and entry limits both remain effective for later nonempty output.

#### Scenario: One append evicts several old entries
- **WHEN** a fully admitted entry requires removal of an old prefix to satisfy the byte or entry limit
- **THEN** only the necessary oldest entries are discarded, and all surviving entries retain their text, ticks, and order
- **AND** the truncation indicator and saved array representation retain their existing meaning.

#### Scenario: Refused append preserves retained history
- **WHEN** formatting, complete entry size, or host-work admission refuses an entry while the log is full
- **THEN** that append changes no retained entry, byte count, or truncation flag
- **AND** a separate host fault diagnostic can still follow the existing diagnostic-retention policy.

#### Scenario: Callback output is published once
- **WHEN** a saved-program callback calls `print` and `computer.log` several times and then returns
- **THEN** the Console receives all admitted entries after the callback, in call order, with the callback tick
- **AND** the retained entries, byte count and truncation flag equal the result of appending each entry immediately.

#### Scenario: Buffered output precedes a fault
- **WHEN** a saved-program callback prints and then fails, stops or is refused by host admission
- **THEN** its admitted entries are published before any fault or diagnostic entry
- **AND** the refused entry is not published.

#### Scenario: Two charges per print
- **WHEN** a saved-program callback calls `print`
- **THEN** argument work is admitted before any native conversion, and one further charge admits the bytes and the entry
- **AND** a refused print publishes nothing, and Console eviction work is charged once per callback.

#### Scenario: Console commands are unchanged
- **WHEN** a player runs a Console command that prints
- **THEN** its entries, charges and publication time follow the existing immediate rules.
