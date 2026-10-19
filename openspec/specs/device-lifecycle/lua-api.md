# Lifecycle effects on Lua APIs

Normative companion to [spec.md](spec.md). This capability adds no unrestricted entity-management namespace. The computer and peripheral facades in the other Lua API documents remain the only guest capabilities.

## Identity and data matrix

This matrix describes saved-program and physical-device state. The independent
[Console lifecycle](../console-shell/lua-api.md#session-lifetime) additionally
retains its scratch graph across window close, load, automatic program fault and
power loss, but clears it on successful Run/Apply, explicit Stop or confirmed
Reset Shell. Shell sessions never travel to a new physical identity.

| Transition | Computer source/state | Runtime/timers/subscriptions | KV contents/TTL | Monitor | Logic output | Target configuration |
| --- | --- | --- | --- | --- | --- | --- |
| Ordinary save/load | Preserve saved and active snapshots/state/identity | Preserve without startup replay | Preserve absolute deadlines | Preserve complete model | Preserve valid bank/owner | Native save preserves |
| Save edited source | Update saved source only | Old active revision continues | Unchanged | Unchanged | Unchanged | Unchanged |
| Explicit Run/Apply | New active revision; retain explicit state | New run generation; old work canceled | Unchanged | Retain image | Clear old run's still-owned bank | Retain |
| Stop/fault | Retain recoverable source/state | Cancel run work | Retain | Retain image | Clear still-owned bank | Retain |
| Computer power loss | Retain | Pause; resync current inputs on return | Retain; ticks still expire keys | Retain | Clear still-owned bank | Retain |
| Peripheral power loss | No change | Services unavailable; relevant current-input resync on return | Retain deadlines/data | Blank presentation, retain model | Clear bank | Retain native targets |
| Mining/replacement | Preserve committed saved/active source snapshots and explicit state in item; new entity ID | Do not carry active run/work; replacement stopped | Preserve data/deadlines in item; new entity ID | Preserve tile settings, not an obsolete merged screen image | New placement zero/unowned | Already-applied settings remain on targets |
| Blueprint/clone/settings copy | Copy source/label/applicable settings, not explicit state; new identity | Start stopped, no work | Empty | New grouping, blank buffers, copied applicable settings | Zero/unowned | Copy only the native target settings if the target itself is copied; configurator does not carry a list of old managed target IDs |
| Destruction | Destroy that device's data | Remove work/authority | Destroy physical database's data | Regroup/remove model resources | Clear/remove output | Retain surviving native target settings |

If both saved and active source differed when mined, retain both for recovery, clearly marking the formerly active snapshot. Neither executes automatically when replaced. Editor drafts live in bounded per-player recovery storage and are not silently embedded as the computer's committed source. Source code can itself contain user literals; blueprint UI must make source inclusion clear, while state and KV data remain excluded by contract.

## API observations

- `computer.getID()` and peripheral/device names survive ordinary saves, not physical replacement or cloning.
- `peripheral.describe()` can still describe an unpowered reachable endpoint. Active services fail E_UNPOWERED; metadata getLimits remains available.
- A lost wire invalidates the bound wrapper/channel even if the same physical peripheral is accessible on a different color. The program must explicitly rebind.
- Force or surface changes revoke old authority before guest effects. Foreign/allied forces are not implicitly authorized.
- Mine/destroy events never require a player callback to complete safety cleanup. A malicious stopped program cannot prevent host cleanup.
- No `on_load` player event exists. Executable reconstruction is synchronized host work with no startup replay.
- A device restored from a data-bearing item can contain expired KV keys logically; first access observes their original deadlines, not fresh durations.

## Persistence cases to exercise

1. Run source that stores a state marker and a timer, then cold-save/reload before the deadline; inspect unchanged identities/state and once-only delivery.
2. Save different source without applying, mine and replace; verify both recoverable source snapshots, retained state and stopped status.
3. Fill a database to its accepted content limit, mine it, advance simulation time, replace it and inspect exact retained/expired values. Include snapshot metadata in capacity tests.
4. Blueprint and clone a running setup; verify no copied state/KV/timers/output owner and no automatic factory changes.
5. Remove/rotate/revive every composite direction through player and robot paths. Verify one item, no orphan ports, no duplicated wire endpoints and no stale handle controlling a replacement.
6. Load the exact archive with base alone and with Space Age; verify quality-aware values and zero references to absent expansion prototypes.

These are required execution cases. The contract itself is not evidence that a headless, client or multiplayer lifecycle test ran; consult the artifact-bound acceptance receipts for actual modes, phases and limitations.
