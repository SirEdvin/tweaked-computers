"""Frozen old-section identities and exact retained runnable source checks."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def confined(root, relative):
    path = root / relative
    if Path(relative).is_absolute() or '..' in Path(relative).parts or path.is_symlink():
        raise ValueError('unsafe migration destination: ' + relative)
    if not path.resolve().is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError('missing migration destination: ' + relative)
    return path


def example_source(record, root=ROOT):
    text = confined(root, record['destination']).read_text()
    if record['form'] == 'module':
        match = re.search(r'return \[(=*)\[(.*)\]\1\]\s*$', text, re.S)
        if not match:
            raise ValueError('missing example module source: ' + record['destination'])
        text = match[2]
    elif record['form'] == 'source':
        text = text.removesuffix('\n')
    else:
        raise ValueError('unsupported retained example format')
    if hashlib.sha256(text.encode()).hexdigest() != record['sha256']:
        raise ValueError('changed retained example: ' + record['path'] + ':' + str(record['index']))
    return text


def examples(root=ROOT):
    records = json.loads((root / 'tools/data/api-example-migration.json').read_text())['examples']
    identities = [(r['path'], r['index']) for r in records]
    if len(records) != 22 or len(set(identities)) != len(records):
        raise ValueError('retained example inventory drift')
    for record in records:
        if record['kind'] not in ('program', 'console'):
            raise ValueError('unknown retained example kind')
        example_source(record, root)
    return records


def validate(records, root=ROOT):
    migration = json.loads((root / 'tools/data/api-section-migration.json').read_text())
    sources = migration['sources']
    if len(sources) != migration['source_count'] or len({s['path'] for s in sources}) != len(sources):
        raise ValueError('migration source inventory drift')
    headings = sum(len(s['sections']) for s in sources)
    if headings != migration['heading_count']:
        raise ValueError('migration heading inventory drift')
    for source in sources:
        for section in source['sections']:
            if not section['heading'] or not section['destinations']:
                raise ValueError('unmapped migration heading: ' + source['path'])
            for destination in section['destinations']:
                path, _, symbol = destination.partition('#')
                confined(root, path)
                if symbol and symbol not in records:
                    raise ValueError('missing migration type: ' + symbol)
    retained = examples(root)
    return {'sources': len(sources), 'headings': headings, 'example_identities': len(retained),
            'unique_example_sources': len({r['destination'] for r in retained})}


def appendix(root=ROOT):
    migration = json.loads((root / 'tools/data/api-section-migration.json').read_text())
    lines = ['# Typed API section and example migration', '',
             'Generated from `tools/data/api-section-migration.json` and',
             '`tools/data/api-example-migration.json`; identities only, not another API contract.',
             'Each old heading names its retained declaration, guide, behavior or acceptance destination.',
             'Source hashes identify the pre-retirement material. Line numbers below are historical.',
             'Lua fence indexes count Lua blocks only, not text/signature fences.', '',
             'Runtime disagreements were resolved against unchanged source and Factorio 2.1.23 probes:',
             'custom devices do not need electricity; wire order is red before green; monitor',
             'getLimits has zero arguments; Console log has a trailing-argument exception;',
             'pcall and xpcall differ for protected-handle errors; falsey blit foreground and',
             'Dashboard format=false retain their existing behavior. Configurator readback',
             'does not inherit write-only requiredness or input ceilings. Historical native',
             'inventory provenance is not evidence of current engine validation.', '']
    for source in migration['sources']:
        lines += ['## ' + source['path'], '',
                  'Action: ' + source['action'] + '. Original SHA-256: `' + source['sha256'] + '`.', '',
                  '| Old line / heading | Retained destinations |', '| --- | --- |']
        for section in source['sections']:
            lines += ['| ' + str(section['line']) + ' — ' + section['heading'].replace('|', '\\|') +
                      ' | ' + '; '.join('`' + d + '`' for d in section['destinations']) + ' |']
        lines += ['']
    lines += ['## Exact retained examples', '', '| Old identity | Source | Kind | SHA-256 |', '| --- | --- | --- | --- |']
    for record in examples(root):
        lines += ['| `' + record['path'] + ':' + str(record['index']) + '` | `' + record['destination'] +
                  '` | ' + record['kind'] + ' | `' + record['sha256'] + '` |']
    return '\n'.join(lines) + '\n'
