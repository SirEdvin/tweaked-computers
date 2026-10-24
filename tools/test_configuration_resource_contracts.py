#!/usr/bin/env python3
"""Keep generated Configurator schemas and player contracts in agreement."""
import unittest

import configuration_catalog
import player_docs


class ConfigurationResourceContractsTests(unittest.TestCase):
    def test_generated_schema_has_no_shape_capacities(self):
        files = configuration_catalog.generate()
        schema = files[configuration_catalog.ROOT / 'scripts/configuration/catalog.lua']
        for obsolete in ('max_items', 'max_bytes', 'no_nul'):
            self.assertNotIn(obsolete, schema)
        self.assertIn('["max"]=65535', schema)
        self.assertIn('["max"]=2147483647', schema)
        self.assertIn('["max"]=3.4028234663852886e+38', schema)
        self.assertIn('["additional_fields"]=false', schema)
        self.assertIn('registered_signal', schema)

    def test_player_schemas_do_not_reintroduce_removed_capacities(self):
        pages = player_docs.generated()
        for name in ('api/settings.md', 'api/schemas.md'):
            with self.subTest(page=name):
                page = pages[name]
                for obsolete in ('≤256', '≤128', 'at most 128', 'at most 256', '1–128', 'no NUL', 'cannot contain NUL'):
                    self.assertNotIn(obsolete, page)
        schema = pages['api/schemas.md']
        self.assertIn('1–65535', schema)
        self.assertIn('configured resource', schema)
        self.assertIn('default_import_location', schema)
        self.assertNotIn('nauvis is the default', schema)
        self.assertIn('Unknown fields are refused', schema)
        self.assertIn('Arrays are dense', schema)


if __name__ == '__main__':
    unittest.main()
