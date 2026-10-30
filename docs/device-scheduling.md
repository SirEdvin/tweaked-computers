# Device scheduling: production hook audit

This is the source disposition map for `demand-driven-device-scheduling`, not a
CPU/FPS result or a replacement for its native acceptance ledger. The editable
[tick-cycle drawing](../openspec/changes/demand-driven-device-scheduling/tick-cycle.excalidraw)
and [preview](../openspec/changes/demand-driven-device-scheduling/tick-cycle.png)
show the same ordering. `control.lua` has one ordinary `on_tick` entry point.
Trusted hooks are registered at control parsing; production has no `on_load`
handler and does not rebuild authoritative membership there.

## Actual tick order

The existing scheduler validates the retained clock/admission headers, attaches
same-tick maintenance accounting without renewing spent credits, and rejects a
repeat call at the same tick. Within each phase, hook names are sorted. After
lifecycle, sampling and notifications, only due timer owners and the frozen ready
round are visited. Render hooks run last, using the existing render reservation.
A new event cannot re-enter dispatch: newly ready computers join a later round.

| Production hook | Live demand / due reason | Retirement / idle behavior |
| --- | --- | --- |
| `lifecycle/00-physical-observation` | Exact custom device deadline; event-targeted repair or staggered non-power observation within the existing topology envelope | Reschedule the same identity; refused work keeps its original due age. No native power sweep. |
| `lifecycle/01-clone-components` | Existing pending cloned sockets | Adopt or destroy the pending exact socket. Related owner lookup is allowed only while actual clone work exists. |
| `lifecycle/01-network-output-authority` | Indexed current output owners, including an empty owned bank | Last-writer cleanup/replacement/retirement removes the exact membership. Proof refusal still clears the old owner's output. |
| `lifecycle/02-computer-undo` | Pending native history settlement or candidate-clear work | Clear the flag when settled; retained history alone does not create tick work. |
| `lifecycle/02-monitor-groups` | Dirty topology, incomplete grouping/partition/retirement | Settled groups sleep; actual regrouping can enumerate affected membership. |
| `lifecycle/02-native-radar-adoption` | Pending computer-rooted native discovery | Complete/refuse/retire that computer/color request; dormant carriers do not seed a world walk. |
| `sample/logic-input` | Ordered reverse subscriptions and watched physical input/color membership | Last unsubscribe or exact run/endpoint retirement removes demand. Direct watched reads remain every tick; no change-hint skip or slower sampling. |
| `notifications/monitor-events` | Indexed registered recipients and pending touches/resizes | Deliver/cancel the pending job; settled displays are not searched for recipients. |
| `notifications/peripheral-topology` | Interested computer/color bindings and unfinished transition jobs | Last interest/finished explicit observation retires the binding. Existing three-channel envelope and live call proofs remain. |
| `render/device-status-art` | Dirty exact identity or next running-computer 10-tick animation transition | Static art has no recurring visit. Stop/fault/retirement removes animation demand. |
| `render/kv-reclamation` | Earliest retained expiry or unfinished due cleanup | Cancel/replace/mine updates the exact deadline; future or persistent-only databases sleep. Lazy logical expiry remains exact. |
| `render/monitor-world` | Existing pending presentation capture/prepare/whole-group commit/retirement | Retain the previous complete image until paid publication; native cursor blink needs no polling. |
| `render/program-editor` | Open exact editor/recovery session on its existing 15-tick deadline | Close/leave/replacement retires the session's deadline, not its drafts. No connected-player discovery. |
| `render/ui-dashboard` | Open authorized viewers; changed definitions/tab/size/availability and indexed selected-tab charts | Stable definitions are not traversed. Hidden/closed charts retire presentation; viewers/charts retain rotating fairness. |
| `render/ui-peripheral-inspectors` | Open exact inspector session on its existing 15-tick deadline | Closing removes only that session's work; local reads create no guest signal watcher or writer. |

Timers reuse the existing indexed next-deadline heap and ready computers reuse
the existing generation-aware ready ring. Service/UI deadlines use the same heap
operations in fixed host lanes, not a second runtime. Empty lane/header checks
are constant bookkeeping; they do not inspect entities or players.

## Deliberately retained non-ordinary walks

- Init/configuration migration inventories supported saved registries once to
  initialize absent memberships. Unsupported versions stay inert/recoverable.
- Explicit player/guest discovery, real topology regrouping and actual pending
  clone/undo settlement may inspect their necessary inputs under existing bounds.
- Force/surface removal, exact identity cleanup and fail-closed corruption handling
  may walk affected records. They are event/error paths, not work discovery on
  healthy ordinary ticks.
- Open Dashboard viewers are themselves live demand. Six tab identity checks and
  selected visible-chart references avoid rediscovering widgets in unchanged
  definitions. Live viewer authority never becomes a cached permission.
- Native radar/speaker simulation belongs to Factorio. The mod checks native
  electrical availability at real metadata/method/receiver eligibility use only.

## Verification boundaries

`tests.scheduling_contract` and `tests.scheduling_engine` enforce no idle
runtime/signal/UI discovery, deadline fairness, cancellation and cold ownership.
The benchmark structure lane labels actual ready/due/watched/owner/UI visits
separately from the old broad-loop counters and native signal reads. Necessary
physical due observations are a separate counter, not hidden as idle discovery.
Baseline and candidate use the same workload/guest fixture; changed test payloads
are explicitly allowlisted and hashed. Timing/profile/structure receipts are not
pooled, and the downstream matched-timing row remains separate.

Native selection/copy/scroll, audio and connected peers require their own actual
client evidence. A mocked GUI, passing package create or useful-work counter is
not a visual, audible, late-join or representative hardware-performance pass.
