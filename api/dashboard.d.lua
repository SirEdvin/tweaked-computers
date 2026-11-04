---@meta

---Dashboard facade with base controls, and chart methods only when compatible
---factorio-charts is active. Narrow by the actual method inventory; missing methods
---are absent, not stubs. Retained definitions may still contain charts without it.
---@alias TC.Dashboard TC.DashboardBase|TC.ChartDashboard

---Recursive declarative layout. Every node ID is a nonempty exact bounded string,
---unique across the whole tab, including containers; another tab may reuse it.
---Unknown fields fail. Text is literal, never LocalisedString or Factorio rich text.
---@alias TC.DashboardNode TC.DashboardRow|TC.DashboardColumn|TC.DashboardLabel|TC.DashboardButton|TC.DashboardLine|TC.DashboardBars

---Horizontal native layout. Empty children are allowed; dense order is display order.
---@class TC.DashboardRow
---@field type 'row' Horizontal-container discriminator.
---@field id string Nonempty tab-unique ID within identifier_bytes.
---@field children TC.DashboardNode[] Dense ordered children, possibly empty.

---Vertical native layout, using host spacing and a bounded scroll area.
---@class TC.DashboardColumn
---@field type 'column' Vertical-container discriminator.
---@field id string Nonempty tab-unique ID within identifier_bytes.
---@field children TC.DashboardNode[] Dense ordered children, possibly empty.

---Wrapping literal text label, with no interpreted markup or arbitrary styles.
---@class TC.DashboardLabel
---@field type 'label' Label discriminator.
---@field id string Nonempty tab-unique ID within identifier_bytes.
---@field text string Literal bounded text; empty is valid.

---Native left-click button; it produces events only for explicit subscriptions.
---@class TC.DashboardButton
---@field type 'button' Button discriminator.
---@field id string Nonempty tab-unique ID within identifier_bytes.
---@field text string Nonempty literal bounded caption.
---@field enabled? boolean Omitted/nil defaults true; false prevents activation/delivery.

---Rolling chart in the unchanged library viewport. Requires compatible
---factorio-charts when publishing a new definition. X means sample order, not
---timestamps/irregular-time interpolation. Empty/one-sample data may show no line.
---The renderer determines series order from its sums; configured name order is
---not a promise of stable series colors as values change.
---@class TC.DashboardLine
---@field type 'line' Rolling-line discriminator.
---@field id string Nonempty tab-unique ID within identifier_bytes.
---@field series string[] Nonempty dense unique names; at most chart_line_series.
---@field capacity integer Required sample capacity at least 2; reserve full fixed shape on definition.
---@field format? 'number'|'percent'|'time'|false Omitted/nil or the existing false compatibility case defaults number; percent values already use percent units, time uses seconds.

---Latest duration dataset, not historical arbitrary numeric/category bars.
---Phase order is bottom-to-top stack order; use surrounding labels to explain bars.
---@class TC.DashboardBars
---@field type 'stacked_bars' Duration-bar discriminator; library required for new definitions.
---@field id string Nonempty tab-unique ID within identifier_bytes.
---@field phases string[] Nonempty dense unique phase names within identifier_bytes.

---Complete tab definition; no implicit partial layout merge. Explicit nil for an
---optional node field means omission/default. No text entry, images, fonts, style
---names, drawing coordinates, chart-click callbacks or guest formatters are exposed.
---@class TC.TabDefinition
---@field title string Nonempty literal bounded tab caption.
---@field content TC.DashboardNode Root of the tab-unique declarative node tree.

---One full chart vector. Keys must match exactly the configured series/phases;
---unknown/missing keys fail. Line values are finite; bar durations additionally
---must be nonnegative seconds. Derived sums/ranges/padding must remain finite.
---@alias TC.ChartValues table<string, number>

---Shared physical Dashboard. Its six numbered slots are ordered by occupied slot;
---empty slots produce no button. Zero configured tabs is valid. Players choose the
---visible tab, not API calls. Removing a viewer's selected tab picks the lowest
---remaining slot or unconfigured screen, without changing other valid selections.
---All writers/wires share retained layout, control text and chart state. No power
---is required; every call retains live identity/scope/path checks.
---
---### Atomicity and capacity
---Validate the complete candidate, retained final model and return admission before
---publication. The shared dashboard_state_bytes allowance includes layout/control
---text, bar dataset, full line capacity/running totals and model metadata. This is
---accounted storage, not calibrated native heap; ordinary Data/work/queue limits
---remain. Lower limits retain accepted data and permit reads/removal/non-growth,
---not truncation. Native rendering has separate host-owned lifetime/admission.
---Visible collecting, pending and error states distinguish absent samples from
---deferred/refused rendering. A render that cannot fit a fresh budget remains
---visibly refused; reopening does not authorize oversized work or reset budgets.
---Wrong arity/shape/fields/kind/duplicate IDs are E_ARGUMENT; invalid slot/capacity/
---format/nonfinite values or renderer domain E_RANGE; missing addressed widget/tab
---E_NOT_FOUND except getTab/removeTab absences. Unsupported charts/schema are
---E_UNSUPPORTED, retained capacity E_CAPACITY, transport envelope E_LIMIT. Fatal
---guest budget remains E_BUDGET. Error wording/precedence after admission is not API.
---
---### Lifetime and optional dependency
---Ordinary reload preserves model, chart order/reservations and legitimate queued
---deliveries without startup replay. Closing windows/stopping producers does not
---clear content. Mining carries versioned definitions/history/latest bars but new
---placement has a new identity and no subscriptions/viewers/render handles. Invalid
---saved schema is retained for recovery. Blueprints/clones/settings copy transfer
---definitions only, never another device's sample history; existing targets keep
---only their own compatible history. Dependency removal preserves model/data and
---releases presentation; reinstall reconstructs it, never reruns the producer.
---Absent chart methods disappear from getMethods/new facades. Stale captured chart
---methods fail safely. New chart-containing definitions are refused without the
---library, but retained charts can be inspected/removed and base controls updated.
---@class TC.DashboardBase
local Dashboard = {}

