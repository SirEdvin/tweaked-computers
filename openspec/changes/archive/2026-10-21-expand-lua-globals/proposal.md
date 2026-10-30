# Proposal

Historical plan, with source-language prose maintained for the declaration grammar. Its original verification evidence does not certify these edited descriptions or a new workload.

## Why

Saved programs currently reject ordinary `print(...)` even though the Console already supports it, and several useful Lua base functions are absent despite fitting the existing native execution model. Expand the everyday global surface using Factorio's Lua and the current guards, without building another language runtime or weakening isolation.

## What Changes

- Make `print(...)` available in saved functions and the Console. Convert arguments with the existing safe `tostring`, preserve nil/false positions, and append one tab-separated entry to the computer's existing bounded Console log. Keep `computer.log(text)` unchanged; do not emit Factorio chat or host stdout.
- Add guarded Lua 5.2 base functions `xpcall`, `rawequal`, `rawget`, `rawset`, and `rawlen` in both execution modes. Raw table access is limited to guest-owned plain tables, never API namespaces, peripheral facades or host state.
- Add `unpack` as an alias of the existing bounded `table.unpack`, and `_VERSION` as the language-family string `Lua 5.2`, not a claim of unrestricted standard-library support.
- Preserve native callbacks, work/allocation/depth/tuple limits, fatal stop/budget controls, immutable API tables, explicit application state and the existing Console graph format.
- Define the practical boundary explicitly: no metatables, dynamic loading, `_G`/`_ENV`, debug, garbage-collector control, coroutines, host facilities, or expansion of the `math`/`string`/`table` library inventories in this change. Factorio provides some facilities which remain unsuitable for direct guest exposure.
- Update the language/API references, in-game help, examples and packaged regression coverage together.
- **BREAKING (name collisions only):** newly exposed names become reserved API globals. Top-level helpers/exports named `xpcall`, `unpack` or `_VERSION` must be renamed; previously accepted Console scratch bindings colliding with newly reserved names must produce an explicit retained-state diagnostic, not be silently shadowed or deleted. Existing explicit Reset Shell remains the user-controlled way to discard such scratch state. Ordinary lexical locals/parameters may still shadow built-ins.

The user confirmed that saved-program output belongs in the existing computer Console, with multiple arguments and no change to `computer.log`. The requested compatibility target is what Factorio can support pragmatically, without elaborate emulation; this proposal interprets that as completing the useful safe base-global surface, not redesigning the sandbox for arbitrary Lua.

## Capabilities

### New Capabilities

None. The behavior belongs to the existing runtime, Console and source-authoring capabilities.

### Modified Capabilities

- `computer-runtime`: shared bounded base globals, Console-routed program printing, guarded raw operations and protected error transformation.
- `console-shell`: use the same base-global surface while retaining output formatting, immutable built-ins, shell graph restrictions and explicit handling of pre-existing name collisions.
- `program-source`: make the expanded globals available in saved functions, reserve their declaration names and define narrow compatibility behavior without changing top-level execution rules.

## Impact

- Runtime/compiler: `scripts/runtime/sandbox.lua`, `scripts/runtime/compiler.lua`; reuse `scripts/runtime/computer.lua` logging and `scripts/runtime/shell.lua` output attribution. Inspect/update `scripts/runtime/shell-values.lua` only for bounded collision detection during decode, not a graph migration.
- Documentation/contracts: `openspec/api/native-language.md`, the affected capability companions, `docs/player/api/language.md`, `docs/player/api/computer.md`, `docs/player/console.md`, and `scripts/ui/help.lua`; maintained example sources and their generated documentation where changed.
- Verification: extend the existing runtime, computer, shell, cold-load and editor contract fixtures and their current CI invocations. Require exact packaged Factorio 2.0.77 checks in base and Space Age, plus a focused real-client Console inspection for saved-program output.
- No new dependency, VM, persistence schema, host service, device, networking feature or higher production budget is proposed. This change does not modify the concurrent peripheral-inspector or radar-modem proposals.
