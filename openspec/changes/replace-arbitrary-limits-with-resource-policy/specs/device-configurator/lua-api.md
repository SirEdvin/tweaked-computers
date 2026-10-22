# device-configurator resource-policy Lua API amendment

Proposed normative amendment to the existing [API](../../../../specs/device-configurator/lua-api.md), with unchanged details retained there unless explicitly replaced below. Shared execution, status and errors: [api-contract.md](../../api-contract.md).

Existing `getDevices(target_wire)`, `getDevice(device_id, target_wire)`, `getCapabilities(device_id, target_wire)`, `getConfiguration(device_id, target_wire)` and `setConfiguration(device_id, patch, target_wire)` retain signatures and full result schemas. `getLimits()` reports effective resource policy instead of invented target-node/edge, section, filter, patch-field or generic array/string maxima.

Target traversal and read projection may suspend but return complete inventories/snapshots only. Capability bounds identify actual engine constraints; where the native field has no independent cardinality bound, no fixed mod limit is advertised. Registered prototype identity replaces arbitrary name-length rejection.

An update prepares a detached candidate, then revalidates identity, path, current configuration and protected/shared-group rules immediately before commit. It returns the complete readback after success. Resource refusal leaves all fields and recovery data unchanged. A native atomic operation too costly for the configured indivisible-work allowance fails recoverably with setting guidance; it is not split into observable partial field updates.
