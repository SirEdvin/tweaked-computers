"""Pinned LuaLS JSON adapter and the two literal documentation projections."""
import copy
import hashlib
from html import escape
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PRIMITIVES = {'any', 'nil', 'boolean', 'number', 'integer', 'string', 'table', 'function', 'thread', 'userdata', 'lightuserdata'}
FAMILIES = {
    'computer': 'TC.Computer', 'peripheral': 'TC.PeripheralLibrary',
    'monitor': 'TC.Monitor', 'dashboard': 'TC.Dashboard', 'kv_database': 'TC.KVDatabase',
    'logic_handler': 'TC.LogicHandler', 'configurator': 'TC.Configurator',
    'recipe_searcher': 'TC.RecipeSearcher', 'factoriopedia_interface': 'TC.FactoriopediaInterface',
    'production_statistics': 'TC.ProductionStatistics', 'modem': 'TC.Modem', 'speaker': 'TC.Speaker',
}


def export_api(source, binary, output):
    """Run in an isolated copy; a zero exporter exit alone is not a receipt."""
    source, binary, output = source.resolve(), binary.resolve(), output.resolve()
    if output.is_relative_to(ROOT) or output.is_relative_to(source):
        raise ValueError('LuaLS output must be outside the checkout and declaration source')
    lock = json.loads((ROOT / 'tools/luals-lock.json').read_text())
    version = subprocess.run([str(binary), '--version'], check=True, capture_output=True, text=True).stdout.strip()
    if version != lock['version']:
        raise ValueError(f'LuaLS version {version!r}, expected {lock["version"]}')
    workspace = output / 'workspace'
    workspace.mkdir(parents=True, exist_ok=False)
    hashes = {}
    for path in sorted(source.rglob('*.d.lua')):
        if path.is_symlink() or not path.resolve().is_relative_to(source):
            raise ValueError(f'declaration path escapes source: {path}')
        relative = path.relative_to(source)
        target = workspace / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        hashes[relative.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    if not hashes:
        raise ValueError('no public declarations')
    for name in ('luals-export.lua', 'luals-docs.json'):
        shutil.copyfile(ROOT / 'tools' / name, output / name)
    flags = [str(binary), f'--configpath={output / "luals-docs.json"}',
             f'--metapath={output / "meta"}', '--locale=en-us']
    diagnostics = output / 'diagnostics.json'
    with (output / 'check.log').open('w') as log:
        result = subprocess.run(flags + [f'--check={workspace}', '--check_format=json',
                                f'--check_out_path={diagnostics}', f'--logpath={output / "check-logs"}'],
                                stdout=log, stderr=subprocess.STDOUT, timeout=120)
    if result.returncode or (diagnostics.exists() and json.loads(diagnostics.read_text())):
        raise ValueError(f'LuaLS diagnostics failed; see {output / "check.log"} and {diagnostics}')
    documents = output / 'documents'
    documents.mkdir()
    with (output / 'export.log').open('w') as log:
        result = subprocess.run(flags + [f'--doc={workspace}', f'--doc_out_path={documents}',
                                f'--logpath={output / "export-logs"}'],
                                stdout=log, stderr=subprocess.STDOUT, timeout=120)
    path = documents / 'doc.json'
    if result.returncode or not path.is_file():
        raise ValueError(f'LuaLS export failed or missing output; see {output / "export.log"}')
    raw = json.loads(path.read_text())
    if not isinstance(raw, list) or not raw:
        raise ValueError('empty or invalid LuaLS documentation output')
    provenance = {'definitions': hashes, 'tool': lock, 'configuration': {
        name: hashlib.sha256((ROOT / 'tools' / name).read_bytes()).hexdigest()
        for name in ('luals-docs.json', 'luals-export.lua')}}
    (output / 'provenance.json').write_text(json.dumps(provenance, indent=2, sort_keys=True) + '\n')
    return raw


def _name(value):
    if isinstance(value, str):
        return value
    return value.get('literal', value.get('[1]', '')) if value else ''


def _type(node):
    """Project parsed type nodes, never parse Lua or infer types from hover text."""
    kind = node.get('type')
    refs = set()
    def child(value):
        text, names = _type(value)
        refs.update(names)
        return text
    if kind == 'doc.type':
        text = '|'.join(child(t) for t in node['types'])
    elif kind in ('doc.type.name', 'doc.extends.name', 'doc.generic.name'):
        text = node['literal']
        if text not in PRIMITIVES and kind != 'doc.generic.name':
            refs.add(text)
    elif kind in ('doc.type.string', 'doc.type.integer', 'doc.type.boolean'):
        text = node['text']
    elif kind == 'doc.type.array':
        text = '(' + child(node['node']) + ')[]'
    elif kind == 'doc.type.sign':
        text = child(node['node']) + '<' + ', '.join(child(t) for t in node['signs']) + '>'
    elif kind == 'doc.type.function':
        args = []
        for arg in node['args']:
            args.append(_name(arg['name']) + ('?' if arg['optional'] else '') + ': ' + child(arg['extends']))
        results = [(_name(r.get('name')) + ': ' if r.get('name') else '') + child(r) for r in node['returns']]
        text = 'fun(' + ', '.join(args) + ')' + (': ' + ', '.join(results) if results else '')
    elif kind == 'doc.type.table':
        fields = []
        for field in node.get('fields', []):
            fields.append(_name(field.get('name') or field.get('field')) +
                          ('?' if field.get('optional') else '') + ': ' + child(field['extends']))
        text = '{' + ', '.join(fields) + '}'
    else:
        raise ValueError(f'unsupported exported type structure: {kind}')
    if node.get('optional'):
        text += '?'
    return text, sorted(refs)


def _position(node):
    return node.get('file'), tuple(node.get('start', []))


def _parameter(node, name, description, optional=False):
    text, refs = _type(node)
    return {'name': name, 'type': text, 'references': refs,
            'optional': optional, 'variadic': name == '...', 'description': description}


def _function(node, name, description):
    primary = {'parameters': [], 'returns': [], 'description': ''}
    overloads = []
    for annotation in node['annotations']:
        kind = annotation['type']
        if kind == 'doc.param':
            primary['parameters'].append(_parameter(annotation['extends'], _name(annotation['param']),
                                                    annotation.get('comment', ''), annotation['optional']))
        elif kind == 'doc.return':
            for result in annotation['returns']:
                primary['returns'].append(_parameter(result, _name(result.get('name')), annotation.get('comment', '')))
        elif kind == 'doc.overload':
            overloads.append(annotation)
        else:
            raise ValueError(f'unsupported function annotation: {kind}')
    actual = [_name(a.get('name')) or ('...' if a['type'] == '...' else '') for a in node.get('args', [])]
    if actual != [p['name'] for p in primary['parameters']]:
        raise ValueError(f'missing or misordered parameter annotations for {name}: {actual}')
    signatures = [primary]
    for annotation in overloads:
        overload = annotation['overload']
        params = {p['name']: p for p in primary['parameters']}
        signature = {'parameters': [], 'returns': [], 'description': annotation.get('comment', '')}
        for arg in overload['args']:
            key = _name(arg['name'])
            base = params.get(key, {})
            part_description = base.get('description', '') if base.get('type') == _type(arg['extends'])[0] else signature['description']
            signature['parameters'].append(_parameter(arg['extends'], key, part_description, arg['optional']))
        for index, result in enumerate(overload['returns']):
            base = primary['returns'][index] if index < len(primary['returns']) else {}
            part_description = base.get('description', '') if base.get('type') == _type(result)[0] else signature['description']
            signature['returns'].append(_parameter(result, _name(result.get('name')) or base.get('name', ''),
                                                   part_description))
        signatures.append(signature)
    # LuaLS stores the third comment hyphen in these parsed comment strings.
    prose = '\n'.join(line.removeprefix('-') for line in node.get('comments', [])) or description
    return {'name': name, 'kind': 'function', 'description': prose, 'signatures': signatures}


def api_records(raw):
    records, aliases, locations = {}, [], {}
    field_positions = {}
    for item in raw:
        if item['type'] == 'luals.config':
            continue
        if item['type'] not in ('type', 'variable'):
            raise ValueError(f'unsupported export structure: {item["type"]}')
        name = item['name']
        definitions = item.get('defines', [])
        if len(definitions) != 1:
            raise ValueError(f'expected one public definition for {name}, found {len(definitions)}')
        definition = definitions[0]
        if definition['file'].startswith('[FOREIGN]'):
            raise ValueError(f'unexpected foreign definition: {name}')
        if name in records:
            raise ValueError(f'duplicate public identity: {name}')
        record = {'name': name, 'description': item.get('rawdesc') or definition.get('rawdesc', ''),
                  'source': {'file': definition['file'], 'line': definition['start'][0] + 1},
                  'references': [], 'fields': {}}
        kind = definition['type']
        if kind == 'doc.class':
            record['kind'] = 'class'
            field_positions[name] = {}
            record['extends'] = [_type(parent)[0] for parent in definition.get('extends', [])]
            record['references'] = list(record['extends'])
            for field in item.get('fields', []):
                key = field['name']
                if key in record['fields']:
                    raise ValueError(f'duplicate field {name}.{key}')
                description = field.get('rawdesc', field.get('desc', ''))
                value = field['extends']
                if value['type'] == 'function':
                    normalized = _function(value, key, description)
                elif value['type'] == 'getfield':
                    normalized = {'name': key, 'kind': 'function', 'description': description}
                    aliases.append((normalized, value['aliases']))
                elif value['type'] == 'table' and value['view'].startswith('enum '):
                    normalized = {'name': key, 'kind': 'field', 'type': value['view'][5:],
                                  'references': [value['view'][5:]], 'description': description, 'optional': False}
                else:
                    text, refs = _type(value)
                    normalized = {'name': key, 'kind': 'field', 'type': text, 'references': refs,
                                  'description': description, 'optional': field['optional']}
                record['fields'][key] = normalized
                field_positions[name][key] = _position(field)
                locations[_position(field)] = normalized
        elif kind == 'doc.alias':
            record['kind'] = 'alias'
            record['type'], record['references'] = _type(definition['extends'])
            literal_nodes = [t for t in definition['extends']['types'] if t['type'] == 'doc.type.string']
            record['literals'] = [t['text'] for t in literal_nodes]
            for literal in literal_nodes:
                if literal.get('comment'):
                    record['description'] += '\n\n' + literal['text'] + ': ' + literal['comment']
        elif kind == 'doc.enum':
            record['kind'] = 'enum'
            record['values'] = {member['name']: member['value']['value'] for member in definition['members']}
            for member in definition['members']:
                description = member.get('rawdesc', '')
                if not description:
                    raise ValueError(f'missing enum member description: {name}.{member["name"]}')
                record['description'] += '\n\n' + member['name'] + ': ' + description
        elif kind in ('setglobal', 'setfield'):
            value = definition['extends']
            if value['type'] == 'function':
                record.update(_function(value, name, record['description']))
            elif value['type'] in ('getfield', 'getglobal'):
                record['kind'] = 'alias-value'
                aliases.append((record, value['aliases']))
            elif value['type'] == 'table':
                record['kind'] = 'namespace'
                record['type'] = value['view'].removeprefix('enum ')
                record['references'] = [record['type']]
            elif value['type'] in ('integer', 'number', 'string', 'boolean'):
                record['kind'] = 'constant'
                record['type'] = value['type']
                record['value'] = value['value']
            else:
                raise ValueError(f'unsupported public value {name}: {value["type"]}')
        else:
            raise ValueError(f'unsupported definition {name}: {kind}')
        records[name] = record
        locations[_position(definition)] = record
    for record, targets in aliases:
        matches = [locations[_position(t)] for t in targets if _position(t) in locations
                   and locations[_position(t)]['kind'] in ('function', 'namespace', 'constant')]
        if len(matches) != 1:
            raise ValueError(f'unresolved public alias: {record["name"]}')
        for key in ('kind', 'type', 'value', 'references', 'signatures'):
            if key in matches[0]:
                record[key] = copy.deepcopy(matches[0][key])
        record['description'] += '\n\n' + matches[0]['description']
    # LuaLS emits dotted globals a second time beside the class fields.
    for name in list(records):
        if records[name]['kind'] in ('class', 'alias', 'enum') or '.' not in name:
            continue
        namespace, member = name.rsplit('.', 1)
        if namespace in records:
            class_name = records[namespace].get('type')
            if member in records.get(class_name, {}).get('fields', {}):
                del records[name]
    for record in records.values():
        if not record['description'] and record.get('type') in records:
            record['description'] = records[record['type']]['description']
        for field in record['fields'].values():
            if not field['description'] and field.get('type') in records:
                field['description'] = records[field['type']]['description']
    # LuaLS repeats inherited methods for table-backed classes. Preserve genuine
    # overrides, but publish each source declaration once and link its parent.
    def inherited_positions(identity, seen=None):
        seen = set() if seen is None else seen
        if identity in seen or identity not in records:
            return {}
        seen.add(identity)
        result = {}
        for parent in records[identity].get('extends', []):
            result.update(inherited_positions(parent, seen))
        result.update(field_positions.get(identity, {}))
        return result
    for name, record in records.items():
        inherited = {}
        for parent in record.get('extends', []):
            inherited.update(inherited_positions(parent))
        for key in list(record['fields']):
            if key in inherited and field_positions[name][key] == inherited[key]:
                del record['fields'][key]
    validate_api_records(records)
    return dict(sorted(records.items()))


def validate_api_records(records):
    def check(record, identity):
        if not record.get('description', '').strip():
            raise ValueError(f'missing description for {identity}')
        for reference in record.get('references', []):
            if reference not in records:
                raise ValueError(f'unresolved type {reference} in {identity}')
        for signature in record.get('signatures', []):
            for part in ('parameters', 'returns'):
                for index, value in enumerate(signature[part]):
                    check(value, identity + '.' + (value['name'] or str(index + 1)))
        for key, field in record.get('fields', {}).items():
            check(field, identity + '.' + key)
    for identity, record in records.items():
        check(record, identity)


def public_fields(records, identity, visited=None):
    """Follow facade inheritance/union alternatives without expanding data graphs."""
    visited = set() if visited is None else visited
    if identity in visited:
        return {}
    visited.add(identity)
    record = records[identity]
    parents = record.get('extends', []) if record['kind'] == 'class' else record.get('references', [])
    fields = {}
    for parent in parents:
        fields.update(public_fields(records, parent, visited))
    fields.update(record.get('fields', {}))
    return fields


def validate_api_inventory(records, inventory):
    """Compare with the independent implementation/guest-fixture inventory."""
    if set(inventory['exports']) != set(FAMILIES):
        raise ValueError('public family inventory changed')
    for family, identity in FAMILIES.items():
        actual = {key for key, value in public_fields(records, identity).items() if value['kind'] == 'function'}
        expected = set(inventory['exports'][family])
        if actual != expected:
            raise ValueError(f'public export coverage {family}: missing={sorted(expected-actual)}, unexpected={sorted(actual-expected)}')
    helpers = inventory['standard_helpers']
    for namespace in ('table', 'string', 'math'):
        actual = set(public_fields(records, records[namespace]['type']))
        if actual != set(helpers[namespace]):
            raise ValueError('public helper coverage: ' + namespace)
    globals_expected = set(helpers['globals']) | {'computer', 'peripheral', 'table', 'string', 'math', 'colors', 'colours'}
    if {key for key in records if not key.startswith('TC.')} != globals_expected:
        raise ValueError('public global coverage')
    if set(records['TC.Color']['values']) != set(inventory['colors']):
        raise ValueError('public color coverage')
    if records['colors']['type'] != records['colours']['type']:
        raise ValueError('public colours alias differs')
    remaining = set(inventory['events'])
    for reference in records['TC.Event']['references']:
        discriminator = records[reference]['fields']['name']['type']
        found = [name for name in remaining if discriminator in (repr(name), json.dumps(name))]
        if len(found) != 1:
            raise ValueError('public event discriminator: ' + reference)
        remaining.remove(found[0])
    if remaining:
        raise ValueError('public event coverage: ' + ', '.join(sorted(remaining)))


def _prose_blocks(prose):
    blocks, paragraph, code = [], [], None
    def flush():
        if paragraph:
            blocks.append({'kind': 'prose', 'text': '\n'.join(paragraph)})
            paragraph.clear()
    for line in prose.splitlines():
        if code is not None:
            if line == '```':
                blocks.append({'kind': 'code', 'text': '\n'.join(code)})
                code = None
            else:
                code.append(line)
        elif line in ('```lua', '```text', '```'):
            flush()
            code = []
        elif line.startswith('```') or re.search(r'<\/?[A-Za-z][^>]*>|!\[|\]\([^)]*\)|^\|', line):
            raise ValueError(f'unsupported documentation markup: {line}')
        elif re.match(r'^#{1,6} ', line):
            flush()
            blocks.append({'kind': 'heading', 'text': line.lstrip('# ')})
        elif not line.strip():
            flush()
        else:
            paragraph.append(line)
    if code is not None:
        raise ValueError('unsupported unterminated documentation code fence')
    flush()
    return blocks


def api_blocks(record):
    blocks = [{'kind': 'heading', 'text': record['name']}]
    blocks.extend(_prose_blocks(record['description']))
    if record.get('type'):
        blocks.append({'kind': 'signature', 'text': record['type']})
    if 'value' in record:
        blocks.append({'kind': 'signature', 'text': record['name'] + ' = ' + json.dumps(record['value'])})
    for parent in record.get('extends', []):
        blocks.append({'kind': 'prose', 'text': 'Extends: ' + parent})
    for key, value in record.get('values', {}).items():
        blocks.append({'kind': 'signature', 'text': key + ' = ' + json.dumps(value)})
    for signature in record.get('signatures', []):
        parameters = [p['name'] + ('?' if p['optional'] else '') + ': ' + p['type'] for p in signature['parameters']]
        results = [r['name'] + ': ' + r['type'] for r in signature['returns']]
        blocks.append({'kind': 'signature', 'text': record['name'] + '(' + ', '.join(parameters) + ')' +
                       (' -> ' + ', '.join(results) if results else '')})
        blocks.extend(_prose_blocks(signature['description']))
        for part, title in (('parameters', 'Parameters'), ('returns', 'Returns')):
            blocks.append({'kind': 'heading', 'text': title})
            if not signature[part]:
                blocks.append({'kind': 'prose', 'text': 'No parameters.' if part == 'parameters' else
                               'No result positions. See the behavior notes for normal-return versus failure semantics.'})
            for index, value in enumerate(signature[part], 1):
                label = value['name'] or str(index)
                if value['optional']:
                    label += ' (optional)'
                if value['variadic']:
                    label += ' (zero or more positions)'
                blocks.append({'kind': 'prose', 'text': label + ': ' + value['type'] + '\n' + value['description']})
    for key, field in record.get('fields', {}).items():
        if field.get('optional'):
            field = dict(field, name=key + ' (optional)')
        blocks.extend(api_blocks(field))
    return blocks


def api_markdown(blocks):
    lines = []
    for block in blocks:
        if block['kind'] in ('code', 'signature'):
            fence = '`' * max(3, max((len(m[0]) + 1 for m in re.finditer(r'`+', block['text'])), default=3))
            lines.extend([fence + ('lua' if block['kind'] == 'code' else 'text'), block['text'], fence, ''])
        else:
            lines.extend([('### ' if block['kind'] == 'heading' else '') + escape(block['text'], quote=False), ''])
    return '\n'.join(lines)


def api_lua(blocks):
    def quote(value):
        eq = '='
        while ']' + eq + ']' in value:
            eq += '='
        return '[' + eq + '[\n' + value + ']' + eq + ']'
    return 'return {\n' + ''.join('  {kind=' + quote(block['kind']) + ',text=' + quote(block['text']) + '},\n'
                                   for block in blocks) + '}\n'
