# Design

## Context

See `proposal.md` for motivation and the five capability deltas for the behavior contract. This design is required because native opening, shared GUI events, service reads, maintenance admission and existing-save handling intersect.

Observed implementation constraints:

- `scripts/services/peripheral.lua:12` registers five peripheral kinds. Ordinary names come from registry identities; monitor names instead resolve to logical groups through `scripts/services/monitor.lua:26`.
- `scripts/ui/interaction.lua:7-30` currently routes Ctrl-click to computers/touches and dismisses native device dialogs. `scripts/lifecycle.lua:78-87` makes the body inoperable and removes native signal sections. Adding an open-event handler alone cannot make normal player opening work.
- `control.lua:21-34` registers most GUI events directly to the editor. `scripts/ui/editor-model.lua:16-51` demonstrates exact ownership, force/surface, reach, permission and session checks, but its authority function is computer-specific.
- `scripts/ui/editor.lua:29-31,461,489-490` already uses read-only, rich-text-disabled text boxes plus focus/select-all for native Copy. No clipboard API or external library is necessary.
- `scripts/services/kv.lua:29-32` defines live-entry expiry; `snapshot` at line 178 is a mining snapshot that includes retained expired entries and runs import validation. It is not the desired live browser query.
- `scripts/configuration/targets.lua:14-45` implements bounded target-side traversal and maps owned components to logical bodies. `scripts/services/configurator.lua:10-17` adds expensive configuration descriptions that a prototype count does not need.
- `scripts/services/logic.lua:70-91` has bounded, quality/type-aware native input sampling. Its one output bank is distinct from aggregate signals present on output wires. Existing subscription caches do not necessarily contain both input colors when no program subscribes.
- Monitor groups have `width_tiles`, `height_tiles`, `members` and a model containing `width`, `height` and `scale`; world-space bounding dimensions are different for rotated nonsquare displays. Group resolution explicitly refuses while regrouping is uncommitted.
- `scripts/scheduler.lua:50-82` owns persistent same-tick maintenance admission. Render hooks run in name order, with existing `monitor-world` and `program-editor` hooks. Inspection must not obtain unmetered work or masquerade as a computer callback.

The requested visual reference was inspected using the official Factorio article “Friday Facts #384 — Combinators 2.0” and its arithmetic-combinator image. It shows red/green-backed rows within one Input signals section beside neutral Output signals. The installed 2.0.77 core `prototypes/style.lua:1724-1749` contains `red_circuit_network_content_slot` and `green_circuit_network_content_slot`, based on `compact_slot`. This is reference inspection, not a claim that the proposed UI has been rendered in the client.

## Goals / Non-Goals

**Goals:**

- Separate inspection authority from computer execution authority, while reusing existing bounded service primitives and native visual conventions.
- Keep UI state per player and data snapshots detached, so browsing cannot acquire write authority or leak mutable provider tables.
- Deliver one coherent vertical feature including real entity opening, all peripheral panels, old-save reconciliation and native interaction verification.

**Non-Goals:**

- No generic GUI framework/event bus, plugin registry, secondary network graph or replacement scheduler.
- No editable names, database/configuration editors, recipe-search GUI, pixel framebuffer API or new guest methods.
- No changes to guest per-color reads, power policy, output ownership, monitor grouping/scale, device progression or physical artwork.
- No claim of one-click OS clipboard writes: select the exact name and use Factorio's native Copy control.

## Decisions

### 1. Operable peripheral bodies with immediate owned-dialog replacement

Allow normal opening on the five peripheral body kinds, while computers and owned role/power helpers retain their current inoperability. Keep the passive body circuit behavior disabled with no native signal sections. Separate the existing electrical passivity invariant from the UI-operability decision in `lifecycle.lua`, including build, network reset/settings paste, physical upgrade and existing layout-version-2 records.

`interaction.on_opened` must verify that the opened entity is the player's actual current target, resolve its registry binding, dismiss its native carrier dialog and open the inspector only after player authority passes. Unknown owned helpers still get dismissed; vanilla entities and another already-open GUI remain untouched. Do not recreate entities merely to change operability.

The existing rotation bridge already ignores operable bodies; those bodies should use normal native rotation and the existing lifecycle event exactly once. Keep the custom rotation path for inoperable computers. Actual Ctrl-click must still reach `tc-interact` without also opening a monitor inspector; verify this in the full client, not only by calling Lua handlers.

Alternative rejected: a new inspection shortcut. The user explicitly chose ordinary opening. Re-enabling the carrier's editable constant-combinator dialog is also unacceptable.

### 2. Small inspector model/view with explicit shared-event routing

Proposed new modules are `scripts/ui/peripheral-inspector.lua` for native construction/events and `scripts/ui/peripheral-inspector-model.lua` for session validation and detached view data. Keep device-specific readers next to the owning service where they can reuse its private validation; do not turn these into a public provider framework.

