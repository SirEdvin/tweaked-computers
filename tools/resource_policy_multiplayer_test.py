#!/usr/bin/env python3
"""Small regression checks for test-only instrumentation and real-process gates."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile
from resource_policy_multiplayer import instrument, wait


class HarnessTest(unittest.TestCase):
    def test_instrumentation_never_changes_production(self):
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as temporary:
            folder = Path(temporary); archive = folder / 'source.zip'
            original = {'info.json': json.dumps({'name': 'tweaked-computers', 'version': '0.1.13'}),
                        'control.lua': 'production control', 'scripts/runtime.lua': 'production runtime',
                        'tests/shell_client_engine.lua': 'return {}'}
            with zipfile.ZipFile(archive, 'w') as output:
                for name, content in original.items():
                    output.writestr('tweaked-computers_0.1.13/' + name, content)
            result = folder / 'instrumented/source.zip'
            receipt = instrument(archive, result, 'tests.resource_policy_multiplayer')
            self.assertTrue(receipt['production_payloads_unchanged'])
            self.assertNotEqual(receipt['source_archive_sha256'], receipt['instrumented_archive_sha256'])
            with zipfile.ZipFile(result) as output:
                for name in ('info.json', 'control.lua', 'scripts/runtime.lua'):
                    self.assertEqual(output.read('tweaked-computers_0.1.13/' + name).decode(), original[name])

    def test_process_exit_is_not_a_pass(self):
        process = subprocess.Popen([sys.executable, '-c', 'pass'])
        process.wait(timeout=10)
        with self.assertRaisesRegex(RuntimeError, 'process exited'):
            wait(lambda: True, 'connected', [process], timeout=1)

    def test_missing_marker_times_out(self):
        with self.assertRaisesRegex(RuntimeError, 'timeout'):
            wait(lambda: False, 'connected', timeout=.01)


if __name__ == '__main__':
    unittest.main()
