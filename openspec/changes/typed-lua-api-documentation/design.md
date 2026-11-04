# Design

## Context

See `proposal.md` for motivation and capability scope. This is a planning-only change; runtime edits, workflow configuration, installations, commits, publication and native execution have not been authorized by this proposal request.

Inspected baseline: `c53a60327babc2f9d5637a14332408c5b69f046f` on `main`, with a clean worktree before creating this planning branch. The existing `python3 tools/player_docs.py --check` passed during exploration and reported 123 computer/discovery/peripheral exports. That is a static inventory receipt, not complete type or native-client acceptance.

Relevant current boundaries:

| Existing source | Observed responsibility |
| --- | --- |
| `scripts/ui/help.lua` | Handwritten API prose, starter, topic IDs and prose-to-block heuristics; tutorial composition |
| `scripts/ui/reference.lua` | Native read-only selectable blocks; rich text disabled; unchanged-topic resize without reconstruction |
| `scripts/ui/editor.lua:122` | Category/search over topic title/text and existing contextual navigation |
| `tools/player_docs.py` | Generates settings, nested schemas, limits and examples; checks exported-name presence in other handwritten API pages |
| `tests/api_inventory.lua`, `tests/help_contract.lua`, `tools/test_build.py` | Independent runtime method inventory and existing help/package/contract assertions, including aliases and overloads |
| `tools/configuration_catalog.py` | Produces the normalized runtime schema and coverage ledger from `openspec/specs/device-configurator/configuration-catalog.json` |
| `tools/planning_examples.py` | Extracts complete programs from maintained OpenSpec companions; excludes archives |
| `tools/build.py` | Explicit companion allowlist and packaged source inventory |
| `openspec/config.yaml` | Package `spec-driven` workflow; asks for peripheral API companions but does not track a Lua API artifact |
| `.github/workflows/docs.yml` | Builds and publishes the existing site; its path trigger does not include a future `api/` tree |

Current declaration targets are not discoverable from host signatures alone: `computer.lua` registers closures with explicit arity, while service methods such as `production-statistics.lua` accept host-only arguments before guest varargs. Current docs also contain discrepancies to reconcile: `docs/player/api/computer.md` retains an outage paragraph despite the current electricity-independent contract. Migration must not canonize stale prose or change production to make old prose true.

The installed OpenSpec schema has only `proposal`, `specs`, `design` and `tasks`; `specs` matches `specs/**/*.md`. Its artifact model supports an instruction and dependency list, but no general machine-readable conditional/skip field. Conditional omissions are supported by workflow instructions; `skip_specs` is specifically about behavioral specs and cannot be repurposed to skip API declarations. The apply entry gate currently requires `tasks`; file-existence status is not semantic completeness.

Official LuaLS definition/export documentation was read during planning. It supports annotation-only meta files, recommends `*.d.lua`, and documents JSON/Markdown export and a custom documentation-export hook. No LuaLS binary was found on PATH during exploration, and no exporter execution has been performed. The primary references are `https://luals.github.io/wiki/definition-files/`, `https://luals.github.io/wiki/annotations/` and `https://luals.github.io/wiki/export-docs/`; select and verify the concrete tool version during the first implementation gate.

## Goals / Non-Goals

Goals:

- Keep public contract authoring separate from runtime implementation, without creating another manually maintained schema of the same API.
- Make the same complete API information usable on the website and offline in the existing Reference.
- Preserve every applicable contract caveat and runnable example while retiring duplicate maintained companions.
- Make future typed API artifacts visible to OpenSpec planning/apply and checked beyond glob existence.
- Keep source-of-truth, historical proposals, generated products and independent runtime evidence distinguishable.

Non-goals:

- No guest API additions, changed argument handling, new limits, runtime type-check generation, compiler rewrite or save migration.
- No in-game language server, autocomplete, hover editor, browser, Markdown framework or online documentation service.
- No new documentation UI window, draft-insertion actions, separate release pipeline or automatic publication.
- No promise that general LuaLS diagnostics validate this project's restricted saved-program grammar. The actual compiler remains the authority for executable examples.
- No rewriting archived changes or generated OpenWiki pages by hand. No globally installed OpenSpec schema or another project's workflow changes.

