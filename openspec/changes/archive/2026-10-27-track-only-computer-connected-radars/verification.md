# Radar tracking verification — 2026-10-27

Candidate: `0.1.16`, Factorio `2.1.23` (build `87750`).
Final archive SHA-256: `f7941bfcb8380222060112f1c8120d29efaf271085bb164cc96cc513340bd23d`.
Timing archive SHA-256: `25ff640d011ac86f8ab827cc7afde355128ef71611826aa295dc0d680328bc49`.
`payload-equivalence.json` verifies 532 byte-identical payloads; the only differences are the competition fixture's explicit radar power supply and its generated manifest digest. No production or idle-probe payload changed. The complete functional matrix is rerun on the final archive; the timing matrix remains explicitly attributed to its measured archive.
Baseline: immutable `0.1.15`, SHA-256 `5205daa86f7fb63db4ac522144eb500603ebbd799f6c7a09d87df259628db1ab`.

The production change separates remembered identities from recurring registry order, adopts through complete computer-rooted physical proofs, and routes through eligible receiving computers. No production budget or guest method was changed. Native Factorio simulation, retained memory and save serialization remain costs.

## Evidence and reproduction

Working receipts: `/home/siredvin/.hermes/profiles/albina/cache/scratch/tc-radar-tracking-Sd7ItO/`.
Durable evidence location is recorded in `evidence-location.txt` beside this document after preservation. Engine distributions and display credentials are excluded.
In the durable bundle, receipt directories below live under `runs/`; `package/` contains the final installable ZIP, `source/` captures the uncommitted change, and `SHA256.json` inventories the preserved files.

- `verified-contracts/`: exact-final-candidate production/cold/upgrade fixtures, command logs and verified receipts; `COMPLETE.json` is required, not an inferred pass from partially written smoke summaries.
- `idle-verified.json`: checked inventory of 64 paired cases, 256 count windows and 153,600 measured samples.
- `idle-matrix/`: completed base cases; the outer foreground tool timed out after them during Space Age. The partial Space Age attempt is excluded from acceptance.
- `idle-space-age/`: independently completed Space Age matrix, runner exit zero.
- `verified-player-docs.json`, `verified-docs-build.log`, `verified-host-tests.log`: strict MkDocs, player API/export/link checks and host checks.
- Pilot/failure evidence is retained separately, including the initial registry red test, benchmark harness unit-total mismatch and wrapper timeout. The native whole-update CSV excludes some outer benchmark overhead; conversion sanity is not a performance threshold.
- `final-contracts/competition.log` retains the failed first competition attempt: its fixture supplied power only through generic tick order, so the excluded native receiver was unpowered. The corrected fixture explicitly supplies its two radars with the same 100,000 energy it previously received from that sweep; no guest workload, deadline, admission limit or assertion was relaxed.

Run the reproducible timing matrix serially, in a fresh directory outside git:

```sh
python tools/radar_idle.py --factorio /absolute/factorio-2.1.23 \
  --baseline /absolute/tweaked-computers_0.1.15.zip \
  --archive /absolute/tweaked-computers_0.1.16.zip --output /fresh/idle-results
```

Use a tracked background job for the complete matrix. Each underlying engine run is bounded and exits normally. `--modes base` and `--modes space-age` allow independent serial batches. The preserved immutable baseline hash is enforced. All production payloads are checked unchanged except the disclosed test-only control observer insertion; the owning-mod test entry and generated configuration are the only other overrides.

Run the real older-save upgrade (not merely a candidate configuration-change test):

```sh
python tools/radar_upgrade.py --carrier radar-tracking \
  --factorio /absolute/factorio-2.1.23 --legacy-factorio /absolute/factorio-2.1.23 \
  --legacy /absolute/tweaked-computers_0.1.15.zip \
  --archive /absolute/tweaked-computers_0.1.16.zip --output /fresh/upgrade-results
```

The original 0.1.10 radar/speaker installation modes remain available. Tracking migration covers idle and connected worlds in both content modes, with 100 legacy records, preserved native bodies/channels, guest source/state, an accepted queue snapshot, spent credits, and first-tick receipts before and after a separate-process cold reload. No authoritative migration occurs in production `on_load`.

## Timing results and limits

Each case uses two benchmark save reloads, 60 warmup ticks and 300 measured ticks at each of 0, 100, 500 and 1,000 disconnected radars. Axes are base/Space Age, zero computers/fixed working network, fresh placement/actual enrollment then detachment, powered/unpowered controls, baseline/candidate, and unprofiled total-update/separate phase profiling. The fixed network executes a real periodic KV guest workload; no per-tick energy refill is used.

Mean native script-update milliseconds, zero computers, fresh unpowered radars (600 samples per cell):

| Radars | Base baseline | Base candidate | Space Age baseline | Space Age candidate |
|---:|---:|---:|---:|---:|
| 0 | 0.043 | 0.045 | 0.056 | 0.060 |
| 100 | 0.825 | 0.043 | 1.307 | 0.062 |
| 500 | 4.999 | 0.047 | 12.627 | 0.076 |
| 1,000 | 10.849 | 0.049 | 26.511 | 0.079 |

These are native `scriptUpdate` windows including the small fixture logger, not the original diagnostic's scheduler-only measurements or a measurement of the user's actual save. Full mean/median/p95/min/max distributions, native `wholeUpdate`, `Radar`, incremental Lua GC, phase profiles, hashes and host samples are retained in JSON. At 1,000 radars, the base candidate's whole-update mean was 0.169 ms versus 11.613 ms baseline; Space Age was 0.307 ms versus 29.169 ms.

