# TC05 — peripheral discovery implementation checkpoint

Scope: OpenSpec 2.5 / peripheral-network only. Parent physical commit
`13f89cfd0fe021efa8b747c0d8360c0c1cb690db` was ordinarily merged into the owned
TC05 branch and verified as an ancestor. No sibling implementation or primary
checkout was edited, no OpenSpec archive/release/primary merge was performed.

## Implemented

- Real owned NETWORK connector traversal, independent red/green graphs, one
  force/surface, no vanilla/ghost/INPUT/OUTPUT/TARGETS relay or signal API.
  Unsupported external wires are ignored, never deleted.
- Complete bounded inventories and the exact getNames/isPresent/getType/
  getMethods/describe/wrap/call/find/getName/getWire surface. Nil and multiple
  return arity, sorted copied metadata/methods/names and unknown-method errors.
- Current full physical search before every target query/captured method, stable
  name/generation/channel/run binding, power-independent presence and getLimits,
  active-method power refusal and fresh native body energy checks.
- Closed four-type trusted service bindings, with monitor-only logical identity
  resolution/description hooks. Logical monitor identities never add graph edges.
- Durable per-run/channel availability and bounded transition jobs, sorted
  detach-before-attach events, silent initial baselines, explicit limit/pending
  diagnostics and admitted event publication with retained deferral cursors.
- Source-independent exact-writer output cleanup on retirement, per-tick live
  physical witness validation/alternate path recovery, fail-closed output zeroing
  when proof cannot be admitted, and fixed host revocation hooks for subscription
  cleanup before guest notification.
- A narrowly scoped host-only protected-facade argument opt-in for getName/getWire.
  Fake/foreign namespace handles are rejected; other service arguments still
  require copied Data, so this does not permit persisting a facade or host object.
- Shared scope/real-edge/witness primitives for the separate configurator target
  policy, not a generic extension framework.
- Full API/host integration documentation, localized UI-help keys and an executed
  packaged native inspection program. The inspection program is source text,
  not a new gameplay filesystem or guest require facility.

## Exact artifact and commands

Tested production archive:

`/home/siredvin/.hermes/profiles/albina/cache/scratch/tc05-artifacts-verified/tweaked-computers_0.1.0.zip`

SHA-256: `40d83955b8a4d71928f7d7f67d36f3bc963adb67970ecb810c70db8540af3f04`

Deterministic build: `python3 tools/build.py --output <outside-git-directory>`.
46 packaged files; pinned parser bytes/inventory are checked by the builder.
OpenSpec handoff/checklist files are intentionally not part of the mod ZIP, so
adding these evidence notes does not change the tested runtime archive.

Focused official-engine command:

    python3 tools/smoke.py \
      --factorio /home/siredvin/tools/factorio/bin/x64/factorio \
      --archive <verified-archive-above> \
      --output <fresh-outside-git-directory> \
      --fixture tests.network_engine --cold

Evidence: `/home/siredvin/.hermes/profiles/albina/cache/scratch/tc05-smoke-verified/summary.json`.
Exact Factorio 2.0.77 base and Space Age each pass 12 counted unique groups; both
run two separate cold server processes. All four phases exit 0 after acknowledged
console `/quit`, with no signals/forced kill. Sockets bind localhost only and
public/LAN visibility is disabled. Frozen snapshots are not overwritten by quit.

The grouped checks exercise real same-colour chains and native connectors,
red/green nonpaths, vanilla continuity exclusion with wires retained, vanilla
entity ghosts, real foreign-force and forced cross-surface wire rejection,
role isolation, powered/unpowered metadata, defensive copies, compiled stale
captured calls, facade forgery/persistence/native-object refusals, serialized
shared test binding writes, detach/replacement identity, physical group-member
nonbridging/split invalidation, exact 256-node completion versus 257-node refusal,
129 matching facades refused before tuple construction, edge/work refusal,
deterministic notifications, an actually compiled failing detach handler after
host cleanup, alternate output paths, exact newer-writer preservation, proof-credit
refusal/zero output, stop cleanup, and the packaged native help example.

