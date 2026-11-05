# Dashboard

A Dashboard is an electricity-free 1×1 control panel with up to six shared tabs. Its
physical identity and data belong to the device, not to the last computer that
wrote to it. This feature is unreleased. Its complete acceptance is still in
progress. The dependency evidence below does not replace native or peer gates.

<a id="construction-power-and-identity"></a>

## Construction and identity

Dashboard uses the existing computer research. Its provisional recipe consumes
**4 iron plates, 2 copper plates and 5 electronic circuits**. Its Network-role
body needs no electricity or electrical helper. Connect a computer's Network port with
red or green circuit wire. Rotation preserves the logical device and contacts.

One physical Dashboard has one API identity, shown as selectable, read-only text
in its window. Normal opening shows interactive tabs rather than the read-only
peripheral inspector. Each viewer chooses a tab and scroll position independently.
Controls and content remain shared. Close the window with **Close** or **Escape**.
Only open, authorized viewers participate in refresh. Stable tab definitions keep
their widgets, selection and scroll position. Shared content changes, tab switches
and resizing request a paid update. Only the selected tab's visible chart nodes
request presentation. Unchanged charts keep their image. Pending render work
keeps the existing rotating fairness between visible charts and viewers.

Mining yields one tagged Dashboard item, not separate helper-entity drops. Item
placement creates a new identity. Retained content transfers through the supported
item lifecycle. Blueprints and settings copies describe configuration.
Do not downgrade a populated save to a mod version without Dashboard prototypes.

## Programming the base controls

Use a dot-called wrapper from `peripheral.find('dashboard', 'red')` (or green).
Slots are integers **1–6**. Empty rows and columns and zero configured tabs are valid.
Each tab has `{title=string, content=Node}`. Nodes are named `row`, `column`,
`label` or `button` records. IDs are unique within the tab, including containers.
Rows and columns have dense `children` arrays. Labels have `text`. Buttons also have
an optional boolean `enabled` (default true). Text is literal, not rich text.

| Method | Result |
| --- | --- |
| `setTab(slot, definition)` | No values. Replaces one complete tab atomically. |
| `getTab(slot)` | One defensive definition, or one nil for an unused slot |
| `removeTab(slot)` | One boolean indicating whether the tab existed |
| `setText(slot, id, text)` | No values. Updates one label/button. |
| `setEnabled(slot, id, enabled)` | No values. Updates one button. |
| `getLimits()` | One defensive map of effective limits |
| `subscribe(handler_name)` | One saved-run subscription ID |
| `unsubscribe(subscription_id)` | One boolean. Also cancels matching queued clicks. |

Both wires and every writer share the device's existing `state_bytes` allowance,
including all tabs and reserved chart history. Invalid definitions, wrong argument
counts/types and capacity refusals leave accepted state intact. Lowering the
allowance does not erase accepted content. Reads, removal and non-growing changes
remain available. The separate existing Data/call envelopes still apply.
`getTab` does not expose history, subscriptions, GUI objects or rendering handles.

## Optional charts

The integration targets the unmodified **factorio-charts 1.2.0** release for
Factorio **2.1.23**, with base alone or Space Age. Labels and buttons will not
require this optional library. Supported charts are rolling lines and the
library's duration-stacked bars. Bar values are **seconds**, not arbitrary
numeric/category values. There is no custom renderer, library fork or claim of
Factorio production-widget parity.

Release ZIP SHA-256:
`32b1683912281812c122d6b414d15ab553e943138ceb2b27fe52a38ee6512815`.
Its Lua/API files, MIT license, README and thumbnail are byte-identical to
inspected commit `ff7f6bd06a4532c8cd2bfbf0a4bd464916dbb62a`.
The manifest differs only in line endings. The published changelog differs in
its release date/text and documents the 2.1 light change. Published bytes are
used unchanged, not rebuilt from that tag.

## Dependency verification

`tools/smoke.py --chart-archive /absolute/factorio-charts_1.2.0.zip` installs and
explicitly enables this exact library version only for that isolated run.
Omit the option for library-absent tests. The harness records its SHA-256 in
`summary.json`. It does not download the dependency or use a player mod folder.

`tests.dashboard_dependency_engine` runs in the production mod context on real
ticks. With the library, it creates a private surface and chunk. It checks fitting
camera parameters at three sizes and wraps one rolling interval. It invokes the
unchanged line and duration-bar renderers. It verifies stationary zero-TTL objects
across a separate-process reload. Then it destroys objects and lights, reuses the
chunk and deletes the private surface. Without the library, it never imports
it. This is headless native API evidence, **not** native-window appearance,
Dashboard controls, lifecycle or multiplayer acceptance.
