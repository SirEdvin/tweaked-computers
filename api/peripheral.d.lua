---@meta

---Closed shipped peripheral families. Computers are passive graph vertices, not
---discoverable programmable peripheral facades. Unknown string searches are empty.
---@alias TC.PeripheralType 'monitor'|'kv_database'|'logic_handler'|'configurator'|'recipe_searcher'|'factoriopedia_interface'|'production_statistics'|'dashboard'|'modem'|'speaker'

---A dynamically discovered genuine facade. Inspect getType/getMethods or use a
---literal-family find overload before assuming a concrete member exists. A plain
---lookalike table grants no authority; neither facade nor method is ordinary Data.
---@alias TC.Peripheral TC.Monitor|TC.KVDatabase|TC.LogicHandler|TC.Configurator|TC.RecipeSearcher|TC.FactoriopediaInterface|TC.ProductionStatistics|TC.Dashboard|TC.Modem|TC.Speaker

---Detached physical metadata, not a LuaEntity or a reusable authority proof.
---Positions and footprints describe a monitor's logical rectangle; terminal axes
---and dimensions are separate. Native carriers remain discoverable without power.
---@class TC.PeripheralInfo
---@field name TC.PeripheralName Exact current logical/physical service identity.
---@field type TC.PeripheralType Public facade family.
---@field label? string Descriptive, nonunique label; absent when unset.
---@field powered boolean Live physical availability; valid custom devices need no electricity.
---@field position TC.Position World coordinates of the device/logical monitor center.
---@field surface TC.Surface Current surface identity, not cross-surface access.
---@field quality string Installed prototype quality name.
---@field direction 'north'|'east'|'south'|'west' Cardinal orientation.
---@field footprint TC.Footprint Axis-aligned world extent, not terminal dimensions.
---@field wire TC.Wire Selected proven discovery channel.
---@field modem_tier? 'surface'|'interplanetary' Present for radar modems only.

---Explicit selection reference; exactly these fields are accepted, no facade,
---coordinates, extra keys or implicit wire fallback.
---@class TC.MonitorRef
---@field name TC.PeripheralName Nonempty bounded monitor name.
---@field wire TC.Wire Required independently validated physical path.

---Bounded retained presentation diagnostic; no native recovery objects escape.
---@class TC.MonitorDiagnostic
---@field code TC.ErrorCode Failure/release category.
---@field message string Human-readable explanation, not stable wording.

---Defensive presentation selection/status snapshot. none means no selection,
---empty members, sequence zero and absent tick; a definitive release may retain
---a diagnostic. waiting means incomplete round participation. preparing includes
---sealed, queued and commit-waiting work, not visible completion. blocked takes
---priority over preparing/waiting while proof or geometry capacity is unavailable.
---@class TC.MonitorSyncStatus
---@field members TC.MonitorRef[] Canonical logical identities, sorted by name.
---@field status 'none'|'waiting'|'preparing'|'blocked' Current retained presentation state.
---@field presented_sequence integer Nonnegative safe sequence of last complete group publication.
---@field presented_tick? TC.Tick Actual publication tick; absent until first publication.
---@field diagnostic? TC.MonitorDiagnostic Latest retained blockage/release reason.

---Physical same-color discovery. Only public computer-network connectors and
---supported native radar/speaker sockets relay it. Hidden radar radio links,
---input/output/target ports, unrelated native entities, ghosts, other forces and
---other surfaces do not bridge this network. Red and green never combine into a
---path. A logical monitor reachable through one member does not internally bridge
---unwired members. KV access on both colors is one database, not a color bridge.
---
---Every target call revalidates exact identity/generation, force/surface, selected
---path and device requirements. Temporary/incomplete topology is E_NETWORK_PENDING
---or E_LIMIT, never a successful empty inventory. Native radar/speaker active
---methods require power; reachable metadata/getLimits remain usable without it.
---Wrappers and captured methods are ephemeral in saved callbacks. Persist only
---name and wire in Data and wrap again. Console alone can retain authentic symbolic
---bindings; stale restored descriptors never retarget replacement entities.
---
---Attach/detach registrations observe transitions, not startup inventory. Current
---output owners and pending work have independent fail-safe observation; no
---background snapshot authorizes a later operation. Cold load retains accepted
---observations/order and paid credits without rerunning guest code.
---Background topology interest belongs to attach/detach, modem-message and
---Dashboard-click registrations plus unfinished computer/color reconciliation.
---Removing the final interest retires future observation after pending host work
---settles; already accepted snapshot notifications are not recalled. Definitive
---Dashboard selected-path loss retires its registrations/queued clicks, whereas
---incomplete discovery alone does not. Physical discovery may retain a pending
---native-adoption request from a stopped/faulted placed computer independently of
---program lifetime; program retirement does not cancel that physical-root request.
---@class TC.PeripheralLibrary
peripheral = {}

