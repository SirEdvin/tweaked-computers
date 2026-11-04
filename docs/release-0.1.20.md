# 0.1.20 ALPHA — one typed Lua API reference

This patch makes the separate [`api/**/*.d.lua` library](../api/README.md) the
authoritative player-facing API reference. The website and in-game Reference are
generated from the same declarations, including overloads, exact return shapes,
nested fields, optional capabilities, errors and lifecycle restrictions.

## What changed

- Ship the complete public declaration library for external Lua-aware editors.
  It describes player-facing dot calls, not internal host methods, and is never
  executed by a guest program.
- Generate both reference surfaces from the same typed records. Preserve native
  search, literal selectable text, complete copyable examples and contextual
  peripheral navigation without disturbing a dirty program draft.
- Generate Configurator declarations from the existing machine-readable schema;
  the runtime catalogue is unchanged.
- Retire duplicated maintained Markdown API contracts while retaining tutorials,
  behavioral requirements, historical archives and examples. The
  [migration map](api-migration.md) records their destinations.
- Require future API-changing OpenSpec proposals to include typed Lua artifacts,
  with read-only overlay validation against unchanged canonical dependencies.

There is no guest API, save-format, runtime-budget or scheduling-behavior change
from 0.1.19. This is not an interpreter or a new runtime dependency.

## Install and upgrade

Use `tweaked-computers_0.1.20.zip`, not GitHub's automatic source archive. Keep the
ZIP unextracted and move conflicting older archives or extracted copies aside.
Factorio **2.1** is required; base alone and optional Space Age are supported.
The tested engine is **2.1.23**, not every accepted 2.1 patch or mod combination.

Back up the complete save and matching mod set before upgrading. Restore both to
roll back; never downgrade a newly saved world in place. Synchronizing an old
save's mods can reselect the older version.

Earlier compatibility changes remain: saved programs use named function
declarations only, legacy table-form programs need manual rewriting, and computer
items are plain hardware. Ordinary pickup/replacement loses computer contents;
legacy programmed item payloads are not imported. All nine custom device families
remain electricity-free; native radars and speakers retain their normal supply
requirements. See the [installation guide](player/getting-started.md).

## Verification and limits

The typed-reference candidate passed the full Python tooling suite, strict website
build and generated-reference parity checks, packaged runtime/editor checks,
production-context integration and tutorial cold reloads (with and without the
optional chart mod), and compilation of retained documentation examples.
All engine checks used **2.1.23**, in base and Space Age.

Native Reference checks covered both modes at 100% and 150% UI scale: all generated
topics, nested types and overloads, actual selection/copy/paste, complete tutorial
copying, search/no-result recovery, contextual navigation, dirty-draft preservation
and separate-process cold reopen. Release-only metadata/documentation changes are
compared byte-for-byte against that candidate; the final versioned ZIP additionally
requires packaged checks, a populated published-0.1.19 upgrade, and native smoke
before publication.

This remains **ALPHA**. Software-rendered client checks are not representative GPU
benchmarks. Scheduling performance/scaling remains unverified from 0.1.19's
explicitly waived benchmark campaign. This patch does not add connected-multiplayer
or arbitrary-modpack certification. Backups remain essential.
