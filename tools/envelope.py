#!/usr/bin/env python3
"""Run a counted envelope diagnostic, keeping completion distinct from acceptance."""
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
PROFILES = {'representative': {'computers': 4, 'subscriptions': 1, 'maximum': False},
            'maximum': {'computers': 64, 'subscriptions': 16, 'maximum': True}}


def fixture_source(profile):
    source = (ROOT / 'tests/envelope_engine.lua').read_text()
    marker = 'local profile = {computers=4,subscriptions=1,maximum=false} -- ENVELOPE_PROFILE'
    assert source.count(marker) == 1
    values = PROFILES[profile]
    replacement = ('local profile = {computers=%d,subscriptions=%d,maximum=%s}' %
                   (values['computers'], values['subscriptions'], str(values['maximum']).lower()))
    return source.replace(marker, replacement).encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def combined_replacements(package, prefix, native=False):
    replacements = {'tests/monitor_animation_engine.lua': b"return require('tests.envelope_combined')\n",
                    'tests/acceptance_monitor_engine.lua': b"return require('tests.envelope_combined')\n",
                    'tests/envelope_config.lua': ('return {native=%s}\n' % str(native).lower()).encode()}
    for name in ('envelope_combined', 'envelope_observer'):
        replacements['tests/' + name + '.lua'] = (ROOT / 'tests' / (name + '.lua')).read_bytes()
    source = "local envelope_observer=require('tests.envelope_observer')\n" + package.read(prefix + 'scripts/monitor-presentation.lua').decode()
    probes = {
        'spend(48); backend.cell(c,r,index);': 'spend(48); backend.cell(c,r,index); envelope_observer.prepare();',
        'r.cells[index]=false; i=i+1;': 'envelope_observer.cleanup(); r.cells[index]=false; i=i+1;',
        'for i,o in ipairs(operations) do o.visible=values[i] end': 'envelope_observer.commit(#operations,work); for i,o in ipairs(operations) do o.visible=values[i] end',
    }
    for old, new in probes.items():
        assert source.count(old) == 1, old
        source = source.replace(old, new)
    replacements['scripts/monitor-presentation.lua'] = source.encode()
    return replacements


def summarize(text):
    gates = [json.loads(m[1]) for m in re.finditer(r'TC_ENVELOPE_GATE (\{[^\n]+\})', text)]
    phases = {}
    for match in re.finditer(r'TC_ENVELOPE_CPU tick=(\d+) phase=([\w-]+) Duration: ([0-9.]+)ms', text):
        phases.setdefault(match[2], []).append(float(match[3]))
    profiles = {}
    for phase, samples in phases.items():
        ordered = sorted(samples)
        profiles[phase] = {'samples': len(samples), 'mean_ms': statistics.fmean(samples),
                           'p95_ms': ordered[int((len(ordered) - 1) * .95)], 'max_ms': max(samples)}
    combined = [json.loads(m[1]) for m in re.finditer(r'TC_COMBINED_SIMULTANEOUS (\{[^\n]+\})', text)]
    return {'gates': gates, 'scheduler_profiles': profiles, 'simultaneous': combined,
            'completed': text.count('TC_COLD_OK envelope-diagnostic-complete') == 1,
            'cold_unchanged': text.count('TC_ENVELOPE_COLD_UNCHANGED') == 1}


def case_complete(case, campaign, profile):
    expected = {'combined-active-subscriptions', 'continuous-final-256'}
    expected.add('simultaneous-service' if campaign == 'combined' else
                 'maximum-grid-256' if profile == 'maximum' else 'initial-grid-256')
    names = [g['name'] for g in case['gates']]
    return (case['completed'] and case['cold_unchanged'] and len(names) == len(expected)
            and set(names) == expected
            and (campaign != 'combined' or len(case['simultaneous']) == 1))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--factorio', required=True, type=Path)
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--mode', choices=('base', 'space-age', 'both'), default='both')
    parser.add_argument('--profile', choices=tuple(PROFILES), default='representative',
                        help='small mixed factory by default; maximum is an optional diagnostic, not a release gate')
    parser.add_argument('--campaign', choices=('combined', 'phased'), default='combined')
    args = parser.parse_args()
    folder = args.output.resolve()
    if folder.exists() or folder.is_relative_to(ROOT):
        parser.error('use a fresh output directory outside the repository')
    folder.mkdir(parents=True)
    target = folder / args.archive.name
    replacements = {
        'tests/monitor_animation_engine.lua': b"return require('tests.envelope_engine')\n",
        'tests/envelope_engine.lua': fixture_source(args.profile),
    }
    with zipfile.ZipFile(args.archive) as src, zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as dst:
        prefix = next(n[:-len('info.json')] for n in src.namelist() if n.endswith('/info.json'))
        if args.campaign == 'combined':
            if args.profile != 'representative':
                parser.error('combined campaign uses the approved representative profile; use --campaign phased for optional maximum')
            replacements = combined_replacements(src, prefix)
        payload = {n.removeprefix(prefix): digest(src.read(n)) for n in src.namelist()}
        for entry in src.infolist():
            if entry.filename.removeprefix(prefix) not in replacements:
                dst.writestr(entry, src.read(entry.filename))
        for name, data in replacements.items():
            entry = zipfile.ZipInfo(prefix + name, (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            dst.writestr(entry, data)
    with zipfile.ZipFile(target) as tested:
        unchanged = all(digest(tested.read(prefix + name)) == sha for name, sha in payload.items()
                        if name not in replacements)
    assert unchanged
    command = [sys.executable, str(ROOT / 'tools/smoke.py'), '--factorio', str(args.factorio),
               '--archive', str(target), '--output', str(folder / 'engine'), '--mode', args.mode,
               '--fixture', 'tests.monitor_animation_engine', '--production-context', '--cold',
               '--cold-timeout', '180']
    provenance = {'profile': args.profile, 'campaign': args.campaign, 'workload': PROFILES[args.profile],
                  'archive_sha256': digest(args.archive.read_bytes()),
                  'test_archive_sha256': digest(target.read_bytes()),
                  'test_only_replacements': {name: digest(data) for name, data in replacements.items()},
                  'all_other_payloads_unchanged': unchanged, 'command': command,
                  'observer': 'Three test-only forwarding counters in presenter: prepared/cleaned cells and actual admitted visibility operations; common CPU overhead is included.' if args.campaign == 'combined' else None}
    (folder / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    with (folder / 'driver.log').open('w') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=False)
    modes = ('base', 'space-age') if args.mode == 'both' else (args.mode,)
    cases = []
    for mode in modes:
        logs = [folder / 'engine' / mode / f'{phase}-engine.log' for phase in ('cold-first', 'cold-second')]
        text = '\n'.join(path.read_text() for path in logs if path.exists())
        cases.append({'mode': mode, **summarize(text)})
    complete = result.returncode == 0 and all(case_complete(c, args.campaign, args.profile) for c in cases)
    summary = {**provenance, 'driver_exit': result.returncode, 'diagnostic_completed': complete,
               'envelope_passed': complete and all(g['passed'] for c in cases for g in c['gates']),
               'cases': cases,
               'limits': ['Test counters are common forwarding instrumentation, not an opaque engine CPU bound.',
                          'Headless publication is not native-client visible latency or a frozen simultaneous-capacity promise.']}
    (folder / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary))
    raise SystemExit(0 if summary['envelope_passed'] else 1)


if __name__ == '__main__':
    main()
