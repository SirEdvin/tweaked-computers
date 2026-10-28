"""Package regressions: source-only tools and prohibited executable payloads."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import build


class PackageInventoryTests(unittest.TestCase):
    def test_optional_chart_ci_fixture_is_exact_and_not_shipped(self):
        import smoke
        path=build.ROOT/'.github/fixtures/factorio-charts/factorio-charts_1.2.0.zip'
        self.assertEqual(smoke.chart_archive(path)['sha256'],
                         '32b1683912281812c122d6b414d15ab553e943138ceb2b27fe52a38ee6512815')
        with zipfile.ZipFile(path) as charts:
            self.assertEqual(charts.read('factorio-charts_1.2.0/LICENSE'),path.with_name('LICENSE').read_bytes())
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as output:
            with zipfile.ZipFile(build.build(output)) as package:
                self.assertFalse(any('/.github/' in name or name.endswith('.zip') for name in package.namelist()))
                contracts={'openspec/specs/dashboard-interface/spec.md','openspec/specs/dashboard-interface/lua-api.md'}
                self.assertTrue(contracts.issubset(build.CONTRACT_FILES))
                prefix=next(name[:-len('info.json')] for name in package.namelist() if name.endswith('/info.json'))
                for relative in (*contracts,'examples/dashboard-program.lua','examples/dashboard-charts.lua'):
                    self.assertEqual(package.read(prefix+relative),(build.ROOT/relative).read_bytes())

    def test_console_companion_matches_live_follow_contract(self):
        companion = (build.ROOT / 'openspec/specs/console-shell/lua-api.md').read_text()
        spec = (build.ROOT / 'openspec/specs/console-shell/spec.md').read_text()
        self.assertIn('Follow-off SHALL keep the single Console text box live without automatic scrolling', spec)
        self.assertIn('Follow-off keeps the single Console text box live without automatic scrolling', companion)
        self.assertIn('changed text may clear native selection', companion)
        self.assertIn('unchanged text is not reassigned', companion)
        self.assertIn('There is no Refresh action or separate snapshot view', companion)
        self.assertNotIn('Follow-off preserves the existing snapshot', companion)

    def test_reference_tutorials_share_executable_sources_and_have_no_actions(self):
        import re
        import player_docs
        tutorials = (build.ROOT / 'scripts/ui/tutorials.lua').read_text()
        bindings = re.findall(r"source='([^']+)',code=require\('examples\.([^']+)'\)", tutorials)
        self.assertEqual({name for name, _ in bindings}, {
            'reference-speaker', 'logic-controller', 'reference-recipe', 'reference-factory', 'shared-telemetry', 'production-statistics-program', 'dashboard-program', 'dashboard-charts'})
        for name, module in bindings:
            self.assertEqual(name, module)
        self.assertIn("prelude=require('examples.reference-writer')", tutorials)
        generated = player_docs.generated()['examples.md']
        for name in ('reference-speaker', 'reference-recipe', 'reference-factory', 'reference-writer'):
            match = re.search(r'## ' + name + r'\n.*?```lua\n(.*?)\n```', generated, re.S)
            self.assertIsNotNone(match)
            assert match is not None
            self.assertEqual(match[1], player_docs.guest_example(name))
        adapter = (build.ROOT / 'scripts/ui/editor.lua').read_text()
        self.assertNotIn('select-reference', adapter)
        self.assertNotIn("button(tools,'template'", adapter)
        self.assertIn('if element==c.message.template then', adapter)

    def test_peripheral_help_exact_signatures_including_aliases_and_overloads(self):
        import re
        # Independent full signatures, not merely method-name substring hits.
        # The packaged Lua contract separately checks these methods against the
        # compiled guest inventory and exact paragraph isolation/spacing.
        expected = {
            'PERIPHERALS': '''getNames(wire)
isPresent(name, wire)
getType(name, wire)
getMethods(name, wire)
describe(name, wire)
wrap(name, wire)
call(name, wire, method, ...)
find(type_name, wire)
getName(facade)
getWire(facade)
setMonitorSyncGroup(members)
getMonitorSyncGroup()''',
            'DASHBOARD': '''setTab(slot, definition)
getTab(slot)
removeTab(slot)
setText(slot, id, text)
setEnabled(slot, id, enabled)
subscribe(handler_name)
unsubscribe(subscription_id)
getLimits()
appendSample(slot, id, values)
setBars(slot, id, bars)
clearChart(slot, id)''',
            'PRODUCTION STATISTICS': '''getTotals(kind)
getRates(kind, window)
getHistory(kind, name, window [, quality])
getLimits()''',
            'SPEAKER': '''getInstruments()
getNotes(instrument)
playNote(instrument, volume?, pitch?)
playSound(path, volume?)
getSounds(prefix?, after?)
getLimits()''',
            'RADAR MODEM': '''open(channel)
isOpen(channel)
close(channel)
closeAll()
transmit(channel, replyChannel, payload)
isWireless()
getLimits()''',
            'LOGIC HANDLER': '''readSignal(input, signal)
readSignals(input)
getInputStatus()
getOutput()
setOutput(signals)
clearOutput()
subscribe(options, handler_name)
unsubscribe(subscription_id)
getLimits()''',
            'KV DATABASE': '''get(key)
set(key, value)
del(key, ...)
exists(key, ...)
type(key)
hget(key, field)
hset(key, field, value, ...)
hdel(key, field, ...)
hexists(key, field)
hgetall(key)
hlen(key)
expire(key, seconds)
ttl(key)
persist(key)
getLimits()''',
            'MONITOR': '''write(text)
blit(text, foreground, background)
clear()
clearLine()
scroll(lines)
getSize()
getCursorPos()
setCursorPos(x, y)
getCursorBlink()
setCursorBlink(enabled)
getTextColor()
getTextColour()
setTextColor(color)
setTextColour(color)
getBackgroundColor()
getBackgroundColour()
setBackgroundColor(color)
setBackgroundColour(color)
isColor()
isColour()
setPaletteColor(color, rgb) or setPaletteColor(color, r, g, b)
setPaletteColour(color, rgb) or setPaletteColour(color, r, g, b)
getPaletteColor(color)
getPaletteColour(color)
getTextScale()
setTextScale(scale)
getLimits()''',
            'RECIPE SEARCHER': '''findRecipes("item"/"fluid", exact_product_name, exact_category?)
getLimits()''',
            'CONFIGURATOR': '''getDevices(target_wire)
getDevice(id, target_wire)
getCapabilities(id, target_wire)
getConfiguration(id, target_wire)
setConfiguration(id, patch, target_wire)
getSections(id, target_wire)
addSection(id, definition, target_wire)
setSection(id, index, patch, target_wire)
removeSection(id, index, target_wire)
getLimits()''',
        }
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as output:
            archive = build.build(output)
            with zipfile.ZipFile(archive) as package:
                source = package.read(next(n for n in package.namelist()
                                           if n.endswith('/scripts/ui/help.lua'))).decode()
        reference = re.search(r'  text=\[\[(.*?)\]\]', source, re.S)
        assert reference is not None, 'missing packaged reference'
        text = reference[1]
        self.assertEqual(sum(len(signatures.splitlines()) for signatures in expected.values()), 103)
        for heading, signatures in expected.items():
            found = re.search(r'^' + re.escape(heading) + r'\n(.*?)(?=^[A-Z][A-Z ]+\n|\Z)',
                              text, re.M | re.S)
            assert found is not None, 'missing topic ' + heading
            section = found[1]
            for signature in signatures.splitlines():
                with self.subTest(topic=heading, signature=signature):
                    self.assertEqual(len(re.findall(r'^' + re.escape(signature) + r' -> ',
                                                    section, re.M)), 1)

    def test_speaker_contract_samples_and_fixtures_are_packaged_without_audio_assets(self):
        # Independent expected paths: dropping an allowlist entry must fail even
        # if the rest of the build remains internally self-consistent.
        contracts = {
            'openspec/specs/speaker-peripheral/spec.md',
            'openspec/specs/speaker-peripheral/lua-api.md',
            'openspec/specs/peripheral-network/spec.md',
        }
        self.assertTrue(contracts.issubset(build.CONTRACT_FILES))
        required = contracts | {
            'data-final-fixes.lua', 'prototypes/speaker-audio.lua',
            'scripts/speaker.lua', 'scripts/speaker-audio.lua',
            'scripts/speaker-limits.lua', 'scripts/services/speaker.lua',
            'docs/player/api/speaker.md',
            *(f'examples/speaker-{name}.lua' for name in ('alarm', 'melody', 'catalogue')),
            *(f'tests/speaker_{name}.lua' for name in (
                'engine', 'native_cases', 'admission', 'catalogue_contract', 'data', 'data_final',
                'client_engine', 'competition_engine', 'upgrade_engine')),
        }
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as output:
            archive = build.build(output)
            with zipfile.ZipFile(archive) as package:
                prefix = next(n[:-len('info.json')] for n in package.namelist() if n.endswith('/info.json'))
                for relative in required:
                    self.assertEqual(package.read(prefix + relative), (build.ROOT / relative).read_bytes())
                self.assertFalse(any(Path(name).suffix.lower() in
                                     ('.ogg', '.wav', '.mp3', '.flac', '.mp4')
                                     or '/gameitself/' in name for name in package.namelist()))

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
                for relative in (*build.CONTRACT_FILES, 'examples/monitor-plot-program.lua',
                                 'examples/monitor-plot-baseline.lua', 'examples/monitor-plot-baseline.json'):
                    self.assertEqual(package.read(prefix + relative), (build.ROOT / relative).read_bytes())
                planning = [name[len(prefix):] for name in names if '/openspec/' in name]
                self.assertEqual(set(planning), set(build.CONTRACT_FILES))
                self.assertEqual(len(build.CONTRACT_FILES), 42)
                self.assertFalse(any(name.startswith('openspec/changes/') for name in planning))
                for relative in ('openspec/specs/program-source/spec.md',
                                 'openspec/specs/program-source/lua-api.md'):
                    self.assertEqual(package.read(prefix + relative), (build.ROOT / relative).read_bytes())
                for relative in ('scripts/services/recipe-searcher.lua', 'examples/recipe-searcher-program.lua',
                                 'docs/player/api/recipe-searcher.md', 'assets/icons/recipe_searcher.png',
                                 'scripts/services/factoriopedia-interface.lua', 'examples/factoriopedia-program.lua',
                                 'docs/player/api/factoriopedia-interface.md', 'assets/icons/factoriopedia_interface.png',
                                 'openspec/specs/factoriopedia-interface/spec.md', 'openspec/specs/factoriopedia-interface/lua-api.md',
                                 'scripts/services/production-statistics.lua', 'examples/production-statistics-program.lua',
                                 'examples/production-statistics-monitor.lua', 'docs/player/api/production-statistics.md',
                                 'assets/icons/production_statistics.png', 'openspec/specs/production-statistics/spec.md',
                                 'openspec/specs/production-statistics/lua-api.md'):
                    self.assertEqual(package.read(prefix + relative), (build.ROOT / relative).read_bytes())
                for relative in ('settings.lua', 'scripts/runtime/budget-settings.lua',
                                 'locale/en/settings.cfg', 'tests/runtime_budget_engine.lua',
                                 'docs/player/api/limits.md'):
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
        import hashlib
        import re
        archives = build.ROOT / 'openspec/changes/archive'
        changes = ('2026-10-19-add-native-circuit-computers', '2026-10-19-redesign-device-experience',
                   '2026-10-19-buffer-monitor-presentation', '2026-10-19-add-interactive-console-shell',
                   '2026-10-19-add-recipe-searcher', '2026-10-20-add-function-program-syntax',
                   '2026-10-21-add-peripheral-inspectors', '2026-10-21-add-radar-modems',
                   '2026-10-21-expand-lua-globals', '2026-10-21-add-speaker-peripheral',
                   '2026-10-21-restructure-peripheral-documentation',
                   '2026-10-27-track-only-computer-connected-radars')
        # Exact, intentional scenario evolution in the native-carrier deltas.
        # Every other historical scenario remains byte-for-byte checked below;
        # this is not a blanket name-only exception for modified requirements.
        evolved = {
            ('peripheral-inspection', 'Native inspection for every peripheral family', 'Open each peripheral'):
                ('any of the five peripheral families', 'any of these peripheral families'),
            # Empty-ground recovery is deliberately retired. Keep the exact
            # replacement workflow checked, not a name-only archive exemption.
            ('program-editor', 'Accessible bounded supporting tabs', 'Recover without an accessible computer'):
                ('#### Scenario: Recover without an accessible computer\n'
                 '- **WHEN** the computer is gone or draft capacity is exhausted\n'
                 '- **THEN** the standalone recovery entry remains available and permits reviewed copy/forget without executing source.',
                 "#### Scenario: Recover a removed computer's draft\n"
                 '- **WHEN** the original computer is gone and the player Ctrl-clicks another accessible computer body\n'
                 '- **THEN** Maintenance permits reviewed draft replacement and confirmed forget without executing source or deleting drafts automatically.'),
            ('program-editor', 'Method-isolated peripheral reference', 'Read the discovery API'):
                ('adjacent method paragraphs have at least two empty lines between them.',
                 'adjacent methods have separate selectable signature and result/notes blocks with visible spacing.'),
            # UI1 deliberately supersedes only numeric trackers/manual refresh
            # and the frozen Follow-off snapshot; keep all other archive bytes.
            ('program-editor', 'Separate drafts, saved source and active source', 'Save does not interrupt a working factory controller'):
                ('the old active revision continues and the UI displays both revision identities until Run/Apply succeeds.',
                 'the old active source continues until Run/Apply succeeds, and Maintenance permits separate reviewed inspection of saved and active source without numeric revision trackers.'),
            ('program-editor', 'Select-then-open peripheral documentation', 'First click selects details'):
                ('discovery wire, power status and snapshot details', 'discovery wire and power status without snapshot metadata'),
            ('device-configurator', 'Complete bounded inventory refresh', 'Wire removed before refresh'):
                ('and the player refreshes', 'and the open inspector next polls automatically'),
            ('kv-database', 'Expiry-aware inspection snapshots', 'Program changes the viewed key'):
                ('the old view remains explicitly a snapshot until refresh',
                 'the next admitted automatic observation replaces the old view without manual intervention'),
            ('computer-runtime', 'Program print uses the computer Console', 'Existing retention and failure semantics apply'):
                ("Follow-off continues to preserve the viewer's selected output snapshot.",
                 "Follow-off keeps output live without automatic scrolling, under the Console's accepted changed-text selection-reset and existing eviction rules."),
            ('device-lifecycle', 'Pinned engine and optional expansion', 'Base-only installation'):
                ('without missing expansion references.', 'without missing expansion references'),
            ('peripheral-network', 'Color-preserving physical reachability', 'Vanilla relay is ignored'):
                ('electric pole or ordinary machine', 'electric pole or ordinary unsupported machine'),
            ('peripheral-network', 'Integrated device wiring targets', 'Select without a wire'):
                ('opens a single-role device', 'opens a mod-authored single-role device'),
            ('peripheral-network', 'Wiring compatibility after presentation changes', 'Mixed-color and vanilla relay paths'):
                ('traverses a vanilla relay', 'traverses an unsupported vanilla relay'),
            ('radar-modem', 'Durable transport state without replay', 'Replace or clone a configured radar'):
                ('- **THEN** the new entity has a new identity and an empty channel set, and old wrappers cannot retarget to it.',
                 '- **THEN** the new entity has a new identity and an empty channel set when it is enrolled, and old wrappers cannot retarget to it\n'
                 '- **AND** an unconnected replacement or clone remains unenrolled until a computer-rooted path exists.'),
            ('radar-modem', 'Durable transport state without replay', 'Scope change'):
                ('its previously opened channels are cleared.',
                 'its previously opened channels are cleared before participation in the new scope.'),
        }
        # Exact reviewed circuit/storage replacements, not name-only exemptions.
        # Hash the complete trimmed requirement body; retain every historical scenario.
        native_evolved = {
            ('device-lifecycle', 'Coherent composite lifecycle'): 'c58a4e821fcdc9f5948781f45a26e60b454e91f8a8d2bff8887c53043a8ee903',
            ('device-lifecycle', 'Device-specific mining data policy'): '56fa15dac997051678bc0393d9fa7b5a4dabd0eb26165ddbbcf7641c9f5a0920',
            ('device-lifecycle', 'Blueprint and clone isolation'): '65493110d08f2efa6ea75afd1c4c40de06d28b3f2593854e7116589bf87af28d',
            ('device-lifecycle', 'Blueprint and item continuity across shell changes'): '1c42f7fd22c1327c9cb482ce080c080a390250d5bbbc24f13e07298d79ff5d1e',
            ('computer-runtime', 'Bounded native work'): '9d05602eeb7a4d90163fed7c6069eaf3331404f5c1bef1f7aed63b23e40a1d02',
            ('computer-runtime', 'Guest trust boundary'): '16a8460cfff7643614b925648c11a15e4448debf77c2fc9b04086b7f5b02b6d8',
            ('computer-runtime', 'Simulation timers and bounded queues'): '74b50cac17b7d56b2df832b9d7b1e5ea0cad51f02bbe575cb5ab5b4cb8b90085',
            ('logic-handler', 'Quality-aware input inspection'): '50a675dcbf04bcceb7ae2d0a718585e492dba60e10ff5d44a748b82600881d02',
            ('logic-handler', 'Shared combinator-style output'): '9dcbad34fb19b752031794a7e922f4368a0a7f18a7975cd2032a224a55001393',
            ('logic-handler', 'Tick-sampled change subscriptions'): '3c331da021078833c3d25129460f3dc927003dc7a0299b1d30c272bff87a60c2',
            ('logic-handler', 'Faithful signal identities and counts'): 'b615fa16400875c16614ec0f79e630c759b9de09db06af3151bf1944b0ccc27c',
            ('logic-handler', 'Bounded live signal observation'): '88df9636300ccab501411a2379f693aa5f27d1d9538bcaa771439243edb44ef4',
            ('peripheral-inspection', 'Bounded and honest refresh'): 'bdab1570ade89d62b6a66667b7a2cbaf81538c34f4a0099e10ecb1aaf72cad1d',
        }
        for change in changes:
            folder = archives / change
            self.assertTrue((folder / '.openspec.yaml').is_file(), change)
            for delta in sorted((folder / 'specs').glob('*/spec.md')):
                canonical = (build.ROOT / 'openspec/specs' / delta.parent.name / 'spec.md').read_text()
                for name, body in re.findall(
                        r'^### Requirement: ([^\n]+)\n(.*?)(?=^### Requirement:|^## |\Z)',
                        delta.read_text(), re.M | re.S):
                    with self.subTest(change=change, capability=delta.parent.name, requirement=name):
                        if (delta.parent.name,name)==('device-lifecycle','Mining preserves user data'):
                            name='Device-specific mining data policy'
                        found = re.search(r'^### Requirement: ' + re.escape(name) +
                                          r'\n(.*?)(?=^### Requirement:|\Z)', canonical, re.M | re.S)
                        self.assertIsNotNone(found)
                        assert found is not None
                        expected = native_evolved.get((delta.parent.name, name))
                        if expected:
                            self.assertEqual(hashlib.sha256(found[1].strip().encode()).hexdigest(), expected)
                            old_names = set(re.findall(r'^#### Scenario: ([^\n]+)', body, re.M))
                            new_names = set(re.findall(r'^#### Scenario: ([^\n]+)', found[1], re.M))
                            self.assertLessEqual(old_names, new_names)
                            continue
                        for scenario, text in re.findall(
                                r'^#### Scenario: ([^\n]+)\n(.*?)(?=^#### Scenario:|\Z)',
                                body, re.M | re.S):
                            text = '#### Scenario: ' + scenario + '\n' + text.strip()
                            replacement = evolved.get((delta.parent.name, name, scenario))
                            if replacement:
                                text = text.replace(*replacement)
                            self.assertIn(text, found[1])

    def test_native_carrier_union_and_unique_canonical_scenarios(self):
        import re
        text = (build.ROOT / 'openspec/specs/peripheral-network/spec.md').read_text()
        for phrase in ('supported native radar modem connectors',
                       'registered vanilla programmable-speaker connectors',
                       'Native circuit-network identity MUST NOT substitute',
                       'follow a radar-origin hidden wire',
                       'retain circuit playback independently of peripheral calls',
                       'retain native circuit transmission independently of modem traffic',
                       'preserve native opening behavior',
                       'MUST NOT delete player-owned unsupported wires'):
            self.assertIn(phrase, text)
        for source in (build.ROOT / 'openspec/specs').glob('*/spec.md'):
            names = re.findall(r'^### Requirement: ([^\n]+)', source.read_text(), re.M)
            self.assertEqual(len(names), len(set(names)), source)
            for name, body in re.findall(r'^### Requirement: ([^\n]+)\n(.*?)(?=^### Requirement:|\Z)',
                                         source.read_text(), re.M | re.S):
                scenarios = re.findall(r'^#### Scenario: ([^\n]+)', body, re.M)
                self.assertEqual(len(scenarios), len(set(scenarios)), (source, name))

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

            with patch.object(shell_client.subprocess, 'check_output', return_value='Version: 2.1.23 (unit test full)'), \
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
