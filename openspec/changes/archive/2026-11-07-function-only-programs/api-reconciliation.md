# API reconciliation

The former `specs/program-source/lua-api.md` companion is already canonical in
the destinations below. The documentation migration changes ownership only;
this change's behavioral decisions, completed task flags and evidence remain
unchanged. Do not copy a Markdown API companion back during synchronization.

| Former section | Canonical destinations |
| --- | --- |
| Grammar and names | `docs/player/api/language.md`, `api/computer.d.lua`, `api/globals.d.lua` |
| Scope and values | `docs/player/api/language.md`, `api/computer.d.lua`, `api/common.d.lua` |
| Calls and registration | `api/computer.d.lua`, `api/globals.d.lua`, `api/logic-handler.d.lua`, `docs/player/api/language.md` |
| Example: immediate and recurring work | exact `examples/function-program.lua`, generated examples and in-game starter tutorial |
| Errors, admission and lifecycle | `api/common.d.lua`, `api/computer.d.lua`, `docs/player/api/language.md`, `docs/player/console.md` |

The preserved decisions include simple unique export names and reserved names,
ordinary lexical private helpers, forward-visible exports, temporary callable
identity, fresh callbacks, direct-call argument/result adjustment without event
creation or renewed credits, explicit named registration and optional startup,
Console isolation, original-source diagnostics, failed-candidate retention,
identical warm/cold admission, exact active-source reconstruction and no replay.
The typed files and language guide carry the full details, not this mapping.

Keep the original compiler/runtime, tutorial and native acceptance obligations
in `tasks.md`. The existing exact-source migration manifest checks the retained
example. This reconciliation neither reruns historical tests nor waives an
unverified gate. Future API changes use change-scoped `api/**/*.d.lua` artifacts;
only behavioral `spec.md` files are synchronized into maintained OpenSpec specs.
