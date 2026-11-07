# Recipe searcher delta

## MODIFIED Requirements

### Requirement: Existing resource and persistence safety
Search enumeration, filtering, ordering and snapshot construction SHALL consume the retained shared host-work and Data allowances without renewing them. The 50-record ceiling SHALL NOT override byte, node, depth, or other retained Data limits. Limit failures SHALL return no partial result and perform no recipe/world mutation. Search state MUST NOT persist native prototype tables, iterators or process-local authoritative caches.

#### Scenario: Unrelated recipes and categories are installed
- **WHEN** unrelated catalogue entries grow without changing a query's native candidates or returned records
- **THEN** admission charges the native call and actual candidate/category/projection work, not the size of the installed recipe or category registries.

#### Scenario: Large metadata below the count ceiling
- **WHEN** fewer than 51 matching records exceed a published Data shape or byte bound
- **THEN** the call refuses explicitly instead of truncating ingredients, products or recipes.

#### Scenario: Repeated calls and cold budget retention
- **WHEN** programs repeat searches within one tick or resume after a cold save with already-spent credits
- **THEN** the same shared accounting remains in effect and returning invocations retain the scheduler's normal neighbor-selection order.
