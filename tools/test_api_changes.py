"""Real LuaLS overlay checks; synthetic planning fixtures never touch live changes."""
import json
import hashlib
import contextlib
import io
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import api_changes

A = '---@meta\n--- A retained value.\n---@alias TC.A string\n'
B = '---@meta\n--- A record.\n---@class TC.B\n---@field value TC.A The original value.\n'


class ChangeOverlayTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ['TMPDIR'])
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.root = self.work / 'project'
        self.change = self.root / 'openspec/changes/example'
        self.change.mkdir(parents=True)
        self.put(self.root / 'api/a.d.lua', A)
        self.put(self.root / 'api/b.d.lua', B)
        self.binary = Path(os.environ['LUALS_BIN'])
        self.counter = 0

    def put(self, path, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body)

    def proposal(self, rows=None, status='changed', reviewed='pending'):
        text = '# Proposal\n\n## Why\nTest only.\n\n## API Impact\n'
        text += f'Status: {status}\nReason: Reviewed the public API.\nCompatibility: Test fixture.\n'
        if status == 'none':
            text += f'Reviewed-source: {reviewed}\n'
        if rows is not None:
            text += '| Canonical path | Disposition | Removed identities |\n| --- | --- | --- |\n'
            text += ''.join(f'| {p} | {d} | {r} |\n' for p,d,r in rows)
        self.put(self.change / 'proposal.md', text)

    def check(self, **kwargs):
        self.counter += 1
        return api_changes.check_change(self.root, 'example', self.binary, self.work / f'check-{self.counter}', **kwargs)

    def test_full_replacement_uses_unchanged_type_and_is_read_only(self):
        self.proposal([('api/b.d.lua', 'modified', '-')])
        self.put(self.change / 'api/b.d.lua', B.replace('original', 'proposed'))
        before = {str(p):p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        result = self.check()
        self.assertEqual(result['public_definitions'], 2)
        self.assertEqual(result['removed_identities'], [])
        self.assertEqual(before, {str(p):p.read_bytes() for p in self.root.rglob('*') if p.is_file()})

    def test_actual_cli_entry_checks_overlay_without_generating_products(self):
        import player_docs
        self.proposal([('api/b.d.lua', 'modified', '-')])
        self.put(self.change / 'api/b.d.lua', B)
        out = io.StringIO()
        with patch.object(player_docs, 'ROOT', self.root), patch('sys.argv', ['player_docs.py', '--check', '--change', 'example']), contextlib.redirect_stdout(out):
            player_docs.main()
        self.assertEqual(json.loads(out.getvalue())['public_definitions'], 2)
        self.assertFalse((self.root / 'docs').exists())

    def test_missing_second_file_and_unexpected_file(self):
        self.proposal([('api/a.d.lua', 'modified', '-'), ('api/b.d.lua', 'modified', '-')])
        self.put(self.change / 'api/a.d.lua', A)
        with self.assertRaisesRegex(ValueError, 'missing.*api/b.d.lua'):
            self.check()
        self.put(self.change / 'api/b.d.lua', B)
        self.put(self.change / 'api/extra.d.lua', A)
        with self.assertRaisesRegex(ValueError, 'unexpected.*api/extra.d.lua'):
            self.check()

    def test_addition_and_duplicate_or_unresolved_identity(self):
        self.proposal([('api/c.d.lua', 'added', '-')])
        self.put(self.change / 'api/c.d.lua', A.replace('TC.A', 'TC.C'))
        self.assertEqual(self.check()['public_definitions'], 3)
        self.put(self.change / 'api/c.d.lua', A)
        with self.assertRaisesRegex(ValueError, 'definition|duplicate|diagnostics'):
            self.check()
        self.put(self.change / 'api/c.d.lua', A.replace('TC.A string', 'TC.C TC.Missing'))
        with self.assertRaisesRegex(ValueError, 'unresolved|diagnostics'):
            self.check()

    def test_whole_file_removal_and_member_removal_require_exact_identities(self):
        self.proposal([('api/b.d.lua', 'removed', 'TC.B, TC.B.value')])
        self.put(self.change / 'api/b.d.lua', '-- Removes: api/b.d.lua\n-- Identities: TC.B, TC.B.value\n')
        self.assertEqual(self.check()['removed_identities'], ['TC.B', 'TC.B.value'])
        self.put(self.change / 'api/b.d.lua', '-- Removes: api/a.d.lua\n-- Identities: TC.B, TC.B.value\n')
        with self.assertRaisesRegex(ValueError, 'removal record'):
            self.check()
        self.proposal([('api/b.d.lua', 'modified', '-')])
        self.put(self.change / 'api/b.d.lua', '---@meta\n--- A record.\n---@class TC.B\n')
        with self.assertRaisesRegex(ValueError, 'removed identities.*TC.B.value'):
            self.check()
        self.proposal([('api/b.d.lua', 'modified', 'TC.B.value')])
        self.assertEqual(self.check()['removed_identities'], ['TC.B.value'])

    def promoted_removal(self, whole_file=False):
        baseline = self.work / 'preserved-api'
        shutil.copytree(self.root / 'api', baseline)
        if whole_file:
            self.proposal([('api/b.d.lua', 'removed', 'TC.B, TC.B.value')])
            self.put(self.change / 'api/b.d.lua', '-- Removes: api/b.d.lua\n-- Identities: TC.B, TC.B.value\n')
            (self.root / 'api/b.d.lua').unlink()
        else:
            self.proposal([('api/b.d.lua', 'modified', 'TC.B.value')])
            replacement = '---@meta\n--- A record.\n---@class TC.B\n'
            self.put(self.change / 'api/b.d.lua', replacement)
            self.put(self.root / 'api/b.d.lua', replacement)
        return baseline

    def test_promoted_removal_uses_explicit_baseline_without_changing_inputs(self):
        baseline = self.promoted_removal()
        before = {str(p): p.read_bytes() for d in (self.root, baseline) for p in d.rglob('*') if p.is_file()}
        with self.assertRaisesRegex(ValueError, 'unverifiable removed identity'):
            self.check()
        result = self.check(baseline_api=baseline)
        self.assertEqual(result['removed_identities'], ['TC.B.value'])
        self.assertEqual(result['baseline_api'], str(baseline))
        self.assertEqual(result['baseline_sources'], {'a.d.lua': hashlib.sha256(A.encode()).hexdigest(),
                                                     'b.d.lua': hashlib.sha256(B.encode()).hexdigest()})
        self.assertEqual(before, {str(p): p.read_bytes() for d in (self.root, baseline) for p in d.rglob('*') if p.is_file()})

    def test_promoted_whole_file_removal_still_requires_original_identities(self):
        baseline = self.promoted_removal(whole_file=True)
        with self.assertRaisesRegex(ValueError, 'unverifiable removed identity'):
            self.check()
        self.assertEqual(self.check(baseline_api=baseline)['removed_identities'], ['TC.B', 'TC.B.value'])

    def test_preserved_baseline_cannot_hide_a_current_undeclared_removal(self):
        baseline = self.promoted_removal()
        self.put(self.root / 'api/b.d.lua', B + '---@field extra boolean An additional value.\n')
        with self.assertRaisesRegex(ValueError, 'undeclared removed identities.*TC.B.extra'):
            self.check(baseline_api=baseline)

    def test_preserved_baseline_rejects_missing_or_wrong_identity_origin(self):
        baseline = self.promoted_removal()
        self.put(baseline / 'b.d.lua', (self.root / 'api/b.d.lua').read_text())
        with self.assertRaisesRegex(ValueError, 'unverifiable removed identity'):
            self.check(baseline_api=baseline)
        (baseline / 'b.d.lua').unlink()
        self.put(baseline / 'other.d.lua', B)
        with self.assertRaisesRegex(ValueError, 'incorrect removed identity'):
            self.check(baseline_api=baseline)

    def test_preserved_baseline_rejects_symlinks_and_checkout_paths(self):
        baseline = self.promoted_removal()
        with self.assertRaisesRegex(ValueError, 'outside project'):
            self.check(baseline_api=self.root / 'api')
        (baseline / 'b.d.lua').unlink()
        (baseline / 'b.d.lua').symlink_to(self.root / 'api/b.d.lua')
        with self.assertRaisesRegex(ValueError, 'symlink|escapes source'):
            self.check(baseline_api=baseline)

    def test_preserved_baseline_cannot_be_empty_or_contain_verification_output(self):
        baseline = self.promoted_removal()
        with self.assertRaisesRegex(ValueError, 'outside preserved baseline'):
            api_changes.check_change(self.root, 'example', self.binary, baseline / 'output', baseline_api=baseline)
        self.assertFalse((baseline / 'output').exists())
        empty = self.work / 'empty-api'
        empty.mkdir()
        with self.assertRaisesRegex(ValueError, 'no declarations'):
            self.check(baseline_api=empty)

    def test_cli_accepts_explicit_baseline_only_for_change_checks(self):
        import player_docs
        baseline = self.promoted_removal()
        out = io.StringIO()
        arguments = ['player_docs.py', '--check', '--change', 'example', '--baseline-api', str(baseline)]
        with patch.object(player_docs, 'ROOT', self.root), patch('sys.argv', arguments), contextlib.redirect_stdout(out):
            player_docs.main()
        self.assertEqual(json.loads(out.getvalue())['removed_identities'], ['TC.B.value'])
        with patch('sys.argv', ['player_docs.py', '--check', '--baseline-api', str(baseline)]), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                player_docs.main()
        self.assertEqual(error.exception.code, 2)

    def test_removal_cannot_leave_unresolved_reference(self):
        self.proposal([('api/a.d.lua', 'removed', 'TC.A')])
        self.put(self.change / 'api/a.d.lua', '-- Removes: api/a.d.lua\n-- Identities: TC.A\n')
        with self.assertRaisesRegex(ValueError, 'unresolved|diagnostics'):
            self.check()

    def test_absent_impact_and_stale_no_impact_are_not_implicit_passes(self):
        self.put(self.change / 'proposal.md', '# Proposal\nNo API table.\n')
        with self.assertRaisesRegex(ValueError, 'API Impact'):
            self.check()
        self.proposal(status='none')
        fingerprint = api_changes.review_fingerprint(self.root, self.change)
        self.proposal(status='none', reviewed=fingerprint)
        self.assertEqual(self.check()['status'], 'none')
        self.put(self.change / 'design.md', '# Design\nA new decision.\n')
        with self.assertRaisesRegex(ValueError, 'stale no-impact.*review'):
            self.check()
        self.proposal(status='none', reviewed=api_changes.review_fingerprint(self.root, self.change))
        self.put(self.root / 'scripts/services/new.lua', 'return {}\n')
        with self.assertRaisesRegex(ValueError, 'stale no-impact'):
            self.check()
        self.proposal(status='none', reviewed=api_changes.review_fingerprint(self.root, self.change))
        self.put(self.change / 'api/a.d.lua', A)
        with self.assertRaisesRegex(ValueError, 'unexpected'):
            self.check()

    def test_path_escape_symlink_duplicate_and_markdown_companion(self):
        for path in ('api/../a.d.lua', '/api/a.d.lua', 'api//a.d.lua', 'api/a.lua'):
            self.proposal([(path, 'modified', '-')])
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'unsafe API path'):
                self.check()
        self.proposal([('api/a.d.lua', 'modified', '-')] * 2)
        with self.assertRaisesRegex(ValueError, 'duplicate API path'):
            self.check()
        self.proposal([('api/a.d.lua', 'modified', '-')])
        self.put(self.change / 'api/a.d.lua', A)
        self.put(self.change / 'specs/example/lua-api.md', 'duplicate')
        with self.assertRaisesRegex(ValueError, 'Markdown API companion'):
            self.check()
        (self.change / 'specs/example/lua-api.md').unlink()
        (self.change / 'api/a.d.lua').unlink()
        (self.change / 'api/a.d.lua').symlink_to(self.root / 'api/a.d.lua')
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.check()


if __name__ == '__main__':
    unittest.main()
