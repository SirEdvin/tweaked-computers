"""Host-only wrapper regression; not an engine/cadence acceptance test."""
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile

import build
import monitor_animation


class AnimationInvocationTests(unittest.TestCase):
    def test_sustained_contract_has_explicit_wall_time_without_payload_changes(self):
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as directory:
            root = Path(directory)
            archive = build.build(root / 'package')
            for layout, with_modem in ((layout, modem) for layout in ('four-walls', 'mixed') for modem in (False, True)):
                with self.subTest(layout=layout, modem=with_modem):
                    output = root / f'{layout}-{with_modem}'

                    def simulate(command, **kwargs):
                        # Deliberately mocked subprocess: only command/inventory
                        # plumbing is under test. Real engine gates stay in CI.
                        self.assertEqual(command[command.index('--cold-timeout') + 1], '240')
                        fixture = 'tests.modem_competition_engine' if with_modem else 'tests.monitor_animation_engine'
                        self.assertEqual(command[command.index('--fixture') + 1], fixture)
                        self.assertEqual(command[command.index('--mode') + 1], 'both')
                        self.assertIn('--cold', command)
                        self.assertIn('--production-context', command)
                        engine = Path(command[command.index('--output') + 1])
                        for mode in ('base', 'space-age'):
                            folder = engine / mode
                            folder.mkdir(parents=True)
                            (folder / 'cold-second-engine.log').write_text(
                                'TC_ANIMATION_CADENCE intervals=360 max_gap=2 peak_work=1 peak_allocations=1\n')
                        return SimpleNamespace(returncode=0)

                    argv = ['monitor_animation.py', '--factorio', str(root / 'unused-engine'),
                            '--archive', str(archive), '--output', str(output), '--mode', 'both', '--layout', layout]
                    if with_modem:
                        argv.append('--with-modem')
                    with patch('sys.argv', argv), patch.object(monitor_animation.subprocess, 'run', side_effect=simulate):
                        with self.assertRaises(SystemExit) as stopped:
                            monitor_animation.main()
                    self.assertEqual(stopped.exception.code, 0)
                    record = json.loads((output / 'summary.json').read_text())
                    self.assertEqual(record['layout'], layout)
                    self.assertEqual(record['modem_competition'], with_modem)
                    self.assertEqual(len(record['cadence_samples']), 2)
                    with zipfile.ZipFile(archive) as original, zipfile.ZipFile(output / archive.name) as tested:
                        prefix = next(n[:-len('info.json')] for n in original.namelist() if n.endswith('/info.json'))
                        self.assertEqual(set(tested.namelist()) - set(original.namelist()), {
                            prefix + 'tests/monitor_animation_source.lua',
                            prefix + 'tests/monitor_animation_layout.lua',
                        })
                        for name in original.namelist():
                            self.assertEqual(original.read(name), tested.read(name), name)


if __name__ == '__main__':
    unittest.main()
