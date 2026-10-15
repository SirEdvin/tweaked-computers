# TC03 implementation and verification handoff

Owned tasks: 1.5, 2.1, 2.2, 2.3; capability: computer-runtime.
Merged parent: `0f6fb7f83152b57ca1849b994f09d83099ef209d` (TC01), ordinary
fast-forward merge into the isolated TC03 branch. No primary checkout changes,
remote, push, publication, deployment or OpenSpec archive.

## Implemented

- Versioned authoritative registry, opaque nonreused identities, exact native
  body/child binding, force/surface ownership and source-independent teardown.
- Copied finite Data state with byte/node/key metadata accounting, atomic
  replacement, explicit deletion and alias/cycle/function/LuaObject refusal.
- Saved/active revisions, validation-before-retirement, run generations,
  bounded source-located diagnostics/logs and retained cleanup recovery.
- Native compiler ABI 2; approved language/standard namespaces remain closed.
  Return arity preserves false/nil versus void, including iterator termination
  and empty table.remove (the pinned engine's host helper returns zero values,
  unlike the reference Lua 5.2.4 helper). Bounded generated assignment vectors
  avoid local/register amplification; native publication and preflight use
  right-to-left order so duplicate targets cannot bypass table capacity.
- One production shared scheduler with persistent fair cursors/real-tick
  credits, named subscriptions/events, ordered/coalesced timers, cancellation
  of already admitted timers, visible overflow, power pause/resync hooks and
  private unforgeable stop control. Unsupported admission headers halt safely
  without resetting spent credits.
- Explicit host registration/entity/phase/service/event APIs documented in
  `docs/computer-runtime.md`. TC04/TC06 must use those APIs and revalidate live
  peripheral authority at each actual method effect. Provider factories build
  ephemeral wrappers only, never replay factory effects during reconstruction.

No VM/interpreter, suspended guest stack, OS/filesystem, peripheral discovery,
editor or additional messaging implementation was introduced.

## Actual evidence

Engine: official headless Factorio 2.0.77, build 84539.

Final tested artifact:

    /home/siredvin/.hermes/profiles/albina/cache/scratch/tc03-artifacts-committed/tweaked-computers_0.1.0.zip
    SHA-256 84bbf66ea262fd523d736c55e5fcafb1ad0285fb099ba408de995df8c9c2ddf0
    33 packaged files

Final evidence directory:

    /home/siredvin/.hermes/profiles/albina/cache/scratch/tc03-smoke-committed

Commands (run from this worktree):

    /home/siredvin/.hermes/profiles/albina/cache/scratch/tweaked-computers-research.ZSTlVa/lua-5.2.4/src/lua -e 'storage={}; log=print; require("tests.computer_contract").run()'
    python3 tools/build.py --output /home/siredvin/.hermes/profiles/albina/cache/scratch/tc03-artifacts-committed
    python3 tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio --archive /home/siredvin/.hermes/profiles/albina/cache/scratch/tc03-artifacts-committed/tweaked-computers_0.1.0.zip --output /home/siredvin/.hermes/profiles/albina/cache/scratch/tc03-smoke-committed --fixture tests.computer_cold --cold

Results:

- Reference Lua 5.2.4: 44 grouped checks, exit 0. Pure log retained as
  `/home/siredvin/.hermes/profiles/albina/cache/scratch/tc03-pure-committed.log`.
- Base and Space Age: 45 distinct counted grouped native checks each; fresh
  map creation exit 0. Includes actual LuaObject-return refusal, native registry
  fixture bodies and source execution under the production scheduler module.
- Four cold server phases (two separate processes per mode): all exit 0,
  acknowledged console quit, no signal fallback or forced kill. Initial phases
  never emit reload completion. Snapshot ZIPs are checked readable before quit.
- Cold on_load readback matches exact active/saved sources, revisions, run ID,
  body identity, explicit state, queue sequence, timer deadlines/sequences and
  all spent ledger/scheduler counters. No guest function persisted, no startup
  replay, queued restoration delivered once, one-shot delivered once and timer
  payload alias mutation did not change the registered snapshot.
- A same-tick one-unit-over refusal on the retained real ledger does not refresh
  counters before the next synchronized dispatch.
- Maximum table width: 1024 entries, useful source 4296 bytes, compile 77679,
  work 22748, allocations 7280 in both cold/warm peers. Includes refusal of an
  aliased full-table growth attempt before mutation. These are logical costs,
  not CPU latency measurements. Maximum nil-containing tuple and indexed
  assignment width 128 also execute successfully.

Earlier failed runs remain outside git: `tc03-smoke-first` (missing harness
saves directory), `tc03-smoke-final` (host table.remove arity difference), and
`tc03-smoke-verified` (log-cost exponent precedence). Each was corrected with
focused regressions. They are not claimed as passing runs. The final delivery
archive above is the passing candidate, not an earlier ZIP.

## Deferred/not claimed

Implementation complete; client verification deferred to user. Task 1.5 retains
its open checkbox because joining-client acceptance is mixed with implementation.
No graphical client, screenshots, UI clicking, multiplayer joining, native touch,
focus or rendering acceptance was performed. Other capabilities remain their
own cards; physical body/power sampling is TC04. Power tests here use the actual
runtime hook, not a measured native electrical prototype. Timer/fairness contract
checks include labelled synthetic clocks/pressure; the cold fixture uses real
simulation ticks. Development ceilings remain provisional pending the final
integrated production envelope/latency gate; work credits are not a real-time
CPU bound. All retained logs/builds are outside git.
