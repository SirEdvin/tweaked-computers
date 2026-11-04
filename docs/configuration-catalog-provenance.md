# Configurator inventory provenance

`tools/data/configuration-catalog.json` is the unchanged historical native inventory,
not the public guest API and not a claim that current tests use its historical engine.
Its source was Factorio 2.0.77 runtime JSON, SHA-256
`594b4ec98cc5fbee322d7380db49a388ab38b0d69c06f00ead877cffbb37f578`.
The old Markdown coverage table is replaced by this same machine-readable inventory
and the derived public `api/generated/configurator.d.lua` input/readback definitions.

`tools/configuration_catalog.py` normalizes that inventory through existing guest
policy, producing `scripts/configuration/catalog.lua` and the coverage ledger.
The current 2.1 adapters preserve the approved compatibility vocabulary rather than
exposing every later native addition. Native class applicability is not a prototype
whitelist; base classes are included for inherited-field auditing, not extra entities.
Actual schemas and restrictions belong to the generated declarations and live
capabilities, not this provenance note. A behavior-unset reason does not imply that
all potential setting schemas are missing: inspection must not create the behavior.

During this documentation migration the runtime catalogue is byte-identical to the
pre-migration file. Documentation-only readback types account for cleared native
outputs and normalized defaults separately from accepted write inputs.

Verification uses Factorio 2.1.23 only. Native field/section, invalid-patch atomicity,
GUI readback, expansion-off safety and shared-group containment remain separate
acceptance obligations. An unexercised applicable field is not a passed case;
"not implemented" is not an acceptable permanent native-applicability reason.
Pinned 2.1.23 probes of cleared decider/selector settings establish those particular
readbacks, not universal native GUI or whole-catalogue acceptance.
