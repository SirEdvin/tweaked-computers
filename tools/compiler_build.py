#!/usr/bin/env python3
"""Regenerate trusted compiler native blocks; needs development-only lupa.lua52."""
from pathlib import Path
import hashlib
import json
from lupa.lua52 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
MODULES = ('util', 'stack', 'indexed_linked_list', 'nodes', 'ast_util', 'error_code_util', 'tokenize', 'parser')


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('package.path = ... .. "/?.lua;" .. package.path', str(ROOT))
    transform = lua.eval('require("scripts.runtime.compiler-build").generate')
    inputs = {f'vendor.phobos.{name}': ROOT / f'vendor/phobos/{name}.lua' for name in MODULES}
    inputs['scripts.runtime.compiler-pipeline'] = ROOT / 'scripts/runtime/compiler-pipeline.lua'
    inputs['scripts.runtime.compiler-primitives'] = ROOT / 'scripts/runtime/compiler-primitives.lua'
    output = ROOT / 'scripts/runtime/compiler-generated'
    output.mkdir(exist_ok=True)
    records = {}
    sources = {module: path.read_text() for module, path in inputs.items()}
    compiler = (ROOT / 'scripts/runtime/compiler.lua').read_text()
    validation = compiler[compiler.index('local globals = {}'):compiler.index('\nfunction M.compile')]
    # The durable front end validates the same nodes but does not build the obsolete
    # whole-handler native wrapper. Its executable output is ABI-9 blocks below.
    validation = validation.replace("    if nesting > (limits.host_stack_depth or limits.callback_depth) then reject(n, 'compiler host depth exceeded', 'E_CAPACITY') end", '')
    validation = validation.replace('    return s\n  end\n  local function list', "    return ''\n  end\n  local function list")
    validation = validation.replace("    return table.concat(out, '\\n')\n  end\n  function statement", "    return ''\n  end\n  function statement")
    sources['compiler.validation'] = "local parsing=require('scripts.runtime.parse_admission')\nlocal limits=require('scripts.runtime.limits')\nlocal errors=require('scripts.runtime.errors')\n" + validation + '\nreturn {emit=emit,identifier=identifier,reject=reject,position=position}\n'
    continuation = (ROOT / 'scripts/runtime/continuation.lua').read_text()
    lowering = continuation[continuation.index('function M.lower'):continuation.index('\nfunction M.run')]
    lowering = lowering.replace("entries[#entries+1]='['..quote(name)..']='..entry", 'entries[name]=entry')
    lowering = lowering.replace("transitions[#transitions+1]='['..successor..']=function(f) '..table.concat(cleanup,';')..' end'", "transitions[successor]='function(f) '..table.concat(cleanup,';')..' end'")
    lowering = lowering.replace("cleanups[i]='{'..table.concat(transitions,',')..'}'", 'cleanups[i]=transitions')
    lowering = lowering.replace('    for i,value in ipairs(ordered) do ordered[i]=quote(value) end', '')
    lowering = lowering.replace("    return '{'..table.concat(ordered,',')..'}'", '    return ordered')
    lowering = lowering.replace("functions[i]='{entry='..proto.entry..',captures={'..table.concat(proto.captures,',')..'}}'", 'functions[i]=proto')
    old_return = "  return 'return {blocks={'"
    start = lowering.index(old_return)
    lowering = lowering[:start] + "  return {blocks=blocks,cleanup=cleanups,entries=entries,protos=functions,symbols=quoted_set(symbol_paths),strings=quoted_set(literals),calls=calls,call_count=#outputs,slots=slots,locals=local_count}\nend\n"
    sources['compiler.lower'] = "local M={}\nlocal parsing=require('scripts.runtime.parse_admission')\nlocal function quote(s) return string.format('%q',s) end\n" + lowering + '\nreturn M\n'
    for module, source in sources.items():
        text, blocks, functions = transform(source, '@' + module)
        name = module.rsplit('.', 1)[-1]
        (output / (name + '.lua')).write_text(text)
        records[module] = {'module': name, 'source_sha256': hashlib.sha256(source.encode()).hexdigest(),
                           'generated_sha256': hashlib.sha256(text.encode()).hexdigest(),
                           'blocks': blocks, 'functions': functions}
    identity = hashlib.sha256(json.dumps(records, sort_keys=True).encode()).hexdigest()
    (output / 'identity.lua').write_text(f'-- Generated compiler cursor ABI; source and transform identity.\nreturn "{identity}"\n')
    (output / 'manifest.json').write_text(json.dumps(records, indent=2) + '\n')
    print(json.dumps({'identity': identity, 'modules': records}, indent=2))


if __name__ == '__main__':
    main()