---Atomically replace one complete slot. Compatible chart data survives when ID,
---kind and ordered series+capacity (line) or phases (bars) remain identical. Title,
---text, layout location and line format changes do not reset compatible data.
---Changed/removed data definitions discard only that chart's prior data. Repeating
---the same normalized definition is idempotent; structural replacement invalidates
---old button targets and queued tab clicks. Returns zero values.
---@param slot integer Numbered slot 1..6, independent of current visible tab order.
---@param definition TC.TabDefinition Complete validated tab/layout definition.
function Dashboard.setTab(slot, definition) end

---Read independent configuration/current control text, NOT chart samples/history
---or private rendering state. Retained charts remain inspectable without library.
---@param slot integer Numbered slot 1..6.
---@return TC.TabDefinition|nil definition One snapshot or one nil for an unused slot.
function Dashboard.getTab(slot) end

---Remove one complete slot, its chart data and obsolete click targets.
---@param slot integer Numbered slot 1..6.
---@return boolean removed True if a tab existed; false for an unused valid slot.
function Dashboard.removeTab(slot) end

---Replace label/button text without changing layout identity or chart history.
---Missing target is E_NOT_FOUND; wrong widget kind E_ARGUMENT. Zero results.
---@param slot integer Existing numbered tab slot 1..6.
---@param id string Existing label/button ID, exact bounded nonempty string.
---@param text string New literal text; label may be empty, button must be nonempty.
function Dashboard.setText(slot, id, text) end

---Set a button's enabled state without structural replacement. Enabled state is
---rechecked for queued delivery. Missing/wrong-kind targets fail. Zero results.
---@param slot integer Existing numbered tab slot 1..6.
---@param id string Existing button ID.
---@param enabled boolean Required exact boolean; no truthiness conversion.
function Dashboard.setEnabled(slot, id, enabled) end

---Subscribe this saved run to every button on this exact Dashboard/wire. Each
---call creates a distinct registration; explicitly registering both colors can
---intentionally deliver twice. Merely writing/viewing does not subscribe. All
---eligible subscribers receive clicks, not just the last writer. Console and
---undeclared handler names are refused. See TC.DashboardClick for revalidation.
---@param handler_name TC.HandlerName Declared export receiving scheduled clicks.
---@return TC.SubscriptionId id New exact run/device/wire registration.
function Dashboard.subscribe(handler_name) end

---Cancel an exact registration and matching queued deliveries. Another binding
---or run is invalid; Console cannot edit saved-program subscriptions.
---@param subscription_id TC.SubscriptionId Identity from this run/Dashboard/wire.
---@return boolean removed True if registered, false if already absent.
function Dashboard.unsubscribe(subscription_id) end

---Read common limits plus shared tab/model allowance. Renderer domain fields
---are present only with the chart library, not zero/unlimited placeholders.
---@return TC.DashboardLimits limits Independent effective map.
function Dashboard.getLimits() end

---Dashboard with optional compatible factorio-charts loaded. These extra methods
---are absent without it. They operate on admitted definitions, not arbitrary GUI
---elements/native library objects; all base methods and authority rules remain.
---@class TC.ChartDashboard: TC.DashboardBase
local ChartDashboard = {}

---Append one complete finite vector to all line series in lockstep. At capacity
---evict exactly the oldest vector. Missing/extra series or nonfinite derived
---arithmetic fail atomically without eviction or changing totals. No invented
---samples for closed windows, stopped programs or missed timers. Multiple writers
---follow accepted-call order. No timestamps/history-query API. Zero results.
---@param slot integer Existing numbered tab slot 1..6.
---@param id string Existing line-chart ID; a bar widget is invalid.
---@param values TC.ChartValues Exactly the configured series names with finite values.
function ChartDashboard.appendSample(slot, id, values) end

---Replace the entire latest duration dataset, not a history. Empty clears; zeros
---are valid. Every bar contains exactly configured phases, finite nonnegative
---seconds, with finite totals/padding. Preserve input bar order and native time
---axis/palette; do not interpret counts as seconds. Enforce renderer positive-width
---chart_bar_entries plus shared budgets. No partial replacement. Zero results.
---@param slot integer Existing numbered tab slot 1..6.
---@param id string Existing stacked-bar ID; a line widget is invalid.
---@param bars TC.ChartValues[] Dense ordered complete duration maps; empty clears.
function ChartDashboard.setBars(slot, id, bars) end

---Reset this chart's data/index/totals without removing its definition or reserved
---line capacity. No other chart changes. Returns zero values.
---@param slot integer Existing numbered tab slot 1..6.
---@param id string Existing line or stacked-bar widget ID.
function ChartDashboard.clearChart(slot, id) end
