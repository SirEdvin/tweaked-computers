---@meta

---This Dashboard facade has base controls. Chart methods are present only when
---compatible factorio-charts is active. Narrow the type by the actual method inventory.
---Missing methods are absent, not stubs.
---Retained definitions can still contain charts without the library.
---@alias TC.Dashboard TC.DashboardBase|TC.ChartDashboard

---This type defines a recursive declarative layout.
---Every node ID is a nonempty exact bounded string.
---The ID must be unique across the whole tab, including containers.
---Another tab can use the same ID. Unknown fields cause failure.
---Text is literal, never LocalisedString or Factorio rich text.
---@alias TC.DashboardNode TC.DashboardRow|TC.DashboardColumn|TC.DashboardLabel|TC.DashboardButton|TC.DashboardLine|TC.DashboardBars

---This node defines a horizontal native layout.
---The children array can be empty. Its dense order is the display order.
---@class TC.DashboardRow
---@field type 'row' Horizontal-container discriminator.
---@field id string Nonempty tab-unique ID within identifier_bytes.
---@field children TC.DashboardNode[] Dense ordered children, possibly empty.

---This node defines a vertical native layout with host spacing and a bounded scroll area.
---@class TC.DashboardColumn
---@field type 'column' Vertical-container discriminator.
---@field id string Nonempty tab-unique ID within identifier_bytes.
---@field children TC.DashboardNode[] Dense ordered children, possibly empty.

---This literal text label wraps. It has no interpreted markup or arbitrary styles.
---@class TC.DashboardLabel
---@field type 'label' Label discriminator.
---@field id string Nonempty tab-unique ID within identifier_bytes.
---@field text string Literal bounded text. An empty string is valid.

---This native left-click button produces events only for explicit subscriptions.
---@class TC.DashboardButton
---@field type 'button' Button discriminator.
---@field id string Nonempty tab-unique ID within identifier_bytes.
---@field text string Nonempty literal bounded caption.
---@field enabled? boolean Omission or nil defaults to true. False prevents activation and delivery.

---This rolling chart uses the unchanged library viewport.
---Publication of a new definition requires compatible factorio-charts.
---X means sample order, not timestamps or irregular-time interpolation.
---Empty data or one-sample data can show no line.
---The renderer determines series order from its sums.
---Configured name order does not guarantee stable series colors as values change.
---@class TC.DashboardLine
---@field type 'line' Rolling-line discriminator.
---@field id string Nonempty tab-unique ID within identifier_bytes.
---@field series string[] Nonempty dense array of unique names. The maximum count is chart_line_series.
---@field capacity integer Required sample capacity of at least 2. The definition reserves the full fixed shape.
---@field format? 'number'|'percent'|'time'|false Omission, nil or the existing false compatibility case defaults to number. Percent values already use percent units. Time uses seconds.

---This node shows the latest duration dataset, not historical arbitrary numeric/category bars.
---Phase order is bottom-to-top stack order. Use surrounding labels to explain the bars.
---@class TC.DashboardBars
---@field type 'stacked_bars' Duration-bar discriminator. New definitions require the library.
---@field id string Nonempty tab-unique ID within identifier_bytes.
---@field phases string[] Nonempty dense unique phase names within identifier_bytes.

---This record defines a complete tab. There is no implicit partial layout merge.
---Explicit nil for an optional node field means omission/default.
---The API exposes no text entry, images, fonts, style names, drawing coordinates,
---chart-click callbacks or guest formatters.
---@class TC.TabDefinition
---@field title string Nonempty literal bounded tab caption.
---@field content TC.DashboardNode Root of the tab-unique declarative node tree.

---This map gives one full chart vector.
---Keys must match the configured series or phases exactly.
---Unknown or missing keys cause failure. Line values must be finite.
---Bar durations must also be nonnegative seconds.
---Derived sums, ranges and padding must remain finite.
---@alias TC.ChartValues table<string, number>

