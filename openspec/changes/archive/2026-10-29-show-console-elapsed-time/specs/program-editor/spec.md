# Spec Delta

## ADDED Requirements

### Requirement: Elapsed map timestamps in Console
Each Console log entry SHALL display its recorded map tick as `[HH:MM:SS]`, using completed simulation seconds at 60 ticks per second. Hours SHALL be cumulative and padded to at least two digits; minutes and seconds SHALL have exactly two digits. The prefix SHALL describe when the entry occurred, not its age, local wall-clock time or time since the computer started.

#### Scenario: Zero and subsecond entries
- **WHEN** entries recorded at ticks 0, 59 and 60 are displayed
- **THEN** their prefixes are `[00:00:00]`, `[00:00:00]` and `[00:00:01]` respectively
- **AND** entries sharing a displayed second retain their original order.

#### Scenario: Minute and hour rollover
- **WHEN** entries recorded at ticks 3599, 3600, 215999 and 216000 are displayed
- **THEN** their prefixes are `[00:00:59]`, `[00:01:00]`, `[00:59:59]` and `[01:00:00]` respectively.

#### Scenario: Long-running maps do not wrap or truncate hours
- **WHEN** entries recorded at ticks 5184000, 5846940 and 21600000 are displayed
- **THEN** their prefixes are `[24:00:00]`, `[27:04:09]` and `[100:00:00]` respectively
- **AND** no day field or daily rollover replaces the cumulative hour count.

#### Scenario: Computer and interface lifecycle do not reset the origin
- **WHEN** the Console is reopened or the computer is stopped and restarted
- **THEN** retained entries keep the same elapsed timestamp
- **AND** new entries use their occurrence on the same map timeline rather than a new computer-session origin.

#### Scenario: Simulation timing is not a wall clock
- **WHEN** the simulation is paused, its speed changes, or an old entry is viewed later
- **THEN** the entry's prefix remains derived only from its recorded map tick
- **AND** neither real-world waiting time nor the viewing player's clock changes that prefix.

### Requirement: Display-only timestamp compatibility
Timestamp formatting SHALL preserve stored log ticks and text, ordering, retention bounds and truncation behavior. Program output, shell echoes/results and logged errors SHALL share the same timestamp format without losing attribution or diagnostics. Existing tab-to-space display normalization, literal selectable output, Follow behavior and suppression of unchanged-text writes SHALL remain intact. No save migration SHALL be required.

#### Scenario: Existing saved history remains readable
- **WHEN** a save containing retained tick-based log entries is loaded and its Console is opened
- **THEN** the retained entries display elapsed map timestamps without rewriting their ticks or text, changing retained byte accounting or replaying the logged actions
- **AND** saving and loading again preserves the same history and displayed timestamps.

#### Scenario: Program and shell output use one format
- **WHEN** program messages, shell command echoes, shell results and logged failures are displayed together
- **THEN** every retained entry uses the elapsed timestamp format in its existing position
- **AND** message text, shell command attribution, diagnostic details, newlines and tab-to-space display normalization remain otherwise unchanged.

#### Scenario: Refresh without new output
- **WHEN** the current map tick advances but retained Console entries and diagnostics have not changed
- **THEN** timestamp formatting does not change the displayed text or trigger another text assignment
- **AND** existing native selection and copying remain available between actual output updates.

#### Scenario: Follow and bounded history remain unchanged
- **WHEN** new entries arrive while Follow is disabled and existing retention bounds evict old output
- **THEN** the Console displays the retained entries with elapsed timestamps without forcing a scroll to the newest entry
- **AND** truncation remains visible and enabling Follow resumes the existing tailing behavior.
