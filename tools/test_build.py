"""Package regressions: source-only tools and prohibited executable payloads."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import build


class PackageInventoryTests(unittest.TestCase):
    def test_function_program_matches_packaged_starter_and_documentation(self):
        import re
        import player_docs
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as output:
            archive = build.build(output)
            with zipfile.ZipFile(archive) as package:
                prefix = next(n[:-len('info.json')] for n in package.namelist() if n.endswith('/info.json'))
                source = package.read(prefix + 'examples/function-program.lua')
                self.assertEqual(source, (build.ROOT / 'examples/function-program.lua').read_bytes())
                help_source = package.read(prefix + 'scripts/ui/help.lua')
                template = re.search(rb'template=\[\[(.*?)\]\],', help_source, re.S)
                assert template is not None, 'missing packaged starter'
                self.assertEqual(template[1], source)
                docs = package.read(prefix + 'docs/player/examples.md')
                example = re.search(rb'## function-program\n.*?```lua\n(.*?)\n```', docs, re.S)
                assert example is not None, 'missing documented function program'
                self.assertEqual(example[1] + b'\n', source)
                self.assertEqual(player_docs.guest_example('function-program').encode() + b'\n', source)

    def test_documentation_rejects_starter_example_drift(self):
        import player_docs
        original = player_docs.text
        with patch.object(player_docs, 'text', lambda path: original(path) + '\n'
                          if path == 'examples/function-program.lua' else original(path)):
            with self.assertRaisesRegex(ValueError, 'differs from the inserted starter'):
                player_docs.guest_example('function-program')

    def test_portal_payload_keeps_notices_not_python_tools(self):
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as output:
            archive = build.build(output)
            with zipfile.ZipFile(archive) as package:
                names = package.namelist()
                self.assertFalse(any(Path(name).suffix.lower() in
                                     ('.exe', '.bat', '.ps1', '.sh', '.py', '.pyc')
                                     for name in names))
                for notice in ('assets/notices/Greg-Flavored-MIT.txt',
                               'assets/notices/Tweaked-Computers-MIT.txt',
                               'vendor/phobos/LICENSE.txt', 'changelog.txt'):
                    name = next(name for name in names if name.endswith('/' + notice))
                    self.assertEqual(package.read(name), (build.ROOT / notice).read_bytes())
                self.assertTrue((build.ROOT / 'assets/generate.py').is_file())
                prefix = next(name[:-len('info.json')] for name in names if name.endswith('/info.json'))
                for relative in (*build.CONTRACT_EXTENSIONS, 'examples/monitor-plot-program.lua',
                                 'examples/monitor-plot-baseline.lua', 'examples/monitor-plot-baseline.json'):
                    self.assertEqual(package.read(prefix + relative), (build.ROOT / relative).read_bytes())
                planning = [name[len(prefix):] for name in names if '/openspec/' in name]
                self.assertEqual({name for name in planning if not name.startswith(build.CONTRACT + '/')},
                                 set(build.CONTRACT_EXTENSIONS))
                self.assertEqual(len(build.CONTRACT_EXTENSIONS), 9)
                for relative in ('openspec/changes/add-function-program-syntax/specs/program-source/spec.md',
                                 'openspec/changes/add-function-program-syntax/specs/program-source/lua-api.md'):
                    self.assertEqual(package.read(prefix + relative), (build.ROOT / relative).read_bytes())
                for relative in ('scripts/services/recipe-searcher.lua', 'examples/recipe-searcher-program.lua',
                                 'docs/player/api/recipe-searcher.md', 'assets/icons/recipe_searcher.png'):
                    self.assertEqual(package.read(prefix + relative), (build.ROOT / relative).read_bytes())
                self.assertFalse(any(name.endswith(('/proposal.md', '/design.md', '/tasks.md')) for name in planning))

    def test_actual_gameplay_art_bytes_match_provenance(self):
        import hashlib
        import json
        art=json.loads((build.ROOT/'assets/manifest.json').read_text())
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as output:
            archive=build.build(output)
            with zipfile.ZipFile(archive) as package:
                prefix=next(n[:-len('info.json')] for n in package.namelist() if n.endswith('/info.json'))
                for record in art['outputs']+art['notices']+art['generated_metadata']:
                    data=package.read(prefix+record['path'])
                    self.assertEqual(hashlib.sha256(data).hexdigest(),record['sha256'])
                    self.assertEqual(data,(build.ROOT/record['path']).read_bytes())
                pngs={n[len(prefix):] for n in package.namelist() if n.startswith(prefix+'assets/') and n.endswith('.png') and '/upstream/' not in n}
                self.assertEqual(pngs,{r['path'] for r in art['outputs']})
                self.assertEqual(json.loads(package.read(prefix+'assets/manifest.json')),art)
                self.assertEqual(package.read(prefix+'assets/socket-layout.json'),(build.ROOT/'assets/socket-layout.json').read_bytes())

    def test_explicit_inventory_rejects_prohibited_suffixes(self):
        # Synthetic inventory entries test rejection before payload access; no
        # fake executable is created and the production source stays untouched.
        original = Path.is_file
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as output:
            for suffix in ('.exe', '.bat', '.ps1', '.sh', '.py', '.EXE'):
                with self.subTest(suffix=suffix):
                    name = 'prohibited-payload' + suffix
                    fake = build.ROOT / name
                    with patch.object(build, 'TOP', build.TOP + (name,)), \
                         patch.object(Path, 'is_file', lambda p: p == fake or original(p)):
                        with self.assertRaisesRegex(ValueError, 'Mod Portal forbids executable'):
                            build.build(output)


class ShellClientSceneTests(unittest.TestCase):
    def test_fresh_save_roots_exist_before_engine_creation(self):
        import shell_client
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as output:
            root = Path(output)
            archive = build.build(root / 'package')
            client = root / 'client'
            (client / 'config').mkdir(parents=True)
            (client / 'config/config.ini').write_text(
                'read-data=__PATH__executable__/../../data\nwrite-data=__PATH__executable__/../..\n')
            scene = root / 'scene'

            def create(command, **kwargs):
                for owner in ('server', 'client1', 'client2'):
                    self.assertTrue((scene / owner / 'write/saves').is_dir())
                # Explicit unit stub only; actual engine acceptance is separate.
                Path(command[command.index('--create') + 1]).write_bytes(b'unit-test-only')
                return SimpleNamespace(returncode=0, stdout='TC_SMOKE_OK')

            with patch.object(shell_client.subprocess, 'check_output', return_value='Version: 2.0.77 (unit test full)'), \
                 patch.object(shell_client.subprocess, 'run', side_effect=create):
                shell_client.prepare(archive, root / 'engine/bin/x64/factorio', client, scene, 'base')


class DocumentationSiteTests(unittest.TestCase):
    def test_missing_or_empty_site_is_not_a_passing_link_check(self):
        import player_docs
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as output:
            for path in (Path(output), Path(output) / 'missing'):
                with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'no built HTML pages'):
                    player_docs.site_links(path)

    def test_real_page_and_anchor_are_checked(self):
        import player_docs
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as output:
            folder = Path(output)
            (folder / 'index.html').write_text('<h1 id="start">Start</h1><a href="#start">Go</a>')
            self.assertEqual(player_docs.site_links(folder), {'html_pages': 1, 'internal_links_checked': 1})


if __name__ == '__main__':
    unittest.main()
