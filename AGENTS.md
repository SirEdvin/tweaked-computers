<!-- OPENWIKI:START -->

## OpenWiki

This repository has a generated `openwiki/` evidence index. It is optional just-in-time context, not required startup reading.

- Do not enumerate, preload, or search wikis at task start. Use retrieval when the user asks for it, when unfamiliar architecture or dependency behavior materially affects the task, or when source inspection leaves an important uncertainty. Stop once the question is grounded.
- When those conditions apply and OpenWiki retrieval tools are available, use `openwiki_search` for just-in-time context and `openwiki_read` for the relevant complete sections. If search returns `workspace_required`, ask which listed workspace to use and retry with its ID.
- Use `openwiki_list_workspaces` or `openwiki_list_wikis` when workspace membership itself needs to be discovered.
- If the retrieval tools are unavailable, read `openwiki/quickstart.md` and follow its links to the relevant pages.
- Treat source code and tests as authoritative. A brief's unknowns and review items are verification gaps, not automatic requirements.
- Prefer the narrowest quiet validation that proves the changed behavior. Preserve complete failure output.

The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki. Do not hand-edit generated OpenWiki pages unless explicitly asked; prefer updating source code/docs and letting OpenWiki regenerate.

<!-- OPENWIKI:END -->

## Local Factorio verification

Use headless runs for contracts/save–reload and the full client for visible UI/rendering. The locally provided engines are **2.0.77 (build 84539)**; confirm `--version` and `--help` before using a different installation.

- Headless: `/home/siredvin/tools/factorio/bin/x64/factorio`.
- Base client: `gameitself/base-2.0.77/factorio/bin/x64/factorio`.
- Space Age client: `gameitself/space-age-2.0.77/factorio/bin/x64/factorio`.
- **Never commit Factorio distributions, original archives, binaries or game data.** Keep them under the gitignored `/gameitself/`; preserve the supplied archives and never force-add that directory. Keep saves, logs, recordings and test outputs outside the repository too. Before staging, check `git ls-files -- gameitself` and `git diff --cached --name-only`; the first must be empty. `git check-ignore -v -- gameitself/` must identify the ignore rule.

### Packaged headless checks

Run from the repository root. Use a fresh directory under the configured scratch directory, never an existing player save/config or a source symlink in place of the built archive:

```sh
HEADLESS=/home/siredvin/tools/factorio/bin/x64/factorio
WORK=$(mktemp -d "${TMPDIR:?}/tc-check-XXXXXX")
python tools/build.py --output "$WORK/package" > "$WORK/build.json"
ARCHIVE=$(jq -er .path "$WORK/build.json")
python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" --output "$WORK/smoke" --mode both
python tools/monitor_animation.py --factorio "$HEADLESS" --archive "$ARCHIVE" --output "$WORK/animation" --mode both --layout four-walls
```

`tools/smoke.py` accepts `--fixture MODULE`, `--production-context` and `--cold` for the relevant packaged fixture. Cold runs use separate localhost-only server processes with public/LAN visibility disabled, verify persisted snapshots, and request console `/quit`. The animation wrapper already enables production-context/cold checks; also run `--layout mixed` with a different output directory when changing charts. Preserve full failure logs; do not raise production budgets to make a test pass.

### Full client, screenshots and animation

Use the complete licensed client and its matching data directory, not the headless executable. The proven host-local monitor runner requires Python, `xvfb-run`, X11/XTest libraries, `ffmpeg` and `ffprobe`. Copy its three helpers into the new scratch directory; never run it in-place in a frozen evidence bundle:

```sh
E=/home/siredvin/artifacts/tweaked-computers/subpixel-line-2026-10-16
cp "$E/harness/render_case.py" "$E/harness/monitor_graphics.lua" "$E/harness/x11.py" "$WORK/"
xvfb-run -a -s '-screen 0 1280x720x24 -nolisten tcp' python "$WORK/render_case.py" --archive "$ARCHIVE" --case base-video --mode base --ticks 600 --capture --record-seconds 8
```

