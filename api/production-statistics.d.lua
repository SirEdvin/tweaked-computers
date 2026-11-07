---@meta

---This namespace selects the statistics kind.
---Pollution covers the whole surface.
---Item and fluid statistics use both surface and force.
---@alias TC.StatisticsKind 'item'|'fluid'|'pollution'

---The native precision must be symbolic, never a guessed integer enum.
---Histories always have 300 samples.
---Nominal spacing is window duration/300.
---The API does not invent absolute bucket timestamps from the query tick.
---@alias TC.StatisticsWindow
---| 'five_seconds' # Five simulation seconds.
---| 'one_minute' # One simulation minute.
---| 'ten_minutes' # Ten simulation minutes.
---| 'one_hour' # One simulation hour.
---| 'ten_hours' # Ten simulation hours.
---| 'fifty_hours' # Fifty simulation hours.
---| 'two_hundred_fifty_hours' # Two hundred fifty simulation hours.
---| 'one_thousand_hours' # One thousand simulation hours.

---This native map contains finite numbers for each name.
---The map does not add zero entries for names present only on the opposite side.
---It preserves recorded zeros, empty maps and native numeric precision.
---There is no guarantee of alphabetical order, traversal order or arbitrary-precision integers.
---@alias TC.StatisticsCounts table<string, number>

---The item inventory uses exact quality names, then exact item names, as nested keys.
---All recorded qualities remain separate, also when native quality maps are empty.
---@alias TC.QualityStatisticsCounts table<string, TC.StatisticsCounts>

---This snapshot contains item totals or rates.
---Total leaves count produced or consumed items since the applicable native reset.
---They are not lifetime guarantees or sums of stored samples.
---Rate leaves are native per-game-minute averages for the caller's window.
---The native cumulative count map still selects keys whose current-window rate is zero.
---@class TC.ItemStatisticsSnapshot
---@field tick TC.Tick Query read tick, not the end timestamp of the newest bucket.
---@field input TC.QualityStatisticsCounts Produced item counts or per-minute rates by quality and name.
---@field output TC.QualityStatisticsCounts Consumed item counts or per-minute rates by quality and name.

---This snapshot contains fluid or pollution totals or rates.
---Fluid input means produced native fluid units; output means consumed units.
---Pollution input means emitted pollutant units; output means absorbed units.
---Totals are cumulative since the native reset.
---Rates are per game minute.
---
---Do not subtract one direction from the other to give a net value.
---Do not round fractions.
---Do not smooth the values.
---Do not infer recipe throughput.
---Do not merge names.
---@class TC.FlatStatisticsSnapshot
---@field tick TC.Tick Query read tick, not a bucket end timestamp.
---@field input TC.StatisticsCounts Produced fluid or emitted pollution counts or rates.
---@field output TC.StatisticsCounts Consumed fluid or absorbed pollution counts or rates.

---For kind=item, the snapshot has exactly the item quality-nested shape.
---Other kinds use flat name maps.
---The required input and output maps can be empty.
---The result does not repeat kind or window.
---@alias TC.StatisticsSnapshot TC.ItemStatisticsSnapshot|TC.FlatStatisticsSnapshot

---This snapshot contains two dense 300-value arrays from native get_flow_count(sample_index, count=false).
---Index 1 is newest; index 300 is oldest.
---Values are finite per-game-minute rates.
---The arrays preserve native zero and short-history behavior.
---There is no trimming, reversing, interpolation, GUI smoothing, timestamp synthesis or cross-quality aggregation.
---History can predate the physical peripheral; no guest collector startup is necessary.
---@class TC.HistorySnapshot
---@field tick TC.Tick Synchronized query tick, not an absolute sample timestamp.
---@field input number[] Exactly 300 finite production/emission rates, newest first.
---@field output number[] Exactly 300 finite consumption/absorption rates, newest first.

