"""Focused source-instrumentation guard; native assertions live in the engine."""
from pathlib import Path
import unittest

from monitor_demand import provider_source, visibility_source


class VisibilityInstrumentationTests(unittest.TestCase):
    def test_both_native_boundaries_in_actual_presenter(self):
        source = (Path(__file__).resolve().parents[1] / 'scripts/monitor-presentation.lua').read_text()
        instrumented = visibility_source(source)
        self.assertEqual(instrumented.count('demand_observer.visibility();'), 2)
        self.assertEqual(instrumented.split('\n', 1)[1].replace('demand_observer.visibility(); ', ''), source)

    def test_missing_or_duplicated_boundary_is_not_silently_unobserved(self):
        for source in ('o.visible=value ', 'o.visible=value o.visible=values[i] o.visible=values[i] '):
            with self.assertRaises(ValueError):
                visibility_source(source)

    def test_actual_topology_and_nonreused_proof_boundaries(self):
        source = (Path(__file__).resolve().parents[1] / 'scripts/services/monitor.lua').read_text()
        instrumented = provider_source(source)
        self.assertEqual(instrumented.count("demand_observer.count('topology')"), 1)
        self.assertEqual(instrumented.count("demand_observer.count('full_proofs')"), 1)
        recovered = instrumented.split('\n', 1)[1]
        for name in ('topology', 'full_proofs'):
            recovered = recovered.replace("  demand_observer.count('" + name + "')\n", '')
        self.assertEqual(recovered, source)
        with self.assertRaises(ValueError):
            provider_source('')


if __name__ == '__main__':
    unittest.main()
