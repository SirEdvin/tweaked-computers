# Native circuit computers — planning entry point

Change: `add-native-circuit-computers`

Status: planning package, not an implemented mod. Target: Factorio 2.0.77, base-only and optional Space Age. Native named Lua callbacks only; no interpreter, OS or gameplay filesystem.

## Reading order

1. [Proposal](proposal.md) — scope and deliberate exclusions.
2. [Research](research.md) — pinned upstream findings, compatibility and provenance/feasibility limits.
3. [Design](design.md) — execution, persistence, physical ports, graphs, grouping and adapter architecture.
4. [Shared Lua contract](api/common.md) and [native language](api/native-language.md) — types, errors, timing, limits and accepted syntax.
5. Capability contracts below — each has requirements/scenarios and a separate API file.
6. [Integrated examples](api/examples.md) — actual proposed program source and factory acceptance cases.
7. [Implementation milestones](tasks.md) — executable work and verification, all still unchecked.
8. [Planning validation](validation.md) — checks actually run and what remains unverified.

## Capability index

| Capability | Requirements | Lua API / behavior contract |
| --- | --- | --- |
| Computer runtime | [spec](specs/computer-runtime/spec.md) | [API](specs/computer-runtime/lua-api.md) |
| In-game single-document editor | [spec](specs/program-editor/spec.md) | [API/workflow](specs/program-editor/lua-api.md) |
| Same-color peripheral network | [spec](specs/peripheral-network/spec.md) | [API](specs/peripheral-network/lua-api.md) |
| Merging monitors | [spec](specs/monitor-display/spec.md) | [API](specs/monitor-display/lua-api.md) |
| String/hash KV database | [spec](specs/kv-database/spec.md) | [API](specs/kv-database/lua-api.md) |
| Three-role logic handler | [spec](specs/logic-handler/spec.md) | [API](specs/logic-handler/lua-api.md) |
| Separate-target configurator | [spec](specs/device-configurator/spec.md) | [API](specs/device-configurator/lua-api.md) |
| Physical/data/artwork lifecycle | [spec](specs/device-lifecycle/spec.md) | [API lifecycle matrix](specs/device-lifecycle/lua-api.md) |

Configurator completeness is backed by a [human-readable catalogue](specs/device-configurator/configuration-catalog.md) and [machine-readable pinned inventory](specs/device-configurator/configuration-catalog.json), not a guessed list of universal properties. [Source provenance](research/source-manifest.json) records immutable research inputs and hashes; it is not a permission manifest for final converted sprites.

## Boundaries that must not drift

- Computer --red--> database --green--> monitor is not a discovery path.
- Vanilla poles do not relay computer discovery, but can relay the configurator's separate native target network.
- Network ports are passive hints through actual wires, never a signal transport protocol implemented by this mod.
- Logic INPUT, NETWORK and OUTPUT roles are isolated; one output contribution is mirrored to red/green output wires.
- Native callbacks finish rather than suspend; persistent state is explicit and functions are reconstructed without startup replay.
- Saving source and activating source are different actions.
- Runtime, monitor rendering, composite lifecycle, full configuration adapters and texture clearance still require their stated execution/release gates.

All planning artifacts are ready for review. Applying this change requires a separate explicit request; no production implementation was started during planning.
