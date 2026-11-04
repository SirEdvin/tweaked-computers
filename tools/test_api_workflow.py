"""Exercise the installed CLI in isolated roots, not the repository's changes."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from api_changes import check_change, review_fingerprint
from test_api_changes import A, B

ROOT = Path(__file__).resolve().parents[1]
SPEC = '''# Spec Delta

## Purpose

A synthetic workflow fixture proves that behavioral specifications and API review history stay separate.

## ADDED Requirements

### Requirement: Fixture behavior
The fixture SHALL preserve its explicit behavioral decision.

#### Scenario: Observe behavior
- **WHEN** the fixture is checked
- **THEN** the behavioral decision remains available.
'''


class ProjectWorkflowTests(unittest.TestCase):
    def test_discovery_conditional_completeness_and_archive(self):
        work = Path(tempfile.mkdtemp(prefix='tc-api-workflow-', dir=os.environ['TMPDIR']))
        print('OpenSpec workflow evidence:', work)
        root = work / 'project'
        root.mkdir()
        shutil.copytree(ROOT / 'openspec/schemas', root / 'openspec/schemas')
        (root / 'openspec/config.yaml').write_text('schema: tc-spec-driven\n')
        (root / 'api').mkdir()
        (root / 'api/a.d.lua').write_text(A)
        (root / 'api/b.d.lua').write_text(B)
        binary = Path(os.environ['LUALS_BIN'])
        sequence = 0
        def cli(*arguments):
            nonlocal sequence
            sequence += 1
            result = subprocess.run(['openspec', *arguments], cwd=root, text=True, capture_output=True, timeout=60)
            (work / f'{sequence:02}-stdout.json').write_text(result.stdout)
            (work / f'{sequence:02}-stderr.log').write_text(result.stderr)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return json.loads(result.stdout)
        upstream = Path(cli('schema', 'which', 'spec-driven', '--json')['path'])
        def snapshot(directory):
            return {p.relative_to(directory).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in directory.rglob('*') if p.is_file()}
        global_before = snapshot(upstream)
        live_before = snapshot(ROOT / 'openspec/changes')
        self.assertTrue(cli('schema', 'validate', 'tc-spec-driven', '--json')['valid'])
        for name in ('changed', 'removal-only', 'incomplete', 'no-api'):
            cli('new', 'change', name, '--json')
            change = root / 'openspec/changes' / name
            status = 'none' if name == 'no-api' else 'changed'
            proposal = ('# Proposal\n\n## Why\nSynthetic CLI test only.\n\n## What Changes\n'
                        'Exercise separate planning artifacts.\n\n## Capabilities\n### New Capabilities\n'
                        f'- fixture-{name}: Synthetic behavioral observation.\n\n## Impact\nScratch only.\n\n'
                        f'## API Impact\nStatus: {status}\nReason: Explicit fixture review.\nCompatibility: Test only.\n')
            rows = []
            if name in ('changed', 'incomplete'):
                rows = [('api/b.d.lua', 'modified', '-')]
                if name == 'incomplete':
                    rows.append(('api/a.d.lua', 'modified', '-'))
            elif name == 'removal-only':
                rows = [('api/b.d.lua', 'removed', 'TC.B, TC.B.value')]
            if rows:
                proposal += '| Canonical path | Disposition | Removed identities |\n| --- | --- | --- |\n'
                proposal += ''.join(f'| {p} | {d} | {r} |\n' for p,d,r in rows)
            else:
                proposal += 'Reviewed-source: pending\n'
            (change / 'proposal.md').write_text(proposal)
            spec = change / f'specs/fixture-{name}/spec.md'
            spec.parent.mkdir(parents=True)
            spec.write_text(SPEC)
            (change / 'design.md').write_text('# Design\nSynthetic review; no production change.\n')
            (change / 'tasks.md').write_text('# Tasks\n\n## 1. Fixture\n- [x] 1.1 Verify synthetic fixture.\n')
            if rows:
                artifact = change / 'api/b.d.lua'
                artifact.parent.mkdir()
                artifact.write_text('-- Removes: api/b.d.lua\n-- Identities: TC.B, TC.B.value\n'
                                    if name == 'removal-only' else B.replace('original', 'proposed'))
            else:
                proposal = proposal.replace('Reviewed-source: pending', 'Reviewed-source: ' + review_fingerprint(root, change))
                (change / 'proposal.md').write_text(proposal)
            status = cli('status', '--change', name, '--json')
            artifact_status = next(a for a in status['artifacts'] if a['id'] == 'lua-api')
            self.assertEqual(artifact_status['outputPath'], 'api/**/*.d.lua')
            self.assertEqual(artifact_status['status'], 'ready' if name == 'no-api' else 'done')
            for identity in ('design', 'tasks'):
                self.assertIn('lua-api', next(a for a in status['artifacts'] if a['id'] == identity)['requires'])
            instruction = cli('instructions', 'lua-api', '--change', name, '--json')
            self.assertIn('CONDITIONAL', instruction['instruction'])
            apply = cli('instructions', 'apply', '--change', name, '--json')
            expected = [] if name == 'no-api' else [str(change / 'api/b.d.lua')]
            self.assertEqual(apply['contextFiles'].get('lua-api', []), expected)
            if name == 'incomplete':
                with self.assertRaisesRegex(ValueError, 'missing.*api/a.d.lua'):
                    check_change(root, name, binary, work / name)
                continue
            check_change(root, name, binary, work / name)
            canonical = snapshot(root / 'api')
            cli('validate', name, '--strict', '--json')
            cli('archive', name, '--yes', '--json')
            self.assertEqual(snapshot(root / 'api'), canonical)
            self.assertIn('Fixture behavior', (root / f'openspec/specs/fixture-{name}/spec.md').read_text())
            archived = list((root / 'openspec/changes/archive').glob('*-' + name))
            self.assertEqual(len(archived), 1)
            self.assertEqual((archived[0] / 'api/b.d.lua').exists(), name != 'no-api')
            self.assertFalse(list((root / 'openspec/specs').rglob('*.d.lua')))
        self.assertEqual(snapshot(upstream), global_before)
        self.assertEqual(snapshot(ROOT / 'openspec/changes'), live_before)


if __name__ == '__main__':
    unittest.main()
