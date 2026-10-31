"""Host-only regressions; synthetic receipts are not engine evidence."""
import copy
import json
import os
import re
from pathlib import Path
import tempfile
import sys
import unittest
import zipfile

import build
import scheduling_benchmark as bench


def receipt(tag, value):
    return 'TC_SB_' + tag + ' ' + json.dumps(value) + '\n'


def log(lane='timing'):
    text = receipt('BEGIN', dict(tick=102, load_tick=100, client=False))
    text += receipt('DONE', dict(tick=103, samples=2, valid=True, dispatches=2))
    if lane == 'timing':
        text += 'tick,timestamp,wholeUpdate,other\nt0,0,9000000,0\nt1,0,1000000,0\nt2,0,3000000,0\nt3,0,9000000,0\n'
    elif lane == 'profile':
        for tick in (102, 103):
            for phase in ('scheduler', 'scheduler/dispatch', 'scheduler/advance_timers', 'sample/logic'):
                text += f'TC_SB_CPU tick={tick} phase={phase} Duration: 0.125ms\n'
    else:
        text += receipt('COUNTERS', dict(samples=2, values={'scheduler/visits': 4}))
    return text


class SchedulingBenchmarkTests(unittest.TestCase):
    def test_catalog_and_axes_are_complete_and_unique(self):
        quick = bench.matrix(['*'], True)
        self.assertEqual({c['name'] for c in quick}, {c['name'] for c in bench.catalog()})
        full = bench.matrix(['*'])
        self.assertEqual(len(full), len({c['id'] for c in full}))
        self.assertEqual({c['count'] for c in full if c['name'] == 'idle/monitor'}, {0, 64, 128, 256})
        self.assertEqual({c['count'] for c in full if c['name'] == 'idle/computer'}, {0, 64, 256, 1024})
        timers = [c for c in full if c['name'] == 'timer/future']
        self.assertEqual({(c['count'], c['timers']) for c in timers}, {(n, t) for n in (1, 8, 32, 64) for t in (1, 16)})
        self.assertEqual({c['shape'] for c in full if c['name'] == 'topology/rewire'}, {'chain', 'branch'})
        self.assertEqual({c['signals'] for c in full if c['name'] == 'signal/pulse'}, {1, 32})
        self.assertTrue(all(c['client'] for c in quick if c['name'].startswith('ui/')))

    def test_unmatched_selector_is_not_silently_omitted(self):
        for patterns in (['bogus'], ['empty/*', 'bogus']):
            with self.assertRaises(ValueError):
                bench.matrix(patterns)

    def test_command_timeout_fails_and_retains_command(self):
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as directory:
            path = Path(directory) / 'command.log'
            command = [sys.executable, '-c', 'import time; time.sleep(30)']
            self.assertEqual(bench.run_command(command, path, 0.1), -1)
            self.assertEqual(json.loads(path.with_suffix('.command.json').read_text()), command)

    def test_native_units_and_exact_window(self):
        result = bench.extract(log(), 2, 'timing', [])
        self.assertTrue(result['passed'])
        self.assertEqual(result['phase_samples_ms']['wholeUpdate'], [1, 3])
        self.assertEqual(result['cpu_ms']['wholeUpdate']['mean'], 2)

    def test_native_missing_duplicate_and_wrong_ticks_fail(self):
        for changed in (log().replace('t2,0,3000000,0\n', ''), log() + 't2,0,3000000,0\n', log().replace('t2,', 't4,'),
                        log().replace('3000000', 'nan'), log().replace('3000000', '-1')):
            self.assertFalse(bench.extract(changed, 2, 'timing', [])['passed'])

    def test_missing_duplicate_and_incomplete_receipts_fail(self):
        for changed in ('', log() + receipt('BEGIN', dict(tick=102)), log().replace('"samples": 2', '"samples": 1')):
            self.assertFalse(bench.extract(changed, 2, 'timing', [])['passed'])

    def test_failures_and_invalid_oracles_are_not_speedups(self):
        for changed in (log() + receipt('FAIL', dict(message='starved')), log().replace('"valid": true', '"valid": false')):
            self.assertFalse(bench.extract(changed, 2, 'timing', [])['passed'])

    def test_profile_inventory_and_sample_count(self):
        text = log('profile')
        self.assertTrue(bench.extract(text, 2, 'profile', ['sample/logic'])['passed'])
        self.assertFalse(bench.extract(text, 2, 'profile', ['sample/logic', 'render/new-hook'])['passed'])
        self.assertFalse(bench.extract(text.replace('phase=sample/logic', 'phase=wrong'), 2, 'profile', ['sample/logic'])['passed'])
        self.assertFalse(bench.extract(text + 'TC_SB_CPU tick=102 phase=scheduler Duration: 0.1ms\n', 2, 'profile', ['sample/logic'])['passed'])

    def test_manifest_summary_keeps_raw_evidence_separate(self):
        result = bench.extract(log(), 2, 'timing', [])
        result['done']['latency_ticks'] = [1, 3]
        summary = bench.compact(result)
        self.assertNotIn('phase_samples_ms', summary)
        self.assertEqual(summary['done']['latency_ticks']['mean'], 2)
        self.assertEqual(result['done']['latency_ticks'], [1, 3])
        self.assertIn('phase_samples_ms', result)

    def test_structure_has_no_timing_claim(self):
        result = bench.extract(log('structure'), 2, 'structure', [])
        self.assertTrue(result['passed'])
        self.assertEqual(result['cpu_ms'], {})
        self.assertEqual(result['counters'], {'scheduler/visits': 4})
        self.assertFalse(bench.extract(log(), 2, 'structure', [])['passed'])

    def test_structural_instrumentation_preserves_loop_and_fails_on_drift(self):
        source = 'for offset=0,n-1 do\nvisit()\nend\n'
        payload = bench.instrument('scripts/scheduler.lua', source)
        assert payload is not None
        instrumented = payload.decode()
        self.assertIn("for offset=0,n-1 do bench.count('scripts/scheduler.lua:visit');", instrumented)
        self.assertIn('visit()\nend', instrumented)
        with self.assertRaises(ValueError):
            bench.instrument('scripts/services/logic.lua', 'local function renamed() end')

    def test_hook_disposition_inventory_matches_production(self):
        hooks = set()
        for path in (bench.ROOT / 'scripts').rglob('*.lua'):
            hooks.update('/'.join(h) for h in re.findall(
                r"scheduler.register_phase\('([^']+)','([^']+)'", path.read_text()))
        documented = set(re.findall(r'\| `(lifecycle/[^`]+|sample/[^`]+|notifications/[^`]+|render/[^`]+)`',
                                    (bench.ROOT / 'docs/device-scheduling.md').read_text()))
        self.assertEqual(hooks, documented)

    def test_current_demand_counters_are_distinct_and_complete(self):
        expected = {
            'scripts/scheduler.lua': ('scheduler:ready-member', 'scheduler:due-timer-member'),
            'scripts/lifecycle.lua': ('physical:due-observation',),
            'scripts/services/logic.lua': ('signal:watched-input', 'signal:subscriber'),
            'scripts/services/peripheral.lua': ('output:owner',),
            'scripts/ui/editor.lua': ('ui:editor-due',),
            'scripts/ui/peripheral-inspector.lua': ('ui:inspector-due',),
            'scripts/ui/dashboard.lua': ('ui:dashboard-viewer',),
        }
        for path, counters in expected.items():
            source = (bench.ROOT / path).read_text()
            payload = bench.instrument(path, source)
            assert payload is not None
            payload = payload.decode()
            for key in counters:
                self.assertEqual(payload.count("bench.count('" + key + "')"), 1, (path, key))
            self.assertEqual(source.count('local rec=root.computers[item.id]'),
                             payload.count('local rec=root.computers[item.id]'))

    def test_prepared_archive_and_optional_dependency_are_exact(self):
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as directory:
            root = Path(directory)
            archive = build.build(root / 'package')
            case = bench.matrix(['ui/dashboard-chart-static'], True)[0]
            original = bench.sha(archive.read_bytes())
            for lane in bench.LANES:
                folder = root / lane
                cfg, mods, proof = bench.prepare(archive, folder, case, lane, 60, 60, 'base', Path('/engine/bin/x64/factorio'), False)
                self.assertEqual(bench.sha(archive.read_bytes()), original)
                self.assertEqual(proof['archive_sha256'], original)
                enabled = {m['name']: m['enabled'] for m in json.loads((mods / 'mod-list.json').read_text())['mods']}
                self.assertTrue(enabled['factorio-charts'])
                self.assertFalse(enabled['recycler'])
                self.assertFalse(enabled['space-age'])
                self.assertIn(str(folder / 'write'), cfg.read_text())
                with zipfile.ZipFile(archive) as src, zipfile.ZipFile(mods / archive.name) as dst:
                    prefix = src.namelist()[0].split('/')[0] + '/'
                    for entry in src.namelist():
                        relative = entry.removeprefix(prefix)
                        if relative not in proof['overrides_sha256']:
                            self.assertEqual(src.read(entry), dst.read(entry), relative)
                if lane != 'structure':
                    self.assertFalse(any(p.startswith('scripts/') for p in proof['overrides_sha256']))

    def test_markdown_is_standalone_and_excludes_failed_pairs(self):
        result = bench.extract(log(), 2, 'timing', [])
        result.update(key='baseline', case={'id': 'empty'}, mode='base', label='baseline', lane='timing', repetition=1, path='/evidence/a')
        other = copy.deepcopy(result)
        other.update(key='candidate', label='candidate')
        other['cpu_ms']['wholeUpdate']['mean'] = 1
        manifest: dict = dict(created='2026-10-29T12:00:00+00:00', source_head='abc', engine_version='2.1.23', host='test', command='test',
                        output='/evidence', warmup=60, ticks=2, repetitions=1, quick=True, expected=['baseline', 'candidate'], results=[result, other])
        report = bench.markdown(manifest)
        self.assertTrue(report.startswith('---\ntitle:'))
        self.assertIn('2/2 requested runs completed; 2 passed, 0 failed', report)
        self.assertIn('-50.00%', report)
        self.assertNotIn('|\n\n|', report)
        self.assertIn('```json\n{', report)
        other['passed'] = False
        self.assertNotIn('-50.00%', bench.markdown(manifest))
        manifest['results'].append(other)
        with self.assertRaises(ValueError):
            bench.markdown(manifest)


if __name__ == '__main__':
    unittest.main()
