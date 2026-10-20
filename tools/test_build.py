"""Package regressions: source-only tools and prohibited executable payloads."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import build


class PackageInventoryTests(unittest.TestCase):
    def test_buffered_monitor_inventory_and_determinism(self):
        # Pin the intended public contract explicitly: iterating only the build
        # allowlist cannot detect an accidental removal from that allowlist.
        contracts = {
            'openspec/specs/monitor-display/spec.md',
            'openspec/specs/monitor-display/lua-api.md',
            'openspec/specs/monitor-display/buffering-api.md',
            'openspec/specs/peripheral-network/spec.md',
        }
        self.assertTrue(contracts.issubset(build.CONTRACT_FILES))
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as output:
            first = build.build(Path(output) / 'first')
            second = build.build(Path(output) / 'second')
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with zipfile.ZipFile(first) as package:
                prefix = next(n[:-len('info.json')] for n in package.namelist() if n.endswith('/info.json'))
                for relative in (*contracts, 'examples/monitor-plot-program.lua',
                                 'tests/monitor_state_engine.lua',
                                 *(f'tests/monitor_state_{phase}.lua' for phase in
                                   ('waiting', 'preparing', 'ready', 'retiring'))):
                    self.assertEqual(package.read(prefix + relative), (build.ROOT / relative).read_bytes())

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
                for relative in (*build.CONTRACT_FILES, 'examples/monitor-plot-program.lua',
                                 'examples/monitor-plot-baseline.lua', 'examples/monitor-plot-baseline.json'):
                    self.assertEqual(package.read(prefix + relative), (build.ROOT / relative).read_bytes())
                planning = [name[len(prefix):] for name in names if '/openspec/' in name]
                self.assertEqual(set(planning), set(build.CONTRACT_FILES))
                self.assertEqual(len(build.CONTRACT_FILES), 28)
                self.assertFalse(any(name.startswith('openspec/changes/') for name in planning))
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
                self.assertEqual(art['selection']['candidate'],'B-service-rack')
                for name in ('tc-circuit-computers','tc-recipe-searcher'):
                    technology=art['technologies'][name]
                    self.assertEqual(technology['icon_size'],256)
                    self.assertEqual(package.read(prefix+'assets/'+technology['icon']),
                                     (build.ROOT/'assets'/technology['icon']).read_bytes())

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


class CanonicalContractTests(unittest.TestCase):
    def test_explicit_inventory_covers_canonical_files_only(self):
        expected = {p.relative_to(build.ROOT).as_posix()
                    for folder in ('api', 'specs')
                    for p in (build.ROOT / 'openspec' / folder).rglob('*')
                    if p.is_file() and p.suffix in ('.md', '.json')}
        self.assertEqual(set(build.CONTRACT_FILES), expected)
        self.assertEqual(len(build.CONTRACT_FILES), len(expected))

    def test_archived_requirements_and_scenarios_survive_promotion(self):
        import re
        archives = build.ROOT / 'openspec/changes/archive'
        changes = ('add-native-circuit-computers', 'redesign-device-experience',
                   'buffer-monitor-presentation', 'add-interactive-console-shell',
                   'add-recipe-searcher')
        for change in changes:
            folder = archives / ('2026-10-19-' + change)
            self.assertTrue((folder / '.openspec.yaml').is_file(), change)
            for delta in sorted((folder / 'specs').glob('*/spec.md')):
                canonical = (build.ROOT / 'openspec/specs' / delta.parent.name / 'spec.md').read_text()
                for name, body in re.findall(
                        r'^### Requirement: ([^\n]+)\n(.*?)(?=^### Requirement:|^## |\Z)',
                        delta.read_text(), re.M | re.S):
                    with self.subTest(change=change, capability=delta.parent.name, requirement=name):
                        found = re.search(r'^### Requirement: ' + re.escape(name) +
                                          r'\n(.*?)(?=^### Requirement:|\Z)', canonical, re.M | re.S)
                        self.assertIsNotNone(found)
                        assert found is not None
                        for scenario, text in re.findall(
                                r'^#### Scenario: ([^\n]+)\n(.*?)(?=^#### Scenario:|\Z)',
                                body, re.M | re.S):
                            self.assertIn('#### Scenario: ' + scenario + '\n' + text.strip(), found[1])

    def test_baseline_purposes_preserved_and_no_delta_headers(self):
        import re
        baseline = build.ROOT / 'openspec/changes/archive/2026-10-19-add-native-circuit-computers/specs'
        for source in baseline.glob('*/spec.md'):
            target = (build.ROOT / 'openspec/specs' / source.parent.name / 'spec.md').read_text()
            def purpose(s):
                found = re.search(r'^## Purpose\n(.*?)(?=^## )', s, re.M | re.S)
                assert found is not None
                return found[1]
            self.assertEqual(purpose(source.read_text()), purpose(target))
        for source in (build.ROOT / 'openspec/specs').glob('*/spec.md'):
            text = source.read_text()
            self.assertTrue(text.startswith('# ' + source.parent.name + ' Specification\n'))
            self.assertEqual(text.count('## Requirements\n'), 1)
            self.assertNotRegex(text, r'(?m)^## (ADDED|MODIFIED|REMOVED|RENAMED) Requirements')

    def test_packaged_contract_links_resolve_inside_inventory(self):
        import re
        from urllib.parse import unquote, urlsplit
        files = set(build.CONTRACT_FILES)
        for name in files:
            if not name.endswith('.md'):
                continue
            source = build.ROOT / name
            for href in re.findall(r'\[[^\]]*\]\(([^)]+)\)', source.read_text()):
                url = urlsplit(href)
                if url.scheme or url.netloc or not url.path:
                    continue
                target = (source.parent / unquote(url.path)).resolve()
                self.assertTrue(target.is_file(), (name, href))
                self.assertIn(target.relative_to(build.ROOT).as_posix(), files, (name, href))


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
