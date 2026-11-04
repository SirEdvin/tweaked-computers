"""Derived public schemas must preserve the existing runtime normalization."""
import copy
import os
from pathlib import Path
import tempfile
import unittest

import configuration_catalog as catalog
from lua_api import export_api, api_records


class ConfigurationDeclarationsTests(unittest.TestCase):
    def test_runtime_catalogue_unchanged(self):
        outputs = catalog.generate()
        runtime = catalog.ROOT / 'scripts/configuration/catalog.lua'
        self.assertEqual(outputs[runtime], runtime.read_text())

    def test_generated_types_are_closed_and_described(self):
        generated = catalog.generate()[catalog.ROOT / 'api/generated/configurator.d.lua']
        self.assertTrue(all(line == line.rstrip() for line in generated.splitlines()))
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as work:
            root = Path(work)
            source = root / 'source'
            source.mkdir()
            (source / 'configurator.d.lua').write_text(generated)
            raw = export_api(source, Path(os.environ['LUALS_BIN']), root / 'export')
            records = api_records(raw)
        signal = records['TC.Config.SignalID']['fields']
        self.assertFalse(signal['name']['optional'])
        self.assertFalse(signal['type']['optional'])
        self.assertTrue(signal['quality']['optional'])
        self.assertIn('normal', signal['quality']['description'])
        self.assertNotIn('fulfilled', records['TC.Config.CircuitConditionDefinition']['fields'])
        self.assertIn('TC.Config.SignalFilter', records)
        self.assertIn('TC.Config.SectionFilter', records)
        self.assertIn('128', records['TC.Config.SectionFilter']['fields']['index']['description'])
        selector = records['TC.Config.SelectorCombinatorParameters']
        self.assertIn('quality-transfer', selector['description'])
        self.assertIn('quality_destination_signal', selector['description'])
        self.assertEqual(selector['kind'], 'alias')
        variants = records['TC.Config.SelectorCombinatorParameters.Count']['fields']
        self.assertEqual(set(variants), {'operation', 'count_signal'})
        self.assertFalse(variants['operation']['optional'])
        transfer = records['TC.Config.SelectorCombinatorParameters.QualityTransfer']['fields']
        self.assertFalse(transfer['quality_destination_signal']['optional'])
        default = records['TC.Config.SelectorCombinatorParameters.Select']['fields']
        self.assertTrue(default['operation']['optional'])
        self.assertNotIn('LuaQualityPrototype', generated)
        self.assertNotIn('LuaSpaceLocationPrototype', generated)
        self.assertIn('send_contents_and_set_requests', generated)
        output_signal = records['TC.Config.Read.SignalID']['fields']
        self.assertFalse(output_signal['quality']['optional'])
        self.assertNotIn('256', output_signal['name']['description'])
        self.assertEqual(records['TC.Config.Read.SignalFilter']['kind'], 'class')
        self.assertFalse(records['TC.Config.Read.SignalFilter']['fields']['comparator']['optional'])
        self.assertTrue(records['TC.Config.Read.DeciderCombinatorOutput']['fields']['signal']['optional'])
        read_transfer = records['TC.Config.Read.SelectorCombinatorParameters.QualityTransfer']['fields']
        self.assertTrue(read_transfer['quality_destination_signal']['optional'])
        self.assertFalse(read_transfer['select_quality_from_signal']['optional'])
        comparator = records['TC.Config.Read.ComparatorString']['type']
        self.assertNotIn('>=', str(comparator))
        self.assertIn('≥', str(comparator))

    def test_unknown_schema_kind_refused(self):
        normalized, metadata = catalog.normalized()
        broken = copy.deepcopy(normalized)
        broken['concepts']['SignalID']['kind'] = 'future-unsupported'
        with self.assertRaisesRegex(ValueError, 'unsupported'):
            catalog.typed_declarations(broken, metadata)

    def test_generation_deterministic(self):
        self.assertEqual(catalog.generate(), catalog.generate())


if __name__ == '__main__':
    unittest.main()
