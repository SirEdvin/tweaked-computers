#!/usr/bin/env python3
"""Import only the pinned Phobos parser closure; never its compiler/backend."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

REVISION = '2566dd85807b4f2bdff8e40ba4d79bcf8e96de3f'
MODULES = ('parser', 'tokenize', 'nodes', 'ast_util', 'util', 'indexed_linked_list', 'stack', 'error_code_util')
ROOT = Path(__file__).resolve().parents[1]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('checkout', type=Path)
    args = ap.parse_args()
    def original(path):
        return subprocess.check_output(['git', '-C', str(args.checkout), 'show', f'{REVISION}:{path}'])
    dest = ROOT / 'vendor/phobos'
    dest.mkdir(parents=True, exist_ok=True)
    records = []
    for module in MODULES:
        path = f'src/{module}.lua'
        raw = original(path)
        text = raw.decode()
        text = re.sub(r'require\("([\w_]+)"\)', lambda m: f'require("vendor.phobos.{m[1]}")' if m[1] in MODULES else (_ for _ in ()).throw(ValueError(m[1])), text)
        # Trusted parser-only probes: bounded function entry/loops, nodes and lexical work.
        # This is not a guest execution backend or continuation transform.
        text = 'local admission = require("scripts.runtime.parse_admission")\n' + text
        text = re.sub(r'^(\s*)(local )?function ([\w.:]+)\(([^\n]*)\)\n', lambda m: m[0] + m[1] + '  admission.enter()\n', text, flags=re.M)
        text = re.sub(r'^(\s*)(?:while [^\n]* do|for [^\n]* do|repeat)\n', lambda m: m[0] + m[1] + '  admission.enter()\n', text, flags=re.M)
        if module == 'parser':
            # Bound recursive grammar, even repeated unary operators/right-associated expressions.
            # Wrap shared recursive entry points rather than each call site.
            marker = '  local main = main_func()'
            text = text.replace(marker, '  local main = main_func()')
            text = text.replace('function expr(scope)', '''local raw_sub_expr = sub_expr
sub_expr = function(...)
  admission.push()
  local result, next_op = raw_sub_expr(...)
  admission.pop()
  return result, next_op
end
function expr(scope)''')
            text = text.replace('return parse', '''local raw_expr, raw_statement = expr, statement
expr = function(...)
  admission.push()
  local result = raw_expr(...)
  admission.pop()
  return result
end
statement = function(...)
  admission.push()
  local result = raw_statement(...)
  admission.pop()
  return result
end
local raw_parse = parse
parse = function(...)
  local results = table.pack(pcall(raw_parse, ...))
  -- Release parse roots on success and failure; admission is reset by its owner.
  token = nil; prev_token = nil; token_iter_state = nil
  error_code_insts = nil; invalid_token_invalid_node_lut = nil
  source = nil; prevent_assert = nil; extra_node = nil; err_pos_token = nil
  if not results[1] then error(results[2], 0) end
  return table.unpack(results, 2, results.n)
end
return parse''')
        installed = text.encode()
        (dest / f'{module}.lua').write_bytes(installed)
        records.append({'upstream_path': path, 'installed_path': f'vendor/phobos/{module}.lua', 'original_sha256': hashlib.sha256(raw).hexdigest(), 'installed_sha256': hashlib.sha256(installed).hexdigest(), 'original_bytes': len(raw), 'installed_bytes': len(installed)})
    raw = original('LICENSE.txt')
    (dest / 'LICENSE.txt').write_bytes(raw)
    records.append({'upstream_path': 'LICENSE.txt', 'installed_path': 'vendor/phobos/LICENSE.txt', 'original_sha256': hashlib.sha256(raw).hexdigest(), 'installed_sha256': hashlib.sha256(raw).hexdigest(), 'original_bytes': len(raw), 'installed_bytes': len(raw)})
    (dest / 'manifest.json').write_text(json.dumps({'repository': 'https://github.com/JanSharp/phobos', 'revision': REVISION, 'transform': 'tools/import_parser.py: namespaced requires; host-only parser work/depth probes; error-path root cleanup', 'files': records}, indent=2) + '\n')

if __name__ == '__main__':
    main()
