"""Metadata-only upgrade candidate checks; not native save/upgrade evidence."""
import json
import os
from pathlib import Path
import tempfile
import unittest
import zipfile

import build
import monitor_upgrade


class UpgradeCandidateTests(unittest.TestCase):
    def test_private_version_has_matching_name_manifest_and_only_metadata_changes(self):
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as directory:
            root = Path(directory)
            original = build.build(root / 'source')
            with zipfile.ZipFile(original) as src:
                info_path = next(n for n in src.namelist() if n.endswith('/info.json'))
                old_version = json.loads(src.read(info_path))['version']
            parts = list(map(int, old_version.split('.')))
            parts[2] += 1
            version = '.'.join(map(str, parts))
            candidate = monitor_upgrade.version_candidate(original, root / 'candidate', version)
            self.assertEqual(candidate.name, 'tweaked-computers_' + version + '.zip')
            with zipfile.ZipFile(original) as src, zipfile.ZipFile(candidate) as dst:
                self.assertEqual({n.split('/', 1)[1] for n in src.namelist()}, {n.split('/', 1)[1] for n in dst.namelist()})
                prefix = 'tweaked-computers_' + version + '/'
                info = json.loads(dst.read(prefix + 'info.json'))
                manifest = json.loads(dst.read(prefix + 'package-manifest.json'))
                self.assertEqual(info['version'], version)
                self.assertEqual(manifest['version'], info['version'])
                changed = []
                for name in src.namelist():
                    suffix = name.split('/', 1)[1]
                    if src.read(name) != dst.read(prefix + suffix):
                        changed.append(suffix)
                self.assertEqual(sorted(changed), ['info.json', 'package-manifest.json'])
                import hashlib
                self.assertEqual(manifest['payload_sha256']['info.json'], hashlib.sha256(dst.read(prefix + 'info.json')).hexdigest())
            for bad in (old_version, '0.0.0', version + '-hotfix', '../' + version):
                with self.subTest(version=bad), self.assertRaises(ValueError):
                    monitor_upgrade.version_candidate(original, root / ('bad-' + str(len(bad))), bad)


if __name__ == '__main__':
    unittest.main()
