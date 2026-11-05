#!/usr/bin/env python3
"""Generate player reference tables/examples and check their implementation inventory.

No network, new framework or game client. --fixture-archive adds compile-only
examples to a separate verification ZIP for the existing official-engine harness.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import tempfile
from pathlib import Path
import zipfile
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit

from lua_api import (export_api, api_records, validate_api_records,
                     api_blocks, api_markdown, api_lua)
from limit_docs import declarations as limit_declarations
from configuration_catalog import SOURCE as CONFIGURATION_SOURCE
import api_migration
import api_reference
from lua_api import validate_api_inventory

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / 'docs/player'
CONTRACT = ROOT / 'openspec'
EXAMPLES = {
    'dashboard-program': 'Research Native circuit computers. Build a Dashboard and a computer. Neither device needs electricity. Connect Network red. Select Validate. Select Save. Select Run. Close the computer. Open the Dashboard normally. Left-click Acknowledge. The saved clicked handler changes the status from Ready to Acknowledged. A chart library is not necessary. Console cannot subscribe.',
    'dashboard-charts': 'Use the same Dashboard setup with red wiring and no electricity. Optionally enable unmodified factorio-charts 1.2.0 for rolling lines and duration bars in seconds. Without it, labels and buttons still work. Twelve startup samples wrap an eight-slot line before the window opens. Scroll Overview to see both charts. Switch among six tabs. Acknowledge a button. Live label updates keep the selected tab and unchanged identity selection. X positions use sample order, not wall time. This is not the native production widget.',
    'production-statistics-program': 'Research Recipe Searcher. Craft a Production Statistics device. Connect Network red to the computer. Neither device needs electricity. Select Validate. Select Save. Select Run. The program logs local native item, fluid, and pollution totals and rates. It then logs the newest and oldest iron history for production and consumption. Empty input differs from an E_LIMIT refusal of the complete result. Work or allocation exhaustion remains fatal. This small Console example is not an unlimited export.',
    'production-statistics-monitor': 'Connect a Production Statistics device and monitor on red. Neither device needs electricity. Use a display with at least 14 columns and 7 rows. Select Validate. Select Save. Select Run. Wait 120 ticks. The display shows one-minute iron rates and both 300-sample native histories. The oldest sample is on the left. The newest sample is on the right. Both series use one peak scale. The program does not accumulate history. Query refused means E_LIMIT, not empty data. No activity means both native series are zero.',
    'factoriopedia-program': 'Research Recipe Searcher. Craft a Factoriopedia Interface. It does not need electricity. Connect its Network to a computer on red. Paste the complete document. Select Validate. Select Save. Select Run. The program logs the item reference rocket capacity, water bounds, and both complete name lists, or E_LIMIT. These results do not prove that a current silo or tank can perform an operation.',
    'reference-speaker': 'Open Reference → Examples → One speaker note in the game. The tutorial contains research, power, red-wire setup, execution procedures, and expected results. This is the same program. The in-game tutorial does not require this external copy.',
    'reference-recipe': 'The in-game Find iron plate recipes tutorial uses one Recipe Searcher connected on red. The device does not need electricity. The tutorial prints actual smelting matches. This additional copy uses exactly the same source.',
    'reference-factory': 'Use the complete in-game Small factory dashboard setup. It specifies four peripherals, the chest and inserter, and separate wiring. Discovery and INPUT use red. TARGETS and OUTPUT use green. The tutorial controls one inserter, a KV hash with a three-second TTL, and two monitor rows.',
    'reference-writer': 'This is computer 1 in the complete Two-computer shared data tutorial. Run this writer on the shared red database first. Then run shared-telemetry on computer 2. Computer 2 uses the shared red database and a different physical database on green.',
    'speaker-alarm': 'Connect a powered vanilla programmable-speaker to a computer Network on red. The program plays one positional effect every 120 ticks. After a false result, it waits for the next timer. It does not retry in the same tick. Stop prevents future calls. It cannot cancel a submitted sample.',
    'speaker-melody': 'Connect a powered vanilla programmable-speaker on red. The program finds zero-based piano indices and requests one note every 30 ticks. It advances only after the audio quota permits submission. This uses simulation scheduling, not audio-sample timing. A disconnection or power error faults the program. Reconnect the speaker. Select Run again.',
    'speaker-catalogue': 'Connect a powered vanilla programmable-speaker on red. The program gets at most one page per callback. It stores the last page and cumulative count as plain state. It completes without a busy loop. Console history has limits and is not a complete catalogue export. Examine last_page during paging, or use the continuation pattern with your own storage.',
    'modem-sender': 'Connect one computer to one powered native radar with a red wire. First, run modem-receiver on a different computer and radar in the same force and surface. The sender transmits on numeric channel 200 every 60 ticks. It receives explicit replies on 201. These numbers are not wire colors.',
    'modem-receiver': 'Connect a second computer to its own powered native radar with a red wire. Do not connect the two discovery graphs. Start this receiver before modem-sender. It shares channel 200 on the physical radar, registers a named handler, and replies explicitly. It guarantees neither ACK nor retries. It gives no authority over remote peripherals.',
    'function-program': 'Place a computer. Electricity, peripherals, and wires are not necessary. In an empty Editor draft, choose Insert starter or paste this complete document. Select Validate. Select Save. Select Run. Insertion and validation do not save or execute code. The first dispatch immediately calls `sample()` and logs its result in Console. The explicit `samples` state increases once. It increases again at the first 60-tick timer deadline. Private `increment` is declared before use and is not exported. `sample` is visible before its declaration. Registration uses its string name, not its function value. Each callback has new locals and functions. Apply keeps the explicit count. An ordinary reload does not replay `start`. The live Console cannot call these functions.',
    'recipe-searcher-program': 'Research Recipe Searcher separately. Connect its Network directly to a computer on red. Neither device needs electricity. Paste the complete document. Select Validate. Select Save. Select Run. The program searches item and fluid products. After E_LIMIT, it restricts the search to an exact category. One category can still exceed 50 results or other budgets.',
    'peripheral-program': 'Connect a computer NETWORK to a device NETWORK with a red wire. Examine each color in Peripherals. Read program output in Console.',
    'logic-controller': 'Follow [your first inserter controller](first-controller.md). Stock uses INPUT red. Discovery uses NETWORK red. OUTPUT connects to the inserter.',
    'kv-program': 'Connect one database NETWORK on red. The database does not need electricity. Select Save. Select Run. Examine the delayed status and TTL in Console.',
    'monitor-program': 'Connect a monitor NETWORK on red. The monitor does not need electricity. Select Run. Activate a character cell. Use matching adjacent tiles to test resize.',
    'monitor-plot-program': 'Connect at most four logical monitors on red or green. They do not need electricity. The program uses one shared sine sample and replaces one complete row per screen. It keeps older rows as a rolling trace. Startup discovery, geometry checks, selection, and clearing use separate callbacks. It checks at most eight names per color. Red has priority for duplicate names. Resize or detach events restart discovery. It periodically retries unavailable screens. This is not a complete-grid repaint or an unlimited factory or network benchmark.',
    'smooth-sine-chart': 'Connect at most four logical monitors on red or green. They do not need electricity. The program draws a connected green line with 2×3 mosaic subpixels and a gray axis. It does not use text markers. It samples one phase and updates all selected screens every two ticks. It submits only rows with changed glyphs or colors. It uses scale 2 when a footprint axis exceeds three tiles. Otherwise, it uses scale 1. Grids have at most 32 columns and 22 rows. This example ships with version 0.1.7 and its runtime and presenter optimizations. Older published archives keep their original example. Paste the complete source. Select Validate. Select Save. Select Run. Do not run other content writers on these screens. This example caches rows. See the [subpixel design and verification boundaries](monitor-animation.md).',
    'configurator-program': 'Connect discovery NETWORK red. Connect separate TARGETS green to one inserter. The program sets A > 4, not A > 0. Supply an external A signal of at least 5 to move the inserter.',
    'configurator-sections': 'Connect discovery NETWORK red. Connect TARGETS green to one constant combinator. The program adds a section, activates it, and saves its actual index in computer state. It deliberately writes no signal filters.',
    'factory-controller': 'Follow the complete [factory wiring tutorial](factory.md). Keep one device per type reachable. Paste this whole document.',
    'shared-telemetry': 'Use the [second-computer setup](factory.md#second-computer-shared-and-private-data). Connect the shared database on red. Connect a separate physical database on green.',
}


def text(path):
    return (ROOT / path).read_text()


def quote_lua(value):
    eq = '='
    while ']' + eq + ']' in value:
        eq += '='
    return '[' + eq + '[' + value + ']' + eq + ']'


def guest_example(name):
    if name == 'function-program':
        source = text('examples/' + name + '.lua')
        template = re.search(r'template=\[\[(.*?)\]\],', text('scripts/ui/help.lua'), re.S)
        if not template or template[1] != source:
            raise ValueError('function-program source differs from the inserted starter')
        return source.rstrip()
    if name == 'smooth-sine-chart':
        return text('examples/' + name + '.lua').rstrip()
    match = re.search(r'return \[(=*)\[(.*)\]\1\]\s*$', text('examples/' + name + '.lua'), re.S)
    if not match:
        raise ValueError('missing source wrapper: ' + name)
    return match[2]


def generated():
    examples = ['# Complete runnable programs', '',
                'Copy a complete code block into the [single-document editor](editor.md).',
                'Select Validate. Select Save. Select Run.',
                'These are the exact supplied source documents without their host wrappers.',
                'There is no guest require or file import. These small fixtures are not unlimited factory managers.',
                'Keep the specified topology. The implementation harness tested runtime effects.',
                'Documentation checks compile these blocks. They do not prove graphical keyboard, focus, or touch behavior.', '']
    for name, intro in EXAMPLES.items():
        examples += ['## ' + name, '', intro, '', '```lua', guest_example(name), '```', '']

    examples += ['## Retained API examples', '',
                 'These complete sources come from the former API companions.',
                 'Use a separate stopped computer for each program. Do not combine programs.',
                 'The [wiring guide](getting-started.md), [factory setup](factory.md) and',
                 '[current typed reference](api/types.md) explain their device roles and limits.',
                 'The historical source identities below record the origins of these examples. They are not alternative API contracts.', '']
    seen = set()
    for record in api_migration.examples():
        if record['destination'] in seen:
            continue
        seen.add(record['destination'])
        examples += ['### ' + Path(record['destination']).stem, '']
        if record['path'] == 'openspec/api/examples.md':
            examples += ['Use one computer, one database, one Logic Handler, one Configurator and a 2×2 monitor rectangle.',
                         'Join their NETWORK ports on red. Separately connect a stock-reading chest to INPUT red.',
                         'Connect OUTPUT green and Configurator TARGET green to the powered inserters.',
                         'Enable chest content reading manually. The program configures inserters, not the chest.', '']
        elif record['kind'] == 'console':
            examples += ['These are separate live Console commands, not a saved program.',
                         'Replace the example `tc-42` with your red-connected monitor name.',
                         'Run each line in order. The write changes the real monitor.',
                         'Stop, Run, or confirmed Reset Shell clears these bindings.', '']
        else:
            examples += ['Connect the peripherals named in the source on their stated discovery color.',
                         'Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.',
                         'Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.',
                         'Select Validate. Select Save. Select Run. Examine Console and the device.', '']
        examples += ['Source identity: `' + record['path'] + ':' + str(record['index']) + '`.', '',
                     '```' + ('lua' if record['kind'] == 'program' else 'text'),
                     api_migration.example_source(record), '```', '']
    return {'examples.md': '\n'.join(examples)}


def inventory():
    manifest = json.loads(text('docs/api-coverage.json'))
    names = manifest['public_namespaces']
    maps = manifest['peripheral_methods']
    methods = lambda s: set(re.findall(r"method\('([A-Za-z]+)'", s))
    computer = methods(text('scripts/runtime/computer.lua')) | {'stop'}
    peripheral = methods(text('scripts/services/peripheral.lua')) | {'call', 'getName', 'getWire'}
    command_list = re.search(r"for _,name in ipairs\(\{(.*?)\}\) do\n  local command", text('scripts/services/kv.lua'), re.S)
    assert command_list, 'KV command registration shape changed'
    kv = set(re.findall(r"'([A-Za-z]+)'", command_list[1]))
    monitor_source = text('scripts/monitor-model.lua')
    monitor = methods(monitor_source) | {'setPaletteColor', 'setTextScale', 'getLimits'}
    alias_section = monitor_source.split("for _,name in ipairs({", 1)[1].split('}) do', 1)[0]
    monitor |= {n.replace('Color', 'Colour') for n in re.findall(r"'([A-Za-z]+)'", alias_section)}
    actual = {'computer': computer, 'peripheral': peripheral, 'kv_database': kv,
              'logic_handler': methods(text('scripts/services/logic.lua')),
              'configurator': methods(text('scripts/services/configurator.lua')), 'monitor': monitor,
              'recipe_searcher': set(re.findall(r'function methods\.([A-Za-z]+)\(', text('scripts/services/recipe-searcher.lua'))),
              'factoriopedia_interface': set(re.findall(r'function methods\.([A-Za-z]+)\(', text('scripts/services/factoriopedia-interface.lua'))),
              'production_statistics': set(re.findall(r'function methods\.([A-Za-z]+)\(', text('scripts/services/production-statistics.lua'))),
              'dashboard': methods(text('scripts/services/dashboard.lua')),
              'speaker': set(re.findall(r'function M\.methods\.([A-Za-z]+)\(', text('scripts/services/speaker.lua'))),
              'modem': set(re.findall(r'function M\.methods\.([A-Za-z]+)\(', text('scripts/services/modem.lua')))}
    expected = {'computer': names['computer'], 'peripheral': names['peripheral'], **maps}
    pages = {'computer': 'api/computer.md', 'peripheral': 'api/peripheral.md', 'kv_database': 'api/kv.md',
             'logic_handler': 'api/logic.md', 'configurator': 'api/configurator.md', 'monitor': 'api/monitor.md',
             'recipe_searcher': 'api/recipe-searcher.md', 'factoriopedia_interface': 'api/factoriopedia-interface.md', 'production_statistics': 'api/production-statistics.md', 'dashboard': 'api/dashboard.md', 'modem': 'api/modem.md', 'speaker': 'api/speaker.md'}
    for namespace, exports in actual.items():
        if exports != set(expected[namespace]):
            raise ValueError(f'export inventory drift {namespace}: {exports ^ set(expected[namespace])}')
        page = (DOCS / pages[namespace]).read_text()
        for name in exports:
            if not re.search(r'\b' + name + r'\(', page):
                raise ValueError(f'undocumented {namespace}.{name}')
    all_docs = '\n'.join(p.read_text() for p in DOCS.rglob('*.md'))
    sandbox_source = text('scripts/runtime/sandbox.lua')
    helpers = {'globals': sorted(set(re.findall(r'env\.([a-z]+)=function', sandbox_source)))}
    # Explicit aliases/constants belong to the public inventory too, even though
    # they do not introduce a second function definition.
    assert 'env.unpack=tab.unpack' in sandbox_source and "env._VERSION='Lua 5.2'" in sandbox_source
    helpers['globals'] = sorted(set(helpers['globals']) | {'unpack', '_VERSION'})
    math_list = re.search(r"for _,name in ipairs\(\{('abs'.*?)\}\) do", sandbox_source)
    assert math_list, 'Math registration shape changed'
    helpers['math'] = re.findall(r"'([a-z0-9]+)'", math_list[1]) + ['pi']
    helpers['string'] = sorted(set(re.findall(r'str\.([a-z]+)=function', sandbox_source)) | {'lower', 'upper', 'reverse'})
    helpers['table'] = sorted(set(re.findall(r'tab\.([a-z]+)=function', sandbox_source)))
    for family, entries in helpers.items():
        for name in entries:
            if not re.search(r'\b' + name + r'\b', all_docs):
                raise ValueError(f'undocumented standard helper {family}.{name}')
    for name in names['colors'] + manifest['events']:
        if name not in all_docs:
            raise ValueError('undocumented color/event: ' + name)
    capability_pages = {'dashboard-interface': ['dashboard.md', 'api/dashboard.md'], 'production-statistics': ['api/production-statistics.md'], 'factoriopedia-interface': ['api/factoriopedia-interface.md'], 'speaker-peripheral': ['api/speaker.md'], 'radar-modem': ['api/modem.md', 'radar-native-assets.md'],
                        'computer-runtime': ['api/computer.md', 'api/language.md', 'api/common.md'],
                        'program-editor': ['editor.md'], 'device-lifecycle': ['lifecycle.md'],
                        'peripheral-network': ['api/peripheral.md'], 'monitor-display': ['api/monitor.md'],
                        'kv-database': ['api/kv.md'], 'logic-handler': ['api/logic.md'],
                        'device-configurator': ['api/configurator.md', 'api/settings.md', 'api/schemas.md']}
    contract_inventory = {}
    for cap, pageset in capability_pages.items():
        contract = ROOT / manifest['contract_root'] / manifest['capabilities'][cap]['contract']
        specification = ROOT / manifest['capabilities'][cap]['specification']
        assert contract.is_file() and specification.is_file()
        for page in pageset:
            assert (DOCS / page).is_file()
        contract_inventory[cap] = {
            'contract': str(contract.relative_to(ROOT)),
            'contract_sha256': hashlib.sha256(contract.read_bytes()).hexdigest(),
            'specification_sha256': hashlib.sha256(specification.read_bytes()).hexdigest(),
            'requirements': re.findall(r'^### Requirement: (.+)$', specification.read_text(), re.M),
            'reviewed_player_pages': pageset,
        }
    shell_root=CONTRACT / 'specs/console-shell'
    for name in ('spec.md',):
        assert (shell_root / name).is_file(), 'missing Console contract'
    assert 'console.md' in text('mkdocs.yml') and (DOCS / 'console.md').is_file()
    assert 'no command history' in (DOCS / 'console.md').read_text().lower()
    for file in ['api/common.d.lua', 'api/globals.d.lua', 'docs/player/api/language.md']:
        assert (ROOT / file).is_file()
    catalog = json.loads(CONFIGURATION_SOURCE.read_text())
    return {'exports': {k: sorted(v) for k, v in actual.items()},
            'export_count': sum(len(v) for v in actual.values()),
            'configurator': {'behavior_classes': len(catalog['behaviors']),
                             'root_field_entries': sum(len(b['writable_fields']) for b in catalog['behaviors']),
                             'concepts': len(catalog['concepts']), 'enum_groups': len(catalog['enum_values'])},
            'events': manifest['events'], 'contracts': contract_inventory,
            'contract_extensions': [{'path': path, 'sha256': hashlib.sha256((ROOT / path).read_bytes()).hexdigest()}
                                    for path in manifest.get('contract_extensions', [])],
            'standard_helpers': helpers,
            'colors': names['colors'], 'capability_pages': capability_pages,
            'inventory_kind': 'Independent implementation exports, typed public declarations and behavioral specs; not runtime or graphical acceptance'}


def site_links(folder):
    class Links(HTMLParser):
        def __init__(self):
            super().__init__(); self.ids = set(); self.hrefs = []
        def handle_starttag(self, tag, attrs):
            a = dict(attrs)
            if 'id' in a: self.ids.add(a['id'])
            if tag == 'a' and 'href' in a: self.hrefs.append(a['href'])
    parsed = {}
    for p in folder.rglob('*.html'):
        parser = Links(); parser.feed(p.read_text()); parsed[p.resolve()] = parser
    if not parsed:
        raise ValueError(f'no built HTML pages found: {folder}')
    checked = 0
    for p, parser in parsed.items():
        for href in parser.hrefs:
            u = urlsplit(href)
            if u.scheme or u.netloc or href.startswith('/'):
                continue
            target = (p.parent / unquote(u.path)).resolve() if u.path else p
            if target.is_dir(): target /= 'index.html'
            if not target.is_file(): raise ValueError(f'broken built link {p}: {href}')
            if u.fragment and target in parsed and unquote(u.fragment) not in parsed[target].ids:
                raise ValueError(f'broken built anchor {p}: {href}')
            checked += 1
    return {'html_pages': len(parsed), 'internal_links_checked': checked}


def fixture_archive(source, destination):
    blocks = []
    for p in sorted(DOCS.rglob('*.md')):
        if p.read_text().startswith(api_reference.NOTICE):
            continue  # Definition examples/signatures are not saved programs.
        for i, m in enumerate(re.finditer(r'```lua\n(.*?)\n```', p.read_text(), re.S), 1):
            blocks.append((str(p.relative_to(ROOT)) + ':' + str(i), m[1], None))
    assert blocks, 'no runnable examples'
    for record in api_migration.examples():
        source_text = api_migration.example_source(record)
        identity = record['path'] + ':' + str(record['index'])
        if record['kind'] == 'console':
            for index, line in enumerate(source_text.splitlines(), 1):
                blocks.append((identity + ':command-' + str(index), line, 'shell'))
        else:
            assert any(code == source_text for _, code, _ in blocks), 'lost runnable example: ' + identity
    fixture = ["local compiler=require('scripts.runtime.compiler')", "local admission=require('scripts.runtime.admission')",
               'local M={}', 'function M.run()']
    for name, code, mode in blocks:
        fixture += ['do local plan,err=compiler.compile(' + quote_lua(code) + ',admission.context(admission.new(),"docs",0),' + ('"shell"' if mode else 'nil') + ')',
                    'assert(plan, ' + quote_lua(name + ': ') + '..(err and err.message or "unknown compiler refusal"))',
                    'log(' + quote_lua('TC_CONTRACT ' + name) + ') end']
    fixture += ['log("TC_CONTRACT_TOTAL ' + str(len(blocks)) + '")', 'end', 'return M']
    destination = destination.resolve()
    if destination.is_relative_to(ROOT) or destination.exists():
        raise ValueError('verification ZIP must be new and outside checkout')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(source) as src, zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED) as dst:
        prefix = next(n.rsplit('/', 1)[0] for n in src.namelist() if n.endswith('/info.json'))
        for info in src.infolist(): dst.writestr(info, src.read(info.filename))
        dst.writestr(prefix + '/tests/player_documentation.lua', '\n'.join(fixture) + '\n')
    return {'compile_only_blocks': len(blocks), 'fixture_archive': str(destination),
            'fixture': 'tests.player_documentation', 'not_the_release_archive': True}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--change', help='read-only proposed API overlay check; requires --check')
    ap.add_argument('--site', type=Path)
    ap.add_argument('--fixture-archive', type=Path)
    ap.add_argument('--fixture-output', type=Path)
    ap.add_argument('--report', type=Path)
    ap.add_argument('--luals', type=Path, default=os.environ.get('LUALS_BIN') or shutil.which('lua-language-server'))
    args = ap.parse_args()
    if args.change and (not args.check or args.site or args.fixture_archive or args.fixture_output):
        ap.error('--change requires --check and cannot build a site or fixture')
    if not args.luals:
        ap.error('set LUALS_BIN or --luals to the verified tools/luals-lock.json binary')
    if args.change:
        from api_changes import check_change
        evidence = Path(tempfile.mkdtemp(prefix='tc-api-change-', dir=os.environ['TMPDIR']))
        report = check_change(ROOT, args.change, args.luals, evidence / 'verification')
        report['export_evidence'] = str(evidence)
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report))
        return
    limits_path = ROOT / 'api/generated/limits.d.lua'
    limits = limit_declarations()
    if args.check:
        api_reference.check_products({'api/generated/limits.d.lua': limits})
    else:
        limits_path.write_text(limits)
    evidence = Path(tempfile.mkdtemp(prefix='tc-api-export-', dir=os.environ['TMPDIR']))
    records = api_records(export_api(ROOT / 'api', args.luals, evidence))
    products, topics, locations = api_reference.generate(records)
    products.update({'docs/player/' + path: body for path, body in generated().items()})
    products['docs/api-migration.md'] = api_migration.appendix()
    provenance = api_reference.provenance(products)
    products['docs/api-reference-provenance.json'] = json.dumps(provenance, indent=2, sort_keys=True) + '\n'
    if args.check:
        api_reference.check_products(products)
    else:
        for relative, body in products.items():
            path = ROOT / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(body)
    report = inventory()
    validate_api_inventory(records, report)
    report['migration'] = api_migration.validate(records)
    report['public_definitions'] = len(records)
    report['api_topics'] = len(topics)
    report['locations'] = locations
    report['export_evidence'] = str(evidence)
    report['generated_pages'] = sorted(p for p in products if p.endswith('.md'))
    report['documentation_pages'] = len(list(DOCS.rglob('*.md')))
    report['source_hashes'] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in sorted((ROOT / 'scripts').rglob('*.lua'))}
    if args.site: report['built_links'] = site_links(args.site.resolve())
    if args.fixture_archive:
        if not args.fixture_output: ap.error('--fixture-output required')
        report['syntax_fixture'] = fixture_archive(args.fixture_archive, args.fixture_output)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