All candidate profiled cases observed zero dormant identity lookups, including the first tick after actual detachment. The separate real-upgrade fixture observes the first post-upgrade and post-cold-load ticks. Candidate scheduler windows show small noisy variation, not the baseline's per-radar scan growth. Native simulation/GC and changing host contention still vary total time: measured 1-minute host load ranged from 1.166 to 8.811 (mean 3.318) on the four-CPU environment, with unrelated workloads present. No timing limit, measured FPS, connected multiplayer performance or universal speedup is claimed.

## Delta scenario coverage

`radar` means `tests.radar_engine` with its composed `tests.radar_tracking_cases`; `modem` means `tests.modem_engine`. Both run in the owning mod, base and Space Age, through cold phases. `upgrade` means the immutable-baseline tracking harness above. `idle` means the verified matrix above. The exact logs are under the evidence root.

| Delta scenario | Fixture / receipt |
|---|---|
| Attach a vanilla radar | radar: native-identity-idempotent-no-helpers-and-physical-relay |
| One physical radar on both colors | radar tracking cold reconnect; modem dual-color delivery |
| Unsupported radar-like entity | radar initial unsupported-prototype refusal |
| Placement alone does not enroll a radar | radar raised build, clone/revive cases; idle fresh placement |
| Reload with queued communication | modem frozen queue and cold-once delivery; upgrade connected case |
| Replace or clone a configured radar | radar native-clone-revive-and-mining-material-identity |
| Scope change | modem lifecycle force case; radar Console generation/authority refusal |
| Ordinary reload preserves dormancy | radar snapshot/check_dormant/reconnect; upgrade ordinary phase |
| Factory with no computers | radar_tracking_contract; idle zero-computer cases |
| Unrelated radars beside a working computer network | radar_tracking_contract; idle fixed-network cases |
| Stale saved observations do not restart polling | radar saved detached observations; upgrade first-tick exclusion |
| Native radar simulation is unchanged | radar actual powered hidden-link, scanning and native signal assertions |
| Disconnect and reconnect an enrolled radar | radar Console captured-wrapper and cold reconnect assertions |
| One of several computer paths remains | radar surviving-computer-path-and-last-root-removal-do-not-poll-dormant-component |
| Destroy a dormant radar without a raised removal event | radar targeted native destruction, duplicate/unrelated event and replacement cases |
| Dormant radar changes scope | radar adopter-only scope reconciliation; surface mismatch uses retained-scope injection because native radars cannot teleport surfaces |
| Upgrade an idle radar-heavy save | upgrade idle installation, TC_TRACKING_BEFORE_FIRST_TICK / TC_TRACKING_FIRST_TICK |
| Upgrade mixed connected and disconnected networks | upgrade connected installation, preserved queue/state/credits and rooted receiver |
| Reload the migrated save | upgrade ordinary process, TC_TRACKING_FIRST_TICK / TC_UPGRADE_ORDINARY_OK |
| Transitive same-color attachment | radar rooted native chain; modem indirect receiving KV relay |
| Mixed-color path is not enrollment authority | radar mixed-color negative graph |
| Standalone component with no computer | radar standalone native cycle; last-root removal guard |
| Previously unenrolled relay chain | radar computer–KV–speaker–radar–radar adoption |
| Factory ports and unsupported relays remain excluded | radar logic input/output, configurator targets and vanilla pole negatives |
| Native radio link does not seed adoption | radar actual-powered-native-hidden-link-discovery-and-witness-isolation |
| Stopped or unpowered computer remains a physical root | radar rooted-native-chain-stopped-faulted-unpowered-and-atomic-admission |
| Last computer is removed | radar last-root removal guard; idle detached zero-computer cases |
| Cable cut before an operation | radar captured Console wrapper refuses; modem detach-before-send |
| Another valid path survives | radar multiple-root/alternate-color paths; modem shared channels |
| Discovery proof is incomplete | radar node/capacity/prepublication-work interruption; modem unresolved relevant inventory, no partial delivery |

Additional compatibility gates cover network, runtime/computer, logic, speaker native relays, lifecycle and unchanged modem/monitor/logic competition. The competition runner checks publication sample counts, cadence and normal cold shutdown against unchanged limits; it is not a graphical FPS benchmark.

## Connected-client gate — deferred by user

On 2026-10-27 the user explicitly requested: "For client checks just ignore it for now, mark this task as done and create PR". Task 4.3 is closed under that revised acceptance scope, and all 14 tracked tasks are complete. Connected-peer/late-join verification is deferred, not passed.

Available licensed full clients are 2.0.77; only the headless 2.1.23 engine is installed. Cold reconnect is verified, but a matching 2.1.23 connected peer/late join with independently evaluated identities/channels/queues/cleanup is not. Older-client runs and headless success are not equivalent. Matching licensed base and Space Age clients remain necessary for that future verification; the waiver permits task closure and PR creation, not a claim of multiplayer acceptance or authorization to release/archive.

The initial apply handoff performed no commit, push, release, OpenSpec archive, live-save edit or engine-distribution staging. Its frozen evidence bundle remains unchanged. Subsequent task closure and PR publication are separately authorized by the request above; only the task/verification documentation changed after that handoff, with production and test payloads rechecked against the preserved candidate before publication.
