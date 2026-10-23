#!/usr/bin/env python3
"""Run the KV fixture in its setting-owning mod without editing shared hooks."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--factorio', required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists() or output.is_relative_to(ROOT):
        parser.error('use a fresh output outside the checkout')
    output.mkdir(parents=True)
    candidate = output / args.archive.name
    with zipfile.ZipFile(args.archive) as source:
        entries = source.namelist()
        assert len(entries) == len(set(entries)), 'duplicate archive entries'
        target = next(n for n in entries if n.endswith('/tests/resource_policy_settings.lua'))
        with zipfile.ZipFile(candidate, 'w', zipfile.ZIP_DEFLATED) as tested:
            for entry in source.infolist():
                payload = (b"return require('tests.kv_policy_engine')\n" if entry.filename == target
                           else source.read(entry))
                tested.writestr(copy.copy(entry), payload)
        with zipfile.ZipFile(candidate) as tested:
            assert tested.namelist() == entries
            changed = [n for n in entries if source.read(n) != tested.read(n)]
            assert changed == [target], changed
    receipt = {'source_archive': str(args.archive.resolve()),
               'source_sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest(),
               'tested_archive': str(candidate),
               'tested_sha256': hashlib.sha256(candidate.read_bytes()).hexdigest(),
               'changed_test_entries': changed, 'production_payloads_unchanged': True}
    (output / 'provenance.json').write_text(json.dumps(receipt, indent=2) + '\n')
    command = [sys.executable, str(ROOT / 'tools/smoke.py'), '--factorio', str(args.factorio),
               '--archive', str(candidate), '--output', str(output / 'smoke'), '--mode', 'both',
               '--fixture', 'tests.resource_policy_settings', '--production-context', '--cold']
    (output / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
    result = subprocess.run(command, check=False)
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
