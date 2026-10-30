# Moving, copying and preserving data

Mine or rotate the whole body, not an owned role port. Mining produces one logical
item; helpers have no drops. Rotation retains identity and role wires. Destruction
is data loss, not an alternative to mining. Back up saves before upgrades or repair.

All nine custom families work without electricity. Native radar/speaker power is
separate and still checked when used. Targeted lifecycle events wake repair;
silent geometry/scope changes use staggered observations within the existing
60-tick topology envelope. Calls reject invalid bindings immediately rather than
trusting an earlier observation. Settled clone/undo work does not keep polling,
and ordinary load preserves pending maintenance without restarting programs.

## Upgrading from alpha 0.1.1

Back up the entire save and old mod ZIP before upgrading. The redesigned devices
use new circuit-capable shells without changing public Lua v1, logical IDs or
recipe/item names. During the mod configuration change, existing bodies are
converted only after replacement shells, required sockets and every role/color wire have
been staged. Data, absolute KV deadlines, live monitor contents, active runs and
unsaved recovery drafts are retained; conversion does not run startup again.
Existing editor sessions must be reopened against the new physical body.

Computer items are plain hardware, including old tagged items: ordinary placement
is blank and stopped with a new identity. KV contents/deadlines and monitor tile
settings retain their existing item policy. Old blueprints still restore saved
source/settings and native wires, not application state or database contents.
No extra socket items are required.

If conversion is refused, the old device/data/wires remain and an upgrade
refusal diagnostic is logged. Keep the backup and report the error; do not mine,
delete or reset retained data to force conversion. After the underlying cause is
repaired, conversion can be retried by a synchronized host action or a subsequent
mod configuration change. Rollback means restoring the complete backup with the
old mod, not loading an upgraded save in the old version.

## What survives?

| Transition | Computer | KV database | Monitor | Logic output / factory settings |
| --- | --- | --- | --- | --- |
| Save/load | Saved + active source, state, identity, timers/registrations/queue preserved; no startup replay | Contents and absolute deadlines preserved | Complete model/settings/identity preserved | Valid bank/owner preserved; native target settings preserved |
| Save edited source | Saved revision changes; active run/state unchanged | Unchanged | Unchanged | Unchanged |
| Run/Apply | New generation; state survives; old work canceled | Unchanged | Image remains | Old run's still-owned bank clears; target settings remain |
| Stop/fault | Source/state/logs remain; run work canceled | Unchanged | Image remains | Still-owned bank clears; target settings remain |
| Custom-device electrical cycling | Continue; no pause, cancellation or electrical resync | Deadlines continue with simulation | Retained image/model | Still-owned bank retained; target settings remain |
| Lost/invalid physical binding | Active calls refuse; existing non-power invalidation cleanup applies | Retain contents/deadlines | Hide unavailable presentation, retain model | Fail-safe current-owner cleanup; surviving target settings remain |
| Native radar/speaker electrical loss | Native operations/receiver eligibility refuse; channels remain, no missed-traffic/audio replay | Unchanged | Unchanged | Custom output unchanged; native behavior retained |
| Mine/re-place | Plain hardware: new blank stopped identity, empty state/source and no label | Tagged contents/deadlines; new identity | Tile settings retained, new blank grouping | New logic bank zero/unowned; surviving targets unchanged |
| Native undo of removal | Pre-removal saved source/label/state and different formerly active recovery source; new stopped identity, no run work | Existing item policy | Existing item policy | Old output ownership and earlier factory effects are not restored |
| Blueprint / clone | Saved source/label, new stopped identity, empty state/work | Empty | Applicable settings, new blank model | Zero/unowned; configurator retains no old target list |
| Destruction | That device's committed data destroyed; old player drafts remain recoverable | That physical database's data destroyed | Regroup/remove display | Remove/clear bank; surviving targets unchanged |

Computer and KV items retain their existing single-item stack size; monitors retain
50-item stacks. Computer items carry no computer source, label or application
state. **Ordinary pickup and replacement loses the removed computer's contents.**
Use source-only blueprints/clipboard copies for reusable programs, or native undo
for a qualifying removal. Unsaved per-player drafts remain separately recoverable,
tied to their old identities; a new body never silently adopts an old draft.

KV whole-key expiry uses absolute simulation ticks even while the tagged item is
carried. Replacing it never renews TTL. Only the actual consumed material item
carries contents: a blueprint, ghost tag or clone does not duplicate the database.
Unknown/malformed KV or monitor item formats refuse placement and refund the original material
item rather than silently creating an empty device. Unsupported retained formats
remain inert/guarded for recovery, not truncated or reset. Do not manually delete
retained data to bypass this protection.

