#!/usr/bin/env python3
"""Build deterministic archives from an explicit runtime inventory, outside git."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOP = ('info.json', 'data.lua', 'control.lua', 'settings.lua', 'README.md', 'LICENSE')
DIRS = ('scripts', 'prototypes', 'locale', 'vendor', 'assets', 'docs', 'examples', 'tests')

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
    for name in TOP:
        if not (ROOT / name).is_file():
            raise ValueError(f'missing required package file: {name}')
    files = [ROOT / name for name in TOP]
    for name in DIRS:
        directory = ROOT / name
        if directory.exists():
            files += [p for p in directory.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc']
    for p in files:
        if p.is_symlink():
            raise ValueError(f'symlink in package: {p}')
    with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for p in sorted(files, key=lambda p: str(p.relative_to(ROOT))):
            entry = zipfile.ZipInfo(f'{prefix}/{p.relative_to(ROOT).as_posix()}', (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, p.read_bytes())
    result = {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'files': len(files)}
    print(json.dumps(result))
    return path

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--output', type=Path, required=True)
    build(ap.parse_args().output)