## Decisions

### 1. Public Lua definitions own the API contract

Create `api/` outside OpenSpec, with documentation-only `---@meta` files and a short `api/README.md` describing authoring, generation and optional external-editor use. Proposed files are `common.d.lua`, `globals.d.lua`, `colors.d.lua`, `events.d.lua`, `computer.d.lua`, `peripheral.d.lua`, and one file per existing device family: `monitor.d.lua`, `dashboard.d.lua`, `kv-database.d.lua`, `logic-handler.d.lua`, `configurator.d.lua`, `recipe-searcher.d.lua`, `factoriopedia-interface.d.lua`, `production-statistics.d.lua`, `modem.d.lua`, `speaker.d.lua`. These are proposed paths, not existing modules.

Use conventional LuaCATS classes, aliases, fields, parameters, returns and overloads. Public type names use a consistent `TC.` prefix to avoid collisions between globals, standard helpers and similarly named native types. Namespaces and facade methods describe dot calls without a fictitious implicit `self`. Host-only identifiers and native LuaObjects are absent. An opaque runtime-discovered device name must not falsely imply a known concrete facade; literal family discovery can use precise overloads, while genuinely dynamic results retain their supported union/open form.

Descriptions stay beside definitions as documentation comments. Use ordinary Markdown paragraphs/headings for Errors, Effects, Availability and constraints rather than inventing unsupported annotation tags or a second metadata DSL. Names and syntactic types alone are insufficient: state exact no-value/nil/non-returning cases, defaults, units, enum domains, restrictions, defensive copies, ordering and side-effect rules in exported prose. Fields have descriptions as well as types. Recursive Data and intentional arbitrary guest-value domains are named and explained rather than weakening known results to `any`.

Build the complete approved helper surface, not just the 123-method baseline. Disable unrelated standard-library exports when producing the public documentation. Document Lua 5.2 as the guest family and the compiler restrictions separately; do not imply that ordinary module files, colon calls or arbitrary Lua standard facilities are executable guest programs.

Alternative rejected: annotating host service implementations. Internal wrappers/context arguments do not match player-facing signatures. Alternative rejected: using JSON as the new handwritten source of truth and generating the public declarations from it; that contradicts the agreed authoring format for ordinary API members.

### 2. Derived schema data remains derived, with one public projection

Move the existing Configurator metadata input to proposed `tools/data/configuration-catalog.json`; relocate its provenance/explanation outside maintained OpenSpec as appropriate. Preserve its bytes and semantics during the move. Continue using `tools/configuration_catalog.py` and its normalized guest representation, not raw native types, to produce `scripts/configuration/catalog.lua` and `docs/configuration-coverage.json`.

Extend that same generator to produce proposed `api/generated/configurator.d.lua`. Preserve guest string/array bounds, required/optional fields, read-only omissions, native enum normalization, mode/prototype restrictions and variant-specific fields. Field descriptions and default explanations must be supplied once alongside the source metadata/normalization that owns them; do not restore a separate handwritten player schema. A source hash and generated-file notice make this ownership explicit. Compare the normalized runtime output before/after relocation to prove no adapter policy changes.

Likewise derive public limit-field declarations/descriptions in proposed `api/generated/limits.d.lua` from current implementation keys and maintained setting/domain metadata instead of freezing another handwritten limits inventory. Document defaults separately from live `getLimits()` values. Existing constants and enforcement remain unchanged.

These generated `*.d.lua` files are the canonical public projection consumed by both references. Their upstream implementation metadata is not a competing public API document. Generated declarations are reviewed but never hand-edited; future schema-related API proposals must include the changed projected declarations for review.

### 3. Build-time extraction, one projection for two renderers

Reuse `tools/player_docs.py` as the generation/check entry point. Use the pinned LuaLS exporter to parse declarations into structured documentation; consume its JSON rather than scraping its rendered Markdown. A small adapter then emits website content and the existing native block representation from the same normalized records. Keep that normalization inside the existing documentation tooling unless actual size warrants a focused module; do not add a general schema framework.

