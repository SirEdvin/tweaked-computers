---
type: security
title: Native compiler and sandbox trust boundaries
description: Bounded parser admission and native Lua emission, fresh guarded callback environments, Data copying and uncancellable fatal poisoning.
tags: [compiler, sandbox, security, native, data]
verified:
  - by: openwiki/0.7.1
    at: 2026-10-15T06:41:57.498Z
sources:
  - id: openwiki-source-4cee717286544161165260f8
    resource: repo://scripts/runtime/compiler.lua
  - id: openwiki-source-5d48cd00e5813afcd8f4727c
    resource: repo://scripts/runtime/data.lua
  - id: openwiki-source-2e3e95454d6dba095a611b9f
    resource: repo://scripts/runtime/sandbox.lua
generated: { by: "hermes", at: "2026-10-15T06:41:57.498Z" }
---

# Native compiler and sandbox trust boundaries

## Compile a language subset, not a general Lua loader

`compiler.lua` imports only the pinned Phobos parser/tokenizer dependency closure. The document must return a literal descriptor containing exactly `api_version=1` and literal named function `handlers`. Top-level statements, computed handler definitions, duplicate/unknown descriptor keys and unsupported syntax are rejected before any guest execution. Compiler/API/storage versions are deliberately separate headers.

`compile` bounds source bytes, tokenizer count/identifiers, AST nodes/nesting, tuples, handler count and generated text. Host parser probes share compilation admission. `_ENV`, `_G` and reserved `__tc` identifiers are forbidden; unknown globals and global writes are rejected. Colon declarations/calls are not part of this language. The allowed global surface is a closed set of wrapped primitives/libraries plus `computer` and `peripheral`, not Factorio `game`, `script`, raw loader, filesystem or OS access.

Emission translates accepted AST forms into native Lua with guard calls at statement/loop/call/constructor/index/assignment boundaries. Native `load(...,'t',{})` during compile checks only emitted text syntax; it does not execute a candidate. There is no guest interpreter, bytecode backend, coroutine continuation or saved native stack.

## Dispatch trusts source, not retained generated text

`compiler.run` validates plan versions and recompiles `plan.source` every dispatch. It ignores caller-retained generated text, checks that the requested handler exists and reserves reconstruction costs. It creates a sandbox, loads newly emitted text in an environment containing only `__tc`, constructs the handler table and invokes the named callback with a guarded event snapshot.

The fresh environment is intentional: even an unchanged source document has the same admission/reconstruction behavior after cold load or in a warm process. Local closures/tables can live inside one callback but cannot become a hidden cross-callback state store. Durable communication uses explicit copied Data and named registrations in the [runtime owner](../architecture/runtime-and-state.md).

## Guest values and host effects

The sandbox privately tracks guest-owned tables, protected namespaces/handles and callable values. Indexing never delegates to the host string metatable. Table mutation requires guest-owned, nonprotected plain tables; protected namespaces expose fixed methods. Assignment preflight validates every target/value and table capacity before emitted indexed writes, rather than publishing a partially checked assignment.

`G.service` spends/checks before crossing into trusted code, snapshots arguments and snapshots ordinary results back. Protected handles are exceptional host-built opaque facades; only explicit trusted introspection can accept one as an argument. Individual host services must still validate current physical/run authority and reserve native work before effects. A compiler guard does not automatically make a native setter transactional.

Host durable `data.copy` accepts finite numbers, booleans, bounded strings and plain acyclic tables, either string-key maps or dense positive-index arrays. It rejects functions, metatables, nil values as stored Data, mixed maps/arrays and cycles, and bounds depth/nodes/bytes/entries. Sandbox snapshots allow nil as absence, but protected handles are not serializable Data. Repeated noncyclic references are copied, not retained as host aliases.

## Fatal limits cannot be caught and ignored

Work/allocation/depth/tuple failures poison the current callback with a private sentinel. Every subsequent guard checks poison. Wrapped guest `pcall` checks again after its native protected call, so a script cannot catch a budget fault then perform another service effect. `computer.stop` uses the same nonreturning control mechanism; diagnostics distinguish stop from budget exhaustion. Ordinary API errors can be caught where documented, but catching an error does not grant renewed credits or remove poison.

Wrapped libraries reserve bounded result work before native operations; string concatenation checks primitive operands and full output length before concatenating. New library functions must preserve that preallocation boundary, check callback poison on reentry and avoid exposing addresses/metatables or unbounded native work. Do not add raw `load`, unrestricted pattern engines, host object access or an escape via string methods.

Current resource ceilings live in `limits.lua` (including 16 KiB source, 4096 source tokens/nodes and a 32-depth callback ceiling); they are development/provisional limits, not measured real-time guarantees. Shared [admission](scheduling-and-admission.md) survives save/load and same-tick stop/restart.

## Focused tests and extension rule

`tests/runtime_contract.lua` contains adversarial sandbox/compiler contracts; `tests/computer_contract.lua` and cold fixtures cover retained source/runtime behavior. Review those alongside compiler and sandbox changes. Add a regression at the smallest actual boundary: forbidden syntax before effects, malicious caught budget failure, copied Data isolation or native work admission. This documentation run does not rerun engine fixtures and does not claim client execution evidence.

Related: [runtime/state](../architecture/runtime-and-state.md), [scheduling/admission](scheduling-and-admission.md), [build/parser provenance](../operations/build-test-and-assets.md).
