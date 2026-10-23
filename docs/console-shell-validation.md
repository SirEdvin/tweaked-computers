# Console shell verification and review handoff

This is the implementation fixture guide. Independent SH2 acceptance is complete;
see the receipt in `openspec/changes/archive/2026-10-19-add-interactive-console-shell/tasks.md` and
[0.1.8 release notes](console-shell-release.md). Native workflows passed in both
modes; connected late join/cold-server acceptance passed in base only. History
was explicitly removed by the user after the focused
arrow feasibility failure. Do not reintroduce a history gate or substitute buttons.

## Packaged contracts and cold persistence

Build outside the checkout and test that exact ZIP:

```sh
WORK=$(mktemp -d "${TMPDIR:?}/tc-shell-check-XXXXXX")
HEADLESS=/home/siredvin/tools/factorio/bin/x64/factorio
python tools/build.py --output "$WORK/package" > "$WORK/package.json"
ARCHIVE=$(jq -er .path "$WORK/package.json")
python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" \
  --output "$WORK/shell-contract" --mode both --fixture tests.shell_contract
python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" \
  --output "$WORK/shell-cold" --mode both --fixture tests.shell_cold \
  --production-context --cold
```

`tests.shell_contract` uses the strict editor GUI/player mocks, actual guarded
native compiler, actual wired entities and service providers. Its explicit fixture
clocks/energy injection are not production tick, native focus or latency evidence.
It covers values/aliasing, print arity, failure publication, all device families,
principal ownership, GUI authorization, queue/graph/source/binding/session bounds,
Follow-off and lifecycle/transport boundaries. Cache fixtures independently compare
warm/cold compilation charges, including the shared expression/statement fallback.

`tests.shell_cold` uses production ownership/context, genuine electrical supply
and actual scheduler ticks beside running controller/neighbor programs. Its
players/authoring GUI are labelled mocks. It freezes after queueing two commands
and exhausting the real computer work ledger, then requests `tc03-snapshot` and
performs no more work until an actual cold on_load. Before resuming it compares
shell/queue/graph/ledger/program state, aliases, unknown future schema and counters.
The second process verifies once-only effects and retained facade/method identity.
Both phases must request and acknowledge `/quit`, exit zero and avoid forced cleanup.

The existing CI validation job includes both fixtures plus runtime, cache, editor,
budget, presentation and factory regressions. Keep production budgets unchanged.

## Prepare an isolated real-client scene

The repository has an opt-in `tests.shell_client_engine` production fixture. Its
observer never enters source or invokes a guest command. It creates a real powered
computer with a running heartbeat controller, KV, logic, configurator and a merged
monitor. Joining players are placed nearby and get the real workspace. Use native
keys/clicks to select Console, enter commands and reopen through Ctrl+left-click.
The scene has no connection to a player save.

```sh
BASE=/home/siredvin/projects/tweaked-computers/gameitself/base-2.0.77/factorio
python tools/shell_client.py --archive "$ARCHIVE" --factorio "$HEADLESS" \
  --client "$BASE" --mode base --output "$WORK/native-base"
```

The tool verifies both 2.0.77 engine versions, copies the unchanged production ZIP,
adds only a separate `tc-smoke` companion and creates an isolated save/config/mod/
write-data layout. `commands.json` contains exact argv arrays for `singleplayer`,
`server`, `client1`, `client2`. `provenance.json` records archive/save hashes and
explicitly says preparation is not acceptance. No game distribution or credential
file is copied. For Space Age, pass its complete distribution root and
`--mode space-age`; if it has no generated config, also pass
`--config-template "$BASE/config/config.ini"` from the matching 2.0.77 engine.

Run a command on an owned private display (never the user's desktop):

```sh
xvfb-run -a -s '-screen 0 1280x720x24 -nolisten tcp' \
  python -c 'import json,subprocess,sys; subprocess.run(json.load(open(sys.argv[1]))[sys.argv[2]],check=True)' \
  "$WORK/native-base/commands.json" singleplayer
```

Use the ordinary Ctrl+left-click interaction to reopen the computer after closing.
Let mouse motion settle before an automated Ctrl-click so Factorio's native
`player.selected` resolves the body rather than leaving an inert empty-ground click. Inspect the
actual window before coordinates are used. Capture inside that same display with
its own XAUTHORITY. The native client scene writes bounded current observations to
`client1/write/script-output/shell-client-state.json` and command status changes to
`shell-client-events.jsonl`. The snapshot contains program/heartbeat, current exact
monitor name, shell graph/logs and each connected player's input/tab. It does not
replace actual-window inspection.

Execute the player guide's lines individually using the monitor name in that
snapshot. Prove typing/paste, native caret editing, Enter and Execute, retained
binding after close/reopen, output selection/Follow-off, command-local errors and
confirmed reset. Observe real monitor text beside the still-incrementing heartbeat.
Run the supported size/scale matrix in base and Space Age, inspecting images and
sampled video frames. llvmpipe is software rendering, not GPU performance evidence.

## Connected late join (SH2 required acceptance)

1. Start the exact `server` command with an owned stdin pipe/terminal. It binds
   localhost, hides public/LAN visibility and permits two clients without online
   verification. Keep its input open so `/server-save` and `/quit` are available.
2. Launch only `client1` on its private display. Use its isolated write-data and a
   distinct native multiplayer nickname if prompted. Do not reuse or copy player
   credentials. Confirm normal connection and inspect the real Console.
3. Enter a monitor binding, a captured method, an aliased/cyclic value graph and
   a visible monitor write. Also execute a once-only witness such as
   `computer.setState("effects",(computer.getState("effects") or 0)+1)` and a KV
   write. Retain logs/current graph and exact source lines before starting peer 2.
4. Keep an unfinished draft in client 1, then launch `client2` using its own config/
   write-data on another owned display. This must be a real late join after the
   effects, not two clients present before initialization.
5. In client 2, inspect the retained bindings and `print(computer.getState("effects"))`;
   it must still be 1. Use the captured method. Check client 1's unfinished draft is
   unchanged. Submit conflicting assignments from both clients, compare final
   values/output ordering on both, and test reset/stale authorization.
6. Save, normally stop/reload and exercise retained values again. Inspect server
   and both client logs for desync/error, preserve exact archive hash, commands,
   snapshots and actual-window evidence. Cold headless passes do not satisfy this.
7. Close both clients through native window close, request server `/quit`, and
   verify all owned processes/displays exit normally. Preserve failures separately;
   do not erase an earlier crash with a clean retry.

No merge, release, graphical latency or multiplayer acceptance follows merely
from preparing this scene or observing the headless completion markers.