The runner creates isolated config/mod/write-data/save directories, injects only test fixtures into a copy of the supplied mod ZIP, builds a powered four-monitor scene, then runs the full client with `--benchmark-graphics`, `--benchmark-ticks` and `--output-perf-stats`. It verifies unchanged production payloads. Its repository/client paths and setup-module extraction are host-local assumptions: inspect/adapt the copied helper if the checkout or fixture changes.

- Outputs under `$WORK/base-video/`: `window.png` (actual window), `animation.mp4`, native `write/script-output/chart-{180,210,240}.png`, `client.log`, `render-perf.csv`, `summary.json` and `provenance.json`.
- Repeat with a fresh case name and `--mode space-age` for the expansion client. Use `--ticks 3600` without `--capture`/`--record-seconds` for a separate sustained run; `--workload full-blit` changes only the test copy's row-submission predicate. Never mix recording overhead into timing comparisons.
- The fixture calls `game.take_screenshot` at fixed ticks/camera/zoom with `show_gui=false` and `force_render=true`; paths are relative to that case's write-data `script-output/`. These native screenshots differ from actual-window/UI captures.
- For other saves/UI scenarios, use an isolated config with `read-data` pointing at the chosen distribution's `data` and `write-data` pointing at scratch, plus a separate `--mod-directory`. Start the full client with `--load-game /absolute/copied-save.zip` (or use `--benchmark-graphics` for bounded rendered runs). Inspect the actual window before interacting; do not reuse or overwrite player data.

For manual capture, run these **inside the same private Xvfb session as the live client**; `WORK` must be set there. A second `xvfb-run` creates another display, not a view of the first:

```sh
ffmpeg -nostdin -loglevel error -f x11grab -video_size 1280x720 -i "$DISPLAY" -frames:v 1 "$WORK/window.png"
ffmpeg -nostdin -loglevel error -f x11grab -framerate 30 -video_size 1280x720 -i "$DISPLAY" -t 8 -c:v libx264 -preset ultrafast -crf 20 -threads 1 -pix_fmt yuv420p "$WORK/animation.mp4"
ffprobe -v error -show_entries format=duration:stream=width,height,nb_frames,r_frame_rate -of json "$WORK/animation.mp4"
```

If a later process attaches to the owned display, retain both `DISPLAY` and the `XAUTHORITY` file path from inside its session; never print/copy the authorization cookie or target the user's desktop. Run long cases individually as tracked background jobs with self-contained absolute paths: foreground exports may not reach a new background shell, and a combined command can exceed the tool deadline.

### Evidence and cleanup

- Inspect actual screenshots and sampled video frames; successful startup or an encoded MP4 is not visual acceptance. Check exact sample counts, completion markers, `summary.json` (`passed`, zero exit, no forced cleanup), and hashes of the tested archive/guest source.
- Read the actual renderer in `client.log`. Xvfb/llvmpipe validates appearance, **not representative GPU FPS**. Headless publication cadence and the recording's 30 FPS are not measured client FPS; these isolated runs do not prove connected multiplayer behavior. Keep baseline/candidate timing runs serial with identical workloads/settings and disclose unrelated host contention.
- Preserve selected evidence under `/home/siredvin/artifacts/tweaked-computers/`, outside git and expiring scratch. Exclude game distributions and display credentials. Keep failed/partial attempts separate from final passes; do not overwrite historical bundles.
- Let bounded benchmarks exit normally; for manual runs request normal window close or server `/quit`, then verify the owned Factorio/Xvfb/ffmpeg processes exited. Terminate only owned leftovers, never blanket-kill unrelated clients; forced termination is failed acceptance.
- Further detail: [rendered validation and harness provenance](docs/monitor-render-validation.md), [current chart behavior and headless gates](docs/player/monitor-animation.md). The older rendered report measures the star-marker workload, not the later connected-subpixel chart; its separate local evidence is in `$E` above.
