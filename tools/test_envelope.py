"""Envelope receipt parsing must not mistake completed diagnostics for passes."""
import unittest
import io
import zipfile

import envelope


class EnvelopeReceiptTests(unittest.TestCase):
    def test_forwarding_observer_is_explicit_and_requires_exact_source(self):
        source = (envelope.ROOT / 'scripts/monitor-presentation.lua').read_bytes()
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as package:
            package.writestr('test/scripts/monitor-presentation.lua', source)
        with zipfile.ZipFile(data) as package:
            replacements = envelope.combined_replacements(package, 'test/')
        instrumented = replacements['scripts/monitor-presentation.lua']
        for probe in (b'envelope_observer.prepare()', b'envelope_observer.cleanup()', b'envelope_observer.commit(#operations,work)'):
            self.assertEqual(instrumented.count(probe), 1)
        self.assertIn(b'native=false', replacements['tests/envelope_config.lua'])
        altered = io.BytesIO()
        with zipfile.ZipFile(altered, 'w') as package:
            package.writestr('test/scripts/monitor-presentation.lua',
                             source.replace(b'spend(48); backend.cell(c,r,index);', b'changed preparation path'))
        with zipfile.ZipFile(altered) as package, self.assertRaises(AssertionError):
            envelope.combined_replacements(package, 'test/')

    def test_duplicate_or_wrong_gate_names_cannot_close_a_campaign(self):
        case = {'completed': True, 'cold_unchanged': True, 'simultaneous': [{}],
                'gates': [{'name': n, 'passed': True} for n in
                          ('combined-active-subscriptions', 'simultaneous-service', 'continuous-final-256')]}
        self.assertTrue(envelope.case_complete(case, 'combined', 'representative'))
        case['gates'][2]['name'] = 'simultaneous-service'
        self.assertFalse(envelope.case_complete(case, 'combined', 'representative'))

    def test_representative_profile_is_small_and_maximum_remains_opt_in(self):
        self.assertEqual(envelope.PROFILES['representative'],
                         {'computers': 4, 'subscriptions': 1, 'maximum': False})
        self.assertIn(b'computers=4,subscriptions=1,maximum=false', envelope.fixture_source('representative'))
        self.assertIn(b'computers=64,subscriptions=16,maximum=true', envelope.fixture_source('maximum'))

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
