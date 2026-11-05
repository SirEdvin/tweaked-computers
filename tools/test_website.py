"""Website assembly keeps the complete API and the canonical starter intact."""
import html
import json
import os
from pathlib import Path
import re

import subprocess
import tempfile
import unittest
from unittest.mock import patch

import website


class WebsiteTests(unittest.TestCase):
    def test_welcome_uses_the_exact_starter_and_complete_reference(self):
        welcome = (website.ROOT / 'docs/welcome.html').read_text()
        code = re.search(r'<code>(local function increment.*?)</code>', welcome, re.S)
        assert code is not None
        self.assertEqual(html.unescape(code[1]), (website.ROOT / 'examples/function-program.lua').read_text())
        for target in ('api/types/', 'api/peripheral/', 'api/globals/', 'guide.html', 'getting-started/', 'examples/'):
            self.assertIn('href="' + target + '"', welcome)
        self.assertIn('omits some alias and overload details', welcome)
        self.assertIn("window.LUAFMT_ROOT = 'api/'", welcome)
        for anchor in ('tweaked-computers', 'start-here', 'alpha-warning', 'source-and-developer-documentation'):
            self.assertIn('id="' + anchor + '"', welcome)

    def test_assembly_preserves_the_complete_reference(self):
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as folder:
            root = Path(folder) / 'source'
            (root / 'tools').mkdir(parents=True)
            (root / 'docs').mkdir()
            (root / 'tools/emmy-lock.json').write_text('{"version":"0.25.1"}')
            (root / 'docs/welcome.html').write_text('<a href="guide.html">Guide</a><a href="api/">API</a>')
            site = Path(folder) / 'output'
            complete = '<p id="contract">Complete contract</p>'
            calls = []

            def run(command, **kwargs):
                calls.append(command)
                if '--version' in command:
                    return subprocess.CompletedProcess(command, 0, stdout='emmylua_doc_cli 0.25.1\n')
                if 'mkdocs' in command:
                    (site / 'api/peripheral').mkdir(parents=True)
                    (site / 'api/peripheral/index.html').write_text(complete)
                    (site / 'index.html').write_text('<a href="api/peripheral/#contract">Contract</a>')
                    (site / 'search').mkdir()
                    (site / 'search/search_index.json').write_text(json.dumps({'docs': [
                        {'location': '', 'text': 'Overview'},
                        {'location': '#alpha-warning', 'text': 'Warning'},
                        {'location': 'api/peripheral/#contract', 'text': 'Contract'},
                    ]}))
                else:
                    output = Path(command[command.index('-o') + 1])
                    output.mkdir()
                    (output / 'index.html').write_text('<p>Stock Emmy output</p>')
                return subprocess.CompletedProcess(command, 0)

            with patch.object(website.subprocess, 'run', side_effect=run):
                report = website.build(site, Path('/tool/emmylua_doc_cli'), root)
            self.assertEqual((site / 'api/peripheral/index.html').read_text(), complete)
            self.assertIn('Contract', (site / 'guide.html').read_text())
            self.assertEqual((site / 'index.html').read_bytes(), (root / 'docs/welcome.html').read_bytes())
            self.assertEqual(report['html_pages'], 4)
            self.assertIn('--strict', calls[1])
            self.assertIn(str(root / 'tools/emmy-docs.json'), calls[2])
            search = json.loads((site / 'search/search_index.json').read_text())
            self.assertEqual([d['location'] for d in search['docs']], [
                'guide.html', 'guide.html#alpha-warning', 'api/peripheral/#contract'])
            self.assertEqual([d['text'] for d in search['docs']], ['Overview', 'Warning', 'Contract'])

    def test_refuses_unsafe_output_and_wrong_version_before_building(self):
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as folder:
            root = Path(folder) / 'source'
            (root / 'tools').mkdir(parents=True)
            (root / 'tools/emmy-lock.json').write_text(json.dumps({'version': '0.25.1'}))
            with patch.object(website.subprocess, 'run') as run:
                for path in (root, root.parent, root / 'docs'):
                    with self.assertRaisesRegex(ValueError, 'output must be'):
                        website.build(path, Path('/tool/emmy'), root)
                run.assert_not_called()
                run.return_value = subprocess.CompletedProcess([], 0, stdout='emmylua_doc_cli wrong\n')
                with self.assertRaisesRegex(ValueError, 'unexpected EmmyLua'):
                    website.build(Path(folder) / 'output', Path('/tool/emmy'), root)
                self.assertEqual(run.call_count, 1)

    def test_generator_failure_is_not_a_successful_site(self):
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as folder:
            root = Path(folder) / 'source'
            (root / 'tools').mkdir(parents=True)
            (root / 'tools/emmy-lock.json').write_text('{"version":"0.25.1"}')
            with patch.object(website.subprocess, 'run', side_effect=[
                subprocess.CompletedProcess([], 0, stdout='emmylua_doc_cli 0.25.1\n'),
                subprocess.CalledProcessError(1, ['mkdocs']),
            ]):
                with self.assertRaises(subprocess.CalledProcessError):
                    website.build(Path(folder) / 'output', Path('/tool/emmy'), root)


if __name__ == '__main__':
    unittest.main()
