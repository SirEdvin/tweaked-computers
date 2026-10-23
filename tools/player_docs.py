#!/usr/bin/env python3
"""Generate player reference tables/examples and check their implementation inventory.

No network, new framework or game client. --fixture-archive adds compile-only
examples to a separate verification ZIP for the existing official-engine harness.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
import zipfile
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / 'docs/player'
CONTRACT = ROOT / 'openspec'
EXAMPLES = {
    'reference-speaker': 'The in-game Reference → Examples → One speaker note tutorial includes complete research, power, red-wire setup, execution steps and expected results. This is the same small program, not an external prerequisite.',
    'reference-recipe': 'The in-game Find iron plate recipes tutorial connects one powered Recipe Searcher on red and prints actual smelting matches. This supplementary copy uses the exact same source.',
    'reference-factory': 'The in-game Small factory dashboard tutorial includes the exact four-peripheral and chest/inserter setup, red discovery/INPUT and green TARGETS/OUTPUT separation. It teaches one inserter, a three-second KV hash and a two-line monitor; use its complete in-game setup.',
    'reference-writer': 'Computer 1 of the self-contained Two-computer shared data tutorial. Run this writer on the shared red database before running shared-telemetry on computer 2 with the shared red and a different physical green database.',
    'speaker-alarm': 'Connect a powered vanilla programmable-speaker to a computer Network on red. Requests one positional effect every 120 ticks. Work pressure suspends before submission instead of returning false for a note-count quota; do not retry an uncertain native effect. Stop prevents future calls, not cancellation of an already submitted sample.',
    'speaker-melody': 'Connect a powered vanilla programmable-speaker on red. Discovers zero-based piano indices and requests one note every 30 ticks; advances only after submission. Work pressure may delay the call. This is simulation scheduling, not sample-accurate sequencing. Disconnect/power loss reports an error; reconnect and Run again.',
    'speaker-catalogue': 'Connect a powered vanilla programmable-speaker on red. Fetches at most one page per callback and stores the last page and cumulative count as plain state. Completes without a busy loop. The bounded Console history is not a complete catalogue export; inspect last_page while paging or reuse the continuation pattern with your own storage.',
    'modem-sender': 'Wire one powered computer to one native radar on red. Run modem-receiver on a different computer/radar on the same force and surface first. Sends on numeric channel 200 every 60 ticks and receives explicit replies on 201; these numbers are not wire colors.',
    'modem-receiver': 'Wire a second powered computer to its own radar on red, without connecting the two discovery graphs. Start this receiver before modem-sender. Shares channel 200 on the physical radar, registers a named handler and replies explicitly; no ACK/retry guarantee or remote peripheral authority.',
    'function-program': 'Power a computer; no peripheral or wire is required. In an empty Editor draft, choose Insert starter (or paste this whole document), Validate, Save, then Run. Insertion and validation do not save or execute anything. The first dispatch calls `sample()` immediately and logs its returned count in Console; the `samples` value in explicit computer state increases once, then once more at the first 60-tick timer deadline. Private `increment` is declared before use and is not exported. `sample` is forward-visible and registration uses its string name, not its function value. Each callback has fresh locals/functions; reapplying keeps the explicit count, while ordinary reload does not replay `start`. These functions are not callable from the live Console. The legacy descriptor examples below remain supported.',
    'recipe-searcher-program': 'Research Recipe Searcher separately, power it and connect its Network directly to a computer on red. Paste the whole document, Validate, Save and Run. Searches item/fluid products and refines E_LIMIT by exact category; a single category may still exceed 50 or other budgets.',
    'peripheral-program': 'Wire a computer NETWORK to any device NETWORK on red. Inspect each color in Peripherals; read program output in Console.',
    'logic-controller': 'Follow [your first inserter controller](first-controller.md). Stock INPUT red, discovery NETWORK red, OUTPUT to the inserter.',
    'kv-program': 'Connect one powered database NETWORK on red. Save/Run; inspect the delayed status/TTL in Console.',
    'monitor-program': 'Connect a powered monitor NETWORK on red. Run, then activate a character cell; use matching adjacent tiles to test resize.',
    'monitor-plot-program': 'Connect up to four powered logical monitors on red/green. Uses one shared sine sample and replaces one complete row per screen, retaining older rows as a rolling trace. Startup discovery, geometry inspection, selection and clearing are deliberately sliced across callbacks. Checks at most eight names per color; red wins duplicate names. Resize/detach events restart discovery; unavailable screens are retried periodically. This is not a full-grid repaint or an unlimited factory/network benchmark.',
    'smooth-sine-chart': 'Connect up to four powered logical monitors on red/green. Draws a connected green line using 2×3 mosaic subpixels instead of text markers, with a gray axis. Samples one phase and updates all selected screens every two ticks, submitting only rows whose glyphs or colors changed. Uses scale 2 when a footprint axis exceeds three tiles, otherwise scale 1, and bounds grids to 32 columns / 22 rows. Ships with version 0.1.7 and its runtime/presenter optimizations; older published archives retain their original example. Paste the complete source, then Validate, Save and Run. Do not run other content writers on the same screens with this row-cached example. See the [subpixel design and verification boundaries](monitor-animation.md).',
    'configurator-program': 'Discovery NETWORK red; separate TARGETS green to one inserter. Sets A > 4, not A > 0. Supply an external A signal of at least 5 for motion.',
    'configurator-sections': 'Discovery NETWORK red; TARGETS green to one constant combinator. Adds a section, activates it and saves its actual index in computer state; it intentionally writes no signal filters.',
    'factory-controller': 'Follow the complete [factory wiring tutorial](factory.md). Keep one device per type reachable. Paste this whole document.',
    'shared-telemetry': 'Use the [second-computer setup](factory.md#second-computer-shared-and-private-data): shared database on red, separate physical database on green.',
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
    catalog = json.loads((CONTRACT / 'specs/device-configurator/configuration-catalog.json').read_text())
    ledger = json.loads(text('docs/configuration-coverage.json'))
    indexed = {(f['behavior'], f['field']): f for f in ledger['fields']}
    def typename(t):
        if isinstance(t, str):
            if t in ('QualityID', 'SpaceLocationID'):
                return 'registered ' + ('quality' if t == 'QualityID' else 'location') + ' name string'
            if t.startswith('defines.'):
                return ', '.join('`' + x + '`' for x in catalog['enum_values'][t])
            if t in catalog['concepts'] and t not in ('boolean', 'float', 'int32', 'uint32', 'string', 'nil', 'table'):
                return '[' + t + '](schemas.md#schema-' + t.lower() + ')'
            return {'int32': 'integer −2147483648…2147483647', 'uint32': 'integer 0…4294967295',
                    'float': 'finite number', 'string': 'string ≤256 bytes, no NUL', 'table': 'bounded plain table'}.get(t, t)
        kind = t['complex_type']
        if kind == 'literal':
            return '`' + str(t['value']) + '`'
        if kind == 'type':
            return typename(t['value'])
        if kind == 'array':
            return 'dense array ≤128 of ' + typename(t['value'])
        if kind == 'union':
            return ' or '.join(typename(x) for x in t['options'])
        if kind == 'table':
            return '{' + '; '.join('`' + f['name'] + ('?' if f['optional'] else '') + '`: ' + typename(f['type']) for f in t.get('parameters', [])) + '}'
        if kind == 'builtin':
            return 'bounded primitive; see the type name/ranges above'
        return 'bounded plain ' + kind
    out = ['# Supported configurator settings', '',
           'Factorio 2.0.77 circuit-control settings, grouped by native behavior family.',
           'These tables include inherited roots. Read current getCapabilities before writing:',
           'prototype/expansion/mode restrictions can make a listed field unavailable.',
           'Types link to the [complete nested schemas](schemas.md). All calls, patch semantics',
           'and target-network rules are in the [configurator reference](configurator.md).', '',
           'Boolean values are true/false, not numeric modes. Clearable means explicit patch',
           'clear is accepted; it can normalize to native defaults rather than nil.', '']
    for b in catalog['behaviors']:
        family = b['class'].removeprefix('Lua').removesuffix('ControlBehavior') or 'Base control behavior'
        out += ['## ' + family, '']
        if not b['writable_fields']:
            out += ['No writable root settings on this base behavior; derived families list their inherited settings below.', '']
            continue
        out += ['| Setting | Type | Clearable | Restriction |', '| --- | --- | --- | --- |']
        for f in b['writable_fields']:
            l = indexed[(b['class'], f['name'])]
            clear = f['optional'] and f['write_type'] in ('CircuitConditionDefinition', 'SignalID', 'ArithmeticCombinatorParameters', 'DeciderCombinatorParameters', 'SelectorCombinatorParameters') if isinstance(f['write_type'], str) else False
            restrictions = {
                'fuel_inventory_required': 'Requires fuel inventory',
                'rail_chain_signal_only': 'Chain signal only',
                'logistic_mode_requester_or_buffer': 'Requester/buffer only',
                'native_asteroid_no_logistic_connection': 'Unavailable: native inherited switch is ineffective',
                'ammo_or_fluid_turret_required': 'Ammo/fluid turret only',
                'set_requests_requires_space_travel': 'set_requests requires space travel',
                'registered_signal': 'Installed signal prototype',
                'explicit_signal_type': 'Explicit signal type required',
                'condition_operand_exclusive': 'Use constant or second_signal, not both',
                'condition_signal_roles': 'Only role-appropriate wildcards',
            }
            restriction = '; '.join(str(restrictions.get(c, c)) for c in l['constraints']) or 'Current native applicability'
            out += ['| `' + f['name'] + '` | ' + typename(f['write_type']) + ' | ' + ('yes' if clear else 'no') + ' | ' + restriction + ' |']
        if b['section_adapter']:
            out += ['', 'Also supports [constant-combinator section methods](configurator.md#constant-combinator-sections).']
        out += ['']
    schemas = ['# Configurator nested types and enums', '',
               'This is the player-readable schema companion to [supported settings](settings.md).',
               'Fields marked optional may be omitted; required fields must be present.',
               'Unknown fields are refused. Arrays are dense and at most 128 items. Strings',
               'are at most 256 bytes and cannot contain NUL. Numbers are finite; guest integer',
               'bounds remain exact. Prototype identities use installed names, never objects.', '',
               'SignalID/SignalIDBase require explicit type and name; quality defaults normal',
               'where supported. Conditional fulfilled is read-only and excluded. Quality/location',
               'object unions normalize to registered name strings. Selector fields must belong',
               'to the selected operation; default select. See [normalization](#normalization).', '']
    for name, concept in sorted(catalog['concepts'].items()):
        schemas += ['<a id="schema-' + name.lower() + '"></a>', '', '## ' + name, '']
        if name in ('QualityID', 'SpaceLocationID'):
            schemas += [typename(name), '']
            continue
        t = concept['type']
        if isinstance(t, dict) and t.get('complex_type') == 'builtin':
            schemas += [typename(name) if name != 'nil' else 'Absence only, never a stored Data value or implicit clear patch.', '']
            continue
        if not isinstance(t, dict) or t.get('complex_type') != 'table':
            schemas += [typename(t), '']
            continue
        schemas += ['| Field | Type | Required |', '| --- | --- | --- |']
        for f in t.get('parameters', []):
            if name == 'CircuitConditionDefinition' and f['name'] == 'fulfilled':
                continue
            required = not f['optional'] or name in ('SignalID', 'SignalIDBase') and f['name'] in ('type', 'name')
            schemas += ['| `' + f['name'] + '` | ' + typename(f['type']) + ' | ' + ('yes' if required else 'no') + ' |']
        for variant in t.get('variant_parameter_groups', []):
            schemas += ['', 'For operation **' + variant['name'] + '** only:', '',
                        '| Field | Type | Required |', '| --- | --- | --- |']
            for f in variant['parameters']:
                schemas += ['| `' + f['name'] + '` | ' + typename(f['type']) + ' | ' + ('no' if f['optional'] else 'yes') + ' |']
        if name == 'LogisticFilter':
            schemas += ['', 'Section filters additionally require `index`: integer 1–128. The list is dense',
                        'but indexes can be sparse. Duplicate indexes/identities refuse; nonzero min',
                        'requires explicit exact quality. max must not be below min.']
        schemas += ['']
    schemas += ['## Normalization', '',
                '- Conditions: constant/second_signal exclusive; comparator defaults <, constant 0.',
                '  >=, <=, != normalize to ≥, ≤, ≠. fulfilled is observation-only.',
                '- CircuitNetworkSelection omitted red/green means true for each.',
                '- Arithmetic defaults operation *, missing numeric operands 0; signal operands',
                '  replace corresponding constants. Each output needs each first input.',
                '- Decider compare_type defaults or; output constant defaults 1,',
                '  copy_count_from_input defaults true, networks default both. Each output needs',
                '  an each condition. Ordinary condition first allows anything/everything;',
                '  ordinary second and ordinary signal roots reject wildcards.',
                '- Selector defaults select, index_constant 0, select_max true. count has optional',
                '  count_signal; random defaults random_update_interval 0 (ticks). stack-size',
                '  and rocket-capacity accept no operation-specific fields. quality-filter accepts',
                '  registered quality/quality-comparator; quality-transfer requires destination',
                '  signal, defaults select_quality_from_signal false and static normal; selecting',
                '  signal quality uses quality_source_signal instead of static source.',
                '- SignalFilter/QualityCondition readback includes normal and comparator = defaults.',
                '  BlueprintQualityID defaults name normal. Ordinary signal quality defaults normal.',
                '- LogisticFilter min defaults 0; registered nauvis is the default item import location.',
                '  Section multiplier readback preserves native float32 precision.',
                '- Native enum values are strings, not defines ordinals. Speaker instrument/note',
                '  IDs are zero-based and validated against the actual target catalogue.', '',
                '## Native enum names', '']
    for name, values in sorted(catalog['enum_values'].items()):
        schemas += ['### ' + name, '', ', '.join('`' + v + '`' for v in values), '']
    examples = ['# Complete runnable programs', '',
                'Copy a whole code block into the [single-document editor](editor.md), Validate,',
                'Save, then Run. These are the exact shipped source documents, with host wrappers',
                'removed. There is no guest require/file import. Small fixtures are not unlimited',
                'factory managers; keep the described topology. Runtime effects were exercised by',
                'the implementation harness; documentation checks compile these blocks without',
                'claiming graphical keyboard/focus/touch delivery.', '']
    for name, intro in EXAMPLES.items():
        examples += ['## ' + name, '', intro, '', '```lua', guest_example(name), '```', '']
    limits = re.findall(r'(\w+)\s*=\s*(\d+)', text('scripts/runtime/limits.lua'))
    limit_page = ['# Common effective limits', '',
                  'All integer keys returned by computer.getLimits(). Version keys identify the',
                  'API/compiler/storage representation rather than capacities. Work/compile/allocation',
                  'units are implementation admission units, not milliseconds or measured host bytes.',
                  'Tick-keyed counters persist through same-tick load/replacement. Maintenance is',
                  'reserved inside host_work_per_tick, never added on top. These alpha limits are',
                  'provisional safety ceilings, not simultaneous maximum-world guarantees.', '',
                  '## Live mod settings', '',
                  'Open **Settings → Mod settings → Map** to change the runtime-global',
                  'budgets below while playing. They apply to every player and computer in the',
                  'save, without restarting the map. The table lists defaults; computer.getLimits()',
                  'returns the current effective values in a defensive copy.', '',
                  '| Setting | Limit key | Default | Allowed range |',
                  '| --- | --- | ---: | ---: |',
                  '| Compilation work per computer per tick (`tc-compile-work`) | `compile_work` | 1250000 | 1–100000000 |',
                  '| Execution work per computer per tick (`tc-callback-work`) | `callback_work` | 500000 | 1–100000000 |',
                  '| Guest allocations per computer per tick (`tc-callback-allocations`) | `callback_allocations` | 81920 | 1–100000000 |',
                  '| Shared host work per tick (`tc-host-work-per-tick`) | `host_work_per_tick` | 5000000 | 200001–1000000000 |',
                  '| Disposable compiler cache bytes (`tc-compiler-cache-bytes`) | `compiler_cache_bytes` | 8388608 | 1–1000000000 |',
                  '| World maintenance work per tick (`tc-maintenance-work-per-tick`) | `maintenance_work_per_tick` | 200000 | 200000–100000000 requested |', '',
                  'Compilation, execution and allocation defaults are five times the original',
                  'allowances. The shared host default is also five times larger so it can admit',
                  'them. The maintenance default remains 200000 admission units.',
                  'Prefer a shared ceiling at least as large as all three per-computer budgets',
                  'combined plus maintenance. A smaller shared budget can defer callbacks or',
                  'cause E_BUDGET when actual work exceeds its remaining allowance.', '',
                  'Changes never reset spending: raising a budget adds only the difference;',
                  'lowering it below already-spent credits refuses further charged operations',
                  'until a later tick or another increase. Existing faulted programs still require',
                  'Run to restart. Validate, Run validation and callback reconstruction share',
                  'compilation credits. Higher budgets may reduce UPS; these are not speed or',
                  'frame-rate controls. Source, state, depth, monitor and other structural caps',
                  'remain unchanged.', '',
                  '### Disposable compiler cache', '',
                  '`compiler_cache_bytes` bounds shared retained plans, generated continuation text',
                  'and deterministic charge traces, including metadata. These are accounting bytes,',
                  'not measured Lua heap bytes. There is no separate plan-count or trace-count cap.',
                  'Capacity pressure evicts the cache as a batch; an oversized proof is simply rebuilt.',
                  'The cache is private and disposable: cold, warm and evicted proofs charge the same',
                  'accepted work prefixes, so cache warmth cannot change progress or renew credits.',
                  'Reducing cache retention does not invalidate saved source or suspended invocations.', '',
                  '### Maintenance and shared headroom', '',
                  'The effective maintenance ceiling is `min(requested maintenance, host_work_per_tick - 1)`.',
                  'The requested setting is preserved, so raising host work can make more of it',
                  'effective. This never raises the shared host setting. At least one guest unit',
                  'remains, but one unit cannot run a useful callback: choose host headroom for',
                  'your actual programs, preferably the three per-computer budgets plus maintenance.',
                  'Maintenance covers discovery, power/signal sampling, timers, notifications and',
                  'monitor preparation/publication/retirement. More maintenance can reduce guest',
                  'headroom; it does not automatically increase callback or monitor capacities.', '',
                  'Values below 200000 are deliberately unsupported in this alpha. The renderer',
                  'keeps its 60000 baseline reservation, alternating adaptive reservations up to',
                  '160000 and its separate 160000 whole-commit ceiling. Keeping the existing floor',
                  'preserves baseline non-render service opportunities for indivisible topology',
                  'work; lowering it needs separate feasibility measurements/reconciliation, not',
                  'just a smaller integer setting. Larger settings do not widen render commits.',
                  'The 100000000 upper bound is a provisional configurable-work safety ceiling,',
                  'not a measured CPU allowance or recommendation.', '',
                  'Live changes retain both ledgers, world/guest state and the frozen render',
                  'reservation. Even a previously captured maintenance callback reads the live',
                  'ceiling. No credit is refunded: guests cannot reuse maintenance already spent',
                  'after a decrease, and maintenance cannot reuse guest credits after an increase.',
                  'Reducing host work below combined spending preserves that spending and refuses',
                  'further charged work until a later tick or sufficient increase; it cannot undo',
                  'earlier effects. A saved spent count above the current ceiling is valid and',
                  'stays refused on same-tick reload. No paid reconciliation or on_load mutation',
                  'is needed; ordinary synchronized admission resets counters only on a new tick.', '',
                  '## Default common limits', '',
                  '| Key | Default value |', '| --- | ---: |']
    limit_page += ['| `' + k + '` | ' + v + ' |' for k, v in limits]
    limit_page += ['', 'Device-specific limits: [monitor](monitor.md#bounds-example-and-troubleshooting),',
                   '[KV](kv.md#atomicity-errors-and-capacities), [logic](logic.md#bounds-and-use),',
                   '[configurator](configurator.md#bounds-programs-and-troubleshooting),',
                   '[Recipe Searcher](recipe-searcher.md#complete-results-not-a-prefix).',
                   'See [shared rules](common.md) for Data accounting and refusal behavior.', '']
    return {'api/settings.md': '\n'.join(out), 'api/schemas.md': '\n'.join(schemas),
            'examples.md': '\n'.join(examples), 'api/limits.md': '\n'.join(limit_page)}


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
              'speaker': set(re.findall(r'function M\.methods\.([A-Za-z]+)\(', text('scripts/services/speaker.lua'))),
              'modem': set(re.findall(r'function M\.methods\.([A-Za-z]+)\(', text('scripts/services/modem.lua')))}
    expected = {'computer': names['computer'], 'peripheral': names['peripheral'], **maps}
    pages = {'computer': 'api/computer.md', 'peripheral': 'api/peripheral.md', 'kv_database': 'api/kv.md',
             'logic_handler': 'api/logic.md', 'configurator': 'api/configurator.md', 'monitor': 'api/monitor.md',
             'recipe_searcher': 'api/recipe-searcher.md', 'modem': 'api/modem.md', 'speaker': 'api/speaker.md'}
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
    language_page = (DOCS / 'api/language.md').read_text()
    for family, entries in helpers.items():
        for name in entries:
            if not re.search(r'\b' + name + r'\b', language_page):
                raise ValueError(f'undocumented standard helper {family}.{name}')
    for name in names['colors'] + manifest['events']:
        if name not in all_docs:
            raise ValueError('undocumented color/event: ' + name)
    capability_pages = {'speaker-peripheral': ['api/speaker.md'], 'radar-modem': ['api/modem.md', 'radar-native-assets.md'],
                        'computer-runtime': ['api/computer.md', 'api/language.md', 'api/common.md'],
                        'program-editor': ['editor.md'], 'device-lifecycle': ['lifecycle.md'],
                        'peripheral-network': ['api/peripheral.md'], 'monitor-display': ['api/monitor.md'],
                        'kv-database': ['api/kv.md'], 'logic-handler': ['api/logic.md'],
                        'device-configurator': ['api/configurator.md', 'api/settings.md', 'api/schemas.md']}
    contract_inventory = {}
    for cap, pageset in capability_pages.items():
        contract = CONTRACT / manifest['capabilities'][cap]['contract']
        specification = contract.with_name('spec.md')
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
    for name in ('spec.md', 'lua-api.md'):
        assert (shell_root / name).is_file(), 'missing Console contract'
    assert 'console.md' in text('mkdocs.yml') and (DOCS / 'console.md').is_file()
    assert 'no command history' in (DOCS / 'console.md').read_text().lower()
    for file in ['api/common.md', 'api/native-language.md']:
        assert (CONTRACT / file).is_file()
    catalog = json.loads((CONTRACT / 'specs/device-configurator/configuration-catalog.json').read_text())
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
            'inventory_kind': 'Static implementation-export/signature presence plus reviewed companion contracts; not runtime or graphical acceptance'}


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
        for i, m in enumerate(re.finditer(r'```lua\n(.*?)\n```', p.read_text(), re.S), 1):
            blocks.append((str(p.relative_to(ROOT)) + ':' + str(i), m[1]))
    assert blocks, 'no runnable examples'
    fixture = ["local compiler=require('scripts.runtime.compiler')", "local admission=require('scripts.runtime.admission')",
               'local M={}', 'function M.run()']
    for name, code in blocks:
        fixture += ['do local plan,err=compiler.compile(' + quote_lua(code) + ',admission.context(admission.new(),"docs",0))',
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
    ap.add_argument('--site', type=Path)
    ap.add_argument('--fixture-archive', type=Path)
    ap.add_argument('--fixture-output', type=Path)
    ap.add_argument('--report', type=Path)
    args = ap.parse_args()
    for path, body in generated().items():
        p = DOCS / path
        if args.check:
            if not p.is_file() or p.read_text() != body: raise ValueError('stale player documentation: ' + path)
        else:
            p.parent.mkdir(parents=True, exist_ok=True); p.write_text(body)
    report = inventory()
    report['generated_pages'] = list(generated())
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
