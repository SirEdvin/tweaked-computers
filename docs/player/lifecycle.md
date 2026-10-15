# Moving, copying and preserving data

Mine or rotate the whole body, not an owned role port. Mining produces one logical
item; helpers have no drops. Rotation retains identity and role wires. Destruction
is data loss, not an alternative to mining. Back up saves before upgrades or repair.

## Upgrading from alpha 0.1.1

Back up the entire save and old mod ZIP before upgrading. The redesigned devices
use new circuit-capable shells without changing public Lua v1, logical IDs or
recipe/item names. During the mod configuration change, existing bodies are
converted only after replacement power, sockets and every role/color wire have
been staged. Data, absolute KV deadlines, live monitor contents, active runs and
unsaved recovery drafts are retained; conversion does not run startup again.
Existing editor sessions must be reopened against the new physical body.

Old tagged material items still restore their committed data into a fresh stopped
identity. Old blueprints still restore saved source/settings and native wires,
not application state or database contents. No extra socket items are required.

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
| Computer outage | Pause; keep state/registrations/timers; discard transient history and resync on restoration | Deadlines continue with simulation | Retained | Owned output clears; target settings remain |
| Peripheral outage | Active services refuse | Retain data/deadlines | Hide presentation, keep model | Handler bank clears; target settings remain |
| Mine/re-place | Tagged source/state; new stopped identity, no run/timers/subscriptions | Tagged contents/deadlines; new identity | Tile settings retained, new blank grouping | New logic bank zero/unowned; surviving targets unchanged |
| Blueprint / clone | Saved source/label, new stopped identity, empty state/work | Empty | Applicable settings, new blank model | Zero/unowned; configurator retains no old target list |
| Destruction | That device's committed data destroyed; old player drafts remain recoverable | That physical database's data destroyed | Regroup/remove display | Remove/clear bank; surviving targets unchanged |

Computer/KV/monitor items stack singly with tags. A computer item retains both saved
and formerly active source if different, label and copied explicit state. It does
not carry active execution. The editor can review/copy formerly active source into
a draft. Unsaved per-player drafts live separately, tied to their old identities.

KV whole-key expiry uses absolute simulation ticks even while the tagged item is
carried. Replacing it never renews TTL. Only the actual consumed material item
carries contents: a blueprint, ghost tag or clone does not duplicate the database.
Unknown/malformed item formats refuse placement and refund the original material
item rather than silently creating an empty device. Unsupported retained formats
remain inert/guarded for recovery, not truncated or reset. Do not manually delete
retained data to bypass this protection.

Monitor material items retain scale, palette, text/background colors and blink,
not an obsolete merged image or cursor. Ordinary save/load, unlike mining, keeps
the complete display model. See [monitor identities](api/monitor.md#geometry-identity-and-power).

## Marking a monitor for removal

Use the deconstruction planner on the visible monitor body. Marking/cancelling
keeps the current cells, cursor, palette, scale and merged identity; it does not
reset the display. Only actual robot mining/removal changes topology and invokes
normal split/resize rules. You can cancel one tile before removal without losing
the image. Power restoration reveals retained content, not a newly blank model.

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