Store at most one bounded inspector session per player in an additive `peripheral_inspectors` root field. Retain only plain session metadata and bounded snapshots: token, physical record ID/unit/generation, panel selection, snapshot tick, pending state and UI version. Native GUI objects are recovered from the player's screen tree and checked against session tags, not persisted as authoritative references. No guest functions, handles or subscriptions enter inspector storage.

Mirror the editor's same-force/surface/reach/permission rules without weakening or rewriting its computer-specific checks. A monitor session is anchored to the physical tile the player opened, not to a distant anchor body. Revalidate before all actions and refreshes; clear sensitive details or close when access is lost. Sessions stay independent between players.

Keep one production handler for each Factorio event in `control.lua`. Add narrow routing for shared click/close/selection, player-unavailable and display-size events, forwarding to the owner-specific editor or inspector handlers; existing editor text/console behavior remains intact. Preserve dirty editor drafts when transitioning to an inspector and never reopen either window from an old close event. No second module may overwrite a shared `script.on_event` registration.

Alternative rejected: make every peripheral pretend to be a computer so the editor opens it. That would entangle draft/run authority with read-only inspection and consume unrelated computer budgets.

### 3. Shared identity header and bounded native presentation

Each frame has a localized title/type, availability, read-only exact API-name box, Select name for copy action and Close control. Use the editor's proven focus/select-all approach and native Copy instructions; do not append Lua quotes, a channel or explanatory prose to the selected name. Reuse native style conventions and only focused custom styles where needed. Recipe Searcher ends at this basic panel.

Keep layout fitting separate from the editor's document-height assumptions. Reuse compatible clamping logic rather than copying the entire workspace. At the established supported effective GUI size, keep header and close/copy controls visible while only the details area scrolls. Use deterministic slot/row names, stable selection and value comparisons to avoid rebuilding unchanged text or stealing focus. New strings belong in `locale/en/` rather than hardcoded UI prose.

### 4. KV: bounded live snapshot, key list and full detail viewer

Add a host-only live inspection reader inside `scripts/services/kv.lua`, reusing `audit`, limits and the `live` predicate rather than exposing the mutable database or reusing the mining snapshot. Collect live keys in deterministic byte order, preserve string/hash types and return copied field/value data with a snapshot tick. Do not purge keys, call SET/import/publish or renew deadlines while reading.

Use a bounded key list with type indicators and a selectable read-only detail area. A selected hash exposes every field/value through bounded rows/pages; full values are accessible even when row previews are shortened. Pagination is a view concern over the complete bounded snapshot, not a partial inventory presented as complete. Refresh is explicit for the database so background program writes do not disrupt reading.

Represent byte strings with a documented reversible escaping convention: quoted strings, escaped quote/backslash/control bytes, and escaped non-displayable bytes, with rich text disabled. Keep empty strings visible as empty values rather than missing keys. Account for worst-case escape expansion when reserving formatting work and limiting rendered detail chunks. The current accepted database capacities bound snapshot storage; the inspector must not reduce what existing databases can hold.

Alternative rejected: render every database entry directly from retained storage every tick. That mixes current and expired data, forces scroll/focus churn and bypasses read boundaries.

### 5. Configurator: union target inventories, then group by prototype

Reuse `targets.inventory(rec, wire, spend)` separately for red and green. Union by existing target identity and then group by `entity.name`; derive unique, red-connected and green-connected counts per prototype. Keep native entity type as optional descriptive metadata, not the grouping key. Sort by exact prototype name, with localized names/icons for presentation and prototype names available for disambiguation.

Preserve traversal policy, including ordinary relays and unsupported connected devices. Existing ownership resolution collapses helpers to their logical body and excludes the origin; do not independently count each socket. If another mod device is legitimately on a target network, count its body once rather than excluding the whole class. Devices connected only to the Network role are not target entries.

Publish a snapshot only after both traversals and grouping complete; otherwise expose an explicit refusal/pending state. Label overlapping red/green counts so their sum is not mistaken for the unique total. Read-only identity registration used by existing target enumeration is acceptable host bookkeeping; no configuration adapter mutation is called. Full capability/configuration snapshots are unnecessary for this summary.

Alternative rejected: use computer peripheral discovery or sum two per-color totals. The first traverses the wrong graph; the second double-counts dual-connected devices.

### 6. Logic: native-colored input rows and the own output bank

Expose a narrow host-only inspection read from `scripts/services/logic.lua` using existing normalization, signal limits, physical connector checks and paid native reads. An already-sampled color is reusable only if its sample tick and identity are current; absence of a program subscription must not make the inspector empty. Copy the resulting plain signal records and output bank; do not register a subscription or call output publication.

Use one Input signals panel with red and green row groups, using the pinned native slot styles, beside neutral Output signals. For the same signal on both colors, render distinct wire-qualified slots. The output panel is labelled as this handler's contribution, shared across both output colors, rather than an output-network total. There are no combinator conditions, operators or editable signal elements.