---Return the complete sorted unique current inventory for one explicit color.
---An empty array is complete success; incomplete traversal throws instead.
---@param wire TC.Wire Required red or green path selection.
---@return TC.PeripheralName[] names Sorted opaque service names, possibly empty.
function peripheral.getNames(wire) end

---Test physical reachability after complete discovery. Native power loss alone
---does not make a reachable carrier absent. Invalid/incomplete proof throws.
---@param name TC.PeripheralName Exact bounded peripheral name.
---@param wire TC.Wire Required discovery channel.
---@return boolean present True for a current reachable identity; false when absent.
function peripheral.isPresent(name, wire) end

---Read one reachable family name; no fallback to another wire or old generation.
---@param name TC.PeripheralName Exact bounded peripheral name.
---@param wire TC.Wire Required discovery channel.
---@return TC.PeripheralType|nil type Exactly one family or one nil after complete absence.
function peripheral.getType(name, wire) end

---Read sorted public method names including aliases. Optional Dashboard chart
---methods are absent when the compatible library is absent, not failing stubs.
---@param name TC.PeripheralName Exact bounded peripheral name.
---@param wire TC.Wire Required discovery channel.
---@return string[]|nil methods Complete independent names, or one nil when absent.
function peripheral.getMethods(name, wire) end

---Read current plain metadata. Labels, positions and powered are observations,
---not authority tokens, global discovery shortcuts or native object handles.
---@param name TC.PeripheralName Exact bounded peripheral name.
---@param wire TC.Wire Required discovery channel.
---@return TC.PeripheralInfo|nil info Independent snapshot or exactly one nil when absent.
function peripheral.describe(name, wire) end

---Create a genuine dot-call facade bound to identity, entity generation and wire.
---A later stale call throws; it does not silently return an empty value or switch
---color. Opaque names do not statically identify a concrete peripheral family.
---@param name TC.PeripheralName Exact bounded peripheral name.
---@param wire TC.Wire Required discovery channel.
---@return TC.Peripheral|nil facade Exactly one authentic facade or one nil when absent.
function peripheral.wrap(name, wire) end

---Invoke one public method with its exact trailing arguments/results and current
---authority. Unknown method is E_ARGUMENT. Handler-only/optional-dependency rules
---apply through this route too; no arbitrary native method forwarding exists.
---@param name TC.PeripheralName Exact bounded peripheral name.
---@param wire TC.Wire Required discovery channel.
---@param method string Bounded public method name, including supported aliases.
---@param ... TC.GuestValue Method-specific arguments; see the selected member's contract.
---@return TC.GuestValue ... Exact method result tuple; zero values/nil remain distinct.
function peripheral.call(name, wire, method, ...) end

