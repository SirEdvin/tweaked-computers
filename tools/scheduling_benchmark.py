#!/usr/bin/env python3
"""Granular, exact-archive scheduling experiments; never edits production settings.

A fresh external directory contains raw receipts and a standalone Markdown report.
Timing, profile and structural lanes are intentionally not pooled.
"""
import argparse
import copy
import csv
from datetime import datetime, timezone
import fnmatch
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import signal
import subprocess
import sys
import threading
import zipfile

from maintenance_benchmark import contention, distribution
from smoke import chart_archive, cold_phase

ROOT = Path(__file__).resolve().parents[1]
FAMILIES = ('computer', 'kv', 'monitor', 'logic', 'configurator', 'recipe_searcher',
            'factoriopedia_interface', 'production_statistics', 'dashboard')
LANES = ('timing', 'profile', 'structure')
STRUCTURE_PATHS = ('scripts/scheduler.lua', 'scripts/lifecycle.lua', 'scripts/network.lua',
                   'scripts/services/logic.lua', 'scripts/services/peripheral.lua',
                   'scripts/services/kv.lua', 'scripts/device-art.lua',
                   'scripts/ui/editor.lua', 'scripts/ui/peripheral-inspector.lua', 'scripts/ui/dashboard.lua')


def catalog():
    cases: list[dict] = [{'name': 'empty/no-devices', 'axis': 'fixed'}]
    cases += [dict(name='idle/' + family, axis='idle', family=family) for family in FAMILIES]
    cases += [dict(name='idle/native-' + family, axis='idle', family=family) for family in ('radar', 'speaker')]
    groups = {
        'computer': ('stopped', 'waiting'),
        'dispatch': ('one', 'one-plus-idle', 'all', 'console', 'arbitration'),
        'timer': ('future', 'sparse', 'staggered', 'burst'),
        'signal': ('unwatched', 'watched-static', 'watched-changing', 'shared-input', 'distinct-inputs', 'pulse'),
        'topology': ('no-interest', 'stable-interest', 'rewire', 'adoption'),
        'output': ('no-owner', 'stable-owner', 'revoked-owner'),
        'monitor': ('static', 'one-dirty-row', 'one-dirty-frame', 'all-dirty-row', 'all-dirty-frame', 'regroup'),
        'kv': ('persistent', 'future', 'staggered', 'burst'),
        'art': ('static', 'running-animation'),
        'ui': ('closed', 'editor-static', 'editor-changing', 'inspector-static', 'inspector-changing', 'dashboard-static', 'dashboard-changing', 'dashboard-chart-static', 'dashboard-chart-changing'),
        'churn': ('register-cancel', 'activate-stop'),
        'reload': ('pending',),
        'mixed': ('sparse', 'busy'),
    }
    for group, names in groups.items():
        for name in names:
            axis = 'active' if group in ('computer', 'dispatch', 'timer', 'signal', 'art', 'mixed') else 'devices'
            if group in ('ui', 'churn', 'reload') or name in ('one', 'console', 'arbitration'):
                axis = 'fixed'
            if (group, name) in (('computer', 'stopped'), ('art', 'static'), ('dispatch', 'one-plus-idle')):
                axis = 'idle'
            cases.append(dict(name=f'{group}/{name}', axis=axis, charts='chart-' in name,
                              client=group == 'ui' or name in ('console', 'arbitration')))
    return cases


