#!/usr/bin/env python3
"""Build the guides, stock EmmyLua API browser, and authored welcome page."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from player_docs import site_links

ROOT = Path(__file__).resolve().parents[1]


def build(site, emmy, root=ROOT):
    site = site.resolve()
    root = root.resolve()
    if site == root or root.is_relative_to(site) or (site.is_relative_to(root) and site != root / 'site'):
        raise ValueError('output must be site/ or a separate directory outside the checkout')
    lock = json.loads((root / 'tools/emmy-lock.json').read_text())
    version = subprocess.run([str(emmy), '--version'], check=True, capture_output=True, text=True).stdout.strip()
    if version != 'emmylua_doc_cli ' + lock['version']:
        raise ValueError('unexpected EmmyLua version: ' + version)
    # Keep the complete reference until stock Emmy passes all contract fixtures.
    subprocess.run([sys.executable, '-m', 'mkdocs', 'build', '--strict', '--site-dir', str(site)],
                   cwd=root, check=True)
    with tempfile.TemporaryDirectory(prefix='tc-emmy-site-', dir=os.environ['TMPDIR']) as temp:
        generated = Path(temp) / 'api'
        subprocess.run([str(emmy), str(root / 'api'), '-c', str(root / 'tools/emmy-docs.json'),
                        '-f', 'html', '--site-name', 'Tweaked Computers API', '-o', str(generated)],
                       cwd=root, check=True)
        if not (generated / 'index.html').is_file():
            raise ValueError('EmmyLua did not produce an API index')
        for path in generated.rglob('*'):
            if path.is_file() and (site / 'api' / path.relative_to(generated)).exists():
                raise ValueError('EmmyLua output conflicts with a complete reference page: ' + str(path))
        shutil.copytree(generated, site / 'api', dirs_exist_ok=True)
    shutil.copyfile(site / 'index.html', site / 'guide.html')
    # Guide search must still open the full text of the relocated overview.
    search = site / 'search/search_index.json'
    if search.exists():
        index = json.loads(search.read_text())
        for entry in index['docs']:
            if not entry['location'] or entry['location'].startswith('#'):
                entry['location'] = 'guide.html' + entry['location']
        search.write_text(json.dumps(index))
    shutil.copyfile(root / 'docs/welcome.html', site / 'index.html')
    return site_links(site)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--site', type=Path, default=ROOT / 'site')
    parser.add_argument('--emmy', type=Path, default=os.environ.get('EMMY_DOC_BIN') or shutil.which('emmylua_doc_cli'))
    args = parser.parse_args()
    if not args.emmy:
        parser.error('set EMMY_DOC_BIN or --emmy to the verified tools/emmy-lock.json binary')
    print(json.dumps(build(args.site, args.emmy.resolve()), sort_keys=True))


if __name__ == '__main__':
    main()
