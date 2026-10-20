# Proposal

## Why

The in-game peripheral reference compresses multiple methods into single lines and separates important behavior from the methods it describes, making it hard to scan while programming. Peripheral rows already expose identity details, but provide no direct route from an attached device to its documentation.

## What Changes

- Restructure both the general `peripheral` discovery API and every shipped device-family reference into method-specific paragraphs, separated by multiple empty lines. Give aliases their own method entries; place method-specific arguments, results and caveats with the relevant method and retain shared guidance as clearly separate introductory notes.
- Preserve the current first-click peripheral selection and details. A subsequent click on the same selected peripheral on the same discovery wire opens its device-type topic in the existing Reference tab, without a double-click timing requirement.
- Ensure direct navigation reveals the intended topic even when a previous Reference search/category would hide it. Keep normal topic browsing, search, selectable text and native Copy.
- Make the select-then-open interaction discoverable in the peripheral guidance/tooltips, while preserving drafts, execution, device data and explicit red/green discovery.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `program-editor`: Require readable, method-isolated peripheral reference content and select-then-open contextual documentation navigation from computer peripheral rows.

## Impact

- Primary implementation targets: `scripts/ui/help.lua` (reference content, topic identifiers/type lookup), `scripts/ui/editor.lua` (selection, navigation, filter synchronization and guidance), and relevant editor locale entries.
- Extend `tests/editor_workspace.lua` and focused help/API coverage assertions; cross-check shipped method/alias coverage against service exports, `tests/api_inventory.lua`, existing companion Lua contracts and `docs/player/api/`.
- Verify the packaged GUI contract in the pinned engine and the actual native-client click, reading, copying and layout workflow. Mock GUI coverage alone is not visual acceptance.
- No new GUI framework, external documentation integration, guest API, dependency, save migration, runtime side effect, world interaction change or device-local inspector is introduced. The separate `add-peripheral-inspectors` proposal remains independent; this change targets rows inside the computer UI only.
- Clarification resolved: both discovery and device-specific APIs are in scope; first click selects, repeat click opens documentation. Multiple empty lines are the chosen native-text separator, avoiding a separate rich-text renderer.