---This facade controls a shared physical Dashboard.
---Its six numbered slots appear in occupied-slot order. Empty slots produce no button.
---Zero configured tabs is valid. Players choose the visible tab, not API calls.
---
---If a viewer's selected tab is removed, the Dashboard selects the lowest remaining slot
---or the unconfigured screen. Other valid selections do not change.
---All writers and wires share retained layout, control text and chart state.
---The Dashboard requires no power. Every call retains live identity, scope and path checks.
---
---### Atomicity and capacity
---Before publication, the API validates the complete candidate, retained final
---model and return admission. The shared dashboard_state_bytes allowance includes
---layout/control text, bar dataset, full line capacity, running totals and model metadata.
---This allowance measures accounted storage, not calibrated native heap.
---Ordinary Data, work and queue limits remain.
---Lower limits retain accepted data and permit reads, removal and non-growth,
---not truncation. Native rendering has separate host-owned lifetime and admission.
---
---Visible collecting, pending and error states distinguish absent samples from
---deferred or refused rendering. A render that cannot fit a fresh budget remains
---visibly refused. A reopened view does not authorize oversized work or reset budgets.
---
---Incorrect arity, shape, fields or kind, and duplicate IDs cause E_ARGUMENT.
---Invalid slot, capacity or format, nonfinite values or an invalid renderer domain cause E_RANGE.
---A missing addressed widget or tab causes E_NOT_FOUND, except for getTab/removeTab absences.
---Unsupported charts or schema cause E_UNSUPPORTED.
---Retained capacity refusal causes E_CAPACITY. Transport envelope refusal causes E_LIMIT.
---
---Fatal host-work exhaustion remains E_BUDGET. Pure Lua execution has no mod quota.
---Error wording and precedence after admission are not API contracts.
---
---### Lifetime and optional dependency
---Ordinary reload preserves the model, chart order/reservations and legitimate
---queued deliveries without startup replay. Closed windows and stopped producers
---do not clear content. Mining carries versioned definitions, history and latest bars.
---New placement has a new identity and no subscriptions, viewers or render handles.
---The Dashboard retains invalid saved schema for recovery.
---
---Blueprints, clones and settings copy transfer only definitions, never another device's sample history.
---Existing targets keep only their own compatible history.
---Dependency removal preserves the model and data, and releases presentation.
---Reinstallation reconstructs presentation. It never runs the producer again.
---
---Absent chart methods disappear from getMethods and new facades.
---Stale captured chart methods fail safely.
---The API refuses new definitions that contain charts without the library.
---Without the library, you can still inspect or remove retained charts and update base controls.
---@class TC.DashboardBase
local Dashboard = {}

---Atomically replace one complete slot.
---Compatible chart data survives when ID and kind remain identical.
---Ordered series and capacity must also remain identical for a line chart.
---Phases must remain identical for bars.
---Title, text, layout location and line format changes do not reset compatible data.
---
---Changed or removed data definitions discard only that chart's prior data.
---Repeated application of the same normalized definition is idempotent.
---Structural replacement invalidates old button targets and queued tab clicks.
---This method returns zero values.
---@param slot integer Numbered slot 1..6, independent of current visible tab order.
---@param definition TC.TabDefinition Complete validated tab/layout definition.
function Dashboard.setTab(slot, definition) end

---Read independent configuration and current control text.
---The result excludes chart samples, chart history and private rendering state.
---You can inspect retained charts without the library.
---@param slot integer Numbered slot 1..6.
---@return TC.TabDefinition|nil definition One snapshot or one nil for an unused slot.
function Dashboard.getTab(slot) end

---Remove one complete slot, its chart data and obsolete click targets.
---@param slot integer Numbered slot 1..6.
---@return boolean removed True if a tab existed; false for an unused valid slot.
function Dashboard.removeTab(slot) end

