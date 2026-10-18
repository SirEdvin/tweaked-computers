#!/usr/bin/env python3
"""Build deterministic archives from an explicit runtime inventory, outside git."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOP = ('info.json', 'data.lua', 'control.lua', 'settings.lua', 'README.md', 'LICENSE', 'changelog.txt')
DIRS = ('scripts', 'prototypes', 'locale', 'vendor', 'assets', 'docs', 'examples', 'tests')
CONTRACT = 'openspec/changes/add-native-circuit-computers'
CONTRACT_EXTENSIONS = (
    'openspec/changes/add-interactive-console-shell/specs/console-shell/spec.md',
    'openspec/changes/add-interactive-console-shell/specs/console-shell/lua-api.md',
    'openspec/changes/buffer-monitor-presentation/specs/monitor-display/spec.md',
    'openspec/changes/buffer-monitor-presentation/specs/monitor-display/lua-api.md',
    'openspec/changes/buffer-monitor-presentation/specs/peripheral-network/spec.md',
)

def build(destination):
    info = json.loads((ROOT / 'info.json').read_text())
    prefix = f"{info['name']}_{info['version']}"
    destination = Path(destination).resolve()
    if destination.is_relative_to(ROOT):
        raise ValueError('build output must be outside the checkout')
    destination.mkdir(parents=True, exist_ok=True)
    path = destination / f'{prefix}.zip'
    vendor = ROOT / 'vendor/phobos'
    manifest = json.loads((vendor / 'manifest.json').read_text())
    expected = set()
    for record in manifest['files']:
        installed = ROOT / record['installed_path']
        expected.add(installed)
        if hashlib.sha256(installed.read_bytes()).hexdigest() != record['installed_sha256']:
            raise ValueError(f'stale parser import: {installed}')
    if set(vendor.glob('*.lua')) != {p for p in expected if p.suffix == '.lua'}:
        raise ValueError('unlisted parser module/backend')
    art = json.loads((ROOT / 'assets/manifest.json').read_text())
    for group in ('inputs', 'outputs', 'authored_inputs', 'notices', 'generated_metadata'):
        for record in art[group]:
            source = ROOT / record['path']
            if hashlib.sha256(source.read_bytes()).hexdigest() != record['sha256']:
                raise ValueError(f'stale asset or notice: {source}')
    outputs = {ROOT / r['path'] for r in art['outputs']}
    actual = {p for folder in ('sprites', 'icons', 'glyphs') for p in (ROOT / 'assets' / folder).glob('*.png')}
    if outputs != actual:
        raise ValueError('unlisted or missing derived artwork')
    for name in TOP:
        if not (ROOT / name).is_file():
            raise ValueError(f'missing required package file: {name}')
    files = [ROOT / name for name in TOP]
    for name in DIRS:
        directory = ROOT / name
        if directory.exists():
            files += [p for p in directory.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ('.py', '.pyc')]

    # Ship authoritative source/API contracts too; their relative links remain
    # valid. Exclude orchestration reports, research caches and agent context.
    for folder in ('api', 'specs'):
        files += sorted((ROOT / CONTRACT / folder).rglob('*.md'))
        files += sorted((ROOT / CONTRACT / folder).rglob('*.json'))
    files += [ROOT / name for name in CONTRACT_EXTENSIONS]
    for p in files:
        if p.suffix.lower() in ('.exe', '.bat', '.ps1', '.sh', '.py'):
            raise ValueError(f'Mod Portal forbids executable payloads: {p}')
        if p.is_symlink():
            raise ValueError(f'symlink in package: {p}')
    payload = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    if len(payload) != len(files):
        raise ValueError('duplicate package inventory')
    limit_source = (ROOT / 'scripts/runtime/limits.lua').read_text()
    manifest = {'format_version': 1, 'mod': info['name'], 'version': info['version'],
        'engine': '2.0.77', 'stage': 'alpha-candidate',
        'client_verified': False, 'limits_status': 'provisional; work units are not real-time latency guarantees',
        'common_limits': {k: int(v) for k, v in re.findall(r'(\w+)\s*=\s*(\d+)', limit_source)},
        'payload_sha256': dict(sorted(payload.items()))}
    with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for p in sorted(files, key=lambda p: str(p.relative_to(ROOT))):
            entry = zipfile.ZipInfo(f'{prefix}/{p.relative_to(ROOT).as_posix()}', (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, p.read_bytes())
        entry = zipfile.ZipInfo(f'{prefix}/package-manifest.json', (1980, 1, 1, 0, 0, 0))
        entry.compress_type = zipfile.ZIP_DEFLATED
        entry.external_attr = 0o100644 << 16
        archive.writestr(entry, json.dumps(manifest, sort_keys=True, indent=2).encode()+b'\n')
    result = {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'files': len(files)+1}
    print(json.dumps(result))
    return path

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--output', type=Path, required=True)
    build(ap.parse_args().output)
