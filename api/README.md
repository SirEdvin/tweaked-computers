# Public Lua API definitions

These `*.d.lua` files describe the player-facing Tweaked Computers API. They contain
inert LuaCATS/LuaLS metadata, not implementations. Do not execute these files. Do not use `require` to load them.
Do not paste them into a computer. Methods use dot calls, with no implicit `self` or
host context argument. `TC.*` names are documentation types, not guest globals.
The engine verification target is Factorio **2.1.23**. The guest language family
is Lua 5.2, not unrestricted Factorio scripting.

## Ownership

- Write shared rules, types, parameters, ordered results and behavior in the
  adjacent declaration comments. Keep required positions distinct from optional
  positions and explicit `nil`. Document zero results and non-returning control.
- Include defaults, finite/integer/byte domains, errors, refusal/atomicity,
  authority, availability, persistence and context restrictions alongside types.
  An alias must keep the original contract. An overload needs separate prose
  when its parameter or result types differ. Known nested data needs a named type.
- `generated/configurator.d.lua` is produced by
  `tools/configuration_catalog.py` from the existing normalized runtime schema
  and its documentation projection. `tools/data/configuration-catalog.json`
  keeps the historical source provenance. This provenance does not establish current native
  verification. Read and write shapes differ where native normalization supplies
  defaults or caller-input ceilings do not constrain native readback.
- `generated/limits.d.lua` is produced by `tools/player_docs.py` from current
  implementation tables and setting domains. Listed defaults are not live
  values. Do not edit either generated file manually.
- Complete programs, wiring/tutorials and operational guides remain in
  `examples/`, `scripts/ui/tutorials.lua` and `docs/player/`, separate from inert
  signatures. Behavioral scenarios remain in OpenSpec. Historical proposals are
  not documentation inputs.

The migration builds both the website API and packaged native Reference from
these definitions. It uses a pinned LuaLS extractor. See
[documentation maintenance](../docs/documentation-maintenance.md) for tool
installation, generation/check commands and migration status. Runtime exports
and actual contract fixtures remain independent correctness evidence. Identical
outputs alone do not prove that a declaration describes the game correctly.

## Optional external editor

Use the pinned LuaLS from the maintenance instructions (or a compatible editor
extension). Point `workspace.library` at this directory, including `generated/`.
Do not also load the Factorio host API or the complete mod source as guest
libraries. Those libraries expose privileged globals and internal signatures.

For a separate guest-source project, start from the checked build configuration.
Remove the exporter hook. Use the absolute installed definition path:

```sh
jq --arg api /absolute/path/to/tweaked-computers/api \
  'del(.docScriptPath) | .["workspace.library"] = [$api]' \
  /absolute/path/to/tweaked-computers/tools/luals-docs.json > .luarc.json
```

Run this only in the intended guest project. Do not overwrite an existing
editor configuration without a review. If necessary, merge those settings into the existing
`.luarc.json`. The configuration keeps primitive builtin types and uses Lua 5.2.
It disables unrelated standard libraries, automatic third-party
workspace discovery and telemetry. You can copy the `api/` tree independently.
Its runtime does not depend on LuaLS or a network connection.

For example, external editor completion can follow the literal-family overload:

```lua
function start(event)
  local monitor = peripheral.find('monitor', 'red')
  if monitor then
    local width, height = monitor.getSize()
    monitor.write(string.format('%dx%d', width, height))
  end
end
```

LuaLS checks ordinary Lua and annotations, not this mod's restricted saved-program
grammar, circuit topology, resource admission or native authority. In-game
Validate and the actual compiler/runtime are still authoritative. Console-only
snippets and declaration stubs are not complete saved programs. Feature-dependent
methods such as Dashboard charts require runtime feature detection. A union type
does not permit calls to an absent method.

## Supported documentation notation

Use described LuaCATS classes, aliases, fields, enums, parameters, returns and
overloads. Exported prose supports paragraphs, headings, plain list text and
literal fenced code. Keep prose readable without Markdown link or table rendering
in the native client. Unsupported markup/structures, unresolved named types and
missing descriptions cause generation to fail. Generation does not silently discard this content.

Do not introduce a second handwritten JSON schema, an annotation parser, or
runtime documentation parsing. Generated parser-backed records are build inputs
only. The installed Reference contains literal native blocks.
