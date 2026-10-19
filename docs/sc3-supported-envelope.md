# SC3 supported-envelope gate: failed, not frozen

Status on 2026-10-19: native-computer row 7.1 and buffered-presentation row 6.2
remain **unchecked**. No production code, quota, reservation or 256-tick render
target was changed. This is a reproducible failed-gate checkpoint, not a release
receipt, stable envelope, performance improvement or manual client approval.

## Source and evidence reconciliation

The SC3 branch consumes SC2 `3a50d79f3a21b47b66f9d030e1e98f5e388cd4ea`,
including SC1 `28fcb19` and accepted main
`4fe09733d5a30fa5bbf4ad08af71ae9fa60bc941`. SC2's exact archive is retained at:

`/home/siredvin/artifacts/tweaked-computers/t_febbc243/final/evidence/package-acceptance/tweaked-computers_0.1.9.zip`

SHA-256: `d68f0b5ade10d0deea65cee92f448e43f6d55635aa7cb247a1414bfd482f9843`.
Its production inventory digest is
`b4fe00db6d567600f3b4315a8dc03f35aeca0d090597f68e0071f2b9e91bedaa`;
normal-runtime digest is
`9d7983ad636e4a2fcce01758ac776591ad0fdf7a691dd596cacf18f50c5d09ce`.
See the exact inventory definitions in SC2's `payload-equivalence.json`.

SC1/SC2 structural, cold, GUI and connected-player receipts remain applicable to
those unchanged production bytes. They do not establish this combined envelope.
The existing presentation fixture fills 256 tiles, but does not combine 64
running computers and the subscription maximum. TC13's integrated factory uses
six computers and a 260-cell display, not the simultaneous maximum.

The old performance report measures a star-marker workload; the retained 0.1.7
matched report measures its particular connected-chart source/observer. Neither
is a matched baseline for this new maximum-world fixture. SC2's recorded client
CPU includes observation/recording/software rendering. No historical timing is
silently promoted to a current head-to-head result.

Durable SC3 evidence is under
`/home/siredvin/artifacts/tweaked-computers/t_a3385898/`.
`diagnostic-06/summary.json` binds the final diagnostic to the exact parent archive,
fixture hashes, command, per-mode gates and counted scheduler samples. Its test
ZIP SHA-256 is
`6811267bee9751d54d956ec9634319c1ce808c9c77406d0ff71b3c36b618692a`.
`receipt.json` records final source/package correspondence and the per-row status.
Earlier attempts are preserved separately, not overwritten by the final run.

## Reproduction and workload

From the repository root, with a fresh output path outside git:

```sh
python tools/test_envelope.py
python tools/envelope.py \
  --factorio /home/siredvin/tools/factorio/bin/x64/factorio \
  --archive /absolute/path/to/the/SC2/tweaked-computers_0.1.9.zip \
  --output "$TMPDIR/sc3-fresh-diagnostic" --mode both
```

An exit of 1 is expected for the retained candidate: the smoke driver completes
normally, but at least one acceptance diagnostic fails. `diagnostic_completed`
is separate from `envelope_passed`. Three receipt-parser regressions preserve
false gates, reject missing/duplicate completion and count CPU phases separately.

The wrapper copies the supplied archive, replaces only the opt-in animation
fixture entry with `tests.envelope_engine`, and inserts that test module. It
checks every other existing payload remains byte-identical. It never changes
production scheduler, sampler, renderer, example source or budgets. Isolated
Factorio 2.0.77 build 84539 headless base and Space Age servers bind localhost,
with public/LAN visibility disabled. Both `--version` and `--help` were inspected.

The real production registry contains 448 devices: 64 computers, 128 logic
handlers and 256 monitor tiles. Six 6×6 walls, 3×6 and 6×3 walls and four
singletons form 12 actual logical displays. All use scale 0.5: 74,918 actual cells,
not a claimed reachable 80,000-cell maximum. All devices are refuelled by the
fixture before each measured tick; stable power is intentional. Each computer
has a short real red NETWORK wire to a logic handler. Each of those 64 handlers
has a separate real red INPUT circuit carrying normal-quality signal-A=1; native
readback asserts every input before the cold boundary. The other 64 handlers are
placed but not subscribed: claiming 128 actively sampled handlers would be false.

Stage one fills every display through trusted model methods. Stage two writes a
full first row on every display each tick for 64 ticks, then stops and waits for
complete presentation and retirement. These host writers isolate the renderer;
they are explicitly **not** compiled guest throughput or full-screen continuous
dense guest producers. No selected-cohort stress acceptance is claimed here.

After a separate-process ordinary cold reload, one real saved/activated program
is admitted per tick. Start installs a recurring timer. Each admitted work
callback adds at most one real subscription, up to 16 per computer, then computes
sum(1..128) and saves 8256. The desired aggregate is 64 running useful computers
and 1,024 subscriptions; the program is deliberately small so failure below that
envelope is not confused with maximum-source compilation. Subscription input is
red, initial=false; there is no fabricated subscription graph or refreshed ledger.

