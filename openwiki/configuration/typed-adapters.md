---
type: integration
title: Typed configurator adapters and extension seams
description: Current target authorization, generated pinned schemas, preflight/readback transactions and shared-section safety for native control behaviors.
tags: [configurator, adapters, validation, transactions, extension]
sources:
  - id: openwiki-source-494356088c062b02493311a3
    resource: repo://scripts/configuration/adapters.lua
  - id: openwiki-source-cee121501984e94d377bd99d
    resource: repo://scripts/configuration/sections.lua
  - id: openwiki-source-cb60da2bf5fe82e8150a4867
    resource: repo://scripts/configuration/targets.lua
  - id: openwiki-source-5411e57fe2dc5309042146d3
    resource: repo://scripts/configuration/validation.lua
  - id: openwiki-source-66bfa415f927a71bc299a364
    resource: repo://scripts/services/configurator.lua
  - id: openwiki-source-1cab5c906bc8c125f01e07d3
    resource: repo://tools/configuration_catalog.py
generated: { by: "hermes", at: "2026-10-29T22:50:29.161Z" }
verified:
  - by: openwiki/0.7.1
    at: 2026-10-29T22:50:29.161Z
---

# Typed configurator adapters and extension seams

## Two authorization layers

A guest first reaches a configurator through the mod-only peripheral network. Every configurator method then traverses its physically separate `targets` port with an explicit red/green wire. Target IDs are host native-object registration identities, not coordinates or network IDs. Every call rebuilds current target reachability before reading or writing. Custom composite devices can appear in discovery but carry `protected=true`; native radar/speaker carriers are not made protected merely by adoption. Adapters do not forward writes into protected implementation components.

`services/configurator.lua` binds ten methods to the peripheral type. Description combines copied prototype/type/position/surface/direction/quality data with connected connector IDs and adapter summary. Read-only inspection uses `get_control_behavior`, never creating a native behavior merely to discover it.

## Schema pipeline and native validation

`tools/configuration_catalog.py` reads the pinned configuration catalogue under the OpenSpec device-configurator capability. It generates `scripts/configuration/catalog.lua` and `docs/configuration-coverage.json`; do not edit generated Lua independently. The generator requires every behavior class to appear in explicit BASIC/NATIVE adapter sets and records fixture prototypes, constraints and implemented/native-unavailable status. `--check` compares without writing.

The runtime validator checks finite ranges, plain shapes, required/unknown fields, enums by public names, prototype existence, signal-role wildcard rules, dense arrays and operation-dependent variants. Native conversion/normalization is separate from public schema projection. `fulfilled` and `disabled` are observations, not arbitrary writable properties. A new concept needs deliberate validation, native conversion and normalization—not a generic property-forwarding escape hatch.

Effective capability is contextual. Examples include fuel inventory presence, requester/buffer logistic modes, chain-signal-only blue output, ammo/fluid turret restrictions, Space Travel-dependent landing-pad mode and the explicitly unavailable asteroid logistic-connection field. Keep summary, capabilities, snapshot and mutation behavior aligned; a schema entry alone does not establish native availability.

## Whole-patch preflight, bounded transaction

`adapters.preflight` copies a bounded patch with only `set` and `clear`, checks repeated/unknown/read-only/unavailable fields, validates all supplied values and computes native/expected normalized changes before mutation. Clear is allowed only where the schema permits it. Native cleared values may read back engine defaults rather than nil.

`apply` snapshots existing settings, then reserves setters, readback, defensive publication and restoration work before any mutation. It may create a control behavior only after this authorization/preflight. A newly created behavior has native defaults; failure recovery does not pretend it can delete that behavior.

Writes are ordered: signals/modes first, conditions next, activation switches last, alphabetically within rank. The adapter reads normalized settings back and checks every changed field. On native error or mismatch it attempts target-local restoration and verifies it. Failure to restore retains a bounded `origin.configuration_recovery[target_id]` with before/request/context, and later writes to that target are refused. Even successful restoration does not roll back external effects already caused in the world: this is not a multi-entity or simulation transaction.

## Constant sections have a separate safety policy

`sections.lua` handles native one-based section indexes and explicit filter slot indexes. Readback includes manual/type/group/capability information. Nonmanual sections are read-only. Writing filters while the final group is nonempty raises `E_SHARED_SCOPE`; group-wide shared contents are never mutated by this API.

Explicit detachment to `group=''` preserves effective filters before replacements. Slot identity/index duplicates are rejected. Empty filters replace contents; section fields cannot be cleared with a nonempty `clear` array. Add/set/remove reserve readback/restoration work and verify resulting inventory/settings; multiplier verification permits only float32 storage rounding. Removal recovery rebuilds only a manual suffix and refuses to touch nonmanual neighbors. Recovery failures use the same target-local retained diagnostics.

## Adding support safely

1. Extend the pinned catalogue intentionally, the generator's explicit class/fixture map and any contextual availability rules. Regenerate both outputs and run `python3 tools/configuration_catalog.py --check`.
2. Add concept/variant and signal-role rules to validation, native and normalized forms. Preserve public enum names and copied Data boundaries.
3. Preserve preflight-before-effect, full work reservation, activation-last ordering, native readback and target-local restoration. Do not bypass the protected-owned-device or shared-group policies.
4. Add the smallest native engine fixture to `tests/configurator_engine.lua` or `tests/configurator_full_engine.lua`; optional prototypes live in `tests/configurator_full_data.lua`. Test the invalid-input/no-mutation path as well as round-trip and restoration behavior.

These tests are source coverage references; no application engine test was rerun for wiki generation. See [operations](../operations/build-test-and-assets.md) for the reused harness and [network policy](../network/discovery-and-authority.md) for why target traversal must remain separate from peripheral discovery.
