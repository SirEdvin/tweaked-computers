# recipe-searcher Specification

## Purpose

Let computer programs discover installed recipes that directly produce an item or fluid through a separately researched, powered Recipe Searcher peripheral. Provide complete bounded recipe information without exposing native game objects or performing crafting.

## Requirements

### Requirement: Distinct physical Recipe Searcher
The mod SHALL provide a 1×1 Recipe Searcher consuming 30 kW, with one Network endpoint supporting red and green wires. Its selectable body SHALL be the wire target, with distinct archive/scanner-style Foundry artwork, readable status and cardinal views. It MUST NOT expose item/fluid storage, crafting execution or a dedicated recipe-search GUI.

#### Scenario: Place and connect the device
- **WHEN** a player or robot places the device in any cardinal direction
- **THEN** its footprint, wire contacts and artwork agree, its power helper is nonselectable, and ordinary peripheral discovery recognizes type `recipe_searcher`.

### Requirement: Explicit crafting and research progression
One `tc-recipe-searcher` item SHALL cost 10 steel plates, 5 advanced circuits and 2 processing units with 2 seconds of crafting time. Its separate technology SHALL have exactly `tc-circuit-computers` and `utility-science-pack` as direct prerequisites and cost 200 research units, each consuming one automation, one logistic and one utility science pack in 60 seconds.

#### Scenario: Fresh force progresses to the searcher
- **WHEN** a fresh force researches Circuit Computers but not Recipe Searcher
- **THEN** existing device recipes unlock and the Recipe Searcher recipe remains disabled.
- **WHEN** that force completes Recipe Searcher research
- **THEN** its device recipe becomes enabled without requiring an expansion-only material or additional direct prerequisite.

### Requirement: Upgrade-safe independent unlock
Initialization and configuration-change reconciliation SHALL respect each device's owning technology. Previously researched Circuit Computers MUST NOT grant the new recipe. Existing device unlocks, recipes and balance SHALL remain unchanged. Reconciliation SHALL restore the searcher recipe when its own technology is researched without resetting unrelated research or recipe state.

#### Scenario: Upgrade a researched existing factory
- **WHEN** a pre-feature save with Circuit Computers researched is upgraded in a separate engine process
- **THEN** its existing devices and unlocks survive and the newly introduced Recipe Searcher recipe remains locked.

#### Scenario: Reconcile researched searcher
- **WHEN** a configuration change occurs after Recipe Searcher research
- **THEN** its recipe is enabled and existing device identities and computer state are retained.

### Requirement: Typed direct-product lookup
`findRecipes(product_type, product_name, category?)` SHALL accept an exact registered item or fluid prototype name and return recipes containing that type/name in their products. It SHALL search direct recipe outputs, including by-products and probabilistic outputs, not ingredients or recursive production chains. A valid product without matching recipes SHALL return one empty array. Invalid inputs SHALL produce the errors defined in the companion Lua API contract.

#### Scenario: Item and fluid names are distinct
- **WHEN** an item and fluid share a prototype name
- **THEN** each query matches only its explicit product type, not the other namespace.

#### Scenario: By-product and input-only recipes
- **WHEN** a product appears as a secondary or probabilistic output in one recipe and only as an ingredient in another
- **THEN** the producing recipe is included and the input-only recipe is excluded.

#### Scenario: Valid product without a recipe
- **WHEN** a registered item or fluid is not a product of any installed recipe
- **THEN** the result is one empty array rather than nil, an error or an invented production method.

### Requirement: Complete installed recipe visibility
Unfiltered searches SHALL include matching installed recipe prototypes regardless of research, enabled state, hidden flags, recycling category, mod origin or current surface. Records SHALL expose visibility and force-enabled metadata. The service MUST NOT promise current machine, ingredient, surface or quality feasibility merely because a recipe matches.

#### Scenario: Locked hidden recycling and modded recipes
- **WHEN** visible, hidden, locked, recycling and third-party recipes produce the requested product
- **THEN** all matching recipes are returned if the result fits the limits, with their actual category and visibility/enabled metadata.

### Requirement: Exact crafting-category filter
The optional category SHALL be an exact registered recipe-category name, including categories added by mods. Omission or nil SHALL apply no category filter. A supplied category SHALL match either a recipe's primary or additional category. Filtering SHALL occur before result-limit evaluation. Unknown categories SHALL raise `E_RANGE`; there SHALL be no flag filter, substring matching or fixed vanilla category allowlist.

#### Scenario: Category makes an oversized query usable
- **WHEN** an unfiltered product has more than 50 recipes but the selected category has 50 or fewer
- **THEN** the filtered call returns every matching recipe in that category if the other budgets admit it.

#### Scenario: Additional and modded categories
- **WHEN** a recipe accepts a registered modded category as an additional category
- **THEN** searching that category includes the recipe even though its primary category differs.

#### Scenario: Known category has no matches
- **WHEN** a valid category and product combination has no producing recipe
- **THEN** the result is an empty array, not an invalid-category error.

### Requirement: Complete deterministic results within a fixed ceiling
A successful search SHALL return exactly one dense array of unique recipe records sorted by exact recipe name, containing every filtered match. The fixed maximum SHALL be 50 recipes and SHALL be exposed as `recipe_search_results` by `getLimits()`. A query with 51 or more filtered matches SHALL raise `E_LIMIT` without returning a prefix, cursor or partial count. It MUST NOT silently drop recipes to fit another limit.

