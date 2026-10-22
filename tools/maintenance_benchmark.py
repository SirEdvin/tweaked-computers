#!/usr/bin/env python3
"""Serial, exact-archive maintenance split experiment; no production default edit.

Reuses smoke.py's isolated native context and acknowledged cold server shutdown.
All test-only overrides and unchanged production bytes are inventoried. A failed
workload is retained as a result, not retried under enlarged production quotas.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
import threading
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def distribution(values):
    if not values:
        return {'count': 0}
    ordered = sorted(values)
    return {'count': len(values), 'mean': statistics.fmean(values),
            'median': statistics.median(values), 'p95': ordered[math.ceil(.95 * len(values)) - 1],
            'max': max(values), 'min': min(values)}


def complete_profiles(profiles, inventories, ticks):
    if len(inventories) != 1:
        return False
    names = inventories[0]
    return (len(names) == len(set(names)) and set(names) == set(profiles)
            and all(len(samples) == ticks for samples in profiles.values()))


def extract(folder, ticks, profile):
    paths = list((folder / 'engine').glob('*/cold-second-engine.log'))
    text = paths[0].read_text() if len(paths) == 1 else ''
    records = {}
    for match in re.finditer(r'TC_MB_(\w+) (\{[^\r\n]*\}|\[[^\r\n]*\])', text):
        records.setdefault(match[1], []).append(json.loads(match[2]))
    samples = records.get('SAMPLE', [])
    sample_ticks = {row['tick'] for row in samples}
    profiles = {}
    for match in re.finditer(r'TC_MB_CPU tick=(\d+) phase=(\S+) Duration: ([0-9.]+)ms', text):
        tick, phase, value = int(match[1]), match[2], float(match[3])
        if tick in sample_ticks:
            # Timer/dispatch wrappers run per computer; sum per actual tick.
            profiles.setdefault(phase, {}).setdefault(tick, 0)
            profiles[phase][tick] += value
    if profile:
        # The production timer loop never calls advance_timers on faulted runs.
        # Zero means no call, not a fabricated profiler duration.
        timers = profiles.setdefault('advance_timers', {})
        for tick in sample_ticks:
            timers.setdefault(tick, 0)
    smoke_path = folder / 'engine' / 'summary.json'
    smoke = json.loads(smoke_path.read_text()) if smoke_path.exists() else {}
    cases = smoke.get('cases', [])
    shutdown = [p for c in cases for p in c.get('cold_phases', [])]
    structural = (len(samples) == ticks and len(sample_ticks) == ticks
                  and [r['index'] for r in samples] == list(range(1, ticks + 1))
                  and len(records.get('DONE', [])) == 1 and len(records.get('CLEANUP', [])) == 1
                  and len(shutdown) == 2 and all(p['passed'] for p in shutdown)
                  and len(profiles.get('scheduler', {})) == ticks
                  and (not profile or complete_profiles(profiles, records.get('PHASES', []), ticks)))
    result = {'structural_pass': structural, 'sample_count': len(samples),
              'functional_pass': structural and all(r['faults'] == 0 for r in samples),
              'cpu_ms': {key: distribution(list(values.values())) for key, values in profiles.items()},
              'records': records, 'shutdown': shutdown}
    result['phase_cpu_samples_ms'] = {key: list(values.values()) for key, values in profiles.items()}
    work = {}
    for match in re.finditer(r'TC_MB_WORK tick=(\d+) phase=(\S+) units=(\d+)', text):
        tick, phase, units = int(match[1]), match[2], int(match[3])
        if tick in sample_ticks:
            work.setdefault(phase, {}).setdefault(tick, 0)
            work[phase][tick] += units
    result['phase_maintenance_work'] = {key: distribution(list(values.values())) for key, values in work.items()}
    for key in ('maintenance', 'guest', 'reserved', 'refused', 'faults', 'retired', 'staging'):
        result[key] = distribution([r[key] for r in samples])
    result['refusal_count'] = sum(r['refused'] for r in samples)
    result['all_phase_refusal_count'] = sum(r['refused'] for r in records.get('PRESSURE', []))
    result['input_latency_ticks'] = distribution([r['latency'] for r in records.get('INPUT', [])])
    result['publication_gap_ticks'] = distribution([r['gap'] for r in records.get('PUBLICATION', [])])
    result['publication_latency_ticks'] = distribution([r['latency'] for r in records.get('PUBLICATION', [])])
    beginnings = records.get('BEGIN', [])
    result['progress'] = {key: samples[-1][key] - beginnings[0][key] for key in ('beats', 'changes')} if samples and len(beginnings) == 1 else {}
    first_logs = list((folder / 'engine').glob('*/cold-first-engine.log'))
    first_text = first_logs[0].read_text() if len(first_logs) == 1 else ''
    result['first_phase_faults'] = [json.loads(m[1]) for m in re.finditer(r'TC_MB_FAULT (\{[^\r\n]*\})', first_text)]
    result['first_phase_refusals'] = [json.loads(m[1]) for m in re.finditer(r'TC_MB_PRESSURE (\{[^\r\n]*\})', first_text)]
    config_logs = list((folder / 'engine').glob('*/engine.log'))
    config_text = config_logs[0].read_text() if len(config_logs) == 1 else ''
    result['configuration'] = [json.loads(m[1]) for m in re.finditer(r'TC_MB_CONFIG (\{[^\r\n]*\})', config_text)]
    result['topology'] = [json.loads(m[1]) for m in re.finditer(r'TC_MB_TOPOLOGY (\{[^\r\n]*\})', first_text)]
    config = result['configuration'][0] if len(result['configuration']) == 1 else {}
    states = records.get('STATES', [[]])[0]
    useful = len(states) == config.get('computers') and all(s['status'] == 'running' and s['beats'] > 0 for s in states)
    if config.get('workload') != 'idle':
        useful = useful and len({r['name'] for r in records.get('PUBLICATION', [])}) == config.get('computers')
        useful = useful and len(records.get('INPUT', [])) >= (ticks // 30 - 1) * config.get('computers', 1)
    result['functional_pass'] = result['functional_pass'] and useful and not result['first_phase_faults']
    return result


def prepare(archive, target, budget, workload, ticks, profile):
    config = f"return {{budget={budget},workload={json.dumps(workload)},ticks={ticks},profile={str(profile).lower()}}}\n".encode()
    with zipfile.ZipFile(archive) as src, zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as dst:
        prefix = next(n[:-len('info.json')] for n in src.namelist() if n.endswith('/info.json'))
        control = src.read(prefix + 'control.lua')
        needle = b"local scheduler = require('scripts.scheduler')\n"
        if control.count(needle) != 1:
            raise ValueError('review observer insertion against changed control imports')
        replacements = {
            'control.lua': control.replace(needle, needle + b"require('tests.maintenance_benchmark_observer').install()\n"),
            'tests/monitor_animation_engine.lua': b"return require('tests.maintenance_benchmark_engine')\n",
            'tests/maintenance_benchmark_config.lua': config,
        }
        for name in ('maintenance_benchmark_engine.lua', 'maintenance_benchmark_observer.lua'):
            replacements['tests/' + name] = (ROOT / 'tests' / name).read_bytes()
        unchanged = {}
        for entry in src.infolist():
            relative = entry.filename.removeprefix(prefix)
            if relative not in replacements:
                data = src.read(entry.filename)
                dst.writestr(entry, data)
                unchanged[relative] = digest(data)
        for name, data in replacements.items():
            dst.writestr(prefix + name, data)
    with zipfile.ZipFile(target) as tested:
        assert all(digest(tested.read(prefix + name)) == value for name, value in unchanged.items())
    return {'candidate_sha256': digest(archive.read_bytes()), 'test_archive_sha256': digest(target.read_bytes()),
            'overrides_sha256': {name: digest(data) for name, data in replacements.items()},
            'unchanged_payload_sha256': unchanged}


def contention(stop, records):
    while not stop.is_set():
        records.append({'monotonic': time.monotonic(), 'loadavg': os.getloadavg(),
                        'stat': Path('/proc/stat').read_text().splitlines()[0],
                        'pressure_cpu': Path('/proc/pressure/cpu').read_text().strip()})
        stop.wait(1)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--factorio', type=Path, required=True)
    ap.add_argument('--archive', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--budgets', type=int, nargs='+', default=[200000, 300000, 400000])
    ap.add_argument('--workloads', nargs='+', choices=['idle', 'mixed', 'heavy'], default=['idle', 'mixed', 'heavy'])
    ap.add_argument('--modes', nargs='+', choices=['base', 'space-age'], default=['base', 'space-age'])
    ap.add_argument('--repetitions', type=int, default=3)
    ap.add_argument('--ticks', type=int, default=600)
    ap.add_argument('--unprofiled', action='store_true', help='Forwarding controls without phase profiler wrappers')
    ap.add_argument('--deadline', type=int, default=180)
    args = ap.parse_args()
    output = args.output.resolve()
    if output.exists() or output.is_relative_to(ROOT):
        ap.error('use a fresh directory outside git')
    if not 200000 <= min(args.budgets) <= max(args.budgets) <= 4999999:
        ap.error('budgets must respect MB1 supported minimum and fixed host ceiling')
    if not 60 <= args.ticks <= 3600 or not 1 <= args.repetitions <= 10 or not 1 <= args.deadline <= 1800:
        ap.error('ticks 60..3600, repetitions 1..10, deadline 1..1800')
    output.mkdir(parents=True)
    hardware = {'platform': platform.platform(), 'python': sys.version,
                'lscpu': subprocess.check_output(['lscpu'], text=True),
                'engine_version': subprocess.check_output([str(args.factorio), '--version'], text=True),
                'engine_sha256': digest(args.factorio.read_bytes()),
                'source_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'git_status': subprocess.check_output(['git', 'status', '--short'], cwd=ROOT, text=True),
                'runner_sha256': digest(Path(__file__).read_bytes()), 'command': sys.argv,
                'start_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
    (output / 'environment.json').write_text(json.dumps(hardware, indent=2) + '\n')
    summary = {'cases': [], 'unsupported_lower': {'budget': 199999, 'reason': 'MB1 prototype supported minimum 200000; not executed'}}
    for mode in args.modes:
        for workload in args.workloads:
            for repetition in range(1, args.repetitions + 1):
                # Reverse alternate repetition to reduce monotonic order bias.
                budgets = args.budgets if repetition % 2 else list(reversed(args.budgets))
                for budget in budgets:
                    case = output / f'{mode}-{workload}-r{repetition}-m{budget}'
                    case.mkdir()
                    archive = case / args.archive.name
                    record = prepare(args.archive, archive, budget, workload, args.ticks, not args.unprofiled)
                    (case / 'provenance.json').write_text(json.dumps(record, indent=2) + '\n')
                    command = [sys.executable, str(ROOT / 'tools/smoke.py'), '--factorio', str(args.factorio),
                               '--archive', str(archive), '--output', str(case / 'engine'), '--mode', mode,
                               '--fixture', 'tests.monitor_animation_engine', '--production-context', '--cold',
                               '--cold-timeout', str(args.deadline)]
                    host = []; stop = threading.Event(); thread = threading.Thread(target=contention, args=(stop, host))
                    thread.start()
                    try:
                        with (case / 'runner.log').open('w') as log:
                            process = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=args.deadline * 2 + 180)
                    finally:
                        stop.set(); thread.join()
                        (case / 'contention.json').write_text(json.dumps(host, indent=2) + '\n')
                    result = extract(case, args.ticks, not args.unprofiled)
                    result.update(mode=mode, workload=workload, budget=budget, repetition=repetition,
                                  runner_exit=process.returncode, path=str(case), profile=not args.unprofiled)
                    (case / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
                    summary['cases'].append({key: value for key, value in result.items() if key not in ('records', 'phase_cpu_samples_ms')})
                    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
                    print(json.dumps({key: result[key] for key in ('mode', 'workload', 'budget', 'repetition', 'runner_exit', 'structural_pass', 'functional_pass', 'sample_count')}), flush=True)
    summary['count'] = len(summary['cases'])
    summary['all_structural_pass'] = all(c['structural_pass'] for c in summary['cases'])
    summary['all_functional_pass'] = all(c['functional_pass'] for c in summary['cases'])
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    raise SystemExit(0 if summary['all_structural_pass'] and summary['all_functional_pass'] else 1)


if __name__ == '__main__':
    main()
