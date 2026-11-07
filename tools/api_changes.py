"""Validate change-scoped API overlays without promoting or generating products."""
import hashlib
import json
from pathlib import Path
import re
import shutil

from lua_api import api_records, export_api

IMPACT = re.compile(r'^## API Impact\s*\n(.*?)(?=^## |\Z)', re.M | re.S)
API_PATH = re.compile(r'api/(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+\.d\.lua\Z')


def confined(root, relative):
    path = root / relative
    if any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError('symlink in API input: ' + str(path))
    if not path.resolve().is_relative_to(root.resolve()):
        raise ValueError('API input escapes root: ' + str(path))
    return path


def files(root, relative, pattern):
    base = confined(root, relative)
    for path in sorted(base.rglob('*')):
        confined(root, path.relative_to(root))
        if path.is_file() and path.match(pattern):
            yield path


def review_fingerprint(root, change):
    """A conservative review invalidator, not an API-change inference engine."""
    inputs = {}
    for directory, pattern in (('api', '*.d.lua'), ('scripts', '*.lua'), ('prototypes', '*.lua'),
                               ('tools/data', '*.json')):
        for path in files(root, directory, pattern):
            inputs[path.relative_to(root).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    for name in ('settings.lua', 'control.lua', 'tests/api_inventory.lua'):
        path = confined(root, name)
        if path.is_file():
            inputs[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    for name in ('proposal.md', 'design.md'):
        path = confined(change, name)
        if path.is_file():
            text = path.read_text()
            if name == 'proposal.md':
                text = IMPACT.sub('', text)
            inputs['change/' + name] = hashlib.sha256(text.encode()).hexdigest()
    return hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()


def identities(records):
    result = {}
    for name, record in records.items():
        path = 'api/' + record['source']['file']
        result[name] = path
        for field in record.get('fields', {}):
            result[name + '.' + field] = path
        for field in record.get('values', {}):
            result[name + '.' + field] = path
    return result


def impact_inventory(proposal):
    # Only the small reviewed Markdown inventory is parsed here, never Lua/types.
    sections = IMPACT.findall(proposal)
    if len(sections) != 1:
        raise ValueError('proposal requires exactly one API Impact section')
    section = re.sub(r'<!--.*?-->', '', sections[0], flags=re.S)
    def value(key):
        matches = re.findall(r'^' + re.escape(key) + r': ([^\n]+)$', section, re.M)
        if len(matches) != 1 or not matches[0].strip() or '<' in matches[0]:
            raise ValueError('API Impact requires explicit ' + key)
        return matches[0].strip()
    status = value('Status')
    if status not in ('changed', 'none'):
        raise ValueError('API Impact Status must be changed or none')
    value('Reason')
    value('Compatibility')
    rows = {}
    for line in section.splitlines():
        if not line.startswith('|'):
            continue
        if line in ('| Canonical path | Disposition | Removed identities |', '| --- | --- | --- |'):
            continue
        cells = [c.strip() for c in line.split('|')]
        if len(cells) != 5 or cells[0] or cells[-1]:
            raise ValueError('invalid API Impact table row: ' + line)
        path, disposition, removed = cells[1:4]
        if not API_PATH.fullmatch(path):
            raise ValueError('unsafe API path: ' + path)
        if path in rows:
            raise ValueError('duplicate API path: ' + path)
        if disposition not in ('added', 'modified', 'removed'):
            raise ValueError('invalid API disposition: ' + disposition)
        names = [] if removed == '-' else [n.strip() for n in removed.split(',')]
        if any(not n or ' ' in n for n in names) or len(names) != len(set(names)):
            raise ValueError('invalid removed identities: ' + removed)
        if disposition == 'removed' and not names:
            raise ValueError('whole-file removal requires public identities: ' + path)
        rows[path] = {'disposition': disposition, 'removed': names}
    if (status == 'changed') != bool(rows):
        raise ValueError('API Impact changed requires rows; none forbids them')
    return status, rows, value('Reviewed-source') if status == 'none' else None


def check_change(root, name, binary, output, *, baseline_api=None):
    root = Path(root).absolute()
    if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', name) or name == 'archive':
        raise ValueError('unsafe change name: ' + name)
    change = confined(root, 'openspec/changes/' + name)
    proposal = confined(change, 'proposal.md')
    if not proposal.is_file():
        raise ValueError('missing change proposal: ' + name)
    for path in files(change, '.', '*.md'):
        rel = path.relative_to(change)
        if (path.name.endswith('api.md') or path.name == 'buffering-api.md'
                or rel.parts[0] == 'api' or (rel.parts[0] == 'specs' and path.name != 'spec.md')):
            raise ValueError('forbidden Markdown API companion: ' + rel.as_posix())
    status, rows, reviewed = impact_inventory(proposal.read_text())
    proposed = {p.relative_to(change).as_posix(): p for p in files(change, 'api', '*')}
    if set(proposed) != set(rows):
        raise ValueError('API artifacts missing ' + repr(sorted(set(rows) - set(proposed)))
                         + '; unexpected ' + repr(sorted(set(proposed) - set(rows))))
    if status == 'none':
        if baseline_api is not None:
            raise ValueError('a preserved baseline requires changed API artifacts')
        current = review_fingerprint(root, change)
        if reviewed != current:
            raise ValueError('stale no-impact decision; review source/design before setting Reviewed-source: ' + current)
        return {'change': name, 'status': status, 'reviewed_source': current, 'artifacts': []}
    canonical = {p.relative_to(root).as_posix(): p for p in files(root, 'api', '*.d.lua')}
    output = Path(output).absolute()
    if output.resolve().is_relative_to(root.resolve()):
        raise ValueError('change verification output must be outside project')
    baseline_source = root / 'api'
    baseline_files = list(canonical.values())
    if baseline_api is not None:
        baseline_source = confined(Path(baseline_api).absolute(), '.')
        if baseline_source.resolve().is_relative_to(root.resolve()):
            raise ValueError('preserved API baseline must be outside project')
        if output.resolve().is_relative_to(baseline_source.resolve()):
            raise ValueError('change verification output must be outside preserved baseline')
        baseline_files = list(files(baseline_source, '.', '*.d.lua'))
        if not baseline_files:
            raise ValueError('preserved API baseline has no declarations')
    output.mkdir(parents=True, exist_ok=False)
    overlay = output / 'overlay'
    overlay.mkdir()
    for path, source in canonical.items():
        destination = overlay / path.removeprefix('api/')
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    removals = set()
    for path, row in rows.items():
        source = proposed[path]
        destination = overlay / path.removeprefix('api/')
        disposition = row['disposition']
        if disposition == 'modified' and path not in canonical:
            raise ValueError('modified canonical path is missing: ' + path)
        if disposition == 'added' and path in canonical and canonical[path].read_bytes() != source.read_bytes():
            raise ValueError('added canonical path already exists with different bytes: ' + path)
        if disposition == 'removed':
            lines = [s.strip() for s in source.read_text().splitlines() if s.strip()]
            expected = '-- Identities: ' + ', '.join(row['removed'])
            if (any(not s.startswith('--') for s in lines)
                    or lines.count('-- Removes: ' + path) != 1 or lines.count(expected) != 1
                    or any(s.startswith('---@') for s in lines)):
                raise ValueError('invalid removal record: ' + path)
            destination.unlink(missing_ok=True)
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
        removals.update(row['removed'])
    baseline = api_records(export_api(baseline_source, binary, output / 'baseline')) if baseline_files else {}
    current = baseline
    if baseline_api is not None:
        current = api_records(export_api(root / 'api', binary, output / 'current')) if canonical else {}
    candidate = api_records(export_api(overlay, binary, output / 'candidate')) if list(overlay.rglob('*.d.lua')) else {}
    before, live, after = identities(baseline), identities(current), identities(candidate)
    lost = (set(before) | set(live)) - set(after)
    if lost - removals:
        raise ValueError('undeclared removed identities: ' + ', '.join(sorted(lost - removals)))
    for path, row in rows.items():
        for identity in row['removed']:
            if identity in after or any(identity in source and source[identity] != path for source in (before, live)):
                raise ValueError('incorrect removed identity: ' + identity)
            if identity not in before:
                raise ValueError('unverifiable removed identity; provide the pre-promotion --baseline-api directory: ' + identity)
    report = {'change': name, 'status': status, 'artifacts': rows,
              'baseline_api': str(baseline_source),
              'baseline_sources': json.loads((output / 'baseline/provenance.json').read_text())['definitions'] if baseline_files else {},
              'public_definitions': len(candidate), 'removed_identities': sorted(removals),
              'candidate_sources': {p.relative_to(overlay).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                                    for p in sorted(overlay.rglob('*.d.lua'))}}
    (output / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    return report
