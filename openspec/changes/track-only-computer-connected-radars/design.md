# Design

## Context

See `proposal.md` for the problem and approved behavior. The implementation baseline is commit `c032f99be5bf63c0f56bfe7cc2a9595fbd1e09a3`, mod 0.1.15, pinned to Factorio 2.1.23.

Observed control flow:

- `control.lua:48-54` forwards native build/clone events and runs one global scheduler.
- `scripts/lifecycle.lua:374-382,438-442` eagerly enrolls built/cloned radars. `scripts/radar.lua:78-114` adopts neighbors from every registry entry, including standalone peripheral components, and examines both colors independently of any computer-rooted proof.
- `scripts/registry.lua:57-77` puts every identity into `root.order`. That list feeds physical availability and reconciliation, scheduler walks, output checks, monitor scans, art and KV maintenance. A flag checked only inside `radar.reconcile` would leave the other linear walks intact.
- `scripts/network.lua` already owns same-color, same-scope physical discovery and excludes hidden radar-origin links. Ordinary guest inventories require registered vertices and explicitly report pending native enrollment.
- `scripts/services/modem.lua:89-156` first enumerates radar candidates globally, then proves receiver-computer paths. The inverse order can avoid dormant candidates.
- The existing API already preserves channels on same-scope reconnection and keeps topology power-independent. The identity requirement currently says every placed radar has an identity; the delta changes that to enrolled radars, preserving existing identities rather than resetting them.

Baseline evidence is outside git at `/home/siredvin/artifacts/tweaked-computers/idle-radar-diagnosis-2026-10-27-wJfLD2/`. Its exact-archive diagnostic used zero computers and native raised build events, with separate total-only and phase-profiled windows. It is not the user's save, a connected-multiplayer test or candidate acceptance.

The pinned official runtime API was inspected at `https://lua-api.factorio.com/2.1.23/runtime-api.json`: `on_load` cannot write storage or use `game`; configuration-change handling can migrate authoritative state; object-destruction registration persists through save/load and delivers an identified event. The repository already uses that registration API in `scripts/configuration/targets.lua:8-12`.

## Goals / Non-Goals

Goals:

- Make absence of recurring disconnected-radar work structural, not a timing-dependent cleanup convention.
- Reuse the current registry identity lookups, graph policy, scheduler admission and service proofs instead of introducing a separate network framework.
- Preserve physical identity, channels, guest state and admission ledgers through upgrade and cold reload.

Non-goals:

- Moving guest execution onto entities, replacing the scheduler, changing native radar simulation, or optimizing every peripheral family.
- A new public tracking API, settings, dependencies, resource ceilings or unbounded world discovery.
- A claim that passive data has zero memory/save cost or that headless results establish client FPS.

## Decisions

### 1. Remember radar records without giving them a generic tick slot

Keep enrolled radar records addressable through the existing keyed identity/entity maps. Exclude all native radar records from `root.order`, including connected ones. Connected radar work is performed only by a current computer-rooted discovery or live service operation; disconnected records therefore have no recurring work item to reactivate accidentally on load.

This is smaller and safer than maintaining a second authoritative active-radar list plus reachability reference counts, expiration timers and a dormant cleanup sweep. Attachment is established by physical proofs, not by a saved boolean. Existing computer topology observations can continue supporting notifications, but never authorize calls or seed adoption on their own.

Preserve total retained-identity admission independently of the ticking list's length. Reuse the existing registry ceiling with a synchronized retained-record count, initialized once for old saves and updated on registration/removal; do not count dormant records by scanning them each tick, silently evict accepted state, or let dormancy bypass the existing capacity. No new cap is proposed.

Audit every `root.order` consumer. Recurring consumers intentionally omit radars; event-only whole-registry duties such as surface deletion, force merging and explicit removal must still reach remembered radars through keyed lookup or event-time enumeration. Do not replace `root.order` with a per-tick filter of all devices, which would merely hide the same cost.

