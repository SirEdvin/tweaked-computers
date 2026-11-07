# lua-api-documentation Specification

## Purpose

Give players and API consumers one complete, typed Lua reference whose definitions produce consistent documentation on the website and inside the installed game.

## Requirements

### Requirement: Authoritative public declaration library
The project SHALL publish a separate documentation-only `*.d.lua` library as the authoritative public API reference. Player-facing signatures, types and member descriptions SHALL originate there, not in handwritten OpenSpec API companions or independently authored website/game method lists. Behavioral requirements and runnable tutorials SHALL remain distinct from the declaration library.

#### Scenario: Review one API member
- **WHEN** a maintainer changes an API member's documented signature, type or description
- **THEN** its public declaration is the maintained API source and regeneration updates both player reference destinations
- **AND** no parallel handwritten method/type contract is required in OpenSpec.

#### Scenario: Separate public calls from host implementation
- **WHEN** an implementation uses internal context parameters or registration wrappers
- **THEN** the declaration describes only arguments and results visible to the guest
- **AND** declaration files are not loaded as runtime implementations or exposed as a new guest import facility.

### Requirement: Complete public surface inventory
The reference SHALL cover every supported guest namespace, function, constant, peripheral family, alias, overload and event. Supported base and library helpers SHALL be included without implying unrestricted Lua or Factorio access. Each published declaration SHALL correspond to supported behavior; each exported public member SHALL have documentation.

#### Scenario: Detect an undocumented or invented member
- **WHEN** verification compares declarations with independently inspected or exercised public exports
- **THEN** a missing public member, invented member or missing alias fails verification with its identity
- **AND** a copied expected list derived solely from those same declarations is not sufficient evidence of runtime coverage.

#### Scenario: Document context-dependent availability
- **WHEN** a method is restricted to saved programs, unavailable in Console, dependent on an optional mod, or conditional on device capabilities
- **THEN** its availability and refusal behavior are stated in the reference without hiding that restriction behind a generic function type.

### Requirement: Complete typed member contracts
Each callable SHALL document every parameter's name, type and meaning, required versus optional positions, defaults and applicable value domains. It SHALL document ordered result positions and meanings, overload-specific results and variable arity. No results, one nil, false, empty collections and non-returning control flow SHALL remain distinguishable.

#### Scenario: Inspect optional and overloaded arguments
- **WHEN** a player reads a method with optional arguments, overloads or varargs
- **THEN** each supported call shape explains omission versus explicit nil, defaults, argument ordering, accepted enum values and relevant units or ranges
- **AND** the documentation does not infer permissive extra arguments or colon-call support from standard Lua behavior.

#### Scenario: Inspect result arity
- **WHEN** a player reads a method returning multiple values, zero or more results, an absent value, no values or no normal return
- **THEN** the reference preserves that exact distinction in both destinations instead of converting every outcome to one optional table.

### Requirement: Resolvable named types and events
Named public types SHALL have complete field descriptions, field types, optionality and applicable defaults or variants. Every referenced public type SHALL resolve to its definition in the distributed library and both documentation destinations. Known structures SHALL not be replaced by unexplained `table` or `any`; intentionally open value domains SHALL be documented explicitly.

#### Scenario: Follow a nested result or event
- **WHEN** a method result or callback payload refers to nested records, enums, collections or another named type
- **THEN** readers can obtain the full field definitions and constraints, including inherited event fields and discriminator-dependent shapes
- **AND** recursive types resolve through named references without infinite expansion or omitted definitions.

#### Scenario: Preserve constraints beyond the type notation
- **WHEN** a value domain requires finite numbers, dense arrays, restricted keys, absence of cycles, bounded strings or prototype-dependent values
- **THEN** those restrictions remain documented even when the static annotation language cannot enforce them
- **AND** documentation does not suggest that passing a language-server check bypasses runtime validation.

### Requirement: Behavioral detail accompanies types
API entries SHALL retain relevant failure conditions, side effects, mutation/refusal guarantees, ordering, copy/identity rules, persistence, authority and resource caveats. Shared rules SHALL be referenced without erasing method-specific exceptions. Documentation migration SHALL NOT alter guest behavior, sandbox boundaries, save representation or production limits.

