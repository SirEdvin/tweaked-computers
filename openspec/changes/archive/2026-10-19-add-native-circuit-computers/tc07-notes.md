# TC07 implementation and scoped acceptance

Owned tasks: 2.6, 2.7, 2.8. Logic handler API v1 is implemented; the mixed
2.8 native-client acceptance row remains open under the user's explicit deferral.

## Ancestry and integration

Ordinarily merged TC05 `3e987008fe15f5989f42135eb23fadfa39911567` and TC06
`49c922302be5080b1cfd6e314f4b6bd8abc2640d`; both merge-base ancestry checks pass.
The merge commit is `7a04f2b`. Both parents' control registrations and completed
checklist rows were preserved. No primary checkout, sibling branch, public release,
PR merge or OpenSpec archive was modified.

Implementation homes: scripts/services/logic.lua and the fixed host-only
scripts/ui/network-inspector.lua adapter, parsing-time control imports/registration,
the narrowly adjusted scheduler sample-phase entry, in-editor/localized help,
docs/logic-handler.md, examples/logic-controller.lua and tests/logic_engine.lua.

All nine logic methods are bound through the production peripheral service bridge,
not a test-only API. Read/write identities validate native prototypes/qualities,
normalize normal quality, sort complete identities and preserve signed32 semantics.
One inactive staged manual section is read back before bank publication; ownership
records exact computer/run/channel plus physical witness. Failed validation or
admission does not transfer ownership. Host failure attempts restoration and retains
an explicit bank/owner recovery record if restoration itself fails, clearing output.

The production sample phase uses the existing shared maintenance ledger and once-
per-real-tick scheduler. Named registrations retain copied filters/current admitted
baselines. Initial/current/delta/connectivity and outage resync delivery are explicit;
queue admission, not callback dispatch, advances the baseline. Source-independent
physical/network/registry cleanup preserves newer writers. Unsupported or exhausted
sampling never masquerades as unchanged successful history: affected runs fault
visibly with owned-output cleanup. Sampler entry must execute its own refusal path,
even if earlier maintenance spent the ledger; other phase ordering/entry charges
remain intact.

## Exact engine evidence

Engine: official headless Factorio 2.0.77. Archive:
`/home/siredvin/.hermes/profiles/albina/cache/scratch/tc07-artifacts-final/tweaked-computers_0.1.0.zip`
SHA-256: `207d08727e570f91084a5f6c33ba38ce9da070ba98cbc1d81ac9fcd4d570842d`.
Deterministic 60-file package includes original verified parser/license resources.

Commands:

    python3 tools/build.py --output "$TMPDIR/tc07-artifacts-final"
    python3 tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio \
      --archive "$TMPDIR/tc07-artifacts-final/tweaked-computers_0.1.0.zip" \
      --output "$TMPDIR/tc07-smoke-final" --fixture tests.logic_engine --cold

Fresh map creation passes both modes. Combined unique contract inventory across
create/first/second phases is counted with jq: 17 groups base, 18 Space Age (one
additional real-quality identity group). Group inventories live beside the logs.
Four cold phases all exit 0 after acknowledged console /quit, with no signal attempt
or forced kill. Both first processes freeze every fixture participant until the
snapshot ZIP is readable; second-process on_load and first resumed callback check
state/run/source/subscription/queue/bank/owner aliases, body unit identity and spent
per-machine work/compile/allocation, aggregate and maintenance counters before
resumed work. Startup remains once-only. No functions or GUI/player mock are saved.
Servers bind localhost and disable public/LAN visibility.

Contracts cover native output sections/duplicate and malformed write refusal,
negative int32/output copies, exact newer-writer retirement, complete/admitted
production inspector colors/copies/refusal, native red/green/both wrapping,
mirrored propagation, expansion normal/uncommon separation, filtered initial
baseline advancement/unchanged suppression/unsubscribe cancellation, authentic
editor text/Save/Run handlers, real red computer->KV NETWORK relay->logic chain,
powered inserter transfer, cold threshold response and 90-tick cessation, computer
and handler outage resync, native disappearance zero/connectivity-only events,
source-independent fault/cable cleanup, full queue overflow and exhausted sampling
admission fail-closed behavior. The queue/maintenance pressure and direct power
transition checks are labelled isolated host boundary contracts, not latency gates.

Affected parent regressions ran once in base with the same production/docs bytes:
45 computer/compiler/sandbox groups (including malicious source and healthy peer),
12 editor groups and 12 discovery groups. Evidence:
`$TMPDIR/tc07-regression-computer_contract`,
`$TMPDIR/tc07-regression-editor_contract`,
`$TMPDIR/tc07-regression-network_engine`.
Their archive was the preceding checkpoint; the final ZIP changes only the logic
fixture's additional explicit per-machine cold-counter assertions. Verify ZIP entry
bytes when reusing that evidence. No unrelated performance/client matrix ran.

Earlier failed runs are retained in tc07-smoke-first through ninth: native filters
readback does not include an index (and item SignalID type can be nil), unconnected
output has no red network to read, the test inserter condition must use the native
flat shape, and squared Lua table length requires parentheses. These failures were
fixed without altering shared quotas, inventing results or raising fixture deadlines.

## Deferred acceptance and remaining tuning

Actual client typing/paste/focus, graphical wire/GUI usability and multiplayer join
remain user-owned. Editor delivery above is table-backed GUI/player events through
production handlers, not native client evidence. No graphical client, screenshot,
desktop automation or multiplayer join was run.

Development limits remain provisional: 64 signal slots/filters, shared existing
subscription/owned-bank caps. Factorio 2.0.77 offers no native signal-count query,
so opaque array materialization is precharged against the immutable prototype ×
quality universe before checking accepted snapshot capacity. Copy weights and
notification envelope are not real-time CPU guarantees; heavy modded universes or
oversubscribed worlds may visibly refuse/fault rather than lose history silently.
The existing TC13 integrated envelope gate owns final tuning, not this feature card.

TC12 is the inspected pre-created child, merging logic/KV/monitor/configurator and
finishing source/data snapshots, cloning/blueprints/mining and full lifecycle.
Preserve empty output/no owner on new/clone records. Current computer/KV mining
safety guard remains, pending TC12; no destructive plain mining was added.
Public documentation/OpenWiki/alpha publication stay in TC15/TC16/TC17, not this
partial milestone. Merge this branch normally and retain all sibling control imports.

Hotspots: control.lua (logic import + fixed inspector registration),
scripts/scheduler.lua (sampler-owned fail-closed admission), scripts/ui/help.lua
(additive logic help). Do not wholesale replace any shared registration file.
