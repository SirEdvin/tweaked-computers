# Trusted native Lua: implementation contract

## Scope and verification policy

Saved programs and Console commands execute as native Lua through a checked host API.
The compiler validates source before native loading. It does not add execution probes.
The environment exposes only approved helpers and authorized services.
It does not expose Factorio objects, host globals, dynamic loading, or unrestricted libraries.

**Run only trusted code.** An infinite loop can stop the game.
Temporary Lua values can use all available memory.
Stop cannot interrupt code that does not return control to the host.
Host-work admission does not provide a native execution-time or memory limit.

Use finite contract tests with isolated saves. Do not execute former watchdog tests that require an infinite loop or memory exhaustion.
Headless checks establish runtime behavior, not visible UI behavior, connected multiplayer behavior, or representative GPU performance.
The current acceptance engine is Factorio 2.1.23, with base and Space Age checked separately.

## Entrypoints (trusted implementation code only)

Import modules during control.lua parsing. Never require inside an event.

    local admission = require('scripts.runtime.admission')
    local compiler = require('scripts.runtime.compiler')
    local ledger = admission.new()
    local context = admission.context(ledger, 'computer:1', game.tick)
    local plan, diagnostic = compiler.compile(source, context)
    local ok, diagnostic = compiler.run(plan, 'start', event, services, context)

`compile` returns a plain plan with compiler/API versions, exact source, native text, handler names, and a node count.
It does not execute candidate source. Failure returns nil and an ApiError-style diagnostic.
The caller must retain its previous active source and run.
`run` constructs a fresh environment and native functions for each dispatch.
Success returns true. Failure returns false, a diagnostic, and an optional host-only control classification.
`stop` identifies genuine private stop control. `defer` identifies refused preparation that can wait for a later tick.
Neither classification is a guest ApiError. A started callback cannot suspend or restart after failure.
Native diagnostics retain original source lines where available. The column is 1 when native diagnostics supply no column.

