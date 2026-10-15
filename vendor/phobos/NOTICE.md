# Phobos parser-only import

Upstream: JanSharp/phobos, revision
2566dd85807b4f2bdff8e40ba4d79bcf8e96de3f.

The eight Lua modules listed in manifest.json are the transitive dependency
closure of parser.lua. The original MIT notice is preserved in LICENSE.txt.
No third-party submodule is needed. compiler.lua, il_*, dump, opcodes, binary
serializer, optimizers, runtime/VM code, CLI, filesystem and bytecode loaders
are deliberately not imported.

Reproduce from a checkout containing the exact pinned Git object:

    python3 tools/import_parser.py /path/to/phobos

The importer reads immutable Git objects, never working-tree modifications.
It namespaces imports, adds host-only compilation-work probes at trusted
function/loop boundaries, limits recursive grammar entry, preserves sub_expr's
second return, and clears parser roots after successful or failed parsing.
These changes concern source compilation, not guest execution. Original and
installed byte hashes/lengths are in manifest.json. The original license bytes
are unchanged. The deterministic builder validates installed hashes and exact
Lua module inventory before packaging.
