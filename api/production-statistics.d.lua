---@meta

---Statistics namespace. Pollution is surface-wide; item/fluid are surface+force.
---@alias TC.StatisticsKind 'item'|'fluid'|'pollution'

---Required symbolic native precision, never a guessed integer enum. Histories
---always have 300 samples; nominal spacing is window duration/300, but no absolute
---bucket timestamps are fabricated from the query tick.
---@alias TC.StatisticsWindow
---| 'five_seconds' # Five simulation seconds.
---| 'one_minute' # One simulation minute.
---| 'ten_minutes' # Ten simulation minutes.
---| 'one_hour' # One simulation hour.
---| 'ten_hours' # Ten simulation hours.
---| 'fifty_hours' # Fifty simulation hours.
---| 'two_hundred_fifty_hours' # Two hundred fifty simulation hours.
---| 'one_thousand_hours' # One thousand simulation hours.

---Native per-name finite numeric map. Missing opposite-side entries are not filled
---with zero. Preserve recorded zeros/empty maps and native numeric precision; no
---alphabetical/traversal or arbitrary-precision integer promise.
---@alias TC.StatisticsCounts table<string, number>

---Item inventory nested by exact quality name, then exact item name. All recorded
---qualities remain separate, including native empty quality maps.
---@alias TC.QualityStatisticsCounts table<string, TC.StatisticsCounts>

---Item totals/rates shape. Totals leaves are produced/consumed item counts since
---the native applicable reset, not lifetime guarantees or sums of stored samples.
---Rates leaves are native per-game-minute averages for the caller's window. The
---native cumulative count map still selects keys whose current-window rate is zero.
---@class TC.ItemStatisticsSnapshot
---@field tick TC.Tick Query read tick, not newest bucket end timestamp.
---@field input TC.QualityStatisticsCounts Produced item counts or per-minute rates by quality/name.
---@field output TC.QualityStatisticsCounts Consumed item counts or per-minute rates by quality/name.

---Fluid/pollution totals/rates shape. Fluid input/output means produced/consumed
---native fluid units; pollution input/output means emitted/absorbed pollutant units.
---Totals are cumulative since native reset; rates are per game minute. Never net
---the directions, round fractions, smooth, infer recipe throughput or merge names.
---@class TC.FlatStatisticsSnapshot
---@field tick TC.Tick Query read tick, not a bucket end timestamp.
---@field input TC.StatisticsCounts Produced fluid or emitted pollution counts/rates.
---@field output TC.StatisticsCounts Consumed fluid or absorbed pollution counts/rates.

---Exactly the item quality-nested shape for kind=item, otherwise flat name maps.
---Required input/output may be empty; kind/window are not repeated in the result.
---@alias TC.StatisticsSnapshot TC.ItemStatisticsSnapshot|TC.FlatStatisticsSnapshot

---Two dense 300-value arrays from native get_flow_count(sample_index, count=false).
---Index 1 is newest, index 300 oldest. Values are finite per-game-minute rates;
---preserve native zero/short-history behavior. No trimming, reversing, interpolation,
---GUI smoothing, timestamp synthesis or cross-quality aggregation. History can
---predate the physical peripheral; no guest collector startup is needed.
---@class TC.HistorySnapshot
---@field tick TC.Tick Synchronized query tick, not an absolute sample timestamp.
---@field input number[] Exactly 300 finite production/emission rates, newest first.
---@field output number[] Exactly 300 finite consumption/absorption rates, newest first.

---Research Recipe Searcher and wire this device's NETWORK on red or green.
---Read-only native statistics on this device's current surface. Item/fluid use its
---current force; pollution intentionally includes the whole surface, not just that
---force. Pollution statistics are source/sink flows, not airborne concentration or
---a map. No arbitrary force/surface selector, reset/write, cursor, top-N cutoff,
---all-history query, event subscription, sort option or private collector exists.
---
---Each call resolves fresh native scope/data. Native timing is preserved: current
---tick flows may not yet have merged; never add them manually. API history is raw,
---not the native GUI's sliding-window smoothing. Snapshots are detached and can
---only be retained under independent state/KV capacity. No statistics handles or
---caches persist. Mine/clone/new placement never resets or duplicates native data;
---load retains identity/wires but does not replay source or query statistics.
---
---This custom device needs no electricity. Every method rechecks exact identity,
---scope and explicit-color reachability; Console captures never bypass them.
---Complete native inventories (including modded names/qualities) may still exceed
---generic Data/work/allocation limits. No circuit-only transport exception, quota
---increase, partial-success record or retry credit renewal is implied.
---
---### Errors
---Wrong arity/types/empty identity or non-item quality: E_ARGUMENT. Unknown kind,
---window, identity or quality: E_RANGE. Complete result/argument bounds: E_LIMIT.
---Unsupported/nonfinite native data: E_UNSUPPORTED. Native failure: E_ENGINE, not
---fabricated zeros. Physical failures preserve E_UNREACHABLE/E_NETWORK_PENDING/
---E_LIMIT; exhausted work/allocation remains fatal E_BUDGET. Current authority and
---input admission can fail before a later provider semantic error. No successful
---prefix or retained job results from refusal; consumed credits remain consumed.
---@class TC.ProductionStatistics
local Statistics = {}

---Copy the complete native count maps, with each direction retaining exactly its
---own keys/recorded zeros. Empty maps are success, not nil. Totals reflect native
---resets/other-mod changes on the next call, not a private accumulated lifetime.
---@param kind TC.StatisticsKind Required exact namespace; no default or option table.
---@return TC.StatisticsSnapshot snapshot Quality-nested for item, flat for fluid/pollution; native total units.
function Statistics.getTotals(kind) end

---Read native average per-minute flow for every recorded direction-specific key.
---Uses native flow count with no sample index, never differenced totals or privately
---averaged history. Old activity can remain as a zero current-window rate.
---@param kind TC.StatisticsKind Required exact namespace.
---@param window TC.StatisticsWindow Required symbolic averaging precision; no default.
---@return TC.StatisticsSnapshot snapshot Quality-nested item or flat other-kind maps of rates per game minute.
function Statistics.getRates(kind, window) end

---Read one exact identity's complete raw native history. Registered item/fluid or
---pollution entity without activity has native zero history. Pollution also accepts
---an exact current input/output map key even without an entity prototype; it ceases
---to be valid when absent from both maps. Arbitrary unknown names fail, never produce
---invented zeros. Item native identity includes quality; other kinds use name only.
---@param kind TC.StatisticsKind Required exact namespace.
---@param name string Nonempty exact installed item/fluid/entity or current pollution key; bounded by string_bytes.
---@param window TC.StatisticsWindow Required symbolic history precision.
---@param quality? string Item-only installed quality; omitted/nil means normal. Other kinds accept only omission/nil.
---@return TC.HistorySnapshot snapshot Exactly one complete 300-sample-per-side snapshot.
function Statistics.getHistory(kind, name, window, quality) end

---Read effective common limits. History geometry/windows are not tunable budget
---fields and no statistics-specific count or settings are added.
---@return TC.Limits limits Defensive effective common limit map.
function Statistics.getLimits() end