---Replace label/button text without changing layout identity or chart history.
---A missing target causes E_NOT_FOUND. An incorrect widget kind causes E_ARGUMENT.
---This method returns zero results.
---@param slot integer Existing numbered tab slot 1..6.
---@param id string Existing label/button ID, exact bounded nonempty string.
---@param text string New literal text. A label can be empty, but a button must be nonempty.
function Dashboard.setText(slot, id, text) end

---Set a button's enabled state without structural replacement.
---The host checks the enabled state again for queued delivery.
---Missing targets or targets of the wrong kind cause failure.
---This method returns zero results.
---@param slot integer Existing numbered tab slot 1..6.
---@param id string Existing button ID.
---@param enabled boolean Required exact boolean; no truthiness conversion.
function Dashboard.setEnabled(slot, id, enabled) end

---Subscribe this saved run to every button on this exact Dashboard/wire.
---Each call creates a distinct registration.
---Explicit registration on both colors can intentionally deliver twice.
---Writes or views alone do not create subscriptions.
---All eligible subscribers receive clicks, not only the last writer.
---
---The method refuses Console calls and undeclared handler names.
---See TC.DashboardClick for revalidation.
---@param handler_name TC.HandlerName Declared export receiving scheduled clicks.
---@return TC.SubscriptionId id New exact run/device/wire registration.
function Dashboard.subscribe(handler_name) end

---Cancel an exact registration and matching queued deliveries.
---Another binding or run is invalid.
---Console cannot change saved-program subscriptions.
---@param subscription_id TC.SubscriptionId Identity from this run/Dashboard/wire.
---@return boolean removed True if registered, false if already absent.
function Dashboard.unsubscribe(subscription_id) end

---Read common limits plus the shared tab/model allowance.
---Renderer domain fields are present only with the chart library.
---The API does not supply zero or unlimited placeholders.
---@return TC.DashboardLimits limits Independent effective map.
function Dashboard.getLimits() end

---This Dashboard has the optional compatible factorio-charts library loaded.
---These extra methods are absent without the library.
---They operate on admitted definitions, not arbitrary GUI elements or native library objects.
---All base methods and authority rules remain.
---@class TC.ChartDashboard: TC.DashboardBase
local ChartDashboard = {}

---Append one complete finite vector to all line series in lockstep.
---At capacity, the method evicts exactly the oldest vector.
---Missing series, extra series or nonfinite derived arithmetic cause atomic failure.
---Failure does not evict data or change totals.
---
---The method does not invent samples for closed windows, stopped programs or missed timers.
---Multiple writers use accepted-call order.
---The API provides no timestamps or history queries.
---This method returns zero results.
---@param slot integer Existing numbered tab slot 1..6.
---@param id string Existing line-chart ID; a bar widget is invalid.
---@param values TC.ChartValues Exactly the configured series names with finite values.
function ChartDashboard.appendSample(slot, id, values) end

---Replace the entire latest duration dataset, not a history.
---An empty dataset clears the bars. Zeros are valid.
---Every bar contains exactly the configured phases, with finite nonnegative seconds.
---Totals and padding must be finite.
---
---The method preserves input bar order and the native time axis and palette.
---Do not interpret counts as seconds.
---The renderer's positive-width chart_bar_entries limit and shared budgets apply.
---The method does not make partial replacements. It returns zero results.
---@param slot integer Existing numbered tab slot 1..6.
---@param id string Existing stacked-bar ID; a line widget is invalid.
---@param bars TC.ChartValues[] Dense ordered complete duration maps. An empty array clears the bars.
function ChartDashboard.setBars(slot, id, bars) end

---Reset this chart's data, index and totals without removing its definition or reserved line capacity.
---No other chart changes. This method returns zero values.
---@param slot integer Existing numbered tab slot 1..6.
---@param id string Existing line or stacked-bar widget ID.
function ChartDashboard.clearChart(slot, id) end
