# Design

## Context

See `proposal.md` for motivation and `specs/program-editor/spec.md` for the behavior contract.

Observed implementation:

- `scripts/ui/help.lua` owns one plain-text reference, derives `topics` by section headings, and exposes category names. Peripheral-family methods are currently compressed into lines; the existing six Peripherals topics cover discovery plus `logic_handler`, `kv_database`, `monitor`, `recipe_searcher` and `configurator`.
- `scripts/ui/editor.lua:118` filters topics by numeric category and search; a hidden selection falls back to the first matching topic. A direct link that changes only the selected topic can therefore show unrelated text.
- Peripheral rows are current GUI buttons built from a bounded inventory snapshot. `peripheral_details` uses `s.peripheral` as the selected name. The click handler currently selects that name and renders details. Wire changes refresh inventory but do not record a separate selected wire.
- `activate_tab` already provides explicit tab navigation. The `owned` event path checks session/widget identity and the visible active subtree. These protections must remain in place.
- `tests/editor_workspace.lua` exercises the packaged editor with mocked GUI objects, real discovery/wires and dirty-draft assertions. It checks that combined topic text equals the complete help text, and that searching, categories and native select-for-copy remain available. It explicitly does not establish native rendering, focus or clipboard acceptance.
- `info.json` pins base and optional Space Age to 2.0.77. The separate proposed peripheral inspectors do not exist in this observed UI and are not a prerequisite.

## Goals / Non-Goals

Goals:

- Reuse the native selectable reference text and current tab/event structure.
- Make repeat-click behavior identity-based, deterministic and independent of click timing.
- Keep method documentation and topic routing owned by the help module, not a second UI-side topic catalogue.
- Prove method/alias coverage and preservation of the existing full-reference/category contract.

Non-goals:

- No replacement GUI, rich-text renderer, external browser, documentation dependency, discovery graph or guest method execution for navigation.
- No restructuring of unrelated Computer/language APIs, web documentation redesign or device-local inspectors.
- No persistent click history, timers, program-data migrations or automatic activation.

## Decisions

### 1. Keep plain text and separate every method with two empty lines

Rewrite the discovery and five device sections in the existing help source. Each method paragraph starts with its exact method signature, then explains results and relevant caveats; each alias gets its own entry pointing to its equivalent. Overloads of a single method remain together. Use three newline characters between adjacent paragraphs to produce two empty lines. General topology, events, persistence and shared bounds stay in clearly identified shared notes, not mixed method lists.

Retain the existing full-text-to-topic derivation and section boundaries. Add focused assertions for each expected method/alias and paragraph separation, with coverage checked against actual exports and existing API inventory/companion references. Do not introduce a general documentation generator or duplicate the whole API in a new schema.

Alternative: individual native labels and horizontal-line elements. Rejected because the existing text box already provides readable, searchable, selectable plain text; multiple empty lines satisfy the requested spacer without a new rendering path.

### 2. Give device topics stable routing keys

Attach stable identifiers to relevant topic metadata and expose a help-owned peripheral-type lookup. Resolve the topic from exact inventory type (`kv_database`, for example), not display labels, topic order or text search. Keep normal topic list behavior and the complete help string intact; no additional user-visible topics are required.

Alternative: hardcoded numeric topic positions in the click handler. Rejected because ordering and newly added topics would silently break routing. Unknown types return no mapping and produce a clear message while retaining the details view.

### 3. Treat a repeat click as selection equality, not a timed gesture

Maintain the existing selected-name/details behavior and add the discovery wire to selection identity. When a current row button is clicked:

1. Read the item from the current inventory only after existing ownership and exact-widget checks.
2. If its `(name, wire)` does not match the active selection, select it and update details, staying in Peripherals.
3. If it matches, resolve its type's topic and explicitly navigate to Reference; a missing mapping reports unavailable instead.

Changing wire invalidates the active repeat-click selection, even if a name is reachable on both colors. During refresh, preserve it only if a successful same-wire inventory still contains the selected identity. Row reordering is irrelevant. Pending/error inventories or disappearance invalidate the repeat-click state. Existing last-known details can continue to explain disconnection without arming navigation for a returning device. No clock/deadline state is needed. A new editor session begins with no active row selection.

Update row/tooltips and selected details to explain “Click to select; click the selected peripheral again for documentation.” Prefer existing locale conventions for new UI guidance.

Alternative: a timed double-click handler. Rejected because the user requested first-click selection followed by a second click, not a timing-sensitive gesture; ordinary GUI click delivery is enough.

### 4. Make direct navigation an explicit filter transition

Resolve the target first. For a valid target, clear the Reference search, choose the existing Peripherals category, synchronize visible widgets with session state, select the resolved topic, then use existing tab activation/refresh. Ensure the new topic is readable from its beginning using the supported native text-box scrolling path, verified in the actual client. Preserve the draft source widget and every execution/data state.

This is user-requested navigation, not a background refresh; the prohibition on unsolicited tab changes remains unchanged. Retain all stale/foreign/hidden-widget rejection rules. Documentation is static by type: an inventory snapshot and unpowered rows may open help without live service calls or a new discovery refresh.

Alternative: retain obstructing filters or open a second help window. Rejected because the former can hide the target and the latter duplicates established Reference navigation.

## Risks / Trade-offs

- [Longer documentation requires scrolling] → Keep headings/search and selectable text, put caveats next to the relevant method, and visually check representative long Monitor/Configurator topics at supported display scales.
- [Formatting loses a method, alias or existing caveat] → Check exact public method inventory, retain shared semantics/examples, and keep the concatenated-topic completeness test.
- [Old filter state selects an unrelated first result] → Synchronize category/search widgets and session state before resolving selection in the filtered list; cover no-match and conflicting-category cases.
- [Selected name leaks across wire changes or refreshed row indices] → Track `(name, wire)` explicitly and invalidate repeat-click selection on wire change, missing results or unavailable inventory; test same-name dual-color discovery and stale widgets.
- [Mock GUI tests miss blank-line rendering, scrolling or copy behavior] → Require full-client evidence separately from headless contracts; do not label a successful mocked fixture as visual acceptance.
- [Concurrent proposals add peripheral families] → Cover every family actually shipped at implementation time; coordinate any merged new types through the same help-owned lookup rather than depending on unimplemented proposals.

## Migration Plan

No world/program-data migration is needed: the text and ephemeral editor navigation behavior change only. Keep first-click identity details and normal Reference browsing compatible. Existing sessions lacking the new selection field behave as unselected until a fresh row click. Package and run focused regressions before native-client acceptance in isolated base/Space Age environments. Rollback consists of reverting only this change's UI/help/test edits; no stored device data requires repair. Release/publication and implementation are outside this planning workflow.
