## MODIFIED Requirements

### Requirement: Exact crafting-category filter
The optional category SHALL be an exact registered recipe-category name, including categories added by mods. Omission or nil SHALL apply no category filter. A supplied category SHALL match either a recipe's primary or additional category. Filtering SHALL occur before result projection and resource accounting for retained results. Unknown categories SHALL raise `E_RANGE`; there SHALL be no flag filter, substring matching or fixed vanilla category allowlist.

#### Scenario: Category makes an oversized query usable
- **WHEN** an unfiltered product has more than 50 recipes but the selected category has any number of matches
- **THEN** the filtered call returns every matching recipe in that category under configured resource-policy.

#### Scenario: Additional and modded categories
- **WHEN** a recipe accepts a registered modded category as an additional category
- **THEN** searching that category includes the recipe even though its primary category differs.

#### Scenario: Known category has no matches
- **WHEN** a valid category and product combination has no producing recipe
- **THEN** the result is an empty array, not an invalid-category error.

### Requirement: Complete deterministic results within a fixed ceiling
A successful search SHALL return exactly one dense array of unique recipe records sorted by exact recipe name, containing every filtered match. There SHALL be no mod-imposed maximum recipe count. Queries SHALL retain paid progress across work slices and return complete results or a recoverable resource/native error. It MUST NOT silently drop recipes to fit another limit.

#### Scenario: Exact count boundary
- **WHEN** a filtered query has exactly 50 small recipe records and fresh sufficient work/data budgets
- **THEN** all 50 are returned.
- **WHEN** a filtered query has 51 matching recipes
- **THEN** it returns all 51 records under adequate resources, just as it returns all 50.

#### Scenario: Duplicate output entries and stable ordering
- **WHEN** a recipe lists the requested product more than once, and native catalogue iteration order differs
- **THEN** the recipe appears once and successful arrays have the same name-sorted order.

### Requirement: Existing resource and persistence safety
Search enumeration, filtering, ordering and snapshot construction SHALL consume the existing per-computer/shared work and Data allowances without renewing them. Removed count, node and per-table ceilings SHALL NOT be recreated by transport; aggregate memory/storage and safe-depth accounting still apply. Limit failures SHALL return no partial result and perform no recipe/world mutation. Search state MUST NOT persist native prototype tables, iterators or process-local authoritative caches.

#### Scenario: Unrelated recipes and categories are installed
- **WHEN** unrelated catalogue entries grow without changing a query's native candidates or returned records
- **THEN** admission charges the native call and actual candidate/category/projection work, not the size of the installed recipe or category registries.

#### Scenario: Large metadata below the count ceiling
- **WHEN** matching records exceed configured aggregate memory/storage or necessary safe-depth capacity
- **THEN** the call refuses recoverably and atomically instead of truncating ingredients, products or recipes.

#### Scenario: Repeated calls and cold budget retention
- **WHEN** programs repeat searches within one tick or resume after a cold save with already-spent credits
- **THEN** the same shared accounting remains in effect and neighbors retain the scheduler's normal service opportunities.

### Requirement: Coherent lifecycle and supported engines
The new block SHALL follow existing placement, rotation, mining, cloning, blueprint revival and destruction semantics in Factorio 2.0.77 base and Space Age. Helpers MUST NOT create extra drops or usable orphans. Cold reload SHALL preserve device identity and network paths; replacement SHALL create a new identity. The service SHALL require no guest-visible query-session API or on-load mutation; private save-safe pending query progress SHALL survive scheduler suspension.

#### Scenario: Mine and blueprint the device
- **WHEN** the searcher is mined, replaced, cloned or rebuilt from a wired blueprint
- **THEN** one logical item and correctly owned helpers are used, native wires remain consistent with the operation, and each new entity gets a distinct identity.

#### Scenario: Ordinary separate-process reload
- **WHEN** a connected searcher and computer are saved and loaded in a new process
- **THEN** identities and retained computer state survive, and a fresh query returns the same ordered recipe data if prototypes and force state are unchanged.

### Requirement: Shipped documentation and visual identity
The packaged feature SHALL include localized names, its query contract, discoverable help and a working guest example showing item/fluid searches, category refinement and work suspension and recoverable resource-error handling. Its original artwork SHALL have reproducible provenance. Verification SHALL distinguish actual client appearance and multiplayer behavior from headless or mocked evidence.

#### Scenario: Player uses the packaged feature
- **WHEN** the documented example is run from the tested archive against a powered wired searcher
- **THEN** its documented methods and result fields work, and the package includes the referenced API contract and artwork.

#### Scenario: Native appearance review
- **WHEN** the block is inspected in the full client in each cardinal direction
- **THEN** its scanner/archive silhouette, icon, status and red/green contacts are legible beside the existing device family and vanilla machinery.