Plan data can be retained. Never retain functions or an execution environment.
Source is revalidated or matched against a bounded private exact-source proof on
every run. Caller-owned generated text is never trusted. At most eight plans and
32768 charge records per plan are cached, without ASTs or executable closures.
Warm proofs pay identical compilation/reconstruction credits, including the exact
accepted prefix on partial refusal. See [animation runtime costs](player/monitor-animation.md#runtime-costs).

## Shared budget and service boundary

`admission.new` returns plain `{version=2,tick,total,machines}` data.
Persist one ledger under the versioned storage root.
`context(ledger,id,tick)` rejects backwards clocks and retains each identity's work and compilation spending for the same tick.
Only an actual tick advance resets the ledger. Never delete a counter during stop, removal, or readmission.
`reserve(context,kind,amount)` accepts only `work` and `compile` charges.
Both charge kinds use the shared host allowance. Compilation also uses the per-computer compilation allowance.
Every dispatch validates the exact source and admits reconstruction before native loading.

services is a trusted table with computer/peripheral method maps. Wrappers
check fatal poison before touching host effects, validate and copy Data inputs
and outputs, preserve nil arity, and never expose a Factorio object. Service
implementations must validate arity/domain, recheck current authority and
reserve their own input-dependent native work before effect publication. The
compiler cannot authorize a network path for them. Earlier accepted effects
remain committed when a later call faults. Host teardown is independently
owned and must not call a guest cleanup handler.

Checked environments expose namespace(entries,label), service(fn), snapshot(v),
spend(n), check(), diagnostic(e) to trusted implementation modules. namespace
builds an opaque read-only guest table backed by ephemeral private entries.
For peripheral wrappers, supply a protected handle built with this same run's
guard. No raw host function/table/LuaObject return can cross service(). A method
captured from such a wrapper must revalidate authority on every call. These
are internal hooks, not guest exports. A service map or a guard-aware trusted
factory function(guard) -> service map can be passed to compiler.run. Build
peripheral handles with guard.namespace and guard.service in that factory.
Never put those closures/proxies in storage.

Protected library tables are not copied Data, not mutable by table helpers and
not enumerable. Ordinary tables, including events/service readbacks, are fresh
plain values. API Data rejects cycles, metatables, function/userdata/thread
values, mixed map/array keys, sparse arrays and nonfinite numbers.

## Host-work accounting and preparation

Internal charges and refusal locations can change between versions. Surviving host and persistence limits keep their defaults.
Completed effects remain in order. A refusal does not renew or refund spent credits.
Cold and warm execution use the same charge sequence for the same inputs and remaining credits.

`admission.bind` validates the ledger, machine identity, and tick once. Its work function retains those references, not remaining-credit copies.
Each reservation checks the current tick, machine alias, ceiling, aggregate spending, and maintenance headroom.
Amounts other than the fixed unit charge retain safe-integer validation. General host ingress still uses `admission.reserve`.
Ordinary Lua operations do not spend host credits. There are no callback-work, temporary-allocation, tuple-width, or call-depth meters.
Compiler-cache replay retains the exact accepted compilation prefix, including partial refusal.

Preparation includes source validation, environment construction, event copying, and Console graph reconstruction.
The scheduler retains the pending item until preparation succeeds.
Preparation waits when earlier spending prevents a charge prefix that fits the full current source and host allowances.
Accepted preparation charges remain spent. The item retains its identity and order, without a command echo or graph publication.
Preparation that cannot fit fresh allowances fails instead of waiting indefinitely.
Each attempt checks current authority. Invalid authority consumes the canceled item through the existing visible failure path.
The scheduler consumes accepted work immediately before execution. It never repeats started code or earlier effects.

## Local output admission

Numeric formatting admits host conversion work before native conversion. It uses the existing 512-byte numeric format bound.

Program and Console output use one private buffer writer. Each invocation binds the writer to its exact execution owner.
Generic service calls invalidate its physical proof before provider execution. Later output must establish that proof again.
The writer checks cancellation on each call. Guest code cannot select its destination.
Valid string output does not use the generic Data bridge. Invalid arguments retain the existing ordinary-error path.
Console keeps its ignored-extra-argument exception and its complete attribution prefix.

Output construction admits the complete format, attribution prefix, and retention work before publication. Print and log calls return no values.
An append without eviction costs four retention work units. An append with eviction admits at most `3 * retained_entries + 4` units.
This allowance covers the prefix scan, survivor movement, tail clearing, and publication. Each surviving entry moves at most once.
The saved array, byte counter, and truncation flag keep their existing formats. Refusal changes none of these values.
Host diagnostics use the same bounded writer. Console dispatch reserves linear retention work for its command echo and recovery diagnostic.

## Source validation and checked execution

Saved program mode accepts only a declaration document with at least one simple
exported `function name(...)` and optional private `local function` helpers.
API version 1 is implicit. Comments and empty statements are allowed.
Top-level returns, effects, variable initialization, ordinary assignment, control flow,
dotted declarations and methods are rejected. The live Console is a separate mode
and never inherits saved-program exports.

The declaration validator checks public/private identifiers, reserved names, and the existing export limit.
Private helpers retain source, compiler, and native syntax limits.
Each dispatch constructs a fresh private export table without adding one lexical local for each export.
Only validated declarations can fill that table. Construction closes before handler execution.
Export names permit forward and mutual calls. Private helpers keep their original lexical order and self-recursion.
Locals can shadow exports. Unshadowed export assignment remains forbidden.

Direct calls use ordinary native arguments, aliases, and result adjustment.
Exported functions can be returned, captured, aliased, or called through `pcall`. They cannot be stored as Data.
Calling `start` directly does not activate or reset a run. Named registration APIs accept strings only.
Only exported `start` has automatic startup meaning. Each dispatch reconstructs fresh functions.
No guest function, local state, or executable closure survives a callback.
No guest source executes during `on_load`.

Default-deny validation rejects host/global writes, private names, `_ENV`, `_G`, dynamic loading, colon calls, labels, `goto`, and unknown AST nodes.
Ordinary indexing is native. During guest execution, the string metatable exposes only the approved string members.
Checked host entry restores host string members temporarily. Every return and failure restores the preceding scope.
Native comparator callbacks and protected error handlers execute in guest scope.
No metatable becomes a guest value.

Private fatal status prevents host-work refusal or stop from escaping through `pcall` or `xpcall`.
Checked API entry, error-handler entry, protected-call exit, and retained publication check this status.
Native Lua failures remain ordinary failures. Native helpers do not stage temporary mutations or impose mod execution quotas.
API effects and retained graph publication keep their separate validation and admission requirements.
Safe formatting does not reveal host addresses. Only approved standard helpers are available.
Source bytes, tokens, AST nodes, nesting, and compilation work retain their existing limits.

## Storage and migration

See [computer runtime](computer-runtime.md) for entity bindings, activation, scheduler hooks, and service registration.
Public API and storage versions remain 1. The compiler representation is 3, and the admission ledger version is 2.
Synchronized migration validates known older source before updating its compiler header. It does not execute startup.
Active source remains separate from newer saved-but-unapplied source.
Migration retains run IDs, queues, deadlines, shell graphs, and spent aggregate credits.
Unknown or malformed metadata stays unavailable with source and data retained for recovery.
Ordinary `on_load` does not change authoritative state.
Rollback requires the complete pre-upgrade save and matching mod archive. An in-place downgrade is not supported.

## Reproducible checks

    lua5.2 -e 'require("tests.runtime_contract").run()'
    python3 tools/build.py --output /absolute/artifacts
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /absolute/artifacts/tweaked-computers_0.1.20.zip \
      --output /absolute/fresh-smoke

Use Lua 5.2 for the optional quick check. Factorio remains the acceptance engine.
`smoke.py` uses isolated configuration, mod, and write-data directories with the built archive and a test companion mod.
Keep logs, saves, engine versions, and archive hashes outside git.
Use `--fixture` for focused contracts and `--cold` for separate-process persistence checks.
Those checks do not establish client appearance or connected multiplayer behavior.
