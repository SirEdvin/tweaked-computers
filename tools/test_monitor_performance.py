"""Host-only performance harness/provenance tests; not native timing evidence."""
import hashlib
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile

import build
import monitor_performance


class PerformanceInvocationTests(unittest.TestCase):
    def invoke(self, scene='all', modes=('base', 'space-age'), samples=600, markers=1):
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as directory:
            root = Path(directory)
            archive = build.build(root / 'package')
            output = root / 'result'

            def simulate(command, **kwargs):
                self.assertIn('--cold', command)
                self.assertIn('--production-context', command)
                engine = Path(command[command.index('--output') + 1])
                for mode in modes:
                    folder = engine / mode
                    folder.mkdir(parents=True)
                    (folder / 'cold-second-engine.log').write_text(
                        ''.join(f'TC_PERF_CPU tick={i} Duration: 1.0ms\n' for i in range(samples))
                        + 'TC_PERF_DONE ticks=600 publications=10 visible_changes=10 max_gap=2 peak_objects=10\n' * markers)
                return SimpleNamespace(returncode=0)

            argv = ['monitor_performance.py', '--factorio', str(root / 'unused-engine'),
                    '--archive', str(archive), '--output', str(output), '--mode', 'both',
                    '--scene', scene, '--ticks', '600']
            with patch('sys.argv', argv), patch.object(monitor_performance.subprocess, 'run', side_effect=simulate):
                with self.assertRaises(SystemExit) as stopped:
                    monitor_performance.main()
            if stopped.exception.code == 2:
                self.fail('scene selection is not implemented')
            record = json.loads((output / 'summary.json').read_text())
            self.assertEqual(record['scene'], scene)
            with zipfile.ZipFile(archive) as original, zipfile.ZipFile(output / archive.name) as tested:
                prefix = next(n[:-len('info.json')] for n in original.namelist() if n.endswith('/info.json'))
                replacements = record['test_only_replacements']
                for name in original.namelist():
                    if name.removeprefix(prefix) not in replacements:
                        self.assertEqual(original.read(name), tested.read(name), name)
                for name, digest in replacements.items():
                    self.assertEqual(hashlib.sha256(tested.read(prefix + name)).hexdigest(), digest)
                guest = tested.read(prefix + 'tests/monitor_animation_source.lua').decode()
                self.assertIn(scene, tested.read(prefix + 'tests/monitor_performance_config.lua').decode())
                if scene == 'one':
                    self.assertIn('refs = {refs[1]}', guest)
            return stopped.exception.code

    def test_each_scene_preserves_nonfixture_payloads(self):
        for scene in ('zero', 'idle', 'one', 'all'):
            with self.subTest(scene=scene):
                self.assertEqual(self.invoke(scene), 0)

    def test_exact_receipt_inventory(self):
        for modes, samples, markers in ((('base',), 600, 1), (('base', 'unexpected'), 600, 1),
                                        (('base', 'space-age'), 599, 1),
                                        (('base', 'space-age'), 600, 0),
                                        (('base', 'space-age'), 600, 2)):
            with self.subTest(modes=modes, samples=samples, markers=markers):
                self.assertEqual(self.invoke(modes=modes, samples=samples, markers=markers), 1)


if __name__ == '__main__':
    unittest.main()