#### Scenario: Distinguish absence from failure
- **WHEN** an operation permits a missing result but can also refuse for authority, availability, arguments or capacity
- **THEN** its documentation distinguishes those outcomes and explains ordinary catchable failures versus fatal execution control where applicable
- **AND** an earlier successful effect is not described as rolled back by a later callback failure.

#### Scenario: Preserve method-specific exceptions
- **WHEN** a general data, availability or persistence rule has a narrower exception in one service
- **THEN** that exception remains attached to the relevant member/type and appears in both generated references rather than being flattened into the shared rule.

### Requirement: Equivalent generated references
The website and packaged in-game API reference SHALL derive from the same declaration revision and contain the same member, parameter, result, type, event and semantic-note information. Layout may differ, but neither destination SHALL silently omit unsupported source content. Generation SHALL report unsupported or unresolved documentation constructs as failures.

#### Scenario: Compare website and game documentation
- **WHEN** references are generated for one source revision
- **THEN** their normalized API inventories and per-entry contract content match
- **AND** source/tool provenance identifies the definitions used, without host-specific paths or timestamps making the content nondeterministic.

#### Scenario: Detect a lossy exporter
- **WHEN** generation encounters a construct whose overloads, result positions, field descriptions or semantic notes cannot be preserved
- **THEN** generation fails with an actionable location or identity
- **AND** it does not publish a shortened successful reference or silently substitute a broad type.

### Requirement: Reproducible publication and distributable definitions
Documentation generation SHALL be reproducible with pinned build-time tools. Freshness verification SHALL detect stale derived outputs without modifying sources. The mod package SHALL contain its matching inert public definitions and generated Reference data, without requiring documentation tools or online access at runtime.

#### Scenario: Repeat a clean documentation build
- **WHEN** the same inputs are generated twice in clean output locations
- **THEN** equivalent outputs are byte-identical and all internal links and type references resolve
- **AND** missing or manually altered generated content fails the read-only freshness check.

#### Scenario: Inspect the released package
- **WHEN** a candidate package is built
- **THEN** its documentation and declaration bytes correspond to the tested source revision
- **AND** no language-server binary, build cache, host credential or game distribution is included.

### Requirement: One derived Configurator type surface
Configurator declaration types SHALL derive from the existing normalized configuration schema rather than a separate handwritten schema inventory. Generated declarations SHALL identify their source and preserve guest normalization, optionality, enum values, variants and restrictions. Native implementation metadata SHALL not become public guest objects.

#### Scenario: Regenerate a configuration type
- **WHEN** a reviewed source-schema change affects a guest configuration field
- **THEN** generation updates the corresponding declaration and both player references consistently
- **AND** verification detects any stale derived definition or mismatch with the runtime schema.

#### Scenario: Preserve normalized guest semantics
- **WHEN** native metadata differs from the guest representation or adapter policy
- **THEN** the public type describes the normalized guest representation and relevant restrictions, not an unrestricted native API type.

### Requirement: Retire duplicated contracts without losing guidance
Superseded API companion documents SHALL be removed from maintained OpenSpec after their useful contract content is migrated. Maintained references, packaging, example extraction and validation SHALL use the replacement sources. Historical archives SHALL remain excluded from live authority and generation; active changes SHALL not restore retired companions through later synchronization.

#### Scenario: Remove a companion containing examples and caveats
- **WHEN** a maintained Markdown API companion is retired
- **THEN** its still-applicable API details have identified declaration destinations, its workflow guidance has an appropriate guide/spec destination, and its runnable programs remain available and checked
- **AND** the migration does not delete substantive test coverage merely because its previous input path disappeared.

#### Scenario: Preserve historical records without reintroducing authority
- **WHEN** a reader encounters an archived proposal or an older active change is later synchronized
- **THEN** archived content is not selected as the current reference and the active change cannot restore a second maintained Markdown API contract
- **AND** existing behavioral requirements and scenarios remain intact except for approved reference relocation.
