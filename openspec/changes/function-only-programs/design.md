# Design

## Context

See `proposal.md` for motivation and approved scope. This is a deletion/consolidation change, not a new language implementation.

Observed in the current checkout:

- `scripts/runtime/compiler.lua` separates explicit Console emission from saved declaration discovery/emission. Declaration discovery validates names, builds exports, preserves lexical private helpers and emits guarded functions.
- `compiler.compile` is called by `scripts/runtime/computer.lua:70` and `scripts/ui/editor-model.lua:84`; `scripts/runtime/shell.lua:78` explicitly selects `shell`. `scripts/scheduler.lua:166` dispatches through `compiler.run`, which revalidates the exact active source rather than trusting caller-supplied generated code.
- `scripts/runtime/sandbox.lua:114` and its caller at `compiler.lua:405` prepay handler construction. The helper is shared accounting, not disposable execution protection.
- `tests/runtime_contract.lua` already exercises declarations, lexical behavior, tuples, source diagnostics, protected calls, globals and bounds. Other behavioral fixtures still construct their guest source through reusable body wrappers or inline strings.
- `tools/planning_examples.py` extracts fenced programs from an explicit live-contract allowlist into `examples/planning-programs.lua`. `tools/player_docs.py` obtains most examples from host modules that return source strings; `function-program` and `smooth-sine-chart` have separate source handling. The starter is checked against `scripts/ui/help.lua`.
- `tools/rd1_upgrade.py` injects a fixture into a pinned historical checkout. Its `tests/rd1_upgrade_engine.lua` currently activates guest source before snapshotting physical devices and retained data. Similar source-bearing upgrade fixtures exist for monitors, native circuits, inspection and later device families.
- Current `info.json`, `tools/smoke.py` and `docs/documentation-maintenance.md` require Factorio 2.1.23. The 2.0.77 paths in the repository's older agent guidance apply only to historical-engine cases. Confirm the actual engine before using it.

These facts ground the approach; no runtime behavior or new acceptance results are established by this planning change.

## Goals / Non-Goals

Goals are to use the existing declaration compiler as the sole saved-program path, keep all independent behavior and safety coverage, and make the entire current checkout consistent with the source contract.

Non-goals are a converter, migration/fallback mode, broader Lua support, a VM, new settings or budgets, new service APIs, a source-storage redesign, new hosted test checks, release publication, rewriting Git history or altering existing release assets/player saves. Ordinary table values, API records, host module returns and internal handler maps remain valid and necessary.

## Decisions

### 1. Delete source selection; retain the existing declaration implementation

After the explicit Console branch, run declaration discovery and emission directly. Delete the alternate saved-source parser/emitter and branch-specific errors/comments. Retain complete top-level validation: every statement must be allowed and at least one export must exist. Do not replace this with a first-token heuristic, a string search or an additional compiler facade.

Keep existing forward export resolution, private-helper ordering, protected names, body emission, source coordinates and guarded closures. Rename the shared handler-preparation helper and its only production caller to describe handler preparation; preserve its accounting and allocation behavior. Keep private generated handler tables and `api_version`/compiler metadata where they express runtime contracts rather than user-authored syntax.

Reusing this path is smaller and safer than a new frontend or compatibility switch. There is no reason to alter scheduler, editor, shell or computer lifecycle interfaces: they already converge on the compiler. Verify these call paths instead of introducing call-site workarounds.

The unchanged sort-capacity workload exposed redundant whole-function assembly after conversion. The maintainer approved a scoped bounded-emitter refactor on 2026-10-29: append top-level function headers, already-paid body statements and terminators to the existing final fragment vector instead of assembling and charging a second whole-function string. Preserve nested emission, lexical order, function/statement guards, source locations and all production ceilings. Compute and admit final output length before joining; retain cumulative fragment accounting and exact warm/cold charge-prefix parity. This is construction deduplication, not permission to remove resource protection or weaken a workload.

### 2. State the accepted grammar positively, including in tests

Use `function start(...) ... end` and sibling/private declarations in valid fixtures. Reuse existing local source-body builders rather than adding a generic conversion tool. A deliberate idle program exports a no-op function; blank drafts remain editable but are not valid runnable documents.

