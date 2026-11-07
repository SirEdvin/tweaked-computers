# 0.1.21 ALPHA — trusted native Lua and lower host overhead

This patch runs saved programs and Console commands as trusted native Lua.
It also reduces the host work of idle ticks and of each callback.

## What changed

- **Breaking:** The mod no longer meters execution steps, temporary allocations,
  call depth or tuples. Native Lua limits still apply.
- **Breaking:** The settings `tc-callback-work` and `tc-callback-allocations` are
  removed. `callback_work`, `callback_allocations`, `callback_depth`,
  `tuple_entries` and `generated_source_bytes` are removed from common limits.
- Source validation, API authority, protected namespaces, safe output formatting,
  validated persistence, bounded queues and logs, host-work admission and
  retained-data limits stay.
- The scheduler skips hooks that have no due work. A tick without due work
  allocates no Lua memory. The running status light is a native animation.
- Callbacks of one run reuse host scaffolding and the loaded program chunk.
  Each callback still makes fresh declarations, locals and upvalues. A run pays
  compilation one time.
- A callback buffers `print` and `computer.log` output. The host writes it to the
  Console one time, also when the callback fails or stops. Entry text, order and
  retention do not change.
- The network walk validates each device one time and creates fewer native
  objects. Results, order and refusals do not change.

The public Lua API has no new functions. Saved-program grammar does not change.

## Run only trusted code

An infinite loop can stop the game. Temporary Lua values can use all available
memory. Stop cannot interrupt code that does not return control to the host.

## Install and upgrade

Use `tweaked-computers_0.1.21.zip`, not GitHub's automatic source archive. Keep the
ZIP unextracted and move conflicting older archives or extracted copies aside.
Factorio **2.1** is required; base alone and optional Space Age are supported.
The tested engine is **2.1.23**, not every accepted 2.1 patch or mod combination.

A synchronized migration upgrades 0.1.20 saves. It keeps source, state, Console
graphs, run IDs, queues, deadlines and spent host credits. It does not repeat
startup or completed effects. See
[runtime upgrade and rollback](player/lifecycle.md#upgrading-to-trusted-native-lua).

Back up the complete save and matching mod set before upgrading. Restore both to
roll back. Never downgrade an upgraded save in place.

## Verification and limits

All engine checks used **2.1.23**, in base and Space Age. The final ZIP passed the
Python tooling tests, the packaged 49-fixture smoke matrix with its cold and
production-context phases, the four-walls and mixed monitor animations, and an
upgrade from the published 0.1.20 ZIP with a cold reload.

This remains **ALPHA**. Scheduling performance and scaling are not certified.
This patch adds no arbitrary-modpack certification. Backups remain essential.
