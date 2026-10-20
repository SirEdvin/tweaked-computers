#!/usr/bin/env python3
"""Count and summarize retained maintenance experiments, without running Factorio."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

from maintenance_benchmark import distribution


def canonical_records(result):
    # Timing instrumentation must not change authoritative work or visible images.
    records = result['records']
    return {key: sorted(records.get(key, []), key=lambda row: json.dumps(row, sort_keys=True))
            for key in ('BEGIN', 'SAMPLE', 'INPUT', 'OUTPUT', 'PUBLICATION', 'STATES', 'DONE', 'CLEANUP')}


def idle_window_equivalent(reference, candidate):
    # Very fast idle cold processes can resume 1..3 native ticks apart. Preserve
    # that raw mismatch; compare overlapping actual ticks, full-window work and
    # final state, rather than relabelling absolute ticks as equal observations.
    a, b = canonical_records(reference), canonical_records(candidate)
    if any(a[key] != b[key] for key in ('INPUT', 'OUTPUT', 'PUBLICATION', 'STATES', 'DONE', 'CLEANUP')):
        return False
    if reference['progress'] != candidate['progress']:
        return False
    begin_a = {k: v for k, v in a['BEGIN'][0].items() if k != 'tick'}
    begin_b = {k: v for k, v in b['BEGIN'][0].items() if k != 'tick'}
    if begin_a != begin_b or abs(a['BEGIN'][0]['tick'] - b['BEGIN'][0]['tick']) > 3:
        return False
    ticks_a = {r['tick']: {k: v for k, v in r.items() if k != 'index'} for r in a['SAMPLE']}
    ticks_b = {r['tick']: {k: v for k, v in r.items() if k != 'index'} for r in b['SAMPLE']}
    overlap = ticks_a.keys() & ticks_b.keys()
    if len(overlap) < len(ticks_a) - 3 or any(ticks_a[t] != ticks_b[t] for t in overlap):
        return False
    for key in ('maintenance', 'guest', 'reserved', 'refused', 'faults', 'publications', 'retired', 'staging'):
        if sorted(r[key] for r in a['SAMPLE']) != sorted(r[key] for r in b['SAMPLE']):
            return False
    return True


def host_contention(paths):
    busy, steal, iowait, load, pressure = [], [], [], [], []
    counts = []
    for path in paths:
        records = json.loads((Path(path) / 'contention.json').read_text())
        counts.append(len(records))
        for record in records:
            load.append(record['loadavg'][0])
            pressure.append(float(record['pressure_cpu'].splitlines()[0].split('avg10=')[1].split()[0]))
        for a, b in zip(records, records[1:]):
            before = list(map(int, a['stat'].split()[1:9]))
            after = list(map(int, b['stat'].split()[1:9]))
            delta = [y-x for x, y in zip(before, after)]
            total = sum(delta)
            if total > 0:
                busy.append(100*(total-delta[3]-delta[4])/total)
                steal.append(100*delta[7]/total)
                iowait.append(100*delta[4]/total)
    return {'scope': 'whole isolated case, including startup/save/shutdown; not scheduler-only',
            'records_per_case': counts, 'busy_percent_all_vcpus': distribution(busy),
            'steal_percent': distribution(steal), 'iowait_percent': distribution(iowait),
            'load1': distribution(load), 'cpu_pressure_some_avg10_percent': distribution(pressure)}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--profiled', type=Path, required=True)
    ap.add_argument('--control', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    if args.output.exists():
        ap.error('use a fresh summary directory')
    args.output.mkdir(parents=True)
    groups = {}
    all_cases = []
    source_archives = set()
    source_heads = set()
    harness_hashes = set()
    unchanged_hashes = set()
    settings = set()
    for source in (args.profiled, args.control):
        matrix = json.loads((source / 'summary.json').read_text())
        environment = json.loads((source / 'environment.json').read_text())
        source_heads.add(environment['source_head'])
        assert len(matrix['cases']) == matrix['count']
        identities = set()
        for brief in matrix['cases']:
            path = Path(brief['path'])
            case = json.loads((path / 'result.json').read_text())
            identity = (case['mode'], case['workload'], case['budget'], case['repetition'])
            assert identity not in identities, 'duplicate experimental identity'
            identities.add(identity)
            provenance = json.loads((path / 'provenance.json').read_text())
            source_archives.add(provenance['candidate_sha256'])
            harness_hashes.add(tuple((key, value) for key, value in sorted(provenance['overrides_sha256'].items())
                                     if key != 'tests/maintenance_benchmark_config.lua'))
            unchanged_hashes.add(hashlib.sha256(json.dumps(provenance['unchanged_payload_sha256'], sort_keys=True).encode()).hexdigest())
            actual = case['configuration'][0]['limits'].copy()
            actual.pop('maintenance_work_per_tick')
            settings.add(json.dumps(actual, sort_keys=True))
            key = identity[:3]
            groups.setdefault(key, {'profiled': [], 'control': []})['profiled' if case['profile'] else 'control'].append(case)
            all_cases.append(case)
    assert len(source_archives) == len(source_heads) == len(harness_hashes) == len(unchanged_hashes) == len(settings) == 1
    rows = []
    for (mode, workload, budget), group in sorted(groups.items()):
        profiled, control = group['profiled'], group['control']
        assert len(profiled) == 3 and len(control) == 1, 'expected three profiled repeats and one low-instrumentation control'
        reference = canonical_records(profiled[0])
        matched = all(canonical_records(case) == reference for case in profiled + control)
        equivalent = matched or workload == 'idle' and all(idle_window_equivalent(profiled[0], case) for case in profiled + control)
        phases = {}
        for phase in profiled[0]['phase_cpu_samples_ms']:
            phases[phase] = distribution([value for case in profiled for value in case['phase_cpu_samples_ms'][phase]])
        samples = [row for case in profiled for row in case['records']['SAMPLE']]
        publications = [row for case in profiled for row in case['records'].get('PUBLICATION', [])]
        inputs = [row for case in profiled for row in case['records'].get('INPUT', [])]
        topology = profiled[0]['topology'][0]
        row = {'mode': mode, 'workload': workload, 'budget': budget, 'guest_headroom': 5000000-budget,
               'repetitions': len(profiled), 'samples': len(samples), 'topology': topology,
               'functional_passes': sum(case['functional_pass'] for case in profiled),
               'structural_passes': sum(case['structural_pass'] for case in profiled),
               'control_matches': matched, 'control_work_equivalent': equivalent,
               'measurement_begin_ticks': [case['records']['BEGIN'][0]['tick'] for case in profiled + control],
               'cpu_ms': phases,
               'control_cpu_ms': control[0]['cpu_ms']['scheduler'],
               'maintenance': distribution([s['maintenance'] for s in samples]),
               'guest': distribution([s['guest'] for s in samples]),
               'maintenance_refusals_measured': sum(case['refusal_count'] for case in profiled),
               'first_phase_faults': sum(len(case['first_phase_faults']) for case in profiled),
               'first_phase_refusals': sum(sum(r['refused'] for r in case['first_phase_refusals']) for case in profiled),
               'publication_count': len(publications),
               'changed_first_rows': sum(r['first_row_changed'] for r in publications),
               'publication_gaps': distribution([r['gap'] for r in publications]),
               'publication_latency': distribution([r['latency'] for r in publications]),
               'input_count': len(inputs), 'input_latency': distribution([r['latency'] for r in inputs]),
               'progress_each': [case['progress'] for case in profiled],
               'native_output_records_each': [len(case['records'].get('OUTPUT', [])) for case in profiled],
               'cleanup_ticks': [case['records']['CLEANUP'][0]['ticks'] for case in profiled],
               'peak_retired': max(s['retired'] for s in samples),
               'peak_staging': max(s['staging'] for s in samples),
               'paths': [case['path'] for case in profiled + control]}
        rows.append(row)
    receipts = [receipt for case in all_cases for receipt in case['shutdown']]
    counted = {'cases': len(all_cases), 'profiled_cases': sum(c['profile'] for c in all_cases),
               'control_cases': sum(not c['profile'] for c in all_cases),
               'samples': sum(c['sample_count'] for c in all_cases),
               'profiled_samples': sum(c['sample_count'] for c in all_cases if c['profile']),
               'control_samples': sum(c['sample_count'] for c in all_cases if not c['profile']),
               'shutdown_phases': len(receipts),
               'all_shutdown_clean': all(r['passed'] and r['exit_code'] == 0 and r['cleanup']['console_quit_acknowledged']
                                        and not r['cleanup']['sigint_attempted'] and not r['cleanup']['forced_kill'] for r in receipts),
               'all_structural_pass': all(c['structural_pass'] for c in all_cases),
               'functional_failures': sum(not c['functional_pass'] for c in all_cases),
               'all_controls_match': all(r['control_matches'] for r in rows),
               'all_controls_work_equivalent': all(r['control_work_equivalent'] for r in rows),
               'strictly_matched_groups': sum(r['control_matches'] for r in rows),
               'source_head': next(iter(source_heads)), 'archive_sha256': next(iter(source_archives))}
    host = host_contention([case['path'] for case in all_cases])
    (args.output / 'aggregate.json').write_text(json.dumps({'counts': counted, 'host': host, 'groups': rows}, indent=2) + '\n')
    with (args.output / 'overview.csv').open('w') as stream:
        columns: tuple[str, ...] = ('mode', 'workload', 'budget', 'samples', 'functional_passes', 'mean_ms', 'median_ms', 'p95_ms', 'max_ms',
                   'control_mean_ms', 'maintenance_peak', 'guest_peak', 'input_count', 'input_max_ticks',
                   'publication_count', 'publication_max_gap', 'control_matches')
        writer = csv.DictWriter(stream, fieldnames=columns)
        writer.writeheader()
        for row in rows:
            cpu = row['cpu_ms']['scheduler']
            writer.writerow({**{k: row[k] for k in columns if k in row},
                             **{k+'_ms': cpu[k] for k in ('mean', 'median', 'p95', 'max')},
                             'control_mean_ms': row['control_cpu_ms']['mean'], 'maintenance_peak': row['maintenance']['max'],
                             'guest_peak': row['guest']['max'], 'input_max_ticks': row['input_latency'].get('max'),
                             'publication_max_gap': row['publication_gaps'].get('max')})
    print(json.dumps(counted, indent=2))
    assert counted['all_shutdown_clean'] and counted['all_structural_pass'] and counted['all_controls_work_equivalent']


if __name__ == '__main__':
    main()
