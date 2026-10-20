# TC01 — foundation checkpoint

Implemented tasks 1.1, 1.2 and 1.3 only. Functional specifications are unchanged.

The user requested complete implementation with lean verification, followed by
user-owned client testing once all specifications are implemented. This card
uses a single reusable archive-based headless smoke and compact grouped native
contracts. No graphical client, screenshots, GUI automation, client join matrix,
fuzz/benchmark campaign or speculative refactor was performed. Deferred client
checks do not block this implementation; they remain required before release.

Evidence:

- Exact official Factorio 2.0.77 (build 84539), headless.
- Deterministic tweaked-computers_0.1.0.zip; loadable development skeleton,
  not complete playable devices.
- Base-only and enabled Space Age fresh maps created successfully from the ZIP.
- 26 grouped compiled-native contract checks in each engine mode; nine exact
  planning programs compile, but their future service effects are not executed.
- Infinite loops, direct/mutual recursion, pcall budget swallowing, host/private
  identifiers, dynamic string-metatable access, protected-library writes,
  amplified helpers, malicious sort, cyclic service Data, stop poisoning,
  construction allocation exhaustion, actual engine LuaObject-return refusal
  and retained-generated-text distrust.
- A healthy native callback remains admitted after a malicious peer spends its
  own work quota on the same shared ledger. Services are fixture callbacks;
  this does not establish production entity/scheduler or real-tick latency.
- Retained-plan/fresh-plan admission matches, including partial compile
  exhaustion; generated caller text is ignored and exact source revalidated.
  Actual separate-process lifecycle reconstruction remains TC03/task 1.5.
- Parser-only Phobos import is pinned; exact original/installed/license byte
  hashes and the deterministic transform are recorded. No VM, bytecode,
  continuation or guest filesystem implementation is included.

Reproduction: README.md and docs/runtime-foundation.md. Smoke accepts
--fixture for downstream packaged modules exposing run(), and --mode for
only affected engine checks. It creates no server, so it opens no public or
LAN socket. A fresh external output directory holds logs/commands/maps/hash.

Local evidence directory for this run:
/home/siredvin/.hermes/profiles/albina/cache/scratch/tc01-smoke-verified

Tested archive SHA-256:
c931da297b70930c01a9135e076fb9b01125934576625de4fbc0d8fa6a5920cf

Downstream ownership: TC03 completes precise full language/API semantics,
activation/state/timers, fair synchronized scheduling, schema/identity recovery,
real cold load and independently owned peripheral teardown. Resource ceilings
remain provisional; this checkpoint claims bounded native work, not supported
maximum workload latency or graphical/multiplayer acceptance. Cache-free
recompilation is intentionally simple and must be measured before the final
envelope is frozen. Optimize only without changing admission on cold/exhausted
peers or executing retained generated text without source validation.