def matrix(patterns, quick=False):
    selected = [c for c in catalog() if any(fnmatch.fnmatchcase(c['name'], p) for p in patterns)]
    if not selected:
        raise ValueError('no case matched')
    for pattern in patterns:
        if not any(fnmatch.fnmatchcase(c['name'], pattern) for c in selected):
            raise ValueError('unmatched case selector: ' + pattern)
    counts = {'fixed': [1], 'idle': [0, 64, 256, 1024], 'active': [1, 8, 32, 64], 'devices': [1, 8, 32]}
    result = []
    for case in selected:
        # Monitor placement has a production cap of 256 tiles, not 1024.
        scales = [0, 64, 128, 256] if case['name'] == 'idle/monitor' else counts[case['axis']]
        for n in ([1 if case['axis'] == 'fixed' else 8] if quick else scales):
            # Shared/distinct input fan-out and inventory width are independent axes.
            widths = [1, 32] if case['name'].startswith('signal/') and not quick else [1]
            shapes = ['chain', 'branch'] if case['name'].startswith('topology/') and not quick else ['chain']
            timer_counts = [1, 16] if case['name'].startswith('timer/') and not quick else [1]
            for width in widths:
                for shape in shapes:
                    for timers in timer_counts:
                        row = dict(case, count=n, signals=width, shape=shape, timers=timers)
                        row['id'] = f"{case['name'].replace('/', '-')}-n{n}-s{width}-{shape}-t{timers}"
                        result.append(row)
    assert len({r['id'] for r in result}) == len(result)
    return result


def sha(data):
    return hashlib.sha256(data).hexdigest()


def lua(value):
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    if isinstance(value, list):
        return '{' + ','.join(map(lua, value)) + '}'
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, (int, float)):
        return str(value)
    return json.dumps(value, ensure_ascii=True)


def instrument(path, source):
    """Count actual loop visits, not their precharged fictional work units."""
    prefix = "local bench=require('tests.scheduling_benchmark_observer')\n"
    patterns = [r'(for [^\n]+ in ipairs\(root\.order\) do)',
                r'(for [^\n]+ in pairs\(root\.computers\) do)',
                r'(for offset=0,n-1 do)', r'(for _=1,n do)', r'(for _=1,math.min\(n,128\) do)',
                r'(for [^\n]+ in pairs\(rec\.timers\) do)',
                r'(for [^\n]+ in pairs\(c\.subscriptions\) do)']
    hits = 0
    for pattern in patterns:
        source, n = re.subn(pattern, lambda m: m[1] + " bench.count('" + path + ":visit');", source)
        hits += n
    if path == 'scripts/services/logic.lua':
        needle = 'local function native_read(rec,input,spend)\n'
        if source.count(needle) != 1:
            raise ValueError('review native-read observer against this archive')
        source = source.replace(needle, needle + "  bench.count('logic:native-read')\n")
        hits += 1
    # Keep baseline discovery counters; label candidate demand visits separately.
    demand = {
        'scripts/scheduler.lua': {
            '    for _,item in ipairs(round) do': 'scheduler:ready-member',
            '    local rec=root.computers[item.id]': 'scheduler:due-timer-member',
        },
        'scripts/lifecycle.lua': {'local function observe(rec,tick,spend)': 'physical:due-observation'},
        'scripts/services/logic.lua': {
            '  for _,input in ipairs(s.input_order) do': 'signal:watched-input',
            '  for _,entry in ipairs(subscriptions) do': 'signal:subscriber',
        },
        'scripts/services/peripheral.lua': {
            '  for i,entry in ipairs(index.order) do': 'output:owner',
        },
        'scripts/ui/editor.lua': {'local function refresh_viewer(index,s,tick,spend)': 'ui:editor-due'},
        'scripts/ui/peripheral-inspector.lua': {'local function refresh_viewer(index,s,tick,spend)': 'ui:inspector-due'},
        'scripts/ui/dashboard.lua': {'  for offset=0,#indices-1 do': 'ui:dashboard-viewer'},
    }
    for needle, key in demand.get(path, {}).items():
        source, n = re.subn('^' + re.escape(needle),
                            lambda m: m[0] + " bench.count('" + key + "');", source, flags=re.MULTILINE)
        hits += n
    return (prefix + source).encode() if hits else None