Monitor material items retain scale, palette, text/background colors and blink,
not an obsolete merged image or cursor. Ordinary save/load, unlike mining, keeps
the complete display model. See [monitor identities](api/monitor.md#geometry-identity-and-power).

## Dashboard items and configuration copies

Dashboard mining produces one tagged item retaining the accepted layout, rolling
sample order and latest duration-bar dataset, including metadata at full admitted
capacity. Replacement has a new identity and no old subscriptions, viewers or
render resources. Blueprints/clones copy definitions with empty charts; settings
copy onto an existing Dashboard preserves only its own compatible chart history,
never the source's samples. Invalid snapshots refuse placement without truncation
or a silently empty replacement.

Removing `factorio-charts` preserves those contents and item restoration; base
labels/buttons still work and chart regions show unavailable. Reinstalling it
restores chart presentation without replaying producer startup. This is **not** a
promise that downgrading the main mod to a version without Dashboard prototypes
preserves the device: restore the complete backup and matching archive instead.
See [Dashboard windows](dashboard.md).

## Undo and redo

Ctrl+Z of an eligible player removal, or a completed player-marked robot removal,
restores a native ghost. Supply a computer item or let a robot construct it. Saved
source, label and explicit state come from immediately before removal, even if
edited after the deconstruction mark. The restored computer is **stopped with a
new identity**: no startup, timers, callbacks, subscriptions, Console session or
old output ownership resumes. If saved/active source differed, Maintenance can
review/copy the formerly active source into a draft without executing it.

Undoing a mark before removal only cancels the order; it does not reset or stop
the live computer. Repeated native undo/redo and cold saves retain the applicable
snapshot while its native history or original ghost remains valid. Copying a
restoration ghost still copies only saved source/label, not state or undo authority.
History expiry, discarded history and cancelled ghosts are **not permanent backup**.
Old native history created without a snapshot cannot retroactively recover data.
Refusal preserves the snapshot in valid history/ghost and reports failure instead
of publishing a blank successful restoration; do not delete that recovery ghost.
If even the recovery ghost cannot be allocated, the exact inert, non-mineable body
retains the payload for host repair. Keep that body, save and diagnostic.

## Compatibility break and rollback

Old `tc_computer` item contents are ignored on use, whether valid, malformed or
unsupported. There is **no legacy item import or item-data recovery**. Upgrade does
not clear placed-computer records, active programs, private drafts, KV contents or
monitor models/settings. Back up the complete save and matching old mod archive
before updating. Restore both to roll back; downgrading the mod alone cannot
recover discarded item contents or contents lost by newly mining/replacing a
computer normally.

## Marking a monitor for removal

Use the deconstruction planner on the visible monitor body. Marking/cancelling
keeps the current cells, cursor, palette, scale and merged identity; it does not
reset the display. Only actual robot mining/removal changes topology and invokes
normal split/resize rules. You can cancel one tile before removal without losing
the image. Electrical cycling has no effect on custom monitor presentation.

The renderer puts content below native world feedback rather than drawing a
custom removal symbol. Native red-X visibility while the display changes is
still a user-owned graphical check for this alpha; headless state tests alone do
not establish it. See the [integrated playtest](editor.md#integrated-redesign-playtest).

## Blueprint disclosure and copies

Blueprints include saved source and labels, which may contain private literals.
The blueprint description discloses source inclusion. Inspect/remove source before
sharing. State, KV contents, active source/run, subscriptions, outputs and managed
target IDs are not embedded.

Network blueprint wires attach directly to the device. Owned auxiliary socket ghosts preserve their separate role wires through rotated native revival. Building
the body adopts/revives its exact helpers without consuming extra device items.
Hidden port tokens are not craftable supplies; never build ports independently.
Unowned helper remnants are removed instead of becoming usable peripherals.

Settings copy stops the destination computer, copies saved source/label and advances
its revision, but **retains the destination's existing state**. It does not copy
the source computer's runtime/state. Monitor settings copy changes that selected
group. KV data and old configurator target settings are not copied by a peripheral
settings operation. Clones, unlike settings copy, start with empty computer state.

Force changes/merges revoke old authority and stop affected computers without
clearing data. Surface deletion/clearing retires that surface's devices and helpers.
Cross-surface cloning is a fresh identity, not a same-ID teleport guarantee. IDs
never silently retarget a newly placed body at the same coordinates.

Applied configurator settings are native factory settings. Stop, disconnection or
configurator removal does not undo them; player edits win until another explicit
program write. For safety, configure target machines to stop on absent output
where appropriate; signal cleanup is not a factory-wide rollback.