---Research Recipe Searcher.
---Connect this device's NETWORK with a red or green wire.
---The device reads native statistics on its current surface without write access.
---Item and fluid statistics use its current force.
---Pollution intentionally includes the whole surface, not only that force.
---Pollution statistics are source/sink flows, not airborne concentration or a map.
---
---There is no arbitrary force/surface selector, reset/write operation, cursor or top-N cutoff.
---There is no all-history query, event subscription, sort option or private collector.
---
---Each call resolves fresh native scope and data.
---Native timing remains unchanged: current-tick flows might not yet appear in the merged data.
---Never add current-tick flows manually.
---API history is raw, without the sliding-window smoothing of the native GUI.
---
---Snapshots are detached and require independent state/KV capacity for retention.
---No statistics handles or caches persist.
---Mining, cloning and new placement never reset or duplicate native data.
---Load retains identity and wires but does not replay source or query statistics.
---
---This custom device needs no electricity.
---Every method checks exact identity, scope and explicit-color reachability again.
---Console captures never bypass those checks.
---Complete native inventories, with modded names and qualities, can still exceed generic Data or shared host-work limits.
---There is no implied circuit-only transport exception, quota increase, partial-success record or credit renewal for retries.
---
---### Errors
---Wrong arity, wrong types, an empty identity or non-item quality causes E_ARGUMENT.
---An unknown kind, window, identity or quality causes E_RANGE.
---Complete result or argument bounds cause E_LIMIT.
---Unsupported or nonfinite native data causes E_UNSUPPORTED.
---Native failure causes E_ENGINE, not invented zeros.
---
---Physical failures preserve E_UNREACHABLE, E_NETWORK_PENDING and E_LIMIT.
---Host-work exhaustion remains fatal E_BUDGET.
---Current authority and input admission can fail before a later provider semantic error.
---Refusal gives no successful prefix or retained job.
---Consumed credits remain consumed.
---@class TC.ProductionStatistics
local Statistics = {}

---Copy the complete native count maps.
---Each direction retains exactly its own keys and recorded zeros.
---Empty maps indicate success, not nil.
---On the next call, totals reflect native resets and changes from other mods, not a private accumulated lifetime.
---@param kind TC.StatisticsKind Required exact namespace. There is no default or option table.
---@return TC.StatisticsSnapshot snapshot Quality-nested for item, flat for fluid or pollution. Values use native total units.
function Statistics.getTotals(kind) end

---Read the native average per-minute flow for every recorded direction-specific key.
---The method uses native flow count without a sample index, never differences between totals or private history averages.
---Old activity can remain as a zero current-window rate.
---@param kind TC.StatisticsKind Required exact namespace.
---@param window TC.StatisticsWindow Required symbolic averaging precision; no default.
---@return TC.StatisticsSnapshot snapshot Quality-nested item or flat other-kind maps of rates per game minute.
function Statistics.getRates(kind, window) end

---Read the complete raw native history for one exact identity.
---A registered item, fluid or pollution entity without activity has native zero history.
---Pollution also accepts an exact current input/output map key, even without an entity prototype.
---That key becomes invalid when absent from both maps.
---Arbitrary unknown names cause failure, never invented zeros.
---Native item identity includes quality; other kinds use only the name.
---@param kind TC.StatisticsKind Required exact namespace.
---@param name string Nonempty exact installed item, fluid or entity name, or current pollution key. The string_bytes bound applies.
---@param window TC.StatisticsWindow Required symbolic history precision.
---@param quality? string Item-only installed quality. Omission or nil means normal. Other kinds accept only omission or nil.
---@return TC.HistorySnapshot snapshot Exactly one complete 300-sample-per-side snapshot.
function Statistics.getHistory(kind, name, window, quality) end

---Read the effective common limits.
---History geometry and windows are not adjustable budget fields.
---The method adds no statistics-specific count or settings.
---@return TC.Limits limits Defensive effective common limit map.
function Statistics.getLimits() end