def prepare(archive, folder, case, lane, ticks, warmup, mode, engine, capture, fixtures=ROOT / 'tests'):
    mods, write = folder / 'mods', folder / 'write'
    mods.mkdir(parents=True); (write / 'saves').mkdir(parents=True)
    config = dict(case, lane=lane, ticks=ticks, warmup=warmup, capture=capture)
    overrides = {'tests/monitor_animation_engine.lua': b"return require('tests.scheduling_benchmark_engine')\n",
                 'tests/scheduling_benchmark_config.lua': ('return ' + lua(config) + '\n').encode()}
    for name in ('engine', 'observer'):
        key = f'tests/scheduling_benchmark_{name}.lua'
        overrides[key] = (fixtures / Path(key).name).read_bytes()
    copied = mods / archive.name
    with zipfile.ZipFile(archive) as src:
        names = src.namelist()
        manifests = [n for n in names if n.endswith('/info.json') and n.count('/') == 1]
        if len(manifests) != 1 or len(names) != len(set(names)):
            raise ValueError('archive must have one root manifest and unique entries')
        prefix = manifests[0][:-len('info.json')]
        info = json.loads(src.read(manifests[0]))
        control = src.read(prefix + 'control.lua').decode()
        marker = "local scheduler = require('scripts.scheduler')\n"
        if control.count(marker) != 1:
            raise ValueError('review observer insertion against control imports')
        overrides['control.lua'] = control.replace(marker, marker + "require('tests.scheduling_benchmark_observer').install()\n").encode()
        if lane == 'structure':
            for path in STRUCTURE_PATHS:
                changed = instrument(path, src.read(prefix + path).decode())
                if changed:
                    overrides[path] = changed
        with zipfile.ZipFile(copied, 'w', zipfile.ZIP_DEFLATED) as dst:
            for entry in src.infolist():
                relative = entry.filename.removeprefix(prefix)
                dst.writestr(copy.copy(entry), overrides.pop(relative, src.read(entry.filename)))
            for relative, payload in overrides.items():
                dst.writestr(prefix + relative, payload)
    with zipfile.ZipFile(archive) as src, zipfile.ZipFile(copied) as dst:
        changed = {n.removeprefix(prefix): sha(dst.read(n)) for n in dst.namelist()
                   if n not in src.namelist() or src.read(n) != dst.read(n)}
        allowed = {'control.lua', 'tests/monitor_animation_engine.lua', 'tests/scheduling_benchmark_config.lua',
                   'tests/scheduling_benchmark_engine.lua', 'tests/scheduling_benchmark_observer.lua'}
        if lane == 'structure':
            allowed |= set(STRUCTURE_PATHS)
        if set(changed) - allowed:
            raise ValueError('unexpected changed payloads: ' + str(set(changed) - allowed))
        hooks = sorted(set(re.findall(r"scheduler.register_phase\('([^']+)','([^']+)'", '\n'.join(
            src.read(n).decode() for n in src.namelist() if n.startswith(prefix + 'scripts/') and n.endswith('.lua')))))
    fixture = mods / 'tc-smoke_0.0.1'; fixture.mkdir()
    (fixture / 'info.json').write_text(json.dumps(dict(name='tc-smoke', version='0.0.1', title='Scheduling benchmark',
        author='test fixture', factorio_version='2.1', dependencies=['base', info['name']])))
    (fixture / 'control.lua').write_text('-- Production mod owns the isolated fixture.\n')
    (fixture / 'settings.lua').write_text("data:extend{{type='string-setting',name='tc-smoke-production-fixture',setting_type='startup',default_value='tests.monitor_animation_engine',allowed_values={'tests.monitor_animation_engine'}}}\n")
    enabled = [dict(name=n, enabled=True) for n in ('base', info['name'], 'tc-smoke')]
    enabled += [dict(name=n, enabled=mode == 'space-age') for n in ('space-age', 'quality', 'elevated-rails', 'recycler')]
    charts = None
    if case.get('charts'):
        chart = ROOT / '.github/fixtures/factorio-charts/factorio-charts_1.2.0.zip'
        charts = chart_archive(chart)
        shutil.copy2(chart, mods / chart.name)
    enabled += [dict(name='factorio-charts', enabled=charts is not None)]
    (mods / 'mod-list.json').write_text(json.dumps({'mods': enabled}))
    cfg = folder / 'config.ini'
    cfg.write_text(f'[path]\nread-data={engine.resolve().parents[2] / "data"}\nwrite-data={write}\n'
                   '[general]\nlocale=en\n[other]\ncheck-updates=false\nautosave-interval=0\n'
                   '[graphics]\ncache-sprite-atlas=false\n')
    provenance: dict = dict(archive_sha256=sha(archive.read_bytes()), tested_sha256=sha(copied.read_bytes()),
                      overrides_sha256=changed, config=config, hooks=['/'.join(h) for h in hooks],
                      charts=charts, production_unchanged_except_observer=lane != 'structure')
    (folder / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    return cfg, mods, provenance


def records(text, tag):
    return [json.loads(m[1]) for m in re.finditer(r'TC_SB_' + tag + r' (\{[^\r\n]*\})', text)]


def extract(text, ticks, lane, hooks):
    begin, done = records(text, 'BEGIN'), records(text, 'DONE')
    failures = records(text, 'FAIL')
    result = {'passed': False, 'failures': failures, 'samples': 0}
    if len(begin) != 1 or len(done) != 1:
        result['error'] = 'missing/duplicate BEGIN or DONE receipt'
        return result
    start, end = begin[0]['tick'], done[0]['tick']
    if end - start + 1 != ticks or done[0]['samples'] != ticks:
        result['error'] = 'noncontiguous or incomplete measured window'
        return result
    result.update(samples=ticks, begin=begin[0], done=done[0], cpu_ms={}, counters={})
    profiles = {}
    for m in re.finditer(r'TC_SB_CPU tick=(\d+) phase=(\S+) Duration: ([\d.]+)ms', text):
        tick, phase, value = int(m[1]), m[2], float(m[3])
        if start <= tick <= end:
            values = profiles.setdefault(phase, {})
            if tick in values:
                result['error'] = 'duplicate timing sample'; return result
            values[tick] = value
    if lane == 'profile':
        if set(profiles) != set(hooks) | {'scheduler', 'scheduler/dispatch', 'scheduler/advance_timers'} or any(len(v) != ticks for v in profiles.values()):
            result['error'] = 'phase inventory/sample count mismatch'; return result
    result['cpu_ms'] = {k: distribution(list(v.values())) for k, v in profiles.items()}
    result['phase_samples_ms'] = {k: list(v.values()) for k, v in profiles.items()}
    structural = records(text, 'COUNTERS')
    if lane == 'structure':
        if len(structural) != 1 or structural[0]['samples'] != ticks:
            result['error'] = 'structural receipt mismatch'; return result
        result['counters'] = structural[0]['values']
    # Native verbose benchmark times are nanoseconds, with a zero-based update index.
    native = []; header = None; indices = []
    for line in text.splitlines():
        if line.startswith('tick,timestamp,wholeUpdate,'):
            header = next(csv.reader([line]))
        elif header and re.match(r'^t\d+,', line):
            row = dict(zip(header, next(csv.reader([line]))))
            index = int(row['tick'][1:])
            tick = begin[0]['load_tick'] + index + 1
            if start <= tick <= end:
                indices.append(tick)
                value = float(row['wholeUpdate']) / 1000000
                if not math.isfinite(value) or value < 0:
                    result['error'] = 'invalid native duration'; return result
                native.append(value)
    if lane == 'timing' and not begin[0]['client']:
        if indices != list(range(start, end + 1)):
            result['error'] = f'expected {ticks} native update samples, got {len(native)}'; return result
        result['cpu_ms']['wholeUpdate'] = distribution(native)
        result['phase_samples_ms']['wholeUpdate'] = native
    result['guest_sha256'] = {r['computer']: sha(r['source'].encode()) for r in records(text, 'SOURCE')}
    result['passed'] = not failures and done[0]['valid']
    return result


def run_command(command, path, timeout):
    path.with_suffix('.command.json').write_text(json.dumps(command, indent=2) + '\n')
    with path.open('w') as output:
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL); process.wait()
            return -1