## Counted results

Final diagnostic-06 has two successful map creations and four clean cold server
phases. Every server phase exits zero after acknowledged console `/quit`, with
no signal fallback or forced kill. Both modes verify the retained presentation
identity and spent maintenance ledger before resumed dispatch. Diagnostic
completion markers are not acceptance success markers.

| Gate | Base | Space Age | Boundary |
| --- | --- | --- | --- |
| Initial 74,918-cell presentation and complete cleanup | 86 ticks | 86 ticks | Renderer-only 256-tick subgate passes |
| Final quiescence after 64 continuous row-writer ticks | 9 ticks | 9 ticks | Renderer-only 256-tick subgate passes |
| Combined useful computers/subscriptions | Fails diagnostic service window | Run faults E_BUSY | Full envelope does not pass |

Base has 64 running programs and 64 timers after the 256-tick subscription-stage
window, but only 19 subscriptions and three computers with the useful work
result. This window is a diagnostic stopping condition, **not** a newly invented
normative callback deadline or proof of permanent starvation. In particular,
rotating a cursor across the full device registry can have a longer horizon.
It does not prove fair maximum-world service.

Space Age fails after three activations with one retained subscription before
the failing tick: `E_BUSY`, `logic sampling envelope exhausted; run stopped rather
than losing observations`. A fault cleans up its registration; do not interpret
the post-tick inventory as the number admitted before the refusal.

Every measured tick asserts maintenance ≤200,000, guest aggregate ≤4,800,000,
front/pending cells ≤80,000, staging/retired cells ≤10,584 and frame counts ≤256.
These are counter checks, not complete native-operation instrumentation or
continuous native-object residency/ownership auditing. Those remaining full-row
requirements are not closed by this diagnostic.

Whole-scheduler profiles exclude construction, fixture refuelling, host writes,
assertions and logging from the timed call, but those allocations can influence
later GC. Base initial-grid/continuous means are 31.56/25.70 ms (86/64 samples);
Space Age means are 30.42/26.15 ms (86/64 samples). Base subscription-stage mean
is 22.06 ms over 257 samples, p95 73.58 ms, max 187.62 ms. Full phase statistics
and raw samples remain in the receipt/logs. These are unfavorable diagnostics,
not a hardware-independent CPU bound, FPS measurement or matched speedup claim.
Timings were serial, with no client or recording running; sampled shared-host
load was below one on four exposed CPUs. Quiet load is not exclusive host access.

## Root cause and decision boundary

`logic.sample` reserves `subscriptions² + sampled_devices² + 1` before sorting.
At the declared 1,024-subscription/128-handler capacities this is 1,064,961 units:
that atomic reservation alone exceeds the entire unchanged 200,000-unit ledger,
before physical validation, sampling, notifications, timers or rendering.
Therefore the current sampler cannot service that simultaneous declared maximum.
This is a source-derived necessary-condition failure, not an exhaustive claim
that no implementation can meet the requirements.

Each selected-input native read also prepays the prototype/quality universe.
Actual engine readback gives 1,320 identities / 11,600 units in base and 7,272 /
59,216 units in Space Age. In the failed Space Age tick, physical maintenance
has spent 77,577 before sampling. The sampler's fixed inventory admission and
other paid work leave too little non-render headroom for even that one read.
The final log records a 60,000 render reservation; renderer-only quiescence does
not make non-render service free. Timer advancement separately prepays 64² even
for a computer with one timer. These interactions need review together, not a
larger render reservation or a hidden quota waiver.

No safety check was removed and no opaque native cost estimate was lowered to
make this pass. Fixing only the sort reservation cannot certify the full sampled
world. The decision requested is whether to proceed with a bounded maintenance /
sampler redesign preserving every-tick observations and all existing shared
ceilings, or explicitly review a smaller composite admission envelope before
freezing limits. Neither reduced sampling frequency nor reduced advertised
capacity is assumed approved. Both owned rows stay open until that decision and
a successful complete campaign; final consolidation must not promote this
checkpoint as an accepted candidate.

Still unmeasured here: simultaneous maximum useful source, maximum discovery and
target witnesses, KV payloads, active 128-handler sampling, selected-cohort stress,
complete per-tick native-operation/residency audits, matched CPU/ready-to-visible
baseline, cold compile/activation latency and actual client input-to-visible
latency. SC2's visual/connected results remain separately scoped evidence; no
new screenshots, videos or player data were needed to expose this failed gate.

The rejected first attempt had an over-distance test wire; a second batched 16
subscriptions in one callback and hit Space Age callback credits; the next
incremental version reached its fixture deadline without completing the intended
ramp. These are preserved as setup/refusal/deadline attempts, not passed gates.
Later diagnostic windows stop normally and report failure as data rather than
crashing the workload. No merge, release, version bump or archival was performed.
