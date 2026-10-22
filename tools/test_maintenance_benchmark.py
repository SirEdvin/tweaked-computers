#!/usr/bin/env python3
"""Small host-only regressions for counting and explicit idle-window comparison."""
import copy
import unittest

from maintenance_benchmark import complete_profiles, distribution
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
    def test_profiles_match_registered_inventory(self):
        names = ['scheduler', 'dispatch', 'advance_timers', 'render/extra']
        samples = {name: {1: 0.1, 2: 0.2} for name in names}
        self.assertTrue(complete_profiles(samples, [names], 2))
        self.assertFalse(complete_profiles(samples, [], 2))
        self.assertFalse(complete_profiles(samples, [names, names], 2))
        self.assertFalse(complete_profiles(samples, [names + ['render/extra']], 2))
        self.assertFalse(complete_profiles(samples, [names[:-1]], 2))
        self.assertFalse(complete_profiles({**samples, 'unknown': {1: .1, 2: .2}}, [names], 2))
        samples['dispatch'].pop(2)
        self.assertFalse(complete_profiles(samples, [names], 2))

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