---Find all matching facades in sorted-name order as MULTIPLE RETURNS, not an
---array. Zero matches yield zero results. Collect with {peripheral.find(...)} or
---assign the first. Too many matches is E_LIMIT; use getNames/wrap instead.
---A bounded unknown string returns zero matches, not an unsupported-type error.
---@param type_name string Family string; literal supported names refine result type.
---@param wire TC.Wire Required explicit discovery channel.
---@return TC.Peripheral ... Zero or more genuine matching facades in sorted-name order.
---@overload fun(type_name: 'monitor', wire: TC.Wire): ...: TC.Monitor # type_name selects monitors; results are zero or more sorted matching monitor facades.
---@overload fun(type_name: 'kv_database', wire: TC.Wire): ...: TC.KVDatabase # type_name selects databases; results are zero or more sorted matching database facades.
---@overload fun(type_name: 'logic_handler', wire: TC.Wire): ...: TC.LogicHandler # type_name selects Logic handlers; results are zero or more sorted matching Logic facades.
---@overload fun(type_name: 'configurator', wire: TC.Wire): ...: TC.Configurator # type_name selects Configurators; results are zero or more sorted matching Configurator facades.
---@overload fun(type_name: 'recipe_searcher', wire: TC.Wire): ...: TC.RecipeSearcher # type_name selects Recipe Searchers; results are zero or more sorted matching search facades.
---@overload fun(type_name: 'factoriopedia_interface', wire: TC.Wire): ...: TC.FactoriopediaInterface # type_name selects Factoriopedia Interfaces; results are zero or more sorted matching reference facades.
---@overload fun(type_name: 'production_statistics', wire: TC.Wire): ...: TC.ProductionStatistics # type_name selects Production Statistics; results are zero or more sorted matching statistics facades.
---@overload fun(type_name: 'dashboard', wire: TC.Wire): ...: TC.Dashboard # type_name selects Dashboards; results are zero or more sorted facades, with chart methods only when installed.
---@overload fun(type_name: 'modem', wire: TC.Wire): ...: TC.Modem # type_name selects radar modems; results are zero or more sorted matching radio facades.
---@overload fun(type_name: 'speaker', wire: TC.Wire): ...: TC.Speaker # type_name selects native speakers; results are zero or more sorted matching audio facades.
function peripheral.find(type_name, wire) end

---Inspect an authentic facade's bound identity, even after detachment. This does
---not reauthorize target access; plain lookalike records are E_ARGUMENT.
---@param facade TC.Peripheral Genuine wrapped or authentically restored facade.
---@return TC.PeripheralName name Bound service identity.
function peripheral.getName(facade) end

---Inspect an authentic facade's bound discovery color, even after detachment.
---No target access or fallback is granted; forged tables are E_ARGUMENT.
---@param facade TC.Peripheral Genuine wrapped or authentically restored facade.
---@return TC.Wire wire Bound red/green channel.
function peripheral.getWire(facade) end

---Atomically replace this run/session's single monitor synchronization selection;
---{} clears, nil does not. Returns zero values. Validate EVERY supplied path,
---including duplicates, then canonicalize by logical identity: red wins when both
---valid colors name the same display; sort by name. Equal canonical selection is
---idempotent, preserving pending work/sequence. Ordinary refusal preserves the old
---group and every model/front. No selection grants exclusive drawing authority.
---
---All members must be live monitors on one force/surface and fit actual summed
---cells. Another owner's selected member is E_BUSY; non-monitor is E_WRONGTYPE;
---missing path is E_UNREACHABLE; incomplete proof E_NETWORK_PENDING; malformed
---input E_ARGUMENT; excessive proof/input E_LIMIT; final capacity E_CAPACITY.
---No coordinate or implicit color fallback exists.
---
---After registration/each seal, every member needs one successful mutating call
---before the next post-dispatch snapshot; valid no-ops count, getters do not.
---Seal current models together, prepare against old complete fronts, then publish
---all in one tick. Pending snapshots may coalesce; admitted frames are immutable.
---A static unmodified member holds the round indefinitely, without partial output.
---This aligns presentation epochs, not producers' clocks or multi-callback images.
---
---Saved-run and Console-session owners are separate. Stop/fault/replacement,
---owner removal or definitive selected-path/identity loss releases the whole group
---and unpublished work, never accepted model/front contents. Temporary incomplete
---proof blocks instead. Geometry/scale changes reset participation/staging; an
---oversized retained group stays blocked until it fits or is reconfigured.
---Ordinary reload preserves ownership, progress, acknowledgements and credits.
---@param members TC.MonitorRef[] Dense exact reference records; empty array clears.
function peripheral.setMonitorSyncGroup(members) end

---Read one independent status map. This does not drive rendering, retry topology,
---mutate selection or wait for completion. A sequence can skip coalesced pending
---frames and advances only on complete publication, never merely on preparation.
---@return TC.MonitorSyncStatus status Current retained selection/progress/diagnostic.
function peripheral.getMonitorSyncGroup() end