Negative grammar cases use small general violations: scalar top-level return, a return alongside declarations, a call, initializer, assignment, conditional, loop, dotted/method definition, duplicate/reserved name and a private-only document. They prove the top-level allowlist without keeping retired executable examples or explanatory names in the repository. Valid nested constructors and function-body returns must still work.

Converting a fixture must preserve its observations: exact effects, nil/false/tuple arity, aliases, authority failures, diagnostics, quota refusal, no-replay, ordering and cold phases. Remove only assertions whose sole purpose is an unsupported authoring surface. Cases for reserved keys need supported declarations and genuine lexical-shadowing assertions rather than weakening reserved-name rules.

Different source bytes can legitimately have different compilation costs. Re-derive a fixture's source-size/paid-prefix expectations from its new program where necessary, but keep warm/cold equality, one-unit-short refusal, production limits, workload sizes and deadlines. A newly failing native workload is a failure to resolve, not permission to raise budgets or delete coverage.

### 3. Preserve host wrappers and generation pipelines

A host Lua module returning a source string is not itself a guest program. Retain those module interfaces, require paths and tutorial bindings; change the string's contents. Do not mechanically remove every top-level `return` or every table in `examples/` or `tests/`. Keep the deliberately paste-ready `smooth-sine-chart.lua` and exact starter equality intact.

Update authoritative fenced examples in `openspec/api/` and capability companions before running `tools/planning_examples.py`. Preserve its explicit distinction between complete programs and Console/snippet content; do not scrape every fence from every historical document. Update authoring prose in `tools/player_docs.py`, then regenerate the derived player pages with that tool. Existing package tests and `--check` modes remain the freshness gates.

No new generator, dependency or persistent source converter is needed. Extend existing focused assertions only where they do not already cover the changed language contract.

### 4. Keep historical engine evidence honest without retaining obsolete source inputs

Historical mod runtimes are immutable test baselines, not places to backport the new compiler. For a baseline that cannot accept declaration programs, keep its genuine physical/device/data upgrade scenario using stopped computers and narrowly scoped host-side test setup. Preserve its original device graph/order, wires, database values, screens, item/blueprint data, explicit computer state and refusal/rollback assertions where applicable.

Do not synthesize an apparently valid running executable snapshot for such a baseline or claim that stopped-state setup proves running-program continuity. Keep state/record preservation assertions in that case, and cover active source/run identity, timers, subscriptions, queue ordering, credits and no-startup/no-effect replay using a function-capable baseline. Existing current-version cold fixtures cover the same runtime properties independently. Update fixture labels and reports to say exactly which setup ran.

Adapt only the current fixture/harness and its explicitly allowlisted test injection. Do not change historical production payloads, source commits or release archives, hide syntax in string assembly, insert a compiler shim, or drop unrelated upgrade checks. The historical source-format continuity case itself is not a retained product requirement; this fixture maintenance does not add a player migration feature.

### 5. Clean the complete checkout, not only current player docs

The implementation inventory includes these surfaces:

