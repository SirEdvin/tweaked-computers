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

## Mixed old-save and connected-peer fixtures

`tools/scheduling_upgrade.py` consumes the exact candidate ZIP and a SHA-256-pinned
function-capable pre-scheduler **source-built 0.1.17** archive. That comparison
archive is not a public release. The tool replaces only the existing opt-in
`tests/monitor_upgrade_engine.lua` test hook with the candidate's packaged
`tests/scheduling_upgrade_engine.lua`; it checks every other archive member.
When both supplied mod versions are equal, the existing version helper makes a
private metadata-only patch advance. An already newer candidate is used without
version rewriting. No supplied archive or original rollback save is overwritten.

```sh
python3 tools/scheduling_upgrade.py --factorio "$FACTORIO" \
  --baseline "$PRE_SCHEDULER" --baseline-sha256 "$BASELINE_SHA256" \
  --archive "$ARCHIVE" --output "$WORK/scheduling-upgrade"
```

Both content modes create an old-runtime scene, freeze it in a separate old
server, upgrade in a new process, then ordinarily reload in another process.
The fixture preserves all nine physical families, role wires, a genuinely paused
old run, aligned/coalesced timers, canceled queued signal delivery, a complete
1,100-signal observation, output ownership, queued Console ingress, database and
Dashboard models, and a paid partial monitor frame. It compares source, aliases,
queue order and spent credits before synchronized work. Console delivery uses
an explicitly table-backed authorized player, not a native typing claim.

`tests/scheduling_client_engine.lua` is the separate native-peer fixture. Its
external exact-package driver redirects only the existing allowlisted native
client test hook in a private ZIP. Client one reaches a real frozen queue/watch/
deadline boundary before client two starts; the synchronized player-joined event
resumes all peers. Independently evaluated server/client snapshots, actual window
captures, a second server process, exact effect counts and clean exits establish
that case. The external driver and replacement-byte proofs belong with the
receipt bundle; neither a headless create nor these source descriptions certifies
a native-client pass. Native radar and private-output speaker capture cases remain
separate from the custom-device scene and from downstream matched timings.
