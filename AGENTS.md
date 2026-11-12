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

## Documentation language

Use ASD-STE100 Simplified Technical English, Issue 9, for maintained mod documentation.
This rule includes player guides, API descriptions, generated prose, and in-game help.
Consult the official standard: https://www.asd-ste100.org/assets/files/ASD-STE100_ISSUE9.pdf.

- Use approved words with their approved meanings and parts of speech.
- Use consistent technical nouns and technical verbs for Factorio, Lua, and this mod.
- Keep procedural sentences within 20 words. Keep descriptive sentences within 25 words.
- Give one instruction per sentence. Use the imperative for instructions.
- Prefer active voice. Do not invent an actor or change a requirement to avoid passive voice.
- Preserve code, identifiers, UI labels, commands, values, and API contracts exactly.
- Preserve warnings, limitations, return arity, optionality, errors, and persistence rules.
- Change the source of generated prose. Regenerate its outputs with the existing tools.
- Review vocabulary, grammar, and technical meaning. A word-count check alone does not prove compliance.
- Do not rewrite historical evidence, third-party notices, or generated OpenWiki as part of a language change.
- Do not change OpenSpec unless the user separately requests it.

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

Use the complete licensed client and its matching data directory, not the headless executable. Rendered runs need `xvfb-run`, X11/XTest libraries, `ffmpeg` and `ffprobe`. No rendered-run harness is kept; write a small scratch runner for the task:

- Use isolated configs: `read-data` at the chosen distribution's `data`, `write-data` in scratch, and a separate `--mod-directory` that holds the built ZIP plus any test-only scene mod. Never inject test files into the production ZIP.
- Create the scene save with the headless executable (`--create`), then run the full client inside `xvfb-run` with `--benchmark-graphics SAVE --benchmark-ticks N` (add `--output-perf-stats` for timing). Run base and Space Age as separate cases in fresh directories.
- For native screenshots, call `game.take_screenshot` with `show_gui=false` and `force_render=true`; paths are relative to the case's write-data `script-output/`. These differ from actual-window/UI captures.
- For timing, use long `--benchmark-ticks` runs without capture or recording. Never mix recording overhead into timing comparisons.
- For other saves/UI scenarios, start the full client with `--load-game /absolute/copied-save.zip`. Inspect the actual window before interacting; do not reuse or overwrite player data.

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
- Further detail: [rendered validation report](docs/monitor-render-validation.md), [current chart behavior and headless gates](docs/player/monitor-animation.md). The older rendered report measures the star-marker workload, not the later connected-subpixel chart.
