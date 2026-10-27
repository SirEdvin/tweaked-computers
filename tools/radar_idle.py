#!/usr/bin/env python3
"""Serial paired radar-idle windows; adapts the preserved 0.1.15 diagnostic.

Unprofiled engine total-update windows and separately labeled hook profiling.
The fixture performs real enrollment/detachment; migration is radar_upgrade.py.
"""
import argparse
import copy
import csv
import hashlib
import itertools
import json
from pathlib import Path
import re
import subprocess
import sys
import threading
import zipfile

from maintenance_benchmark import contention, distribution
from radar_upgrade import TRACKING_SHA256

ROOT = Path(__file__).resolve().parents[1]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def prepare(archive, folder, engine, mode, config):
    mods, write = folder / 'mods', folder / 'write'
    mods.mkdir(parents=True); write.mkdir()
    changes = {'control.lua', 'tests/monitor_animation_engine.lua', 'tests/radar_idle_config.lua'}
    unchanged = {}
    with zipfile.ZipFile(archive) as source, zipfile.ZipFile(mods / archive.name, 'w', zipfile.ZIP_DEFLATED) as target:
        prefix = next(n[:-len('info.json')] for n in source.namelist() if n.endswith('/info.json'))
        expected_hooks = sum(source.read(n).count(b'scheduler.register_phase(') for n in source.namelist() if n.startswith(prefix + 'scripts/') and n.endswith('.lua'))
        for entry in source.infolist():
            name = entry.filename.removeprefix(prefix)
            data = source.read(entry.filename)
            if name == 'control.lua':
                needle = b"local scheduler = require('scripts.scheduler')\n"
                assert data.count(needle) == 1
                data = data.replace(needle, needle + b"require('tests.monitor_animation_engine').install()\n")
            elif name == 'tests/monitor_animation_engine.lua':
                data = (ROOT / 'tests/radar_idle_engine.lua').read_bytes()
            elif name == 'tests/radar_idle_config.lua':
                continue
            else:
                unchanged[entry.filename] = digest(data)
            target.writestr(copy.copy(entry), data)
        values = ','.join(k + '=' + (str(v).lower() if isinstance(v, bool) else json.dumps(v)) for k, v in config.items())
        target.writestr(prefix + 'tests/radar_idle_config.lua', 'return {' + values + '}\n')
    with zipfile.ZipFile(mods / archive.name) as tested:
        assert all(digest(tested.read(n)) == h for n, h in unchanged.items())
    companion = mods / 'tc-smoke_0.0.1'; companion.mkdir()
    (companion / 'info.json').write_text(json.dumps(dict(name='tc-smoke', version='0.0.1', title='Idle diagnostic', author='test', factorio_version='2.1', dependencies=['base', 'tweaked-computers'])))
    (companion / 'control.lua').write_text('-- Owning-mod fixture.\n')
    (companion / 'settings.lua').write_text("data:extend{{type='string-setting',name='tc-smoke-production-fixture',setting_type='startup',default_value='tests.monitor_animation_engine',allowed_values={'tests.monitor_animation_engine'}}}\n")
    enabled = ['base', 'tweaked-computers', 'tc-smoke'] + (['space-age', 'quality', 'elevated-rails', 'recycler'] if mode == 'space-age' else [])
    (mods / 'mod-list.json').write_text(json.dumps({'mods': [dict(name=n, enabled=n in enabled) for n in ['base', 'tweaked-computers', 'tc-smoke', 'space-age', 'quality', 'elevated-rails', 'recycler']]}))
    cfg = folder / 'config.ini'
    cfg.write_text(f'[path]\nread-data={engine.resolve().parents[2] / "data"}\nwrite-data={write}\n[other]\ncheck-updates=false\n')
    provenance = dict(source_sha256=digest(archive.read_bytes()), test_sha256=digest((mods / archive.name).read_bytes()), changed_payloads=sorted(changes), unchanged_payloads=unchanged, expected_hooks=expected_hooks)
    (folder / 'provenance.json').write_text(json.dumps(provenance, indent=2))
    return [str(engine), '--config', str(cfg), '--mod-directory', str(mods)]