```text
existing normalized metadata --> api/generated/*.d.lua
                                         |
authored api/*.d.lua ---------------------+
                                         v
                               pinned LuaLS extraction
                                         |
                              validated public records
                                         |
                    +--------------------+--------------------+
                    v                                         v
docs/player/api/*.md + type pages              scripts/ui/api-reference.lua
                    |                                         |
                 MkDocs                          help.lua topic composition
                                                              |
                                                    existing native Reference
```

The first implementation gate is a small exporter conformance corpus covering dot calls, globals, classes/fields, literal unions, recursive references, optional parameters versus explicit nil, overloads, aliases, zero/multiple/variable returns, no normal return, callback/event shapes and multi-paragraph examples. Verify the actual JSON and both renderers retain all contract information. Prefer the built-in exporter; if needed, use only its documented custom-export hook to expose information already in its parsed structures. If neither preserves required information, stop for a tooling decision before bulk migration. Do not quietly add a home-grown Lua/type parser or weaken the contract.

Pin the selected exporter version, source/download integrity and configuration. Export only the public library into task scratch, not the whole repository, avoiding host globals, archived drafts and unrelated libraries. Normalize source locations to repo-relative identities, strip machine-specific paths and use stable sorting while preserving argument/result order. Record definition/config/tool provenance with the products. The same inputs must reproduce the same bytes.

Continue `tools/player_docs.py --check` as a read-only freshness and inventory check. The write mode regenerates explicit products; build/package validation refuses stale outputs. Keep generated products versioned so the mod and existing Pages build consume reviewed content. Update the Pages trigger for `api/**`, relevant generator/metadata and lock/config changes; do not restore unrelated hosted mod tests or trigger deployment from this planning work. Retain current site routes/anchors where practical and validate every maintained link; generated type pages are included in navigation.

### 4. Native Reference consumes data, not documentation tooling

Generate proposed `scripts/ui/api-reference.lua` as a plain data module, with topic IDs, titles, categories, search text and native blocks. `scripts/ui/help.lua` composes it with existing authored Workflow/Language/Safety guidance and `scripts/ui/tutorials.lua`; it no longer carries independent method/type prose or infers API structure from punctuation in that prose.

Retain current device topic IDs such as `peripheral.monitor`, exact-type routing and the selected-row repeat-click behavior. Add a type category and stable type topics whose titles include exact public type names. Type references identify the searchable topic; the existing selector/search is enough, so no clickable-link or back-stack feature is required. Use one shared type definition rather than recursively inlining it into every method. Preserve family/topic context and method order where useful to avoid a needless navigation redesign.

The current renderer already has heading/prose/signature/code blocks and disables Factorio rich-text interpretation. Keep those primitives: a method can have a signature followed by parameter, return and semantic-note sections. Support only the small authored Markdown subset needed to preserve paragraphs, lists, headings and literal code in native blocks; reject unsupported constructs rather than omit content. This is conversion at build time, not a runtime Markdown viewer. Complete runnable examples remain complete code blocks; declaration stubs are never inserted as programs.

Reuse `reference.show`'s unchanged-topic behavior and source-focus safeguards. Render only the selected topic, not all type pages. Filtering remains local over packaged text without device polling or guest effects. Any change to title/identity caching must preserve unchanged-widget selection. Do not introduce UI truncation caps to hide a large definition; use named decomposition and existing scrolling.

### 5. Remove maintained duplicates through an explicit migration map

Before deleting sources, record each old section/example and its destination in a migration table in `docs/documentation-maintenance.md` (or a linked focused maintenance appendix if needed). This table records identities and destinations, not a new copy of API prose. Verify each row against the actual retained content.

| Current input/consumer | Replacement policy |
| --- | --- |
| `openspec/specs/*/lua-api.md`, `base-globals-api.md`, `buffering-api.md` | Move API definitions/semantics into `api/`; move non-API authoring/lifecycle guidance to existing guides/specs; remove superseded maintained files |
| `openspec/api/common.md`, `native-language.md`, `device-experience.md` | Move API rules to definition comments; retain grammar/workflow explanations in appropriate guides/behavioral specs; retire redundant companions |
| `openspec/api/examples.md` and fenced programs in retired companions | Preserve complete source bytes under existing `examples/` conventions and keep fixture provenance through a before/after mapping |
| `openspec/specs/device-configurator/configuration-catalog.*` | Move implementation metadata/provenance out of OpenSpec, preserving normalized runtime outputs |
| `docs/player/api/*.md` and API sections of `scripts/ui/help.lua` | Replace handwritten API sections with generated reference content; keep useful non-API narrative |
| `tools/planning_examples.py` and `examples/planning-programs.lua` | Retarget extraction to retained canonical runnable examples; preserve the source inventory and substantive compiler assertions, without making declaration snippets executable examples |
| `docs/api-coverage.json`, `tools/player_docs.py`, `tools/build.py`, `tools/test_build.py` | Retarget contract paths/package allowlists; derive documentation inventories while preserving independent runtime/export and contract tests |
| Maintained spec/guide/README references | Update links to canonical declarations or generated reference, retaining requirement/scenario meanings |

