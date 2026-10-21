# Peripheral inspectors

Open a KV Database, Monitor, Logic Handler, Configurator or Recipe Searcher
normally to inspect it locally. You do not need a computer connection or running
program. These are read-only windows, not the underlying combinator's controls.
The localized device title, peripheral type, exact API name and availability
appear above the scrollable details. Drag the title bar to move the window.
Close or Escape retires it without discarding computer drafts.

Every inspector shows its structure immediately, before expensive queries are
admitted. Pending is distinct from an empty successful result. Refresh failures
retain any previous complete details with an explicit stale/error status; monitor
names cannot be copied while their logical identity is unresolved. Configurator
counts remain complete, deduplicated snapshots, not partial per-wire totals.
Long explanations are available in tooltips and Reference rather than repeated
above the data. An older saved window may close once after the 0.1.12 upgrade;
reopen it without losing device data or computer drafts.

Computers keep their [workspace](editor.md): Ctrl-click with an empty cursor.
Ctrl-click a monitor to deliver a touch instead of opening an inspector.
Native inventory transfers and normal rotation are unchanged. Private role pads
have no inspector or editable native dialog. Unrelated vanilla dialogs remain
native dialogs.

## Copy an exact peripheral name

Choose **Select name**, then use native Copy (normally Ctrl+C).
Paste into your computer draft or another text field. The selection is only the
API identifier: no quotes, wire suffix, labels or trailing whitespace. Selecting
does not itself write the OS clipboard. The name box cannot rename the device.
Monitor names identify logical displays, not individual physical tiles, and can
change after a split or merge. Regrouping is shown as pending rather than offering
an obsolete name as current.

## KV Database: complete, byte-safe snapshots

Choose a key in the paged list. Every live key and its type are included in a
successful snapshot. String values have a full detail viewer; hashes additionally
have a paged field list and complete selected-field details. Page controls make
the last key and last hash field reachable. List previews are shortened; they
are not a substitute for the complete key/field/value details below.

Values are divided into chunks of at most 512 original bytes. Use the value's
Previous/Next controls to reach every chunk, including long binary values.
Each chunk is independently quoted. Concatenate decoded chunk contents, not the
surrounding quotes, to recover the original value.

The display is a reversible, ASCII-only representation:

- Empty bytes are `""`, distinct from a missing key/field.
- Quote is `\"`; backslash is `\\`.
- Control bytes, bytes 127–255 and square brackets use `\xHH` with exactly two
  uppercase hexadecimal digits. For example NUL is `\x00`, byte 255 is `\xFF`,
  `[` is `\x5B` and `]` is `\x5D`.
- Other printable ASCII bytes are literal. The high bytes of UTF-8 are escaped
  individually too; this representation preserves bytes rather than guessing an
  encoding. Stored rich-text-looking data is never rendered as markup.

Open inspectors update automatically under bounded admission, without Refresh or
numeric tick displays. Unchanged rows/text stay mounted. A fresh snapshot excludes entries at
or after their expiry deadline even when reclamation has not yet removed them.
Selections still present are retained. A disappeared key/field is identified as
no longer present, not silently replaced. Unsupported or corrupt representations
report unavailable without being repaired or replaced. Browsing never sets,
deletes, imports, renews expiry or purges retained data.

## Configurator: target-side inventory

This panel groups reachable target-side entities by their exact prototype, with
localized name/icon, exact prototype name and native entity type. It includes
ordinary relays and connected devices without writable settings. It does not
list the computer-discovery network instead of the target network.

Unique counts deduplicate all paths and both target wire colors. Red and Green
are overlapping memberships: one device connected to both contributes one to
each color and one to Unique. Do not add the two color columns to get a total.
Owned helper sockets and the origin are not extra devices. A successful snapshot
includes both color traversals; a failed traversal is pending/error, never a
plausible partial total. Groups are sorted and paged. Automatic polling observes wiring
changes without reading full configuration schemas or changing machine settings.

## Logic Handler: inputs and its own output

One Input signals region shows both wire groups, with distinct native red and
green slot backgrounds and text labels. The same identity on both wires remains
two slots with separate values. Adjacent Output signals shows this handler's own
bank shared across its two output colors, not the total from other emitters.
The decider-style recessed signal trays appear immediately, including while an
input query is waiting. The regions scroll/reflow at narrower sizes. No slot is
a signal picker or editor; decider conditions and output rules are not added.

Tooltips retain exact signed counts, signal type/name and quality. Recipe signals
use recipe icons, not same-named item icons. Disconnected, connected-empty,
unavailable and over-limit observations have different states. The panel attempts
one input color every 15 ticks when shared host work is admitted, alternating
Red and Green. Each input is published independently;
these are not an atomic circuit snapshot. A deferred or over-limit input shows
its own pending/error state and retains any older sample as explicitly stale.
It cannot block the other wire or the handler's own output bank. Disconnected
inputs do not require a native signal-list query. The own bank is an independent
observation too. Unchanged slots and their scrolling survive polling.
The panel does not capture every pulse between samples. It creates no program
subscription, writer or output publication.
Existing power/writer cleanup remains responsible for fail-safe output removal.

## Monitor: logical tiles and character cells

Open any reachable member, including a non-anchor tile. The inspector follows
that physical tile's current committed logical group. It reports local tile
width × height, total tiles, terminal columns × rows and text scale. Columns and
rows are character cells, not pixels. Rotating a nonsquare display does not
substitute world-space bounding dimensions for its local axes.

Scale changes and committed split/merge identity changes are observed together.
Pending regrouping has no copyable current identity. Replacing the selected tile
does not retarget the old session to a new entity at the same position. Inspection
does not change the saved model, framebuffer or world presentation.

## Recipe Searcher, power and access

Recipe Searcher deliberately ends at identity/status; recipe searches remain
computer API calls, not a dedicated search interface.

Identity stays readable without power. Committed monitor geometry is also
readable while its display is blank. Unpowered KV contents, target inventories
and live logic inputs are unavailable rather than fabricated empty results.

Every interaction rechecks the exact device, force, surface, reach and player
permissions. Losing access closes the window or removes details on the next
check. Independent viewers have independent selections. Removed/replaced devices,
stale events and incompatible saved UI sessions cannot acquire new access.
Save/load runs no inspector code during load; gameplay revalidates retained UI.

Automatic observations coalesce without a request queue. Query, sorting,
escaping and GUI work use the shared non-render maintenance budget. Under load,
an update may remain pending and a previous snapshot is explicitly stale; this is
not an empty successful read. Closing the window stops inspector detail polling.
Unchanged data does not rebuild the detail widgets or steal copy selection.