Cold checks verify unchanged on_load scalar source/run/body identities, cached
inventory/owner/machine aliases, ledger tick/total/work/compile/allocations,
maintenance and sequence. Same-tick quota refusal does not renew credits. Actual
subsequent ticks disconnect the path, clear the native output and deliver both
sorted detach callbacks exactly once without replaying startup. Saved name/wire/
actual position survive and fresh wrapping returns absent after detach.

Affected parent regression:

    python3 tools/smoke.py --factorio <same-engine> \
      --archive <same-verified-archive> --output <fresh-directory> \
      --mode base --fixture tests.computer_contract

`tc05-parent-regression-verified/summary.json` records 45 passing counted parent
native/compiler/state/scheduler groups on this exact archive, including malicious
source and existing fatal-budget/alias/arity checks. No standalone Lua executable
was installed on PATH; these checks executed in the actual pinned engine instead.

## Preserved failures and root cause

Earlier evidence directories `tc05-smoke-first` through `tc05-smoke-fourth` are
retained outside git. The first fixture accidentally forwarded the inventory's
second return as next's cursor; scalar adjustment fixed the fixture, not runtime.
The second tried to ghost an intentionally non-blueprintable owned helper; a real
vanilla constant-combinator ghost now exercises ghost exclusion.

The third cold attempt timed out with clean console shutdown; the fourth's bounded
trace/deadline showed a real notification job stuck at its first transition.
Reserving maximum subscriber copies for every event consumed slightly more than
the remaining shared maintenance envelope even with only two physical devices.
The fix scans bounded registrations and prepays only actual matching subscriber
copies; it retains all caps and atomic event publication. Fifth/candidate/final
checks then passed. Clean retries do not erase those failures. No speculative
signal-handler cause, fabricated engine output or elevated budget is claimed.

## Integration and boundaries

Read `docs/peripheral-network.md` before binding a type. Fixed methods receive
`(computer, target, wire, tick, spend, ...)`, validate their own signature and
reserve effects, returning only Data/ordinary tuples. getLimits is mandatory.
The default checkpoint binding exposes only getLimits; actual KV/logic/monitor/
configurator services belong to the inspected, pre-created TC07/TC08/TC09/TC10
children. Do not load `tests.network_engine` in production: its methods and group
resolver are explicitly test-only.

Logic ownership uses `{computer_id, run_id, wire, path?}`. The network already
registers the exact-run output cleanup and tick authority safety hooks. Logic
must coordinate subscription/sample teardown and writer transfers with these,
not replace scheduler.on_tick or clear a newer writer. Fixed revocation hooks
are bounded to this run's subscriptions; exceptions run remaining hooks then
fault the run independently of source execution.

TC07 owns merging the editor sibling and this commit, then wiring its real
`editor.register_inspector` adapter and displaying the localized discovery help.
TC09 owns actual rectangular monitor grouping/rendering; the synthetic resolver
here proves graph/facade policy only. TC10 reuses real-edge/scope primitives but
implements its different target-relay allowlist and isolated-connector policy.

hotspot: `control.lua` — keep this trusted peripheral import beside lifecycle and
preserve sibling editor/service registrations during merge. The sandbox diff is
only the host-only handle-introspection opt-in; do not turn it into a general
protected-handle/Data bypass. README/checklist changes must preserve sibling rows;
only OpenSpec 2.5 was updated.

Development resource ceilings remain provisional. Graph queries never return a
truncated prefix, and calls never authorize from cached availability. The ordinary
three-channel rotating reconciliation sweep fits the intended 60-tick tuning
without contention; heavy maintenance pressure is explicit pending and retains
jobs, while safety proof failure clears output. A measured maximum-world latency
and final release envelope belong to the existing TC13 integration task, not a
claim made by this focused checkpoint.

Native client editing/typing/focus/wire selection/monitor presentation and joining
multiplayer clients remain user-deferred. No graphical client, screenshots or UI
click automation ran. Computer/KV interim mining guards remain untouched; real
snapshot lifecycle is still the existing downstream scope. This is an implemented
feature-branch checkpoint, not an alpha publication or a final playable mod.