| Surface | Concrete anchors and required treatment |
| --- | --- |
| Runtime and callers | `scripts/runtime/compiler.lua`, `scripts/runtime/sandbox.lua`; verify `computer.lua`, `shell.lua`, `scripts/scheduler.lua`, `scripts/ui/editor-model.lua` |
| Core tests | `tests/runtime_contract.lua`, `compiler_cache_contract.lua`, `computer_contract.lua`, `computer_cold.lua`, `editor_contract.lua`, `editor_cold.lua`, `editor_workspace.lua`, `shell_contract.lua`, `shell_cold.lua`, `api_inventory.lua` |
| Native/runtime fixtures | All source-bearing `tests/*_engine.lua`, including integration, lifecycle, device/network/logic/KV, monitor, dashboard, recipe, production-statistics, Factoriopedia, native-circuit, inspector, envelope and maintenance workloads; include client and upgrade variants |
| Examples and in-game help | All source-bearing `examples/*.lua`, `scripts/ui/help.lua`, `scripts/ui/tutorials.lua`, including chart/baseline programs, factory and shared-data examples |
| Authoritative API docs | `openspec/api/examples.md`, `openspec/api/native-language.md`; source, runtime/base-globals, editor, dashboard, configurator, Factoriopedia, KV, logic, monitor/buffering, network, production-statistics and recipe companions |
| Maintained and historical docs | `README.md`, `changelog.txt`, all relevant `docs/` pages; observed anchors include `docs/computer-runtime.md`, `docs/kv-database.md`, `docs/player/api/language.md`, `docs/player/console.md`, `docs/release-0.1.10.md`, `docs/release-0.1.11.md`, `docs/sc4-final-acceptance.md` |
| Planning history | `openspec/changes/archive/`, any active changes and this change; historical artifacts are not exempt |
| Generated material | `examples/planning-programs.lua`, `docs/player/examples.md`, other affected player output, `openwiki/runtime/compiler-and-sandbox.md`, `openwiki/.claims/runtime/compiler-and-sandbox.json` and any other affected generated page/claim/index |
| Harnesses | `tools/planning_examples.py`, `tools/player_docs.py`, source-dependent `tools/test_*.py`, `tools/rd1_upgrade.py`, `tools/monitor_upgrade.py`, `tools/factoriopedia_upgrade.py`, `tools/recipe_searcher_upgrade.py`, `tools/radar_upgrade.py`, and client/animation wrappers that consume changed fixtures |

This is a grounded starting inventory, not a claim that lexical matches alone establish completeness. Audit tracked files plus new implementation files, hidden metadata, filenames, comments, string-built programs and freshly built ZIP entries. Review context rather than blanket-deleting ordinary terms used for unrelated data structures. Keep any one-off search expressions and audit receipts outside git; do not add a permanent retired-syntax corpus as the cleanup test.

Sync the four spec deltas during implementation, replace the source companion from this change and update all other affected companion examples without changing peripheral signatures. The existing `program-source` Purpose also needs a positive grammar-only replacement during implementation: delta Purpose sections do not update an existing capability. Unmodified ordinary-call, lexical-helper and named-registration requirements remain in force.

The source delta explicitly removes and replaces the boundary, lifecycle, globals and reserved-name requirements. Their replacement blocks preserve supported scenarios but deliberately retire superseded authoring cases. This is not an implicit scenario deletion inside `MODIFIED`: OpenSpec requires that operation to retain existing scenario names. Review each removal together with its named replacement and retain all independent safety/lifecycle assertions.

Regenerate player outputs from their inputs. Refresh affected OpenWiki pages and their claims together after source/docs cleanup, using its existing generation workflow; a clean rendered page with stale hidden claims is not complete. Do not merely change evidence hashes or preserve a claim that no longer has source support. The maintainer explicitly included generated content in scope; if regeneration is blocked, disclose the incomplete gate rather than treating it as optional.

For historical receipts, remove obsolete source examples or unsupported passages while preserving accurate unrelated facts. Never rewrite a workload and leave prose claiming the replacement was executed in an old run. External frozen evidence and Git history remain untouched; new verification gets new receipts.

### 6. Verification is local and tied to the exact package

Use the existing harnesses, not a replacement test framework. Build into a fresh directory below `${TMPDIR:?}` and retain the archive SHA, manifest, command exits, complete failures and expected receipt inventory. The local suite must cover every converted behavioral fixture, directly or through a known aggregator; a default smoke run alone is insufficient.

Verification layers:

