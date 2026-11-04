# API reconciliation

The former Markdown API companion has been reconciled into the canonical public
Lua declaration library by `typed-lua-api-documentation`. No new guest behavior
or completion of this change's remaining acceptance is claimed here. Its
behavioral deltas and task/evidence state remain authoritative for implementation.
Do not recreate or sync a `lua-api.md` companion.

| Former section | Canonical destinations |
| --- | --- |
| Stable public surface | `api/computer.d.lua`, `api/logic-handler.d.lua`, `api/peripheral.d.lua` |
| Availability by peripheral family | `api/common.d.lua`, every family declaration, `api/modem.d.lua`, `api/speaker.d.lua` |
| Signal observation and event compatibility | `api/logic-handler.d.lua`, `api/events.d.lua` (`TC.SignalChanged`), `api/generated/limits.d.lua` |
| Computer and Console lifecycle | `api/computer.d.lua`, `api/common.d.lua`, `api/events.d.lua`, `docs/player/console.md` |
| Dispatch and errors | `api/common.d.lua`, `api/computer.d.lua`, `api/speaker.d.lua` |

The preserved decisions include electricity-free custom devices versus native
radar/speaker availability, fresh description metadata rather than stored
authority, registration-driven observation, red/green selection, distinct sample
and dispatch times, physical-recovery/legacy resync but no electrical resync,
inert legacy power-restored registration, preserved accepted historical events,
aligned timers, FIFO/fair dispatch and unchanged refusal/cancellation semantics.
The typed files supply the complete contracts; this inventory is not a second
signature or type catalogue.

## Contract verification still belongs to this change

Exercise the exact unchanged methods through saved handlers and Console where supported, not internal host calls alone. Cover every custom family without electrical infrastructure, unchanged native outages and restoration, metadata-to-call races, queued timer cancellation, same-input fan-out with different filters/colors, native one-tick pulses, no-subscriber populations, local read-only inspection, cold upgrade/reload and late joining. Verify source/state/wires/model/queue/credit preservation and no callbacks, output writes, audio or radio replay during load. Update the canonical typed declarations and regenerate both references when implementing; do not restore the prior electrical contract or Markdown companion.