An existing Markdown claim that conflicts with current behavior is a discrepancy, not automatically a new requirement. Use actual implementation, accepted behavioral specs and focused existing tests to resolve obsolete descriptions. Preserve unresolved material conflicts as blockers rather than modifying runtime policy inside this migration.

The active `function-only-programs` and `demand-driven-device-scheduling` changes contain API prose and/or companion files. During apply, read their current state, reconcile proposed semantics with canonical definitions, remove their obsolete maintained companion authority and update references. Do not mark the scheduling change's unfinished acceptance complete, rewrite its unrelated design, or automatically archive either change. Archived changes remain untouched; all live generation/check discovery excludes `openspec/changes/archive/` and other historical reports. Generated OpenWiki is not an API source; refresh it only through its normal authorized workflow if needed, not by hand.

### 6. Future OpenSpec changes carry typed API artifacts

During apply, fork `spec-driven` into proposed project-local `openspec/schemas/tc-spec-driven/`, set it as this project's default in `openspec/config.yaml`, and retain the original planning nodes. Do not modify the installed package schema. Narrow behavioral output discovery to `specs/**/spec.md`, and add a `lua-api` artifact with `generates: api/**/*.d.lua`, dependent on proposal. Make design/tasks depend on its review in the instruction/dependency graph; keep the native apply entry requirement as `tasks` so an explicitly inapplicable conditional artifact is not an unconditional CLI gate.

The `lua-api` instruction is conditional: create it when public API contracts change; otherwise record a no-API-impact decision in the proposal and deliberately skip it. This uses the existing workflow's conditional-instruction handling, not an invented `skip_api` metadata flag or `skip_specs`. Explain that CLI file-existence status can still show a deliberately omitted conditional artifact as pending; project applicability verification, not that status alone, decides completeness.

Add a concise API Impact section to the local proposal template: an explicit no-impact statement, or a table of canonical `api/` paths with added/modified/removed disposition and any removed public identities. This is a path/change inventory, not duplicated signatures. The Lua API artifact contains full proposed replacement definitions for affected files at matching relative paths under the change's `api/`, so a candidate overlay of unchanged canonical definitions plus replacements can be checked. For a whole-file removal, retain a comment-only `*.d.lua` review record explicitly naming the removed canonical file; it is a removal declaration, not a promoted empty module. Unchanged files are not copied into every proposal.

Extend the project documentation check with a proposed `--change NAME` mode. Validate the explicit impact inventory, required file set, removal declarations, path confinement, duplicate public identities and type-reference closure over that overlay. Reject a missing second affected module even if the CLI glob already reports `lua-api` done. Reject newly authored `lua-api.md` companions in active changes after the transition; exclude preserved archives. Do not use heuristics that assume every edit to a service file changes its API, or accept silent absence as a no-impact declaration.

Apply guidance requires the accepted overlay to be reconciled into canonical `api/`, both outputs regenerated and independent runtime contracts checked before task completion. Archive/sync instructions preserve the new typed artifacts as historical proposal files outside behavioral `specs/`; they must not copy declarations into maintained `openspec/specs/`. Existing changes can keep their original schema while their obsolete companion destinations are explicitly migrated. This bootstrap proposal stays on the current schema; it changes documentation ownership, not guest signatures, and does not fabricate a partial replacement API library during planning.

Alternative rejected: changing only a prose rule while continuing to discover only Markdown; typed artifacts would be invisible to status/apply context. Alternative rejected: requiring a copied API snapshot for every no-API change. Alternative rejected: modifying OpenSpec globally to introduce a new conditional field.