def run_case(archive, engine, folder, case, lane, args, mode):
    folder.mkdir()
    cfg, mods, provenance = prepare(archive, folder, case, lane, args.ticks, args.warmup, mode, engine, args.capture, folder.parent / 'harness')
    common = [str(engine), '--config', str(cfg), '--mod-directory', str(mods)]
    save = folder / 'scene.zip'
    code = run_command(common + ['--create', str(save), '--map-gen-seed', '1'], folder / 'create.log', args.timeout)
    if code or 'TC_SMOKE_OK' not in (folder / 'create.log').read_text() or not save.exists():
        return dict(passed=False, error='scene creation failed', exit_code=code, provenance=provenance)
    cold = None
    if case['name'] == 'reload/pending':
        snapshot = folder / 'write/saves/tc03-snapshot.zip'
        try:
            cold = cold_phase(engine, cfg, mods, save, folder, 'cold-first', 'TC_COLD_SNAPSHOT_REQUESTED', snapshot, args.timeout)
        except RuntimeError as error:
            return dict(passed=False, error=str(error), provenance=provenance)
        save = folder / 'resume.zip'; shutil.copy2(snapshot, save)
    total = args.warmup + args.ticks + case['count'] * 3 + 300
    command = common + ['--benchmark-graphics' if case.get('client') else '--benchmark', str(save),
                        '--benchmark-ticks', str(total), '--benchmark-runs', '1', '--benchmark-verbose', 'all']
    if case.get('client'):
        command += ['--disable-audio', '--window-size', '1280x720', '--force-graphics-preset', 'low',
                    '--output-perf-stats', str(folder / 'render-perf.csv')]
        command = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24 -nolisten tcp'] + command
    host = []; stop = threading.Event()
    observer = threading.Thread(target=contention, args=(stop, host)); observer.start()
    try:
        code = run_command(command, folder / 'engine.log', args.timeout)
    finally:
        stop.set(); observer.join()
        (folder / 'contention.json').write_text(json.dumps(host, indent=2) + '\n')
    text = (folder / 'engine.log').read_text()
    result = extract(text, args.ticks, lane, provenance['hooks'])
    source_text = text + (folder / 'cold-first-engine.log').read_text() if cold else text
    result['guest_sha256'] = {r['computer']: sha(r['source'].encode()) for r in records(source_text, 'SOURCE')}
    if case.get('client'):
        perf = folder / 'render-perf.csv'
        if not perf.exists():
            result.update(passed=False, error='missing native rendering CSV')
        else:
            with perf.open() as handle:
                frames = list(csv.DictReader(handle))
            result['render_full_run_ms'] = {name: distribution([float(r[name]) for r in frames])
                                           for name in ('update', 'cpu-render', 'cpu-frame', 'gpu-frame')}
        if args.capture and not (folder / 'write/script-output/benchmark-ui.png').exists():
            result.update(passed=False, error='missing native UI capture')
    result.update(exit_code=code, cold=cold, provenance=provenance,
                  clean_exit=code == 0 and 'Goodbye' in text and 'Exception at tick' not in text,
                  renderer=[l.strip() for l in text.splitlines() if 'Renderer:' in l or 'Initialised OpenGL' in l])
    result['passed'] = result['passed'] and result['clean_exit']
    return result


