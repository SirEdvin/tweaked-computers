#!/usr/bin/env python3
"""Small host-only regressions for counting and explicit idle-window comparison."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from maintenance_benchmark import PROFILE_PHASES, distribution, extract
from maintenance_benchmark_summary import canonical_records, idle_window_equivalent


def idle(start):
    samples = []
    for index, tick in enumerate(range(start, start+600), 1):
        samples.append({'index': index, 'tick': tick, 'beats': tick//60,
                        'maintenance': 1, 'guest': 7 if tick%60 == 0 else 0,
                        'reserved': 60000, 'refused': 0, 'faults': 0,
                        'publications': 0, 'retired': 0, 'staging': 0})
    return {'progress': {'beats': 10, 'changes': 0}, 'records': {
        'BEGIN': [{'tick': start-1, 'beats': 1, 'changes': 0}], 'SAMPLE': samples,
        'STATES': [[{'status': 'running', 'last': 660, 'beats': 11}]],
        'DONE': [{'samples': 600, 'faults': 0}], 'CLEANUP': [{'ticks': 1, 'retired': 0}]}}


class CountedBenchmarkTests(unittest.TestCase):
    def test_complete_current_hook_inventory(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp); engine = folder / 'engine'; case = engine / 'base'
            case.mkdir(parents=True)
            (engine / 'summary.json').write_text(json.dumps({'cases': [{'cold_phases': [{'passed': True}, {'passed': True}]}]}))
            samples = [{'tick': i, 'index': i, **dict.fromkeys(('maintenance', 'guest', 'reserved', 'refused', 'faults', 'retired', 'staging', 'beats', 'changes'), 0)} for i in (1, 2)]
            lines = ['TC_MB_SAMPLE '+json.dumps(row) for row in samples]
            lines += ['TC_MB_DONE {}', 'TC_MB_CLEANUP {}', 'TC_MB_BEGIN '+json.dumps({'beats': 0, 'changes': 0})]
            for phases, expected in ((PROFILE_PHASES, True), (PROFILE_PHASES - {'render/ui-dashboard'}, False), (PROFILE_PHASES | {'unexpected/hook'}, False)):
                cpu = [f'TC_MB_CPU tick={tick} phase={phase} Duration: 0.1ms' for phase in phases for tick in (1, 2)]
                (case / 'cold-second-engine.log').write_text('\n'.join(lines+cpu))
                self.assertEqual(extract(folder, 2, True)['structural_pass'], expected)

    def test_nearest_rank_and_empty(self):
        self.assertEqual(distribution([]), {'count': 0})
        self.assertEqual(distribution(list(range(1, 101)))['p95'], 95)
        self.assertEqual(distribution([2, 4])['mean'], 3)

    def test_actual_idle_ticks_remain_different(self):
        a, b = idle(100), idle(102)
        self.assertNotEqual(canonical_records(a), canonical_records(b))
        self.assertTrue(idle_window_equivalent(a, b))
        self.assertTrue(idle_window_equivalent(a, copy.deepcopy(a)))

    def test_changed_common_tick_rejected(self):
        candidate = idle(102)
        candidate['records']['SAMPLE'][10]['beats'] += 1
        self.assertFalse(idle_window_equivalent(idle(100), candidate))

    def test_changed_exclusive_tick_work_rejected(self):
        candidate = idle(102)
        candidate['records']['SAMPLE'][-1]['guest'] += 1
        self.assertFalse(idle_window_equivalent(idle(100), candidate))

    def test_changed_progress_and_final_state_rejected(self):
        for key in ('progress', 'state'):
            candidate = idle(102)
            if key == 'progress':
                candidate['progress']['beats'] += 1
            else:
                candidate['records']['STATES'][0][0]['last'] += 1
            self.assertFalse(idle_window_equivalent(idle(100), candidate))

    def test_large_window_shift_rejected(self):
        self.assertFalse(idle_window_equivalent(idle(100), idle(104)))


if __name__ == '__main__':
    unittest.main()
