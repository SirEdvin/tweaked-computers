#!/usr/bin/env python3
"""Wrap the exact packaged paste-ready chart for isolated production-tick tests."""
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
    ap = argparse.ArgumentParser()
    ap.add_argument('--factorio', type=Path, required=True)
    ap.add_argument('--archive', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--mode', choices=('base', 'space-age', 'both'), default='both')
    ap.add_argument('--layout', choices=('four-walls', 'mixed'), default='four-walls')
    ap.add_argument('--inspectors', type=int, choices=(0, 16), default=0, help='Opt-in paid GUI-double contention; not native client evidence')
    args = ap.parse_args()
    folder = args.output.resolve()
    if folder.is_relative_to(ROOT) or folder.exists():
        ap.error('use a fresh output directory outside git')
    folder.mkdir(parents=True)
    target = folder / args.archive.name
    with zipfile.ZipFile(args.archive) as src, zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as dst:
        prefix = next(n[:-len('info.json')] for n in src.namelist() if n.endswith('/info.json'))
        source = src.read(prefix + 'examples/smooth-sine-chart.lua').decode()
        eq = '='
        while ']' + eq + ']' in source:
            eq += '='
        for entry in src.infolist():
            dst.writestr(entry, src.read(entry.filename))
        dst.writestr(prefix + 'tests/monitor_animation_source.lua', 'return [' + eq + '[' + source + ']' + eq + ']\n')
        dst.writestr(prefix + 'tests/monitor_animation_layout.lua', 'return ' + json.dumps(args.layout) + '\n')
        if args.inspectors:
            dst.writestr(prefix + 'tests/peripheral_inspector_contention_config.lua', 'return {viewers=' + str(args.inspectors) + '}\n')
    additions = ['tests/monitor_animation_source.lua', 'tests/monitor_animation_layout.lua']
    if args.inspectors:
        additions.append('tests/peripheral_inspector_contention_config.lua')
    record: dict[str, object] = {'candidate_sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest(),
              'test_archive_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
              'guest_sha256': hashlib.sha256(source.encode()).hexdigest(),
              'layout': args.layout,
              'inspector_viewers': args.inspectors,
              'test_only_additions': additions}
    (folder / 'provenance.json').write_text(json.dumps(record, indent=2) + '\n')
    command = [sys.executable, str(ROOT / 'tools/smoke.py'), '--factorio', str(args.factorio),
               '--archive', str(target), '--output', str(folder / 'engine'), '--mode', args.mode,
               '--fixture', 'tests.monitor_animation_engine', '--production-context', '--cold',
               # The fixed-tick cadence plus outage/recovery contract can take
               # over 90 wall seconds on hosted CPUs. This is not a latency
               # gate: retain its 2200-tick deadline, cadence and paid limits.
               '--cold-timeout', '240']
    result = subprocess.run(command, check=False)
    samples = []
    profiles = []
    for path in sorted((folder / 'engine').glob('*/cold-second-engine.log')):
        for match in re.finditer(r'TC_ANIMATION_CADENCE intervals=(\d+) max_gap=(\d+) peak_work=(\d+) peak_allocations=(\d+)', path.read_text()):
            samples.append({'mode': path.parent.name, 'intervals': int(match[1]), 'max_gap_ticks': int(match[2]),
                            'peak_work': int(match[3]), 'peak_allocations': int(match[4])})
    for mode in ('base', 'space-age'):
        durations = []
        for path in sorted((folder / 'engine' / mode).glob('cold-*-engine.log')):
            durations += [float(m[1]) for m in re.finditer(r'TC_ANIMATION_CPU tick=\d+ Duration: ([0-9.]+)ms', path.read_text())]
        if durations:
            ordered = sorted(durations)
            profiles.append({'mode': mode, 'samples': len(durations), 'mean_ms': statistics.fmean(durations),
                             'p95_ms': ordered[int((len(ordered) - 1) * 0.95)], 'max_ms': max(durations),
                             'excludes_fixture_observation': True, 'includes_cold_reconstruction': True})
    if result.returncode == 0:
        expected = 2 if args.mode == 'both' else 1
        assert len(samples) == expected and all(s['intervals'] >= 360 and s['max_gap_ticks'] <= 2 for s in samples)
    record.update(exit_code=result.returncode, cadence_samples=samples, scheduler_profiles=profiles)
    (folder / 'summary.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