### 7. Verification is layered and independent

Add focused generator regressions in proposed `tools/test_player_docs.py`, preserving related assertions in `tools/test_build.py`. Expected extraction cases must be authored independently of the output under test. Negative cases include missing descriptions/types, unknown references, duplicate symbols, missing aliases/overloads, arity collapse, unsupported content, missing generated files and stale output. Test path traversal and missing/extra files in proposed API overlays. Known intentionally open value domains are explicit exceptions, not a broad suppression of type completeness.

Compare normalized website/game records for all API members and types, and independently compare declarations to exported runtime inventory. Existing `tests/api_inventory.lua` continues exercising actual guests; do not derive both expected and actual runtime exports from one generated list. Preserve exact argument/result behavior in the existing relevant contract fixtures, with focused new assertions only where documentation exposes a previously unchecked corner.

Reuse `tests/help_contract.lua`, `tests/editor_contract.lua`, `tests/reference_tutorials_engine.lua` and `tests/editor_reference_client_engine.lua` for topic completeness, safe routing, unchanged drafts, literal native copy and real tutorial behavior. Native UI acceptance must inspect every generated topic/category structurally and representative long/nested/overloaded entries visually at supported scales in base and Space Age. Include actual clipboard copy/paste witnesses, filters, contextual navigation with prior filters, dirty drafts, search/no-result recovery, reopening/load and long type pages. Headless block existence is not visual acceptance.

Use `docs/documentation-maintenance.md` and the current `tools/smoke.py`/`tools/shell_client.py` help for exact Factorio 2.1.23 execution. Validate packaged examples through the actual restricted compiler; separate complete runnable sources from declaration-only snippets and do not simply exclude formerly checked examples. Preserve packaged hashes, receipts, native captures, normal exits and failures outside git. No performance or connected multiplayer claim follows from these checks; exercise a connected authorization case if navigation event handling is changed.

## Risks / Trade-offs

- [Exporter fidelity and dependency cost] -> Run the conformance corpus first, pin the tool/config, prefer the documented exporter hook, and stop rather than silently degrade types or add a second language parser.
- [Static notation cannot express all runtime rules] -> Keep documented domains/constraints and exact result semantics in the same declaration comments; retain independent native tests and guest validation.
- [A canonical library can still describe the wrong behavior] -> Compare to actual exports/contracts and resolve stale prose before promotion; output parity alone proves only consistency.
- [Removing companions loses examples or subtly different caveats] -> Require a section/source migration map, before/after example inventory and retained substantive assertions before deleting old inputs.
- [Large type content harms Reference usability] -> Reuse selected-topic rendering and named type topics; verify native wrapping, scales, copying and filtering without arbitrary truncation.
- [Custom workflow overstates completeness] -> Validate explicit API applicability and every affected file; document conditional-pending CLI status rather than creating fake skip flags or accepting one glob match.
- [Old changes restore obsolete authority] -> Reconcile active companions and enforce the new source boundary in apply/archive guidance and project checks; exclude immutable archives from current inputs.

## Migration Plan

1. Establish the exporter conformance gate and deterministic normalized representation with tests; do not remove existing documentation yet.
2. Build the complete public library and derived schema/limits declarations, with explicit old-section and example migration mapping. Reconcile discrepancies without runtime behavior changes.
3. Generate website and native data from the library, wire existing Reference composition, and execute focused generation/help/native acceptance alongside the retained tutorials.
4. Retarget package, coverage, example extraction and links; remove obsolete maintained companions only after conservation/parity checks pass. Migrate active-change references without absorbing their unrelated work.
5. Introduce the project-local typed API workflow and verify API-changing, removal-only, partial and no-API proposal cases in isolated temporary project roots. Keep this planning artifact and installed global schema unchanged.
6. Run the integrated local documentation/package and appropriate exact-engine/native matrix. Record incomplete gates honestly; release, deployment and archive require their separate authorization.

Rollback is a coherent source/tooling/docs change revert, restoring the previous matching reference inputs and outputs together. No player-data migration or program reset is required or permitted. Do not roll back only the generated UI data while leaving mismatched definitions, generators or package inventories.
