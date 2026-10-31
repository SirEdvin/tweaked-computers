import tempfile
import unittest
import json
from pathlib import Path
import zipfile

from scheduling_upgrade import candidate_archive, install_fixture


class SchedulingUpgradeArchiveTest(unittest.TestCase):
    def candidate(self, root, version):
        archive = root / ('tweaked-computers_' + version + '.zip')
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr(archive.stem + '/info.json', json.dumps({'name': 'tweaked-computers', 'version': version}))
            z.writestr(archive.stem + '/package-manifest.json', json.dumps({'version': version, 'payload_sha256': {}}))
            z.writestr(archive.stem + '/control.lua', b'unchanged production')
        return archive

    def test_real_version_advance_uses_exact_candidate(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = self.candidate(root, '0.1.19'); original = source.read_bytes()
            candidate, private = candidate_archive(source, root / 'private', '0.1.17')
            self.assertEqual(candidate, source); self.assertIsNone(private)
            self.assertFalse((root / 'private').exists()); self.assertEqual(source.read_bytes(), original)

    def test_same_version_uses_private_metadata_only_advance(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = self.candidate(root, '0.1.17'); original = source.read_bytes()
            candidate, private = candidate_archive(source, root / 'private', '0.1.17')
            self.assertEqual(private, '0.1.18'); self.assertEqual(source.read_bytes(), original)
            with zipfile.ZipFile(candidate) as z:
                self.assertEqual(z.read(candidate.stem + '/control.lua'), b'unchanged production')
                self.assertEqual(json.loads(z.read(candidate.stem + '/info.json'))['version'], private)

    def test_only_existing_test_hook_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / 'tweaked-computers_0.1.17.zip'
            prefix = archive.stem + '/'
            entries = {'info.json': b'{}', 'control.lua': b'-- tc-buffer-upgrade',
                       'scripts/runtime/computer.lua': b'production payload',
                       'tests/monitor_upgrade_engine.lua': b'old fixture'}
            with zipfile.ZipFile(archive, 'w') as z:
                for name, payload in entries.items():
                    z.writestr(prefix + name, payload)
            original = archive.read_bytes()
            tested = install_fixture(archive, root / 'tested', b'new fixture')
            self.assertEqual(archive.read_bytes(), original)
            with zipfile.ZipFile(tested) as z:
                self.assertEqual(z.namelist(), [prefix + name for name in entries])
                for name, payload in entries.items():
                    self.assertEqual(z.read(prefix + name), b'new fixture' if name == 'tests/monitor_upgrade_engine.lua' else payload)

    def test_refuses_archive_without_opt_in_hook(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / 'tweaked-computers_0.1.17.zip'
            with zipfile.ZipFile(archive, 'w') as z:
                z.writestr(archive.stem + '/info.json', b'{}')
                z.writestr(archive.stem + '/control.lua', b'production')
            with self.assertRaises(AssertionError):
                install_fixture(archive, root / 'tested', b'fixture')


if __name__ == '__main__':
    unittest.main()
