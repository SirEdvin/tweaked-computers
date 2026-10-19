"""Envelope receipt parsing must not mistake completed diagnostics for passes."""
import unittest

import envelope


class EnvelopeReceiptTests(unittest.TestCase):
    def test_false_gate_is_retained(self):
        text = ('TC_ENVELOPE_GATE {"name":"combined","passed":false,"detail":{"ticks":256}}\n'
                'TC_ENVELOPE_COLD_UNCHANGED\nTC_COLD_OK envelope-diagnostic-complete\n')
        receipt = envelope.summarize(text)
        self.assertTrue(receipt['completed'])
        self.assertTrue(receipt['cold_unchanged'])
        self.assertFalse(receipt['gates'][0]['passed'])

    def test_missing_or_duplicate_completion_is_not_complete(self):
        self.assertFalse(envelope.summarize('')['completed'])
        self.assertFalse(envelope.summarize('TC_COLD_OK envelope-diagnostic-complete\n' * 2)['completed'])

    def test_cpu_phases_and_counts_are_separate(self):
        text = ('TC_ENVELOPE_CPU tick=1 phase=maximum-grid Duration: 2.0ms\n'
                'TC_ENVELOPE_CPU tick=2 phase=maximum-grid Duration: 4.0ms\n'
                'TC_ENVELOPE_CPU tick=3 phase=subscriptions Duration: 9.0ms\n')
        profiles = envelope.summarize(text)['scheduler_profiles']
        self.assertEqual(profiles['maximum-grid']['samples'], 2)
        self.assertEqual(profiles['maximum-grid']['mean_ms'], 3)
        self.assertEqual(profiles['subscriptions']['samples'], 1)
        self.assertEqual(profiles['subscriptions']['max_ms'], 9)


if __name__ == '__main__':
    unittest.main()