#### Scenario: Exact count boundary
- **WHEN** a filtered query has exactly 50 small recipe records and fresh sufficient work/data budgets
- **THEN** all 50 are returned.
- **WHEN** a filtered query has 51 matching recipes
- **THEN** it raises `E_LIMIT` and publishes no result array.

#### Scenario: Duplicate output entries and stable ordering
- **WHEN** a recipe lists the requested product more than once, and native catalogue iteration order differs
- **THEN** the recipe appears once and successful arrays have the same name-sorted order.

### Requirement: Full defensive recipe records
Each recipe record SHALL follow `lua-api.md`, including identity, primary/additional categories, ingredients, products, base crafting seconds, visibility, default/current enabled state and surface constraints. Amount ranges, probabilities, fluid temperatures and documented ingredient/product modifiers SHALL remain distinguishable. Returned records SHALL be detached finite plain Data, without native objects, methods or omitted entries disguised as a complete recipe.

#### Scenario: Complex production record
- **WHEN** a recipe has multiple products, ranged/probabilistic quantities, fluid temperatures or surface restrictions
- **THEN** its record preserves the declared values and optional-field distinctions rather than replacing them with expected amounts or a single primary product.

#### Scenario: Caller mutates a snapshot
- **WHEN** a program changes a returned ingredient amount or removes a returned product
- **THEN** neither the underlying recipe nor a subsequent caller's snapshot changes.

### Requirement: Live force-specific availability
The `enabled` flag SHALL reflect the requesting computer's current force recipe at call time; `enabled_by_default` SHALL describe prototype startup availability. Research and script-driven enable/disable changes SHALL affect subsequent calls without rebooting the computer. Enabled status MUST NOT be equated with a researched flag or a guarantee that the current surface or machine can craft the recipe.

#### Scenario: Forces and research differ
- **WHEN** authorized computers in different forces query the same product, or a force changes its recipe's enabled state
- **THEN** each new result reports its own force's current enabled state while recipe inclusion remains unchanged.

### Requirement: Network and power authority
Every search SHALL use the existing same-force, same-surface, explicit-color Network authority and check the current bound identity. Reachable unpowered devices SHALL remain discoverable and allow `getLimits()` but reject searches with `E_UNPOWERED`. Stale methods SHALL fail closed after detach, replacement or scope changes. The device SHALL remain a passive network relay without signal read/write services.

#### Scenario: Power loss and restoration
- **WHEN** a connected searcher loses power
- **THEN** discovery and `getLimits()` remain usable while searches fail with `E_UNPOWERED`.
- **WHEN** physical power is restored
- **THEN** newly authorized calls can search again without new research or replacement.

#### Scenario: Captured call after replacement
- **WHEN** a program retains a search method and the addressed block is removed or replaced
- **THEN** the old method fails with `E_UNREACHABLE` rather than addressing the replacement.

### Requirement: Existing resource and persistence safety
Search enumeration, filtering, ordering and snapshot construction SHALL consume the existing per-computer/shared work and Data allowances without renewing them. The 50-record ceiling SHALL NOT override byte, node, depth or allocation limits. Limit failures SHALL return no partial result and perform no recipe/world mutation. Search state MUST NOT persist native prototype tables, iterators or process-local authoritative caches.

#### Scenario: Unrelated recipes and categories are installed
- **WHEN** unrelated catalogue entries grow without changing a query's native candidates or returned records
- **THEN** admission charges the native call and actual candidate/category/projection work, not the size of the installed recipe or category registries.

#### Scenario: Large metadata below the count ceiling
- **WHEN** fewer than 51 matching records exceed a published Data shape or byte bound
- **THEN** the call refuses explicitly instead of truncating ingredients, products or recipes.

#### Scenario: Repeated calls and cold budget retention
- **WHEN** programs repeat searches within one tick or resume after a cold save with already-spent credits
- **THEN** the same shared accounting remains in effect and neighbors retain the scheduler's normal service opportunities.

### Requirement: Coherent lifecycle and supported engines
The new block SHALL follow existing placement, rotation, mining, cloning, blueprint revival and destruction semantics in Factorio 2.0.77 base and Space Age. Helpers MUST NOT create extra drops or usable orphans. Cold reload SHALL preserve device identity and network paths; replacement SHALL create a new identity. The service SHALL require no persistent query sessions or on-load mutation.

#### Scenario: Mine and blueprint the device
- **WHEN** the searcher is mined, replaced, cloned or rebuilt from a wired blueprint
- **THEN** one logical item and correctly owned helpers are used, native wires remain consistent with the operation, and each new entity gets a distinct identity.

#### Scenario: Ordinary separate-process reload
- **WHEN** a connected searcher and computer are saved and loaded in a new process
- **THEN** identities and retained computer state survive, and a fresh query returns the same ordered recipe data if prototypes and force state are unchanged.

### Requirement: Shipped documentation and visual identity
The packaged feature SHALL include localized names, its query contract, discoverable help and a working guest example showing item/fluid searches, category refinement and `E_LIMIT` handling. Its original artwork SHALL have reproducible provenance. Verification SHALL distinguish actual client appearance and multiplayer behavior from headless or mocked evidence.

#### Scenario: Player uses the packaged feature
- **WHEN** the documented example is run from the tested archive against a powered wired searcher
- **THEN** its documented methods and result fields work, and the package includes the referenced API contract and artwork.

#### Scenario: Native appearance review
- **WHEN** the block is inspected in the full client in each cardinal direction
- **THEN** its scanner/archive silhouette, icon, status and red/green contacts are legible beside the existing device family and vanilla machinery.