Use non-mutating sprite slots with counts, identity/quality information and exact-count tooltips. Choose sprites by signal namespace so recipes do not alias items. Preserve color backplates in the noninteractive state; simply disabling a native button may change its visual style, so inspect actual client output. Supplement color with Red/Green labels and tooltip text.

Alternative rejected: sum red/green values into one entry. The requested layout places both in one region, but its colored slots preserve wire provenance; summing would hide information and conflict with the existing explicit-color API if reused there.

### 7. Monitor: derive one coherent view from current group state

Resolve the selected physical member with `monitor.resolve`. Copy group ID, `width_tiles`, `height_tiles`, member count and model width/height/scale in one admitted read. Do not use world bounding dimensions or derive a second terminal-size formula. Display Connected tiles, Terminal columns × rows and Text scale with explicit units; the user chose these over pixel dimensions.

While regrouping is pending, disable copying an obsolete logical name and label dimensions unavailable/pending. Once a surviving selected tile maps to a committed group, replace name and geometry together and indicate an identity change. If the selected physical tile is removed or replaced, invalidate the session rather than finding another entity at its position. Power loss permits committed metadata inspection but never unblanks or captures a framebuffer.

### 8. Throttle work through existing maintenance admission

Opening creates the small shared frame and requests a detail snapshot. KV and configurator use explicit Refresh. Logic and monitor request periodic updates while open, initially at the editor's existing 15-tick UI cadence; this is proposed UI sampling, not a promise to capture every circuit pulse. Repeated clicks coalesce into one pending request per session.

Register a late `render` phase hook, for example `ui-peripheral-inspectors`, after the existing monitor/editor work. Acquire a non-render spend function from `scheduler.maintenance(root, tick)` so the UI cannot consume specially reserved publication credits. Charge authority walks, provider reads, sorting/copying, byte escaping and GUI updates; do not call readers with a no-op spend function. Use a retained rotating player cursor and explicit per-refresh bounds so one large panel cannot monopolize inspection service. Charge even work that ends in refusal; never reset ledger totals or count a retry as a new tick.

Build candidates privately and replace displayed snapshots only after successful completion. Bounded refusals leave a clearly labelled prior snapshot or an error, not partial counts. Authority checks and small status changes must remain cheaper than detail reads. Do not query details for closed/hidden sessions; coalesce pending work and drop it on closure. Implement no standalone `on_tick`, wall clock, per-process authoritative cache or automatic background world scan.

Alternative rejected: invoke guest service facades from GUI callbacks or allocate artificial computer admission records. Local read authority is not a computer run, and UI activity must not fault an unrelated program or renew its allowances.

## Risks / Trade-offs

- [Changing operability could expose native sections or double-rotate] → Keep the passive electrical invariant; update every reset/build/upgrade path; prove ordinary open interception, helper suppression, settings-paste behavior and single rotation in the client.
- [Native open and Ctrl-click interactions differ from synthetic events] → Gate the interaction milestone on actual input for monitors and computers, including held modifiers and inventory transfers.
- [Signal sampling and target traversal can be expensive] → Reuse existing limits, admit before native work, throttle/coalesce, rotate viewers fairly and verify under the unchanged supported animation/program workload. Explicit pending/error is preferable to fake completeness.
- [Arbitrary byte values or native button states render misleadingly] → Use reversible escaped text and full-value access; visually inspect binary/long-value cases and colored read-only slots.
- [Large data snapshots cause duplication or selection churn] → One bounded snapshot per session, paged visible rows and updates only when content changes; no history cache.
- [Old tests encode blanket inoperability] → Replace only that intentionally changed expectation with stronger assertions for correct custom opening and inaccessible native controls. Preserve helper protection and network-output invariants.
- [Unpowered data browsing could silently widen service policy] → Show identity/status and committed monitor geometry, but refuse new active KV/target/input detail queries, consistent with current service restrictions.

## Migration Plan

1. Add inspector state compatibly during synchronized initialization/configuration change or first authorized GUI use; never during `on_load`. Unsupported storage remains untouched.
2. Reconcile opening eligibility for existing peripheral bodies as well as newly placed, cloned, revived and pasted/reset devices. Preserve identities, physical wires, database values/deadlines, display state and output ownership; do not rebuild the devices.
3. Revalidate saved sessions on the next synchronized UI cycle. Close incompatible/stale inspector trees safely; retain computer drafts and all device state. No guest callbacks or reads run during load.
4. Keep a copied pre-change save and the exact packaged candidate for upgrade and cold-load checks in base and Space Age. Test actual GUI/copy/rotation and two connected viewers separately from headless provider contracts.
5. Roll back by restoring the pre-change mod and copied save if acceptance fails. Do not promise that loading an arbitrary older alpha into the newly saved world is a verified downgrade path. No publication is authorized by this planning change.
