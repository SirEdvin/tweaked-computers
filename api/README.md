# Public Lua API definitions

These `*.d.lua` files describe the player-facing Tweaked Computers API. They are
inert LuaCATS/LuaLS metadata, not implementations: do not execute, `require`, or
paste them into a computer. Methods use dot calls, with no implicit `self` or
host context argument. `TC.*` names are documentation types, not guest globals.
The engine verification target is Factorio **2.1.23**; the guest language family
is Lua 5.2, not unrestricted Factorio scripting.

## Ownership

- Author shared rules, types, parameters, ordered results and behavior in the
  adjacent declaration comments. Keep required positions distinct from optional
  positions and explicit `nil`; document zero results and non-returning control.
- Include defaults, finite/integer/byte domains, errors, refusal/atomicity,
  authority, availability, persistence and context restrictions alongside types.
  An alias must retain the original contract; an overload needs its own prose
  when its parameter/result types differ. Known nested data needs a named type.
- `generated/configurator.d.lua` is produced by
  `tools/configuration_catalog.py` from the existing normalized runtime schema
  and its documentation projection. `tools/data/configuration-catalog.json`
  retains the historical source provenance; it is not a claim of current native
  verification. Read/write shapes differ where native normalization supplies
  defaults or caller-input ceilings do not constrain native readback.
- `generated/limits.d.lua` is produced by `tools/player_docs.py` from current
  implementation tables and setting domains. Listed defaults are not live
  values. Neither generated file is edited by hand.
- Complete programs, wiring/tutorials and operational guides remain in
  `examples/`, `scripts/ui/tutorials.lua` and `docs/player/`, separate from inert
  signatures. Behavioral scenarios remain in OpenSpec. Historical proposals are
  not documentation inputs.

The migration builds both the website API and packaged native Reference from
these definitions through pinned LuaLS extraction. See
[documentation maintenance](../docs/documentation-maintenance.md) for tool
installation, generation/check commands and migration status. Runtime exports
and actual contract fixtures remain independent correctness evidence; identical
outputs alone do not prove that a declaration describes the game correctly.

## Optional external editor

Use the pinned LuaLS from the maintenance instructions (or a compatible editor
extension). Point `workspace.library` at this directory, including `generated/`.
Do not also load the Factorio host API or the complete mod source as guest
libraries: those expose privileged globals and internal signatures.

For a separate guest-source project, start from the checked build configuration
but remove the exporter hook and use the absolute installed definition path:

```sh
jq --arg api /absolute/path/to/tweaked-computers/api \
  'del(.docScriptPath) | .["workspace.library"] = [$api]' \
  /absolute/path/to/tweaked-computers/tools/luals-docs.json > .luarc.json
```

Run this only in the intended guest project, without replacing an existing
editor configuration blindly. Merge those settings into an existing
`.luarc.json` when necessary. The configuration keeps primitive builtin types,
uses Lua 5.2, disables unrelated standard libraries, automatic third-party
workspace discovery and telemetry. The `api/` tree can be copied independently;
its runtime has no dependency on LuaLS or a network connection.

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
methods such as Dashboard charts require runtime feature detection; a union type
is not permission to call an absent method.

## Supported documentation notation

Use described LuaCATS classes, aliases, fields, enums, parameters, returns and
overloads. Exported prose supports paragraphs, headings, plain list text and
literal fenced code. Keep prose readable without Markdown link or table rendering
in the native client. Unsupported markup/structures, unresolved named types and
missing descriptions fail generation rather than silently losing content.

Do not introduce a second handwritten JSON schema, an annotation parser, or
runtime documentation parsing. Generated parser-backed records are build inputs
only; installed Reference consists of literal native blocks.
