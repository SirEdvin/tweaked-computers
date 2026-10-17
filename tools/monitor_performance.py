#!/usr/bin/env python3
"""Matched sustained chart benchmark; exact production scripts, test-only driver.

Run baseline and candidate serially on the same host. CPU is whole-scheduler Lua
CPU (no graphical client), not a claim about real-time UPS. See provenance.json
for every injected/replaced fixture and the exact guest-source hash.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import statistics
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--factorio', type=Path, required=True)
    ap.add_argument('--archive', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--mode', choices=('base', 'space-age', 'both'), default='base')
    ap.add_argument('--layout', choices=('four-walls', 'mixed'), default='four-walls')
    ap.add_argument('--workload', choices=('sparse', 'full-blit'), default='sparse')
    ap.add_argument('--ticks', type=int, default=3600)
    ap.add_argument('--deadline', type=int, default=180)
    ap.add_argument('--max-gap', type=int, help='Optional publication-gap acceptance gate')
    args = ap.parse_args()
    folder = args.output.resolve()
    if folder.is_relative_to(ROOT) or folder.exists():
        ap.error('use a fresh output directory outside git')
    if not 600 <= args.ticks <= 216000 or not 1 <= args.deadline <= 1800:
        ap.error('ticks must be 600..216000 and deadline 1..1800 seconds per cold phase')
    if args.max_gap is not None and args.max_gap < 1:
        ap.error('max-gap must be positive')
    folder.mkdir(parents=True)
    driver = (ROOT / 'tests/monitor_performance_engine.lua').read_bytes()
    target = folder / args.archive.name
    config = f'return {{ticks={args.ticks},max_gap={args.max_gap or "nil"}}}\n'
    with zipfile.ZipFile(args.archive) as src, zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as dst:
        prefix = next(n[:-len('info.json')] for n in src.namelist() if n.endswith('/info.json'))
        source = src.read(prefix + 'examples/smooth-sine-chart.lua').decode()
        if args.workload == 'full-blit':
            # Same image and cadence, but submit every terminal row like a
            # buffered pixelbox renderer. This is NOT executing Telem itself.
            pattern = r'if not old or rows\[y\] ~= old\[y\] then|if not old or rows\[y\]~=old\[y\] then'
            source, count = re.subn(pattern, 'if true then', source)
            if count != 1:
                raise ValueError('review full-row workload transform against changed example')
        eq = '='
        while ']' + eq + ']' in source:
            eq += '='
        replacements = {
            'tests/monitor_animation_engine.lua': b"return require('tests.monitor_performance_engine')\n",
            'tests/monitor_animation_setup.lua': src.read(prefix + 'tests/monitor_animation_engine.lua'),
            'tests/monitor_performance_engine.lua': driver,
            'tests/monitor_performance_config.lua': config.encode(),
            'tests/monitor_animation_source.lua': ('return [' + eq + '[' + source + ']' + eq + ']\n').encode(),
            'tests/monitor_animation_layout.lua': ('return ' + json.dumps(args.layout) + '\n').encode(),
        }
        for entry in src.infolist():
            if entry.filename.removeprefix(prefix) not in replacements:
                dst.writestr(entry, src.read(entry.filename))
        for path, content in replacements.items():
            dst.writestr(prefix + path, content)
    record = {'candidate_sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest(),
              'test_archive_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
              'guest_sha256': hashlib.sha256(source.encode()).hexdigest(),
              'layout': args.layout, 'workload': args.workload, 'ticks': args.ticks,
              'test_only_replacements': {k: hashlib.sha256(v).hexdigest() for k, v in replacements.items()}}
    (folder / 'provenance.json').write_text(json.dumps(record, indent=2) + '\n')
    result = subprocess.run([sys.executable, str(ROOT / 'tools/smoke.py'), '--factorio', str(args.factorio),
                             '--archive', str(target), '--output', str(folder / 'engine'), '--mode', args.mode,
                             '--fixture', 'tests.monitor_animation_engine', '--production-context', '--cold',
                             '--cold-timeout', str(args.deadline)], check=False)
    samples = []
    for path in sorted((folder / 'engine').glob('*/cold-second-engine.log')):
        text = path.read_text()
        durations = [float(m[1]) for m in re.finditer(r'TC_PERF_CPU tick=\d+ Duration: ([0-9.]+)ms', text)]
        done = list(re.finditer(r'TC_PERF_DONE ticks=(\d+) publications=(\d+) visible_changes=(\d+) max_gap=(\d+) peak_objects=(\d+)', text))
        entry = {'mode': path.parent.name, 'samples': len(durations), 'completed': len(done) == 1}
        if durations:
            ordered = sorted(durations)
            entry.update(mean_ms=statistics.fmean(durations), median_ms=statistics.median(durations),
                         p95_ms=ordered[int((len(ordered) - 1) * .95)], max_ms=max(durations))
        if len(done) == 1:
            entry.update(zip(('ticks', 'publications', 'visible_changes', 'max_gap_ticks', 'peak_objects'), map(int, done[0].groups())))
        samples.append(entry)
    expected = 2 if args.mode == 'both' else 1
    complete = len(samples) == expected and all(s['completed'] and s['samples'] == args.ticks for s in samples)
    exit_code = result.returncode or (0 if complete else 1)
    record.update(exit_code=exit_code, scheduler_profiles=samples)
    (folder / 'summary.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))
    raise SystemExit(exit_code)


if __name__ == '__main__':
    main()
