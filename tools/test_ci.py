"""Exercise the actual CI change detector against isolated Git histories."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml  # Already pinned in requirements-docs.txt.


WORKFLOW = yaml.load(
    (Path(__file__).resolve().parents[1] / '.github/workflows/ci.yml').read_text(),
    Loader=yaml.BaseLoader,
)
STEPS = WORKFLOW['jobs']['validate']['steps']
DETECTOR = next(step['run'] for step in STEPS if step.get('id') == 'changes')


class CIChangeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(dir=os.environ['TMPDIR'])
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.git('init', '-q', '-b', 'main')
        self.git('config', 'user.name', 'CI regression')
        self.git('config', 'user.email', 'ci@example.invalid')
        self.change('control.lua')
        self.base = self.change('docs/note.md')
        self.git('update-ref', 'refs/remotes/origin/main', self.base)
        self.git('checkout', '-q', '-b', 'feature')

    def git(self, *args):
        return subprocess.check_output(
            ['git', '-c', 'commit.gpgsign=false', *args], cwd=self.repo, text=True,
            stderr=subprocess.STDOUT,
        ).strip()

    def change(self, name):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(path.read_text() + '\nchange\n' if path.exists() else 'fixture\n')
        self.git('add', '--', name)
        self.git('commit', '-qm', 'fixture')
        return self.git('rev-parse', 'HEAD')

    def detect(self, **overrides):
        output = self.root / 'output'
        output.write_text('')
        env = dict(os.environ, EVENT='pull_request', REF='refs/pull/1/merge',
                   DEFAULT_BRANCH='main', BASE=self.base, BEFORE=self.base,
                   HEAD=self.git('rev-parse', 'HEAD'), GITHUB_OUTPUT=str(output))
        env.update(overrides)
        result = subprocess.run(['bash', '-c', DETECTOR], cwd=self.repo, env=env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return output.read_text().strip()

    def test_changed_paths(self):
        included = (
            'control.lua', 'data-final-fixes.lua', 'migrations/new.lua', 'info.json',
            'scripts/runtime/new.lua', 'prototypes/new.lua', 'locale/en/test.cfg',
            'vendor/manifest.json', 'assets/icons/new.png', 'examples/program.lua',
            'tests/contract.lua', 'tools/build.py', '.github/workflows/ci.yml',
            'mkdocs.yml', 'requirements-docs.txt',
        )
        excluded = (
            'openspec/changes/new/spec.md', 'openspec/specs/runtime/spec.md',
            'openspec/api/common.md', 'openspec/config.yaml', 'docs/player/index.md',
            'openwiki/index.md', 'README.md', 'AGENTS.md', 'changelog.txt',
            '.github/workflows/docs.yml', '.github/workflows/openwiki-update.yml',
        )
        for expected, paths in (('true', included), ('false', excluded)):
            for path in paths:
                with self.subTest(path=path):
                    self.git('checkout', '-q', '--detach', self.base)
                    self.change(path)
                    self.assertEqual(self.detect(), f'changed={expected}')

    def test_deletions_and_renames(self):
        for operation in (('rm', 'control.lua'),
                          ('mv', 'control.lua', 'docs/retired.md'),
                          ('mv', 'docs/note.md', 'new.lua')):
            with self.subTest(operation=operation):
                self.git('checkout', '-q', '--detach', self.base)
                self.git(*operation)
                self.git('commit', '-qm', 'remove or rename')
                self.assertEqual(self.detect(), 'changed=true')

    def test_docs_followup_does_not_hide_code(self):
        previous = self.change('control.lua')
        self.change('docs/note.md')
        self.assertEqual(self.detect(), 'changed=true')
        self.assertEqual(self.detect(EVENT='push', REF='refs/heads/feature', BEFORE=previous),
                         'changed=true')

    def test_base_branch_advancement_is_not_a_pr_change(self):
        head = self.change('docs/note.md')
        self.git('checkout', '-q', 'main')
        base = self.change('control.lua')
        self.git('update-ref', 'refs/remotes/origin/main', base)
        self.assertEqual(self.detect(BASE=base, HEAD=head), 'changed=false')
        self.assertEqual(self.detect(EVENT='push', REF='refs/heads/feature', HEAD=head),
                         'changed=false')

    def test_new_branch_and_default_branch_pushes(self):
        self.change('docs/note.md')
        self.assertEqual(self.detect(EVENT='push', REF='refs/heads/feature', BEFORE='0' * 40),
                         'changed=false')
        self.assertEqual(self.detect(EVENT='push', REF='refs/heads/main'), 'changed=false')
        previous = self.git('rev-parse', 'HEAD')
        self.change('control.lua')
        self.assertEqual(self.detect(EVENT='push', REF='refs/heads/feature', BEFORE='0' * 40),
                         'changed=true')
        self.assertEqual(self.detect(EVENT='push', REF='refs/heads/main', BEFORE=previous),
                         'changed=true')

    def test_manual_and_unknown_previous_head_run_tests(self):
        self.assertEqual(self.detect(EVENT='workflow_dispatch', BASE='', HEAD=''), 'changed=true')
        self.assertEqual(self.detect(EVENT='push', REF='refs/heads/main', BEFORE='0' * 40),
                         'changed=true')

    def test_required_check_and_expensive_step_guards(self):
        self.assertEqual(WORKFLOW['jobs']['validate']['name'], 'Mod validation')
        self.assertEqual(WORKFLOW['on']['pull_request'], '')
        self.assertEqual(WORKFLOW['on']['push'], {'branches': ['**']})
        self.assertIn('workflow_dispatch', WORKFLOW['on'])
        self.assertEqual(STEPS[0]['with']['fetch-depth'], '0')
        start = next(i for i, step in enumerate(STEPS) if step.get('id') == 'changes')
        self.assertEqual(STEPS[start + 1]['if'], "steps.changes.outputs.changed == 'false'")
        for step in STEPS[start + 2:]:
            with self.subTest(step=step.get('name', step.get('uses'))):
                expected = "steps.changes.outputs.changed == 'true'"
                if 'actions/upload-artifact@' in step.get('uses', ''):
                    expected = '${{ always() && ' + expected + ' }}'
                self.assertEqual(step['if'], expected)


if __name__ == '__main__':
    unittest.main()