def extract(text, repetitions, profile):
    assert text.count('TC_IDLE_DONE') == repetitions
    assert len(re.findall(r'TC_IDLE_CASE_DONE count=', text)) == repetitions * 4
    measurements = re.findall(r'TC_IDLE count=(\d+) sample=(\d+) tick=(\d+) visits=(\d+)', text)
    assert len(measurements) == repetitions * 1200
    header = None; timings = []
    for line in text.splitlines():
        if line.startswith('tick,timestamp,wholeUpdate,'):
            header = next(csv.reader([line]))
        elif header and re.match(r'^t\d+,', line):
            timings.append(dict(zip(header, next(csv.reader([line])))))
    assert len(timings) == 1440 * repetitions
    assert [r['tick'] for r in timings] == ['t' + str(i) for i in range(1440)] * repetitions
    # Unit sanity only: engine totals also include work outside wholeUpdate.
    totals = [float(v) for v in re.findall(r'Performed 1440 updates in ([0-9.]+) ms', text)]
    assert len(totals) == repetitions
    assert .5 < sum(float(r['wholeUpdate']) / 1e6 for r in timings) / sum(totals) < 2
    result = []
    for count in (0, 100, 500, 1000):
        selected = [(int(s), int(t), int(v)) for n, s, t, v in measurements if int(n) == count]
        assert [s for s, _, _ in selected] == list(range(1, 301)) * repetitions
        row = dict(radars=count, samples=len(selected), dormant_visits=distribution([v for _, _, v in selected]) if profile else None)
        measured_ticks = {t for _, t, _ in selected}
        native = [r for r in timings if int(r['tick'][1:]) in measured_ticks]
        assert len(native) == 300 * repetitions
        row['native_ms'] = {k: distribution([float(r[k]) / 1e6 for r in native]) for k in ('wholeUpdate', 'scriptUpdate', 'Radar', 'luaGarbageIncremental')}
        profiles = {}
        for n, sample, tick, phase, duration in re.findall(r'TC_IDLE count=(\d+) sample=(\d+) tick=(\d+) phase=(\S+) Duration: ([0-9.]+)ms', text):
            if int(n) == count:
                profiles.setdefault(phase, []).append(float(duration))
        if profile:
            assert profiles and all(len(v) == 300 * repetitions for v in profiles.values())
            row['phase_ms'] = {k: distribution(v) for k, v in profiles.items()}
        result.append(row)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('factorio', 'baseline', 'archive', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--modes', nargs='+', choices=('base', 'space-age'), default=['base', 'space-age'])
    parser.add_argument('--workloads', nargs='+', choices=('zero', 'network'), default=['zero', 'network'])
    parser.add_argument('--histories', nargs='+', choices=('fresh', 'detached'), default=['fresh', 'detached'])
    parser.add_argument('--power', nargs='+', choices=('off', 'on'), default=['off', 'on'])
    parser.add_argument('--variants', nargs='+', choices=('baseline', 'candidate'), default=['baseline', 'candidate'])
    parser.add_argument('--profiles', nargs='+', choices=('total', 'phases'), default=['total', 'phases'])
    parser.add_argument('--repetitions', type=int, default=2)
    args = parser.parse_args()
    assert 1 <= args.repetitions <= 5
    assert digest(args.baseline.read_bytes()) == TRACKING_SHA256
    assert not args.output.exists() and not args.output.resolve().is_relative_to(ROOT)
    args.output.mkdir(parents=True)
    version = subprocess.check_output([str(args.factorio), '--version'], text=True)
    assert version.startswith('Version: 2.1.23 ')
    environment = dict(version=version, engine_sha256=digest(args.factorio.read_bytes()), command=sys.argv,
                       lscpu=subprocess.check_output(['lscpu'], text=True), runner_sha256=digest(Path(__file__).read_bytes()))
    (args.output / 'environment.json').write_text(json.dumps(environment, indent=2))
    cases = []
    for mode, workload, history, power, profile, variant in itertools.product(args.modes, args.workloads, args.histories, args.power, args.profiles, args.variants):
        name = '-'.join((mode, workload, history, power, profile, variant))
        folder = args.output / name
        config = dict(workload=workload, history=history, powered=power == 'on', profile=profile == 'phases', candidate=variant == 'candidate')
        archive = args.archive if config['candidate'] else args.baseline
        base = prepare(archive, folder, args.factorio, mode, config)
        commands = [base + ['--create', str(folder / 'idle.zip'), '--map-gen-seed', '1'],
                    base + ['--benchmark', str(folder / 'idle.zip'), '--benchmark-ticks', '1440', '--benchmark-runs', str(args.repetitions), '--benchmark-verbose', 'all']]
        (folder / 'commands.json').write_text(json.dumps(commands, indent=2))
        host = []; stop = threading.Event(); watcher = threading.Thread(target=contention, args=(stop, host)); watcher.start()
        try:
            for label, command in zip(('create', 'benchmark'), commands):
                with (folder / (label + '.log')).open('w') as log:
                    process = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=300)
                assert process.returncode == 0, str(folder / (label + '.log'))
        finally:
            stop.set(); watcher.join()
            (folder / 'contention.json').write_text(json.dumps(host, indent=2))
        rows = extract((folder / 'benchmark.log').read_text(), args.repetitions, config['profile'])
        if config['profile']:
            expected = json.loads((folder / 'provenance.json').read_text())['expected_hooks'] + 1
            assert all(len(r['phase_ms']) == expected for r in rows)
            if config['candidate']:
                assert all(r['dormant_visits']['max'] == 0 for r in rows)
        case = dict(name=name, mode=mode, config=config, rows=rows, exit_codes=[0, 0])
        cases.append(case)
        (args.output / 'summary.json').write_text(json.dumps(dict(cases=cases), indent=2))
        print(json.dumps(dict(name=name, passed=True, rows=len(rows))), flush=True)


if __name__ == '__main__':
    main()
