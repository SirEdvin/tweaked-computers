#!/usr/bin/env python3
"""Local optional-chart archive admission; synthetic ZIPs are never engine evidence."""
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

import smoke


class ChartArchiveTests(unittest.TestCase):
    def archive(self, folder, **changes):
        path = Path(folder) / 'charts.zip'
        manifest = dict(name='factorio-charts', version='1.2.0', factorio_version='2.1')
        manifest.update(changes)
        with zipfile.ZipFile(path, 'w') as archive:
            archive.writestr('factorio-charts_1.2.0/info.json', json.dumps(manifest))
            archive.writestr('factorio-charts_1.2.0/charts.lua', 'return {}')
        return path

    def test_identifies_exact_supported_release(self):
        with tempfile.TemporaryDirectory() as folder:
            result = smoke.chart_archive(self.archive(folder))
            self.assertEqual(result['version'], '1.2.0')
            self.assertEqual(len(result['sha256']), 64)

    def test_rejects_other_mod_version_and_engine(self):
        with tempfile.TemporaryDirectory() as folder:
            for changes in ({'name': 'other'}, {'version': '1.1.0'}, {'factorio_version': '2.0'}):
                with self.subTest(changes=changes), self.assertRaises(ValueError):
                    smoke.chart_archive(self.archive(folder, **changes))

    def test_rejects_missing_api_and_duplicate_manifest(self):
        with tempfile.TemporaryDirectory() as folder:
            path = self.archive(folder)
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('factorio-charts_1.2.0/info.json', '{}')
            with self.assertRaises(ValueError):
                smoke.chart_archive(path)
            path = self.archive(folder)
            with zipfile.ZipFile(path, 'a') as archive:
                archive.writestr('other/info.json', '{}')
            with self.assertRaises(ValueError):
                smoke.chart_archive(path)


if __name__ == '__main__':
    unittest.main()