### 2. Adopt from real computer roots, preserving one color through the walk

Reuse the existing bounded adoption phase, but select placed computer roots rather than arbitrary device entries. Roots remain eligible when stopped, faulted or unpowered; program-running state is not a physical wiring rule. Iterate computers/colors deterministically under the existing maintenance budget.

Factor the existing physical-vertex/edge checks just enough for trusted adoption to walk supported native connectors before those vertices have records. Enrollment must be preceded by a current same-color path from a computer, not merely adjacency to an already registered peripheral. Preserve exact prototype, role, force, surface, ghost and hidden-link exclusions at every edge. An unwired monitor tile must not become a bridge through its logical display group.

Use the existing pending-adoption contract for public inventories. Keep public discovery fail-closed and read-only with respect to admission: unknown native vertices can report pending while the synchronized adoption path progresses. Charge native edge arrays and each identity publication before mutation, preserve existing envelope failures, and revalidate any retained frontier before using it. Reuse the existing bounded graph policy rather than building an independent graph cache or world index.

The shared frontier also handles speakers. Preserve their existing reachable-relay behavior and tests, including a newly encountered speaker before a radar. Do not turn this radar change into general speaker dormancy or change audio semantics.

A detached remembered radar is found again by keyed entity lookup when a fresh computer-rooted traversal reaches it. It is not periodically asked whether it has reconnected.

### 3. Read radar availability and scope where they are actually needed

Remove reliance on the two generic per-tick radar availability samples. The existing radar service binding already supplies a live availability check; use that boundary and computer-rooted traversal for current native state. Ensure `peripheral.describe` reports a live radar availability value rather than the old cached `rec.powered` field.

Before a newly reached remembered radar participates in discovery/service under another scope, the synchronized adopter reconciles its force/surface and generation, clears channels as required, and invalidates old bindings. Public reads detecting a mismatch refuse pending/unreachable until that reconciliation; they do not silently mutate scope as a side effect of lookup. Saved IDs or an old positive power observation are never authority. A complete physical path remains discoverable through unpowered supported relays; powered operations are a separate test.

This removes the need to prove that an active-radar list was refreshed before the first tick after every load. Even a stale pre-save attachment observation cannot put a radar into generic polling.

### 4. Build radio candidates from receiver computers, not remembered radars

In `services/modem.lua`, select eligible running, powered, same-force receiving computers with a `modem_message` registration and a potentially compatible surface first. Obtain their current red/green inventories, then select reachable, available radar receivers with the requested channel open. Deduplicate physical receivers and paths, enforce the existing candidate/delivery limits, and retain the existing deterministic publication order and prepublication admission.

Do not scan all remembered devices or dormant channel sets to discover that nobody is listening. Connected candidates use fresh paths; pending relevant topology must retain the current explicit refusal/no-partial-publication behavior, not become a silent successful omission. Computer/radar power, both-color deduplication, self-echo exclusion, tier/surface checks, queue overflow and accepted-message snapshots remain unchanged.

This modestly changes what consumes routing candidate capacity: disconnected retained radars no longer occupy slots. The API amendment states that explicitly; numeric ceilings and accepted payloads are unchanged. Exercise empty/no-recipient and incomplete-graph cases because reversing the planning order can otherwise introduce needless refusals or hide a failed proof.

### 5. Retire dormant data through targeted lifecycle events

Register remembered radars with `script.register_on_object_destroyed` when enrolled or migrated, keeping a mod-owned registration-to-identity lookup. Compose `on_object_destroyed` in `control.lua`; ignore registrations outside that map because the engine shares destruction notifications across mods. Make ordinary removal and destruction notification idempotent and verify exact identity before cleanup.

This handles destruction without a raised entity-removal event without scanning dormant records. Existing build/revive/clone handlers must not eagerly create identities. Replacement/cloning starts unconfigured and gets its own identity only when a valid computer-rooted path enrolls it. Native bodies and wires are never destroyed or rewritten merely to change tracking.