def compact(result):
    # Raw samples live once in result.json, not in every rewritten matrix manifest.
    summary = {k: v for k, v in result.items() if k != 'phase_samples_ms'}
    if result.get('done'):
        summary['done'] = dict(result['done'])
        for key in ('latency_ticks', 'signal_latency_ticks', 'frame_gap_ticks'):
            summary['done'][key] = distribution(result['done'].get(key) or [])
    return summary


def markdown(manifest):
    now = manifest['created'][:10]
    rows = manifest['results']; passed = sum(r.get('passed', False) for r in rows)
    expected = len(manifest['expected'])
    keys = [r['key'] for r in rows]
    if len(set(manifest['expected'])) != expected or len(keys) != len(set(keys)) or set(keys) - set(manifest['expected']):
        raise ValueError('duplicate or unexpected run identity in report')
    text = [f'---\ntitle: Tweaked Computers scheduling benchmark\ncreated: {now}\nupdated: {now}\ntype: summary\ntags: [evidence-pack]\nsources: []\nconfidence: medium\n---',
            '# Tweaked Computers: granular scheduling benchmark',
            f"## Summary\n\n{len(rows)}/{expected} requested runs completed; {passed} passed, {len(rows)-passed} failed. "
            + ('This is a reduced verification matrix, not the full scaling baseline.' if manifest['quick'] else 'Each row is an independently isolated experiment.'),
            'No speedup is established by a single archive. Failed workloads are never treated as faster results.',
            '## Reproduction and provenance',
            f"- Harness checkout commit (working tree may differ): `{manifest['source_head']}`\n- Engine: `{manifest['engine_version'].splitlines()[0]}`\n"
            f"- Host: `{manifest['host']}`\n- Command: `{manifest['command']}`\n"
            f"- Warmup: {manifest['warmup']} ticks; measured: {manifest['ticks']} ticks/run; repetitions: {manifest['repetitions']}.\n"
            f"- Evidence directory: `{manifest['output']}`\n- Optional factorio-charts: pinned 1.2.0 only in explicitly named dashboard-chart cases; disabled otherwise.",
            '## Measurements\n\nTiming: native whole-update nanoseconds converted to milliseconds; includes fixture driving/check overhead. '
            'Profile: inclusive scheduler/phase LuaProfiler timings; never mixed with native timings. '
            'Structure: test-only loop and call counters; not CPU evidence. '
            'Client timing uses native rendering CSV separately; phase profiles measure its simulation scheduler, not FPS. '
            'Setup, activation and warmup are excluded from the measured window. Budgets are unchanged.',
            '| Case | Mode | Archive | Lane | Repeat | Status | Samples | Metric | Mean ms | Median ms | p95 ms | Max ms |',
            '|---|---|---|---|---:|---|---:|---|---:|---:|---:|---:|']
    for row in rows:
        metric = 'wholeUpdate' if row['lane'] == 'timing' else 'scheduler'
        stats = row.get('cpu_ms', {}).get(metric, {})
        values = [f"{stats[k]:.6f}" if k in stats else '—' for k in ('mean', 'median', 'p95', 'max')]
        text.append('| ' + ' | '.join([row['case']['id'], row['mode'], row['label'], row['lane'], str(row['repetition']),
                    'PASS' if row.get('passed') else 'FAIL', str(row.get('samples', 0)), metric, *values]) + ' |')
    text += ['Harness file hashes:', '```json', json.dumps(manifest.get('harness_sha256', {}), sort_keys=True), '```',
             'Working-tree status at execution:', '```text', manifest.get('git_status', '') or '(clean)', '```',
             '## Paired comparisons', 'Negative CPU deltas mean less time; useful work must still be compared. Only passing pairs are included.']
    pairs = {}
    for row in rows:
        pairs.setdefault((row['case']['id'], row['mode'], row['lane'], row['repetition']), {})[row['label']] = row
    text += ['| Case / mode / lane / repeat | Mean CPU change | p95 CPU change | Callback change |', '|---|---:|---:|---:|']
    for key, pair in pairs.items():
        if set(pair) != {'baseline', 'candidate'} or not all(r.get('passed') for r in pair.values()):
            continue
        metric = 'wholeUpdate' if key[2] == 'timing' else 'scheduler'
        a, b = (pair[label].get('cpu_ms', {}).get(metric, {}) for label in ('baseline', 'candidate'))
        if not a.get('mean') or not a.get('p95') or not b:
            continue
        delta = pair['candidate']['done']['dispatches'] - pair['baseline']['done']['dispatches']
        text.append(f"| {' / '.join(map(str, key))} | {(b['mean']/a['mean']-1)*100:+.2f}% | {(b['p95']/a['p95']-1)*100:+.2f}% | {delta:+d} |")
    text += ['## Detailed receipts']
    for row in rows:
        text += [f"### {row['key']}", f"Evidence: `{row['path']}`; archive SHA-256: `{row.get('provenance', {}).get('archive_sha256', 'unavailable')}`."]
        if row.get('error') or row.get('failures'):
            text.append('Failure: ' + json.dumps(row.get('error') or row['failures']))
        if row.get('done'):
            oracle = dict(row['done'])
            for key in ('latency_ticks', 'signal_latency_ticks', 'frame_gap_ticks'):
                value = oracle.get(key)
                oracle[key] = value if isinstance(value, dict) and 'count' in value else distribution(value or [])
            text += ['Workload oracle and useful work:', '```json', json.dumps(oracle, sort_keys=True), '```']
        if row.get('cpu_ms'):
            text += ['| Phase | Samples | Mean ms | Median ms | p95 ms | Max ms |', '|---|---:|---:|---:|---:|---:|']
            for name, stats in sorted(row['cpu_ms'].items()):
                text.append(f"| {name} | {stats['count']} | {stats['mean']:.6f} | {stats['median']:.6f} | {stats['p95']:.6f} | {stats['max']:.6f} |")
        if row.get('counters'):
            text += ['Structural totals (actual visits/calls, not work charges):', '```json', json.dumps(row['counters'], sort_keys=True), '```']
        if row.get('render_full_run_ms'):
            text += ['Native render CSV summary, **entire process including setup/warmup/capture**, not the measured simulation window:',
                     '```json', json.dumps(row['render_full_run_ms'], sort_keys=True), '```',
                     'Renderer: ' + '; '.join(row.get('renderer', []))]
    text += ['## Interpretation and limitations',
             '- Compare fixed useful work while idle population grows; necessary due physical observations remain separate from work discovery.',
             '- Power helpers and native entity updates contribute to whole-update timing. A later removal is not purely a ready-queue improvement.',
             '- Capture runs include screenshot overhead and are not acceptance timings. Software-rendered clients do not establish representative GPU performance. Rendering CSV has no simulation-tick key; its full-run statistics must not be compared with the warmup-excluded simulation windows.',
             '- Cold pending recovery checks queue/timer/presentation preservation; no connected multiplayer or late-join claim.',
             '- Exact inputs, modified payload hashes, raw logs, per-phase samples and host contention are retained in each evidence directory.',
             '- This standalone note can be filed in LLM-Wiki; filing/index maintenance is intentionally not performed by the runner.']
    # Keep table rows and fenced payloads contiguous, paragraphs separated.
    output = ''; fenced = False
    for i, line in enumerate(text):
        adjacent = i and (fenced or line == '```' or line.startswith('|') and text[i-1].startswith('|'))
        output += ('\n' if adjacent else '\n\n' if i else '') + line
        if line.startswith('```'):
            fenced = not fenced
    return output + '\n'


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--factorio', type=Path)
    ap.add_argument('--client-base', type=Path, help='full-client executable, required for selected base UI cases')
    ap.add_argument('--client-space-age', type=Path)
    ap.add_argument('--archive', type=Path)
    ap.add_argument('--baseline', type=Path, help='optional second archive; alternate serial pair order')
    ap.add_argument('--output', type=Path)
    ap.add_argument('--cases', nargs='+', default=['*'])
    ap.add_argument('--modes', nargs='+', choices=['base', 'space-age'], default=['base', 'space-age'])
    ap.add_argument('--lanes', nargs='+', choices=LANES, default=list(LANES))
    ap.add_argument('--ticks', type=int, default=3600)
    ap.add_argument('--warmup', type=int, default=600)
    ap.add_argument('--repetitions', type=int, default=3)
    ap.add_argument('--timeout', type=int, default=600)
    ap.add_argument('--quick', action='store_true', help='one representative scale per case; no hidden timing changes')
    ap.add_argument('--capture', action='store_true', help='capture native UI screenshots; timings become diagnostic')
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--report', type=Path, help='regenerate report from an existing manifest, no engine execution')
    args = ap.parse_args()
    if args.report:
        data = json.loads(args.report.read_text()); report = args.report.with_name('report.md')
        report.write_text(markdown(data)); print(report); return
    cases = matrix(args.cases, args.quick)
    if args.list:
        print(json.dumps(cases, indent=2)); return
    if not all((args.factorio, args.archive, args.output)):
        ap.error('--factorio, --archive and --output are required')
    if not 60 <= args.ticks <= 36000 or not 60 <= args.warmup <= 36000 or not 1 <= args.repetitions <= 10 or not 30 <= args.timeout <= 1800:
        ap.error('ticks/warmup 60..36000, repetitions 1..10, timeout 30..1800')
    output = args.output.resolve()
    if output.exists() or output.is_relative_to(ROOT):
        ap.error('use a fresh output directory outside the checkout')
    engines = {'headless': args.factorio.resolve(), 'base': args.client_base, 'space-age': args.client_space_age}
    if any(c.get('client') for c in cases):
        for mode in args.modes:
            if not engines[mode]:
                ap.error(f'selected UI/Console cases require --client-{mode}; select other cases explicitly to omit UI')
    versions = {}
    for key, engine in engines.items():
        if engine:
            engines[key] = engine.resolve()
            versions[key] = subprocess.check_output([str(engine), '--version'], text=True)
            if not versions[key].startswith('Version: 2.1.23 ') or key != 'headless' and 'full' not in versions[key]:
                ap.error('exact Factorio 2.1.23 required; UI requires full client')
            subprocess.check_output([str(engine), '--help'], text=True)
    archives = [('candidate', args.archive.resolve())]
    if args.baseline:
        archives.insert(0, ('baseline', args.baseline.resolve()))
    jobs = []
    for mode in dict.fromkeys(args.modes):
        for case in cases:
            for lane in dict.fromkeys(args.lanes):
                for rep in range(1, args.repetitions + 1):
                    for label, archive in (archives if rep % 2 else list(reversed(archives))):
                        key = f'{mode}__{case["id"]}__{lane}__r{rep}__{label}'
                        jobs.append((key, mode, case, lane, rep, label, archive))
    output.mkdir(parents=True)
    sources = output / 'harness'; sources.mkdir()
    for path in (Path(__file__), ROOT / 'tools/maintenance_benchmark.py', ROOT / 'tools/smoke.py',
                 ROOT / 'tests/scheduling_benchmark_engine.lua', ROOT / 'tests/scheduling_benchmark_observer.lua'):
        shutil.copy2(path, sources / path.name)
    manifest = dict(created=datetime.now(timezone.utc).isoformat(), source_head=subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), git_status=subprocess.check_output(
        ['git', 'status', '--short'], cwd=ROOT, text=True), engine_version=versions['headless'],
        engine_versions=versions, host=platform.platform(), cpu=subprocess.check_output(['lscpu'], text=True),
        command=shlex.join(sys.argv), command_argv=sys.argv, output=str(output), ticks=args.ticks, warmup=args.warmup,
        repetitions=args.repetitions, quick=args.quick, capture=args.capture,
        harness_sha256={p.name: sha(p.read_bytes()) for p in sources.iterdir()},
        expected=[j[0] for j in jobs], results=[])
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    for key, mode, case, lane, rep, label, archive in jobs:
        folder = output / key
        engine = engines[mode] if case.get('client') else engines['headless']
        try:
            result = run_case(archive, engine, folder, case, lane, args, mode)
        except (OSError, ValueError, AssertionError, subprocess.SubprocessError) as error:
            result = dict(passed=False, error=f'{type(error).__name__}: {error}')
        result.update(key=key, mode=mode, case=case, lane=lane, repetition=rep, label=label, path=str(folder))
        folder.mkdir(exist_ok=True)
        (folder / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        manifest['results'].append(compact(result))
        (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        (output / 'report.md').write_text(markdown(manifest))
        print(json.dumps(dict(key=key, passed=result['passed'], error=result.get('error'), samples=result.get('samples', 0))), flush=True)
    assert [r['key'] for r in manifest['results']] == manifest['expected']
    print(output / 'report.md')
    raise SystemExit(0 if all(r['passed'] for r in manifest['results']) else 1)


if __name__ == '__main__':
    main()
