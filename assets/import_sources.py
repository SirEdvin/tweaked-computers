#!/usr/bin/env python3
"""Import only allowlisted pinned Git blobs; never use mutable checkout bytes."""
import argparse
import hashlib
import json
from pathlib import Path
from audit_sources import GREG_REV, blob

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--greg-repo', required=True, type=Path)
    args = parser.parse_args()
    audit = json.loads((ROOT / 'source-audit.json').read_text())
    assert audit['status'] == 'selected-assets-approved'
    assert audit['greg_flavored']['revision'] == GREG_REV
    records = audit['candidate_models'] + audit['candidate_textures']
    records += [r['animation'] for r in audit['candidate_textures'] if 'animation' in r]
    for record in records:
        relative = record['path'].split('/assets/', 1)[1]
        assert not Path(relative).is_absolute() and '..' not in Path(relative).parts
        data = blob(args.greg_repo, GREG_REV, record['path'])
        assert hashlib.sha256(data).hexdigest() == record['sha256']
        target = ROOT / 'upstream' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    for record in audit['greg_flavored']['evidence']:
        data = blob(args.greg_repo, GREG_REV, record['path'])
        assert hashlib.sha256(data).hexdigest() == record['sha256']
        target = ROOT / 'notices' / ('Greg-Flavored-MIT.txt' if record['path'] == 'LICENSE' else 'Greg-Flavored-README.md')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    print(json.dumps({'pinned_imports': len(records), 'notices': 2, 'revision': GREG_REV}))


if __name__ == '__main__':
    main()