Surface deletion and force-merging handlers must cover retained records even though `root.order` no longer includes them. A direct force/surface change not announced by an event is checked before subsequent participation; no polling is added solely to observe inactive entities. Already accepted packet snapshots are not recalled when their source peripheral record is retired.

### 6. Separate structural acceptance from wall-clock evidence

Native fixtures must assert that dormant/unrelated radar IDs are absent from generic recurring iteration, that availability/adoption/routing observers do not visit them, and that fixed computer-connected work does not grow with disconnected record count. Include first ordinary ticks after upgrade and cold load, not just a warmed-up interval after cleanup.

Use serial baseline/candidate measurements with identical engine, settings, map workload and observation mode. Measure fresh unregistered and legacy/detached dormant populations of 0, 100, 500 and 1,000 radars, first with zero computers and then with a fixed working network. Report sample counts, mean/median/tails, archive hashes and host contention; use phase observers only as a separately labeled attribution run. Native engine radar costs are not mod scheduler time. Do not raise budgets or invent a universal millisecond threshold to force a pass; unexplained scaling requires investigation before accepting the optimization.

## Risks / Trade-offs

- Retained state still consumes memory/save space -> keep existing identity admission and targeted destruction cleanup; measure/report serialization separately if material. There is no background dormant sweep.
- Shrinking `root.order` can change cursor positions and omit event-only duties -> normalize cursors without resetting credits, audit all consumers, and test surface/force/removal paths with dormant records.
- The old adopter bridges its scanning across colors and standalone components -> require computer-rooted, color-preserving tests, including disconnected cycles and native speaker/radar relay chains.
- Receiver-first routing can change refusal timing -> preserve typed errors, complete relevant proof and zero partial delivery; verify native modem capacity and competition fixtures without budget changes.
- Native connector arrays can include hidden radio edges -> reject their origin before inspecting remote owners or records, and include powered as well as unpowered native-radar controls in measurements. Existing edge admission still accounts for native array materialization; do not mistake retained-record scan elimination for proof that all connected-graph costs disappeared.
- Ordinary reload or late joining can tempt an ephemeral rescan flag -> do not make synchronized behavior depend on `on_load` having run on one peer. Persist the structural separation and test connected-peer consistency for the changed lifecycle before claiming multiplayer acceptance.
- Pinned API checks are not execution proof -> exercise object destruction, first-tick migration, public guest calls and cold state in the native 2.1.23 engine during implementation.

## Migration Plan

1. Ship under a distinct mod version so configuration-change migration actually runs when upgrading 0.1.15. Use an additive, validated tracking-layout marker; unsupported storage stays retained/inert rather than reset.
2. In synchronized initialization/configuration change, make a one-time pass over the old registered records. Retain radar records, identity bindings, scope/generation and channel data; remove radar IDs from the generic recurring order. Initialize retained-identity accounting and destruction registrations. Normalize only affected cursors and retire the obsolete all-device adoption cursor. Do not touch guest state, queued events, run IDs or spent tick credits.
3. Complete that separation before returning to ordinary ticking. Do not spread legacy radar removal over gameplay ticks. Fresh computer-rooted discovery resumes under existing budgets and pending semantics; no world search or player rewiring is required.
4. Ordinary cold load restores the saved maps and non-radar order without authoritative mutation in `on_load`. Stale saved topology observations cannot reintroduce radar tick slots. Re-run only actual targeted lifecycle work or fresh computer-rooted proofs.
5. Verify with an immutable 0.1.15 archive/save containing both connected and eagerly registered unconnected radars, then save and reload the candidate in another process. Retain the existing older-installation fixture separately; it does not substitute for this upgrade.
6. Roll back using the backed-up pre-upgrade save and matching previous archive. Do not promise safe downgrade of the newly partitioned registry to older code that assumes every record appears in `root.order`.
