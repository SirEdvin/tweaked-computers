# Production statistics delta

## MODIFIED Requirements

### Requirement: Existing resource safety without silent truncation
Successful results SHALL contain the entire requested snapshot. Retained shared host-work and Data limits SHALL remain enforced without renewal, new statistics-specific entry caps, new settings or global limit increases. A snapshot that cannot fit SHALL fail explicitly with no partial result or retained query state. The native 300-sample history length SHALL not be treated as a configurable resource policy.

#### Scenario: Complete bulk result or refusal
- **WHEN** the complete native inventory fits the existing call envelope
- **THEN** every recorded entry is returned with no top-N cutoff.
- **WHEN** the same requested snapshot exceeds an existing protection
- **THEN** the call refuses under the existing error/control contract without a successful prefix, truncated map, continuation token or retry loop.

#### Scenario: Repeated expensive queries
- **WHEN** a program repeats rate/history queries during one callback or shared tick
- **THEN** actual native calls and result-processing work consume retained host budgets without resetting credits; returning invocations retain normal neighbor selection.
