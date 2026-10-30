#!/usr/bin/env python3
"""Explicitly instrument native visibility boundaries for structural tests only.

Never use this archive for whole-scheduler timings: production presentation Lua
is instrumented, while all other nonfixture payloads must remain byte-identical.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def visibility_source(source):
    for assignment in ('o.visible=value ', 'o.visible=values[i] '):
        if source.count(assignment) != 1:
            raise ValueError('review structural visibility instrumentation against changed presenter')
        source = source.replace(assignment, 'demand_observer.visibility(); ' + assignment)
    return "local demand_observer=require('tests.monitor_demand_counters'); demand_observer.instrumented=true\n" + source


def provider_source(source):
    for marker, counter in (("local function signature(tiles)\n", 'topology'),
                            ("if proofs and proofs[g]==g.members then return true end\n", 'full_proofs')):
        if source.count(marker) != 1:
            raise ValueError('review structural topology/proof instrumentation against changed provider')
        source = source.replace(marker, marker + "  demand_observer.count('" + counter + "')\n")
    return "local demand_observer=require('tests.monitor_demand_counters')\n" + source


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--factorio', type=Path, required=True)
    ap.add_argument('--archive', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--mode', choices=('base', 'space-age', 'both'), default='both')
    args = ap.parse_args()
    folder = args.output.resolve()
    if folder.exists() or folder.is_relative_to(ROOT):
        ap.error('use a fresh output directory outside git')
    folder.mkdir(parents=True)
    target = folder / args.archive.name
    with zipfile.ZipFile(args.archive) as src:
        prefix = next(n[:-len('info.json')] for n in src.namelist() if n.endswith('/info.json'))
        changes = {'scripts/monitor-presentation.lua': visibility_source(
            src.read(prefix + 'scripts/monitor-presentation.lua').decode()).encode()}
        changes['scripts/services/monitor.lua'] = provider_source(
            src.read(prefix + 'scripts/services/monitor.lua').decode()).encode()
        for name in ('engine', 'observer', 'counters'):
            path = 'tests/monitor_demand_' + name + '.lua'
            changes[path] = (ROOT / path).read_bytes()
        control = src.read(prefix + 'control.lua').decode()
        if "require('tests.monitor_demand_observer')" not in control:
            marker = "local scheduler = require('scripts.scheduler')"
            assert control.count(marker) == 1
            control = control.replace(marker, marker + "\nif script.active_mods['tc-smoke'] and settings.startup['tc-smoke-production-fixture'] and settings.startup['tc-smoke-production-fixture'].value=='tests.monitor_demand_engine' then require('tests.monitor_demand_observer') end")
            marker = 'local monitor_state_fixture={'
            assert control.count(marker) == 1
            control = control.replace(marker, marker + "['tests.monitor_demand_engine']=true,")
            changes['control.lua'] = control.encode()
        with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as dst:
            for entry in src.infolist():
                if entry.filename.removeprefix(prefix) not in changes:
                    dst.writestr(copy.copy(entry), src.read(entry.filename))
            for name, payload in changes.items():
                dst.writestr(prefix + name, payload)
    with zipfile.ZipFile(args.archive) as src, zipfile.ZipFile(target) as dst:
        assert all(src.read(n) == dst.read(n) for n in src.namelist() if n.removeprefix(prefix) not in changes)
        assert all(dst.read(prefix + n) == payload for n, payload in changes.items())
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    record = {'archive_sha256': digest(args.archive), 'instrumented_sha256': digest(target),
              'structural_only': True, 'instrumentation_sha256': {
                  n: hashlib.sha256(v).hexdigest() for n, v in changes.items()}}
    (folder / 'provenance.json').write_text(json.dumps(record, indent=2) + '\n')
    result = subprocess.run([sys.executable, str(ROOT / 'tools/smoke.py'), '--factorio', str(args.factorio),
                             '--archive', str(target), '--output', str(folder / 'engine'), '--mode', args.mode,
                             '--fixture', 'tests.monitor_demand_engine', '--production-context', '--cold'], check=False)
    expected = ['base', 'space-age'] if args.mode == 'both' else [args.mode]
    receipts = []
    for mode in expected:
        passes = []
        physical = []
        for phase in ('cold-first', 'cold-second'):
            path = folder / 'engine' / mode / (phase + '-engine.log')
            if path.exists():
                passes += re.findall(r'TC_DEMAND_PASS phase=(\S+) samples=(\d+) tiles=(\d+)', path.read_text())
                physical += re.findall(r'TC_DEMAND_PHYSICAL_PASS case=(\S+)', path.read_text())
        receipts.append({'mode': mode, 'passes': passes, 'physical': physical})
    complete = all(sorted(r['passes']) == sorted((p, '8', '144') for p in ('idle', 'cold-idle', 'outage', 'restored', 'one', 'all')) for r in receipts)
    complete = complete and all(sorted(r['physical']) == sorted(('move', 'rotate', 'force', 'surface-clone', 'ownership')) for r in receipts)
    code = result.returncode or (0 if complete else 1)
    record.update(exit_code=code, receipts=receipts)
    (folder / 'summary.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))
    raise SystemExit(code)


if __name__ == '__main__':
    main()
