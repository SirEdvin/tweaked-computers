"""Real-export conformance before replacing any maintained API reference."""
import copy
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

import player_docs
import api_migration
from lua_api import public_fields, validate_api_inventory
from limit_docs import declarations as limit_declarations


class TypedDocumentationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not callable(getattr(player_docs, 'export_api', None)):
            raise AssertionError('missing typed API exporter in player_docs')
        if not callable(getattr(player_docs, 'api_records', None)):
            raise AssertionError('missing lossless typed API adapter in player_docs')
        binary = os.environ.get('LUALS_BIN') or shutil.which('lua-language-server')
        if not binary:
            raise AssertionError('set LUALS_BIN to the integrity-verified tools/luals-lock.json binary')
        cls.binary = Path(binary)
        cls.work = tempfile.TemporaryDirectory(dir=os.environ['TMPDIR'])
        cls.addClassCleanup(cls.work.cleanup)
        cls.source = player_docs.ROOT / 'tools/fixtures/api-docs'
        cls.raw = player_docs.export_api(cls.source, cls.binary, Path(cls.work.name))
        cls.records = player_docs.api_records(cls.raw)

    def test_exact_inventory_and_dot_call(self):
        self.assertEqual(set(self.records), {
            'TC.Data', 'TC.Wire', 'TC.Event', 'TC.Message', 'TC.Handler',
            'TC.Probe', 'TC.Color', 'TC.Tuple', 'probe', 'probeAlias', 'probeVersion',
        })
        read = self.records['TC.Probe']['fields']['read']
        self.assertEqual(len(read['signatures']), 3)
        primary = read['signatures'][0]
        self.assertEqual([p['name'] for p in primary['parameters']], ['wire', 'fallback', 'limit'])
        self.assertEqual([p['optional'] for p in primary['parameters']], [False, False, True])
        self.assertEqual(primary['parameters'][1]['type'], 'string|nil')
        self.assertIn('explicit nil is refused', primary['parameters'][2]['description'])
        self.assertEqual([r['name'] for r in primary['returns']], ['record', 'found'])
        self.assertIn('including empty payloads', primary['returns'][1]['description'])
        self.assertEqual(read['signatures'][1]['parameters'][0]['type'], "'red'")
        self.assertEqual(len(read['signatures'][1]['returns']), 2)
        alternate = read['signatures'][2]
        self.assertEqual(alternate['parameters'][0]['name'], 'channel')
        self.assertIn('numeric channel in 0..65535', alternate['parameters'][0]['description'])
        self.assertEqual(alternate['returns'][0]['type'], 'nil')
        self.assertIn('exactly one nil result', alternate['returns'][0]['description'])

    def test_alias_and_exact_result_shapes(self):
        fields = self.records['TC.Probe']['fields']
        self.assertEqual(fields['fetch']['signatures'], fields['read']['signatures'])
        self.assertEqual(fields['log']['signatures'][0]['returns'], [])
        absent = fields['absent']['signatures'][0]['returns']
        self.assertEqual(len(absent), 1)
        self.assertEqual(absent[0]['type'], 'nil')
        echo = fields['echo']['signatures'][0]
        self.assertTrue(echo['parameters'][0]['variadic'])
        self.assertTrue(echo['returns'][0]['variadic'])
        self.assertIn('Does not return normally', fields['fail']['description'])

    def test_nested_types_and_field_descriptions(self):
        message = self.records['TC.Message']
        self.assertEqual(message['extends'], ['TC.Event'])
        self.assertEqual(message['fields']['data']['type'], 'TC.Data')
        self.assertIn('without cycles', message['fields']['data']['description'])
        self.assertTrue(message['fields']['reply']['optional'])
        self.assertFalse(message['fields']['channel']['optional'])
        self.assertEqual(self.records['TC.Data']['references'], ['TC.Data'])
        self.assertIn('TC.Message', self.records['TC.Handler']['references'])
        wire = self.records['TC.Wire']
        self.assertEqual(wire['literals'], ["'red'", "'green'"])
        self.assertIn('Red network.', wire['description'])
        color = self.records['TC.Color']
        self.assertEqual(color['values'], {'red': 1, 'green': 2})
        self.assertIn('not a color mask combination', color['description'])

    def test_namespace_alias_and_literal_constant(self):
        alias = self.records['probeAlias']
        self.assertEqual(alias['kind'], 'namespace')
        self.assertEqual(alias['type'], 'TC.Probe')
        constant = self.records['probeVersion']
        self.assertEqual(constant['kind'], 'constant')
        self.assertEqual(constant['value'], 'Lua 5.2')
        self.assertIn('Lua 5.2', player_docs.api_markdown(player_docs.api_blocks(constant)))
        self.assertIn('[integer]', self.records['TC.Tuple']['fields'])

    def test_both_projections_preserve_contract_content(self):
        read = self.records['TC.Probe']['fields']['read']
        blocks = player_docs.api_blocks(read)
        page = player_docs.api_markdown(blocks)
        native = player_docs.api_lua(blocks)
        for fragment in (
            'E_ARGUMENT refuses an invalid wire.',
            'Returns a defensive copy.',
            'Required second position; explicit nil means no fallback.',
            'Detached record, or exactly nil when absent.',
            'probe.log(\'[color=red]literal[/color] ]=] "quoted"\', found)',
        ):
            self.assertIn(fragment, page)
            self.assertIn(fragment, native)
        self.assertTrue(any(b['kind'] == 'code' for b in blocks))
        self.assertTrue(any(b['kind'] == 'signature' for b in blocks))
        self.assertIn('Parameters', page)
        self.assertIn('Returns', page)

    def test_type_prose_cannot_be_interpreted_as_html(self):
        blocks = [{'kind': 'prose', 'text': 'value: table<string, TC.Data>\nA&B < 3.'}]
        page = player_docs.api_markdown(blocks)
        self.assertIn('table&lt;string, TC.Data&gt;', page)
        self.assertIn('A&amp;B &lt; 3.', page)
        self.assertIn(blocks[0]['text'], player_docs.api_lua(blocks))

    def test_reject_missing_description(self):
        records = copy.deepcopy(self.records)
        records['TC.Probe']['fields']['read']['signatures'][0]['parameters'][0]['description'] = ''
        with self.assertRaisesRegex(ValueError, 'description.*wire|wire.*description'):
            player_docs.validate_api_records(records)

    def test_reject_unresolved_reference(self):
        records = copy.deepcopy(self.records)
        records.pop('TC.Message')
        with self.assertRaisesRegex(ValueError, 'TC.Message'):
            player_docs.validate_api_records(records)

    def test_reject_unsupported_prose(self):
        record = copy.deepcopy(self.records['TC.Probe']['fields']['read'])
        record['description'] += '\n\n<img src="not-rendered.png">'
        with self.assertRaisesRegex(ValueError, 'unsupported'):
            player_docs.api_blocks(record)

    def test_reject_unknown_export_structure(self):
        raw = copy.deepcopy(self.raw)
        raw.append({'type': 'future.unknown', 'name': 'TC.NewKind'})
        with self.assertRaisesRegex(ValueError, 'future.unknown'):
            player_docs.api_records(raw)

    def test_reject_inferred_unknown_type(self):
        raw = copy.deepcopy(self.raw)
        alias = next(item for item in raw if item['name'] == 'TC.Data')
        alias['defines'][0]['extends']['types'][0]['literal'] = 'unknown'
        with self.assertRaisesRegex(ValueError, 'unresolved type unknown'):
            player_docs.api_records(raw)

    def test_fresh_exports_are_deterministic(self):
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as other:
            copied = Path(other) / 'definitions'
            shutil.copytree(self.source, copied)
            raw = player_docs.export_api(copied, self.binary, Path(other) / 'output')
            records = player_docs.api_records(raw)
            self.assertEqual(self.records, records)
            for identity, record in records.items():
                first = player_docs.api_blocks(self.records[identity])
                second = player_docs.api_blocks(record)
                self.assertEqual(player_docs.api_markdown(first), player_docs.api_markdown(second))
                self.assertEqual(player_docs.api_lua(first), player_docs.api_lua(second))


class PublicLibraryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.TemporaryDirectory(dir=os.environ['TMPDIR'])
        cls.addClassCleanup(cls.work.cleanup)
        cls.raw = player_docs.export_api(player_docs.ROOT / 'api', Path(os.environ['LUALS_BIN']), Path(cls.work.name))
        cls.records = player_docs.api_records(cls.raw)
        cls.inventory = player_docs.inventory()

    def test_implementation_export_helper_event_inventory(self):
        validate_api_inventory(self.records, self.inventory)

    def test_native_helper_inventory_includes_direct_bindings(self):
        helpers = self.inventory['standard_helpers']
        self.assertTrue({'type', 'tonumber', 'select', 'rawequal', 'unpack', '_VERSION'} <= set(helpers['globals']))
        self.assertEqual(set(helpers['table']), {'pack', 'unpack', 'concat', 'insert', 'remove', 'sort'})
        self.assertEqual(set(helpers['string']), {'len', 'sub', 'byte', 'char', 'lower', 'upper', 'reverse', 'rep', 'find', 'format'})

    def test_inherited_methods_are_referenced_not_duplicated(self):
        own = self.records['TC.ChartDashboard']['fields']
        self.assertEqual(set(own), {'appendSample', 'setBars', 'clearChart'})
        complete = public_fields(self.records, 'TC.ChartDashboard')
        self.assertEqual(set(complete), set(self.inventory['exports']['dashboard']))
        self.assertEqual(complete['setTab'], self.records['TC.DashboardBase']['fields']['setTab'])

    def test_missing_colour_alias_fails(self):
        records = copy.deepcopy(self.records)
        del records['TC.Monitor']['fields']['setPaletteColour']
        with self.assertRaisesRegex(ValueError, 'setPaletteColour'):
            validate_api_inventory(records, self.inventory)

    def check_palette(self, records):
        method = records['TC.Monitor']['fields']['setPaletteColor']
        self.assertEqual([len(s['parameters']) for s in method['signatures']], [4, 2])
        self.assertTrue(all(s['returns'] == [] for s in method['signatures']))
        alias = records['TC.Monitor']['fields']['setPaletteColour']
        self.assertEqual(method['signatures'], alias['signatures'])

    def test_palette_overload_and_alias(self):
        self.check_palette(self.records)
        broken = copy.deepcopy(self.records)
        broken['TC.Monitor']['fields']['setPaletteColor']['signatures'].pop()
        with self.assertRaises(AssertionError):
            self.check_palette(broken)

    def check_nested(self, records):
        expected = {
            'TC.SoundPage': {'sounds', 'next'}, 'TC.NoteInfo': {'name', 'pitch'},
            'TC.ProbabilityInterval': {'min', 'max'},
            'TC.HistorySnapshot': {'tick', 'input', 'output'},
            'TC.InputStatus': {'red_connected', 'green_connected'},
            'TC.ConfigurationSnapshot': {'values', 'unset', 'observations'},
            'TC.DashboardButton': {'type', 'id', 'text', 'enabled'},
            'TC.DashboardLine': {'type', 'id', 'series', 'capacity', 'format'},
            'TC.DashboardBars': {'type', 'id', 'phases'},
        }
        for identity, fields in expected.items():
            self.assertEqual(set(records[identity]['fields']), fields, identity)
        self.assertTrue(records['TC.SoundPage']['fields']['next']['optional'])
        self.assertFalse(records['TC.SoundPage']['fields']['sounds']['optional'])

    def test_nested_contract_fields_and_corruption(self):
        self.check_nested(self.records)
        broken = copy.deepcopy(self.records)
        del broken['TC.DashboardLine']['fields']['series']
        with self.assertRaises(AssertionError):
            self.check_nested(broken)

    def test_required_nil_message_and_boolean_audio(self):
        transmit = self.records['TC.Modem']['fields']['transmit']['signatures'][0]
        self.assertEqual(len(transmit['parameters']), 3)
        self.assertEqual(transmit['parameters'][2]['type'], 'TC.Data|nil')
        self.assertFalse(transmit['parameters'][2]['optional'])
        self.assertEqual(transmit['returns'], [])
        note = self.records['TC.Speaker']['fields']['playNote']['signatures'][0]
        self.assertEqual([p['optional'] for p in note['parameters']], [False, True, True])
        self.assertEqual([r['type'] for r in note['returns']], ['boolean'])

    def test_audited_compatibility_and_readback_contracts(self):
        monitor = self.records['TC.Monitor']['fields']
        self.assertEqual(monitor['getLimits']['signatures'][0]['parameters'], [])
        blit = monitor['blit']['signatures']
        self.assertEqual(len(blit), 2)
        self.assertTrue(all(len(s['parameters']) == 3 and s['returns'] == [] for s in blit))
        self.assertEqual(blit[1]['parameters'][1]['type'], 'nil|false')
        self.assertFalse(blit[1]['parameters'][2]['optional'])
        self.assertIn('false', self.records['TC.DashboardLine']['fields']['format']['type'])
        self.assertIn('physical unavailability', self.records['TC.SignalChanged']['fields']['resync']['description'])
        for identity in ('TC.MonitorTouch', 'TC.ModemMessage'):
            self.assertIn('red-before-green', public_fields(self.records, identity)['wires']['description'])
        for method in ('getState', 'setState', 'deleteState'):
            key = self.records['TC.Computer']['fields'][method]['signatures'][0]['parameters'][0]
            self.assertIn('identifier_bytes', key['description'])
        self.assertIn('snapshot', self.records['pcall']['description'])
        self.assertIn('protected-handle', self.records['xpcall']['description'])
        self.assertIn('TC.WireConnectorId', self.records['TC.DeviceInfo']['fields']['connected_connector_ids']['type'])
        self.assertEqual(self.records['TC.SectionInfo']['fields']['type']['type'], 'TC.LogisticSectionType')

    def test_all_public_prose_projects_without_loss(self):
        for record in self.records.values():
            blocks = player_docs.api_blocks(record)
            self.assertTrue(player_docs.api_markdown(blocks))
            self.assertTrue(player_docs.api_lua(blocks))

    def test_complete_website_native_projection_and_routing(self):
        import api_reference
        products, topics, locations = api_reference.generate(self.records)
        for path, body in products.items():
            if path.endswith('.md'):
                self.assertEqual(body, body.rstrip() + '\n', path)
        self.assertEqual(set(locations), set(self.records))
        by_id = {topic['id']: topic for topic in topics}
        self.assertEqual(len(by_id), len(topics))
        for name, record in self.records.items():
            location = locations[name]
            blocks = player_docs.api_blocks(record)
            topic = by_id[location['topic']]
            self.assertIn(player_docs.api_markdown(blocks), products[location['page']])
            self.assertIn(name, topic['text'])
            for block in blocks:
                self.assertIn(block, topic['blocks'])
                self.assertIn(block['text'], topic['text'])
        self.assertEqual(locations['TC.Monitor']['topic'], 'peripheral.monitor')
        self.assertEqual(locations['TC.SignalChanged']['topic'], 'type.TC.SignalChanged')
        self.assertIn('TC.Config.Read.SignalID', products['docs/player/api/types.md'])
        self.assertIn('api/types/TC.Config.Read.SignalID.md', products['mkdocs.yml'])
        self.assertEqual(api_reference.generate(self.records), (products, topics, locations))

    def test_whole_content_corruption_missing_and_stale_outputs(self):
        import api_reference
        products, _, _ = api_reference.generate(self.records)
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as folder:
            root = Path(folder)
            for relative, body in products.items():
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(body)
            api_reference.check_products(products, root)
            target = root / 'scripts/ui/api-reference.lua'
            pristine = target.read_bytes()
            changed = pristine.replace(b'red-before-green', b'green-before-red', 1)
            self.assertNotEqual(pristine, changed)
            target.write_bytes(changed)
            with self.assertRaisesRegex(ValueError, 'stale.*api-reference'):
                api_reference.check_products(products, root)
            self.assertEqual(target.read_bytes(), changed, 'read-only check rewrote a corrupted output')
            target.write_bytes(pristine)
            missing = root / 'docs/player/api/types/TC.SignalChanged.md'
            missing.unlink()
            with self.assertRaisesRegex(ValueError, 'stale.*TC.SignalChanged'):
                api_reference.check_products(products, root)
            self.assertFalse(missing.exists(), 'read-only check recreated a missing output')

    def test_package_gate_requires_complete_output_inventory(self):
        import api_reference
        from unittest.mock import patch
        products, _, _ = api_reference.generate(self.records)
        products.update({'docs/player/' + p: body for p, body in player_docs.generated().items()})
        products['docs/api-migration.md'] = api_migration.appendix()
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as temp:
            root = Path(temp)
            for relative, body in products.items():
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(body)
            with patch.object(api_reference, 'inputs', return_value={}):
                receipt = api_reference.provenance(products)
                path = root / 'docs/api-reference-provenance.json'
                path.write_text(json.dumps(receipt))
                api_reference.check_freshness(root)
                native = 'scripts/ui/api-reference.lua'
                del receipt['outputs'][native]
                path.write_text(json.dumps(receipt))
                with self.assertRaisesRegex(ValueError, 'output inventory'):
                    api_reference.check_freshness(root)
                self.assertNotIn(native, json.loads(path.read_text())['outputs'])
                receipt = api_reference.provenance(products)
                path.write_text(json.dumps(receipt))
                (root / native).unlink()
                with self.assertRaisesRegex(ValueError, 'stale.*api-reference'):
                    api_reference.check_freshness(root)
                self.assertFalse((root / native).exists())

    def test_external_editor_setup_and_host_exclusion(self):
        root = player_docs.ROOT
        readme = (root / 'api/README.md').read_text()
        examples = re.findall(r'```lua\n(.*?)\n```', readme, re.S)
        self.assertEqual(len(examples), 1)
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as folder:
            work = Path(folder)
            project = work / 'project'
            project.mkdir()
            config = json.loads((root / 'tools/luals-docs.json').read_text())
            config.pop('docScriptPath')
            config['workspace.library'] = [str(root / 'api')]
            (project / '.luarc.json').write_text(json.dumps(config))
            for name, source in (
                ('valid', examples[0]),
                ('host', examples[0] + '\nfunction forbidden() game.print("host") end'),
            ):
                (project / 'program.lua').write_text(source + '\n')
                diagnostic = work / (name + '.json')
                result = subprocess.run([
                    os.environ['LUALS_BIN'], '--check=' + str(project),
                    '--configpath=' + str(project / '.luarc.json'), '--check_format=json',
                    '--check_out_path=' + str(diagnostic), '--logpath=' + str(work / (name + '-logs')),
                    '--metapath=' + str(work / 'meta'),
                ], capture_output=True, text=True, timeout=120)
                report = json.loads(diagnostic.read_text())
                if name == 'valid':
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(report, [])
                else:
                    self.assertIn('undefined-global', json.dumps(report))
                    self.assertIn('game', json.dumps(report))

    def test_limits_fresh_complete_and_deterministic(self):
        generated = limit_declarations()
        self.assertEqual(generated, (player_docs.ROOT / 'api/generated/limits.d.lua').read_text())
        self.assertEqual(generated, limit_declarations())
        removed = {'signal_slots', 'filter_signals', 'active_logic_handlers', 'aggregate_owned_outputs',
                   'callback_work', 'callback_allocations', 'callback_depth', 'tuple_entries', 'generated_source_bytes'}
        for name in self.records:
            if name.endswith('Limits'):
                fields = public_fields(self.records, name)
                self.assertFalse(removed.intersection(fields), name)
                self.assertTrue(all(field['description'] and field['type'] == 'integer' for field in fields.values()))
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as folder:
            root = Path(folder)
            shutil.copytree(player_docs.ROOT / 'scripts', root / 'scripts')
            limits = root / 'scripts/runtime/limits.lua'
            source = limits.read_text()
            updated = source.replace('return {', 'return {\n  undocumented = 1,', 1)
            self.assertNotEqual(source, updated)
            limits.write_text(updated)
            with self.assertRaisesRegex(ValueError, 'undocumented'):
                limit_declarations(root)

    def test_complete_section_and_example_migration(self):
        self.assertEqual(api_migration.validate(self.records), {
            'sources': 40, 'headings': 354, 'example_identities': 22, 'unique_example_sources': 20,
        })
        self.assertEqual(api_migration.appendix(), (player_docs.ROOT / 'docs/api-migration.md').read_text())
        broken = dict(self.records)
        del broken['TC.Config.SignalID']
        with self.assertRaisesRegex(ValueError, 'missing migration type'):
            api_migration.validate(broken)

    def test_lost_or_changed_retained_example_fails(self):
        records = api_migration.examples()
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as folder:
            root = Path(folder)
            source = root / records[0]['destination']
            source.parent.mkdir(parents=True)
            source.write_text('function start() end\n')
            with self.assertRaisesRegex(ValueError, 'changed retained example'):
                api_migration.example_source(records[0], root)
            source.unlink()
            with self.assertRaisesRegex(ValueError, 'missing migration destination'):
                api_migration.example_source(records[0], root)


if __name__ == '__main__':
    unittest.main()
