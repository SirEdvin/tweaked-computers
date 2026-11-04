"""Real LuaLS overlay checks; synthetic planning fixtures never touch live changes."""
import json
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

    def check(self):
        self.counter += 1
        return api_changes.check_change(self.root, 'example', self.binary, self.work / f'check-{self.counter}')

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