1. Python package/tool regressions, planning-example freshness, configuration-catalog freshness, strict MkDocs build and player-document checks using the locked documentation dependencies.
2. Packaged compiler/runtime/cache/computer/editor/shell contracts and API inventory under both base and Space Age. Run computer/editor cold fixtures in their existing companion context and shell cold in its required production context. Check source-location assertions after fixture rewrites.
3. Changed native fixtures and specialized upgrade/envelope/monitor wrappers under their existing supported modes. `smoke.py` requires both `--production-context` and `--cold` for its allowlisted lifecycle fixtures; do not apply those flags indiscriminately. Include genuine separate-process save/reload rather than counting configuration change as cold proof.
4. Compile the regenerated player-document examples using `tools/player_docs.py --fixture-archive ... --fixture-output ...` and `tests.player_documentation` in a separate test-only ZIP. Execute Reference tutorials through `tests.reference_tutorials_engine`; syntax-only compilation does not prove wiring or effects.
5. Run `tools/monitor_animation.py` with `--layout four-walls` and `--layout mixed`, both modes, retaining the unchanged cadence/workload assertions for the converted chart. Include affected device fixtures with the optional chart dependency present and absent where they already require it.
6. Use matching full 2.1.23 clients and isolated saves for the changed authoring content: Insert starter → Validate → Save → Run; native Reference copy/paste of a complete tutorial; dirty draft and failed-replacement retention; separate Console expression/table/local-function behavior. Inspect actual windows and output in base and Space Age. Reuse existing client preparation and bounded input drivers; headless/mock GUI passes are not native-copy evidence.
7. Final checkout/package semantic absence audit, generated freshness, spec validation and diff review. Associate every pass with the final archive or explicitly proven equivalent production payloads; keep failures and earlier packages separate.

Representative existing command sequence (implementation, not executed by this proposal):

```sh
WORK=$(mktemp -d "${TMPDIR:?}/tc-function-only-XXXXXX")
HEADLESS="$PWD/gameitself/headless-2.1.23/factorio/bin/x64/factorio"
"$HEADLESS" --version
"$HEADLESS" --help > "$WORK/engine-help.txt"
python -m unittest discover -s tools -p 'test_*.py'
python tools/planning_examples.py --check
python tools/configuration_catalog.py --check
python -m mkdocs build --strict --site-dir "$WORK/site"
python tools/player_docs.py --check --site "$WORK/site" --report "$WORK/player-docs.json"
python tools/build.py --output "$WORK/package" > "$WORK/build.json"
ARCHIVE=$(jq -er .path "$WORK/build.json")
python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" --output "$WORK/runtime" --mode both
python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" --output "$WORK/integration" --mode both --fixture tests.integration_engine --production-context --cold
python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" --output "$WORK/tutorials" --mode both --fixture tests.reference_tutorials_engine --production-context --cold
python tools/monitor_animation.py --factorio "$HEADLESS" --archive "$ARCHIVE" --output "$WORK/chart-walls" --mode both --layout four-walls
python tools/monitor_animation.py --factorio "$HEADLESS" --archive "$ARCHIVE" --output "$WORK/chart-mixed" --mode both --layout mixed
```

This sequence is not the entire fixture matrix. Preserve each additional changed fixture's existing arguments, dependencies, cold markers and completion assertions. Do not raise production budgets, shorten deadlines, replace real observations with fabricated data or restore hosted checks to make verification convenient. UI/rendering runs make no new connected-multiplayer or representative-GPU-performance claim.

## Risks / Trade-offs

- Broad fixture edits can accidentally weaken assertions → change source construction while retaining independent outcomes; review any deleted assertion separately.
- Mechanical source rewriting can corrupt host wrappers or ordinary guest tables → distinguish host code from the exact string passed to the compiler and compile the real extracted corpus.
- New declarations reserve names and bind siblings differently → use valid existing declaration rules; preserve lexical/global and protected-call tests instead of exempting fixture names.
- Converted programs can consume different work and expose latent limits → retain real failures and fix redundant work or fixture assumptions without widening guards or weakening workload acceptance.
- Historical source cleanup can misrepresent evidence → remove obsolete passages, keep valid unrelated observations and label newly executed workloads with new receipts.
- Generated output can reintroduce stale material → update input sources first, regenerate, and inspect hidden metadata and package payloads as well as visible pages.
- Many affected engine runs take time → batch local tooling checks and use existing aggregators where they genuinely cover the changed cases; do not substitute a representative subset for the declared acceptance matrix.

## Migration Plan

No player-source converter, migration or retained-format feature is planned. Implement the compiler/content/test cleanup together on the feature branch, synchronize current contracts, regenerate derived content and complete local verification before review. Keep implementation tasks unchecked until their receipts exist. Release/version selection, publication, merging and archival require their usual separate authorization.

Rollback is a normal code revert or reinstalling a previously published archive against an isolated backed-up save; do not rewrite releases, mutate player saves or add a hidden runtime toggle. This proposal makes no guarantee that a save written by a newer engine can be downgraded.
