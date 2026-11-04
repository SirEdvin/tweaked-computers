# Proposal

## Why

Players currently encounter independently maintained API descriptions in OpenSpec companions, website pages and the in-game Reference; existing checks establish exported-name coverage, not complete input/output contracts. A separate typed Lua API library should describe the entire guest surface once and supply equally complete documentation on the website and inside the game.

## What Changes

- Introduce a public, documentation-only `api/**/*.d.lua` library as the authoritative API reference. Cover computer/discovery APIs, all shipped peripheral families, supported base/library helpers, constants, aliases, overloads, named types, nested fields and event payloads. Document parameter/return meanings, optionality, defaults, domains, exact result arity, failures, effects and execution-context restrictions without changing their behavior.
- Generate the website API reference and packaged in-game Reference data from those definitions. Preserve authored tutorials and operational guides, native literal copying, existing contextual navigation and the complete available API information in both destinations. Named types must be resolvable in game, not only through external pages.
- Reuse the existing Python documentation tooling, MkDocs site and native Reference renderer. Evaluate and pin the LuaLS documentation exporter with explicit losslessness checks before adopting it; do not introduce an in-game language server, source parser or network dependency.
- Remove superseded handwritten API companions and duplicate signature/type inventories from maintained OpenSpec after moving their useful content. Retain behavioral requirements and scenarios with references to the public library. Keep archived change records historical and excluded from live generation; reconcile still-active changes so later sync/archive cannot restore retired Markdown contracts.
- Reuse the Configurator's existing machine-readable schema pipeline to derive its declaration types. Move that implementation input out of OpenSpec, preserve runtime schema semantics, and label generated definitions with their provenance instead of hand-copying the catalog.
- Require future API-changing OpenSpec proposals to carry reviewable `*.d.lua` API artifacts. Add a project-local workflow/template and validation guidance during implementation; retain Markdown for rationale, behavioral specs and tasks, not a parallel API contract.
- Extend verification from method-name presence to full declaration inventory, type-reference closure, output parity, example preservation, deterministic generation, package freshness and real native Reference usability.
- **BREAKING (documentation/tooling paths only):** Maintained `openspec/api/` API-reference material and `openspec/specs/*/lua-api.md` or extension companions stop being authoritative inputs. Their consumers and links must migrate together. Guest calls, sandbox restrictions, save formats, limits and runtime semantics do not change.

## Capabilities

### New Capabilities

- `lua-api-documentation`: A complete public typed Lua reference with one source of API truth, generated website/game representations, distributable definition files and verifiable coverage.
- `lua-api-workflow`: Reviewable Lua declaration artifacts for future API-changing proposals, with explicit scope, compatibility review and promotion to the canonical public library rather than Markdown API companions.

### Modified Capabilities

- `program-editor`: The existing Reference exposes complete generated typed method and named-type documentation offline while preserving native readability, literal copying, filtering, contextual navigation and non-mutating browsing.

## Impact

- Proposed public definitions under `api/`; existing `scripts/runtime/computer.lua`, `scripts/runtime/sandbox.lua`, `scripts/services/*.lua`, `scripts/monitor-model.lua` and `tests/api_inventory.lua` provide independent implementation evidence. They are not replaced by declaration stubs.
- `tools/player_docs.py`, `tools/configuration_catalog.py`, `tools/planning_examples.py`, `tools/build.py`, `tools/test_build.py`, `docs/api-coverage.json` and documentation maintenance instructions must stop depending on retired companion paths. Preserve complete runnable sources and existing substantive assertions when adapting consumers.
- `docs/player/api/`, `mkdocs.yml`, `.github/workflows/docs.yml`, `scripts/ui/help.lua`, `scripts/ui/reference.lua`, `scripts/ui/editor.lua`, `scripts/ui/tutorials.lua` and existing help/editor/native-client fixtures participate in generation or presentation. No new hosted test requirement or deployment authorization is implied.
- `openspec/config.yaml`, a proposed project-local schema/templates, maintained spec links and outstanding API companions need a coordinated authoring transition. This proposal itself uses the current `spec-driven` schema; those configuration changes belong to apply, not this planning run.
- Build-time Lua documentation tooling needs a reproducible version/source pin. Player installations receive inert declaration files and generated Lua data, not tool binaries. Verification must use the repository's current Factorio 2.1.23 harness/client matrix, not the historical engine paths in older guidance.
