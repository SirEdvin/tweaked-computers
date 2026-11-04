# Typed API section and example migration

Generated from `tools/data/api-section-migration.json` and
`tools/data/api-example-migration.json`; identities only, not another API contract.
Each old heading names its retained declaration, guide, behavior or acceptance destination.
Source hashes identify the pre-retirement material. Line numbers below are historical.
Lua fence indexes count Lua blocks only, not text/signature fences.

Runtime disagreements were resolved against unchanged source and Factorio 2.1.23 probes:
custom devices do not need electricity; wire order is red before green; monitor
getLimits has zero arguments; Console log has a trailing-argument exception;
pcall and xpcall differ for protected-handle errors; falsey blit foreground and
Dashboard format=false retain their existing behavior. Configurator readback
does not inherit write-only requiredness or input ceilings. Historical native
inventory provenance is not evidence of current engine validation.

## docs/player/api/common.md

Action: generate. Original SHA-256: `7419c036c4b630eef37e3bc7052e7b428e21538e3fbf9f512a9cf5db8e1e81bd`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Shared Lua rules, types, errors and limits | `api/common.d.lua`; `api/generated/limits.d.lua` |
| 10 — Types | `api/common.d.lua`; `api/generated/limits.d.lua` |
| 53 — Errors | `api/common.d.lua`; `api/generated/limits.d.lua` |
| 88 — Scheduling and availability | `api/common.d.lua`; `api/generated/limits.d.lua` |
| 127 — Effective safety ceilings | `api/common.d.lua`; `api/generated/limits.d.lua` |

## docs/player/api/computer.md

Action: generate. Original SHA-256: `2ab71eb252f9569636cea5f0d0f3cf83b1b9d42bd029255a1028404dcec53a4b`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Computer callbacks and state | `api/computer.d.lua`; `api/generated/limits.d.lua` |
| 18 — Complete method reference | `api/computer.d.lua`; `api/generated/limits.d.lua` |
| 56 — General events | `api/computer.d.lua`; `api/generated/limits.d.lua` |
| 82 — TimerEvent | `api/computer.d.lua`; `api/generated/limits.d.lua` |
| 96 — Run lifecycle and errors | `api/computer.d.lua`; `api/generated/limits.d.lua` |

## docs/player/api/configurator.md

Action: generate. Original SHA-256: `8626d8d666b4d38953b485596c0c82e5fc2855274b2500052eb3eda3f49ee8ad`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Configurator: factory circuit settings | `api/configurator.d.lua`; `api/generated/limits.d.lua` |
| 10 — Complete methods | `api/configurator.d.lua`; `api/generated/limits.d.lua` |
| 29 — Device and schema records | `api/configurator.d.lua`; `api/generated/limits.d.lua` |
| 66 — Read and patch | `api/configurator.d.lua`; `api/generated/limits.d.lua` |
| 105 — Constant-combinator sections | `api/configurator.d.lua`; `api/generated/limits.d.lua` |
| 131 — Bounds, programs and troubleshooting | `api/configurator.d.lua`; `api/generated/limits.d.lua` |

## docs/player/api/dashboard.md

Action: generate. Original SHA-256: `15faf7140ebfda0dd719cf77ef8d8598838608eb10d54e4a7739193a42b861b2`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Dashboard API | `api/dashboard.d.lua`; `api/generated/limits.d.lua` |
| 10 — Base methods | `api/dashboard.d.lua`; `api/generated/limits.d.lua` |
| 29 — Complete definitions | `api/dashboard.d.lua`; `api/generated/limits.d.lua` |
| 57 — Scheduled buttons | `api/dashboard.d.lua`; `api/generated/limits.d.lua` |
| 92 — Optional line and duration methods | `api/dashboard.d.lua`; `api/generated/limits.d.lua` |
| 101 — `appendSample(slot, id, values)` | `api/dashboard.d.lua`; `api/generated/limits.d.lua` |
| 119 — `setBars(slot, id, bars)` | `api/dashboard.d.lua`; `api/generated/limits.d.lua` |
| 134 — `clearChart(slot, id)` | `api/dashboard.d.lua`; `api/generated/limits.d.lua` |
| 140 — Capacity, errors and lifetime | `api/dashboard.d.lua`; `api/generated/limits.d.lua`; `docs/player/lifecycle.md`; `docs/player/console.md` |

## docs/player/api/factoriopedia-interface.md

Action: generate. Original SHA-256: `54260734fc5b4b7b283f818d7ac1a9c91a1a09033020a7bb43c26fa8b56cff39`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Factoriopedia Interface | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 11 — Setup | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 21 — Methods | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 37 — Records | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 85 — Failures and limits | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 105 — Example | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |

## docs/player/api/kv.md

Action: generate. Original SHA-256: `fd9bfa455511ad5942308a2f4b26359e1aaf9d781377a11a7d68591943ae1bc5`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — KV database | `api/kv-database.d.lua`; `api/generated/limits.d.lua` |
| 10 — Complete commands | `api/kv-database.d.lua`; `api/generated/limits.d.lua` |
| 35 — Expiry | `api/kv-database.d.lua`; `api/generated/limits.d.lua` |
| 49 — Atomicity, errors and capacities | `api/kv-database.d.lua`; `api/generated/limits.d.lua` |
| 77 — Catch a wrong-type read safely | `api/kv-database.d.lua`; `api/generated/limits.d.lua`; `examples/api-contract/player-kv-1.lua` |
| 100 — Mining and shared storage | `api/kv-database.d.lua`; `api/generated/limits.d.lua`; `docs/player/lifecycle.md`; `docs/player/console.md` |

## docs/player/api/language.md

Action: retain-guide. Original SHA-256: `caea3f95711bfc59a56aa2ce26f02e4f1155f3af8ed55f35e75fbba3288a87aa`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Bounded native Lua language | `docs/player/api/language.md`; `openspec/specs/program-source/spec.md`; `examples/function-program.lua` |
| 33 — Declaration scope and calls | `docs/player/api/language.md`; `openspec/specs/program-source/spec.md` |
| 79 — Approved globals and libraries | `api/globals.d.lua`; `api/colors.d.lua` |
| 114 — Standard helper signatures | `api/globals.d.lua`; `api/colors.d.lua` |
| 187 — Printing, raw helpers and error transformation | `docs/player/api/language.md`; `openspec/specs/program-source/spec.md`; `api/globals.d.lua` |
| 230 — Excluded features | `docs/player/api/language.md`; `openspec/specs/program-source/spec.md` |
| 242 — Failure and persistence | `docs/player/api/language.md`; `openspec/specs/program-source/spec.md` |

## docs/player/api/limits.md

Action: generate. Original SHA-256: `e58d6473912aa5d47a79c5a74087fbe56d0bd960adfa2b93bc9b18e8f5b15d05`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Common effective limits | `api/generated/limits.d.lua`; `docs/player/monitor-animation.md` |
| 10 — Live mod settings | `api/generated/limits.d.lua`; `docs/player/monitor-animation.md`; `docs/player/budget-settings.md` |
| 40 — Maintenance and shared headroom | `api/generated/limits.d.lua`; `docs/player/monitor-animation.md`; `docs/player/budget-settings.md` |
| 70 — Default common limits | `api/generated/limits.d.lua`; `docs/player/monitor-animation.md` |

## docs/player/api/logic.md

Action: generate. Original SHA-256: `9340ccc9c6346aed45c7954b84a1cd3fcebad97fef4684ebd095c974528a5dc3`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Logic handler input, output and subscriptions | `api/logic-handler.d.lua`; `api/generated/limits.d.lua` |
| 10 — Complete methods | `api/logic-handler.d.lua`; `api/generated/limits.d.lua` |
| 50 — Subscriptions | `api/logic-handler.d.lua`; `api/generated/limits.d.lua` |
| 84 — Fail-safe ownership and persistence | `api/logic-handler.d.lua`; `api/generated/limits.d.lua`; `docs/player/lifecycle.md`; `docs/player/console.md` |
| 102 — Bounds and use | `api/logic-handler.d.lua`; `api/generated/limits.d.lua` |

## docs/player/api/modem.md

Action: generate. Original SHA-256: `b9d5b6822a820aae51697ce4c686992ba8368cb0ad834eedd69d55ccba4e4541`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Radar modems | `api/modem.d.lua`; `api/generated/limits.d.lua` |
| 26 — Local wire authority, radio channels | `api/modem.d.lua`; `api/generated/limits.d.lua` |
| 41 — Seven methods | `api/modem.d.lua`; `api/generated/limits.d.lua` |
| 70 — Messages and named handlers | `api/modem.d.lua`; `api/generated/limits.d.lua` |
| 113 — Bounds and datagram failure | `api/modem.d.lua`; `api/generated/limits.d.lua`; `docs/player/radio-operations.md` |
| 153 — Space Age advanced tier | `api/modem.d.lua`; `api/generated/limits.d.lua`; `docs/player/radio-operations.md` |
| 178 — Saves and moving devices | `api/modem.d.lua`; `api/generated/limits.d.lua`; `docs/player/radio-operations.md` |

## docs/player/api/monitor.md

Action: generate. Original SHA-256: `4ec9e9ae0dab7fd44af38e88f3bae82ac8b7f93642b195127be0827115b39f1f`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Merged monitors and terminal methods | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `docs/monitor.md`; `docs/player/lifecycle.md` |
| 21 — Automatic buffered presentation | `api/monitor.d.lua`; `api/generated/limits.d.lua` |
| 57 — Complete terminal reference | `api/monitor.d.lua`; `api/generated/limits.d.lua` |
| 89 — Colors and glyphs | `api/monitor.d.lua`; `api/generated/limits.d.lua` |
| 120 — Geometry, identity and availability | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `docs/monitor.md`; `docs/player/lifecycle.md` |
| 143 — Touch and resize events | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `docs/monitor.md`; `docs/player/lifecycle.md` |
| 167 — Bounds, example and troubleshooting | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `docs/monitor.md`; `docs/player/lifecycle.md` |

## docs/player/api/peripheral.md

Action: generate. Original SHA-256: `7ee6ec3de5eababb2781102ae4886e04d11fa337460b47fd0d6b8db25bcf37ed`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Peripheral discovery and calls | `api/peripheral.d.lua`; `api/generated/limits.d.lua` |
| 16 — Complete methods | `api/peripheral.d.lua`; `api/generated/limits.d.lua` |
| 57 — Wrappers and stale identities | `api/peripheral.d.lua`; `api/generated/limits.d.lua` |
| 69 — Synchronized monitor presentation | `api/peripheral.d.lua`; `api/generated/limits.d.lua` |
| 101 — Events | `api/peripheral.d.lua`; `api/generated/limits.d.lua` |
| 140 — Use and troubleshooting | `api/peripheral.d.lua`; `api/generated/limits.d.lua`; `docs/player/lifecycle.md`; `docs/player/console.md` |

## docs/player/api/production-statistics.md

Action: generate. Original SHA-256: `2276df0697d6161023bbbade93cd9e605edfa4799bd02c462c252a59d53bcc06`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Production Statistics | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 7 — Build and connect | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 19 — Methods | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 35 — Scope, directions and shapes | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 59 — Windows and historical order | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 80 — Whole result or explicit refusal | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 106 — Run the tutorials | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 125 — Save, upgrade and rollback | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |

## docs/player/api/recipe-searcher.md

Action: generate. Original SHA-256: `c12cffdeab7c705c4569e83737913ddda4afacf5c06e7f138aa2dd9048cb2179`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Recipe Searcher | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 9 — Discovery and calls | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md`; `examples/api-contract/player-recipe-searcher-1.lua` |
| 39 — Complete results, not a prefix | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 55 — Recipe record | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 109 — Freshness, authority and lifecycle | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 135 — Errors and example | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |

## docs/player/api/schemas.md

Action: generate. Original SHA-256: `2770c37ef2c6bb50feaab91f37a68a142be80e35ae2831ca08d99acb3da36ec4`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Configurator nested types and enums | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 16 — ArithmeticCombinatorParameterOperation | `api/generated/configurator.d.lua#TC.Config.ArithmeticCombinatorParameterOperation`; `api/generated/configurator.d.lua#TC.Config.Read.ArithmeticCombinatorParameterOperation` |
| 22 — ArithmeticCombinatorParameters | `api/generated/configurator.d.lua#TC.Config.ArithmeticCombinatorParameters`; `api/generated/configurator.d.lua#TC.Config.Read.ArithmeticCombinatorParameters` |
| 37 — BlueprintQualityID | `api/generated/configurator.d.lua#TC.Config.BlueprintQualityID`; `api/generated/configurator.d.lua#TC.Config.Read.BlueprintQualityID` |
| 45 — CircuitConditionDefinition | `api/generated/configurator.d.lua#TC.Config.CircuitConditionDefinition`; `api/generated/configurator.d.lua#TC.Config.Read.CircuitConditionDefinition` |
| 56 — CircuitNetworkSelection | `api/generated/configurator.d.lua#TC.Config.CircuitNetworkSelection`; `api/generated/configurator.d.lua#TC.Config.Read.CircuitNetworkSelection` |
| 65 — ComparatorString | `api/generated/configurator.d.lua#TC.Config.ComparatorString`; `api/generated/configurator.d.lua#TC.Config.Read.ComparatorString` |
| 71 — DeciderCombinatorCondition | `api/generated/configurator.d.lua#TC.Config.DeciderCombinatorCondition`; `api/generated/configurator.d.lua#TC.Config.Read.DeciderCombinatorCondition` |
| 85 — DeciderCombinatorOutput | `api/generated/configurator.d.lua#TC.Config.DeciderCombinatorOutput`; `api/generated/configurator.d.lua#TC.Config.Read.DeciderCombinatorOutput` |
| 96 — DeciderCombinatorParameters | `api/generated/configurator.d.lua#TC.Config.DeciderCombinatorParameters`; `api/generated/configurator.d.lua#TC.Config.Read.DeciderCombinatorParameters` |
| 105 — DisplayPanelMessageDefinition | `api/generated/configurator.d.lua#TC.Config.DisplayPanelMessageDefinition`; `api/generated/configurator.d.lua#TC.Config.Read.DisplayPanelMessageDefinition` |
| 115 — ItemCountType | `api/generated/configurator.d.lua#TC.Config.ItemCountType`; `api/generated/configurator.d.lua#TC.Config.Read.ItemCountType` |
| 121 — LogisticFilter | `api/generated/configurator.d.lua#TC.Config.LogisticFilter`; `api/generated/configurator.d.lua#TC.Config.Read.LogisticFilter` |
| 137 — ProgrammableSpeakerCircuitParameters | `api/generated/configurator.d.lua#TC.Config.ProgrammableSpeakerCircuitParameters`; `api/generated/configurator.d.lua#TC.Config.Read.ProgrammableSpeakerCircuitParameters` |
| 148 — QualityCondition | `api/generated/configurator.d.lua#TC.Config.QualityCondition`; `api/generated/configurator.d.lua#TC.Config.Read.QualityCondition` |
| 154 — QualityID | `api/generated/configurator.d.lua#TC.Config.QualityID`; `api/generated/configurator.d.lua#TC.Config.Read.QualityID` |
| 160 — SelectorCombinatorParameterOperation | `api/generated/configurator.d.lua#TC.Config.SelectorCombinatorParameterOperation`; `api/generated/configurator.d.lua#TC.Config.Read.SelectorCombinatorParameterOperation` |
| 166 — SelectorCombinatorParameters | `api/generated/configurator.d.lua#TC.Config.SelectorCombinatorParameters`; `api/generated/configurator.d.lua#TC.Config.Read.SelectorCombinatorParameters` |
| 209 — SignalFilter | `api/generated/configurator.d.lua#TC.Config.SignalFilter`; `api/generated/configurator.d.lua#TC.Config.Read.SignalFilter` |
| 215 — SignalID | `api/generated/configurator.d.lua#TC.Config.SignalID`; `api/generated/configurator.d.lua#TC.Config.Read.SignalID` |
| 225 — SignalIDBase | `api/generated/configurator.d.lua#TC.Config.SignalIDBase`; `api/generated/configurator.d.lua#TC.Config.Read.SignalIDBase` |
| 234 — SignalIDType | `api/generated/configurator.d.lua#TC.Config.SignalIDType`; `api/generated/configurator.d.lua#TC.Config.Read.SignalIDType` |
| 240 — SpaceLocationID | `api/generated/configurator.d.lua#TC.Config.SpaceLocationID`; `api/generated/configurator.d.lua#TC.Config.Read.SpaceLocationID` |
| 246 — boolean | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 252 — float | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 258 — int32 | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 264 — nil | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 270 — string | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 276 — table | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 282 — uint32 | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 286 — Normalization | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 310 — Native enum names | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 312 — defines.control_behavior.cargo_landing_pad.exclusive_mode | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 316 — defines.control_behavior.inserter.hand_read_mode | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 320 — defines.control_behavior.lamp.color_mode | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 324 — defines.control_behavior.logistic_container.exclusive_mode | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 328 — defines.control_behavior.mining_drill.resource_read_mode | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 332 — defines.control_behavior.roboport.read_items_mode | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 336 — defines.control_behavior.rocket_silo.read_mode | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 340 — defines.control_behavior.transport_belt.content_read_mode | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 344 — defines.logistic_section_type | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |
| 348 — defines.wire_connector_id | `api/generated/configurator.d.lua`; `api/configurator.d.lua`; `api/common.d.lua` |

## docs/player/api/settings.md

Action: generate. Original SHA-256: `67c610db43e1ee498a8e40317dcc9e763abfae4594160509644a4359d3f12c35`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Supported configurator settings | `api/configurator.d.lua` |
| 15 — Accumulator | `api/generated/configurator.d.lua#TC.Config.LuaAccumulatorControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaAccumulatorControlBehavior` |
| 22 — AgriculturalTower | `api/generated/configurator.d.lua#TC.Config.LuaAgriculturalTowerControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaAgriculturalTowerControlBehavior` |
| 32 — ArithmeticCombinator | `api/generated/configurator.d.lua#TC.Config.LuaArithmeticCombinatorControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaArithmeticCombinatorControlBehavior` |
| 38 — ArtilleryTurret | `api/generated/configurator.d.lua#TC.Config.LuaArtilleryTurretControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaArtilleryTurretControlBehavior` |
| 48 — AssemblingMachine | `api/generated/configurator.d.lua#TC.Config.LuaAssemblingMachineControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaAssemblingMachineControlBehavior` |
| 66 — AsteroidCollector | `api/generated/configurator.d.lua#TC.Config.LuaAsteroidCollectorControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaAsteroidCollectorControlBehavior` |
| 78 — CargoLandingPad | `api/generated/configurator.d.lua#TC.Config.LuaCargoLandingPadControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaCargoLandingPadControlBehavior` |
| 84 — Combinator | `api/generated/configurator.d.lua#TC.Config.LuaCombinatorControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaCombinatorControlBehavior` |
| 88 — ConstantCombinator | `api/generated/configurator.d.lua#TC.Config.LuaConstantCombinatorControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaConstantCombinatorControlBehavior` |
| 96 — Container | `api/generated/configurator.d.lua#TC.Config.LuaContainerControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaContainerControlBehavior` |
| 102 — Base control behavior | `api/generated/configurator.d.lua#TC.Config.LuaControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaControlBehavior` |
| 106 — DeciderCombinator | `api/generated/configurator.d.lua#TC.Config.LuaDeciderCombinatorControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaDeciderCombinatorControlBehavior` |
| 112 — DisplayPanel | `api/generated/configurator.d.lua#TC.Config.LuaDisplayPanelControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaDisplayPanelControlBehavior` |
| 118 — Furnace | `api/generated/configurator.d.lua#TC.Config.LuaFurnaceControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaFurnaceControlBehavior` |
| 135 — GenericOnOff | `api/generated/configurator.d.lua#TC.Config.LuaGenericOnOffControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaGenericOnOffControlBehavior` |
| 144 — Inserter | `api/generated/configurator.d.lua#TC.Config.LuaInserterControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaInserterControlBehavior` |
| 158 — Lamp | `api/generated/configurator.d.lua#TC.Config.LuaLampControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaLampControlBehavior` |
| 173 — Loader | `api/generated/configurator.d.lua#TC.Config.LuaLoaderControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaLoaderControlBehavior` |
| 184 — LogisticContainer | `api/generated/configurator.d.lua#TC.Config.LuaLogisticContainerControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaLogisticContainerControlBehavior` |
| 192 — MiningDrill | `api/generated/configurator.d.lua#TC.Config.LuaMiningDrillControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaMiningDrillControlBehavior` |
| 203 — ProgrammableSpeaker | `api/generated/configurator.d.lua#TC.Config.LuaProgrammableSpeakerControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaProgrammableSpeakerControlBehavior` |
| 210 — ProxyContainer | `api/generated/configurator.d.lua#TC.Config.LuaProxyContainerControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaProxyContainerControlBehavior` |
| 216 — Pump | `api/generated/configurator.d.lua#TC.Config.LuaPumpControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaPumpControlBehavior` |
| 226 — Radar | `api/generated/configurator.d.lua#TC.Config.LuaRadarControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaRadarControlBehavior` |
| 230 — RailSignalBase | `api/generated/configurator.d.lua#TC.Config.LuaRailSignalBaseControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaRailSignalBaseControlBehavior` |
| 242 — Reactor | `api/generated/configurator.d.lua#TC.Config.LuaReactorControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaReactorControlBehavior` |
| 250 — Roboport | `api/generated/configurator.d.lua#TC.Config.LuaRoboportControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaRoboportControlBehavior` |
| 263 — RocketSilo | `api/generated/configurator.d.lua#TC.Config.LuaRocketSiloControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaRocketSiloControlBehavior` |
| 269 — SelectorCombinator | `api/generated/configurator.d.lua#TC.Config.LuaSelectorCombinatorControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaSelectorCombinatorControlBehavior` |
| 275 — SpacePlatformHub | `api/generated/configurator.d.lua#TC.Config.LuaSpacePlatformHubControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaSpacePlatformHubControlBehavior` |
| 288 — Splitter | `api/generated/configurator.d.lua#TC.Config.LuaSplitterControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaSplitterControlBehavior` |
| 300 — StorageTank | `api/generated/configurator.d.lua#TC.Config.LuaStorageTankControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaStorageTankControlBehavior` |
| 306 — TrainStop | `api/generated/configurator.d.lua#TC.Config.LuaTrainStopControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaTrainStopControlBehavior` |
| 325 — TransportBelt | `api/generated/configurator.d.lua#TC.Config.LuaTransportBeltControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaTransportBeltControlBehavior` |
| 336 — Turret | `api/generated/configurator.d.lua#TC.Config.LuaTurretControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaTurretControlBehavior` |
| 349 — Wall | `api/generated/configurator.d.lua#TC.Config.LuaWallControlBehavior`; `api/generated/configurator.d.lua#TC.Config.Read.LuaWallControlBehavior` |

## docs/player/api/speaker.md

Action: generate. Original SHA-256: `56a12487f5917a1b65fc6ddd7d0e4f53be3f54d6ac424f5b730159758707e3a9`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Programmable speaker | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 7 — Calls and returns | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 11 — getInstruments() | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 15 — getNotes(instrument) | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 19 — playNote(instrument [, volume [, pitch]]) | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 23 — playSound(path [, volume]) | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 27 — getSounds([prefix [, after]]) | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 33 — getLimits() | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 51 — Admission, power and audible output | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |
| 63 — Programs, installation and rollback | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `docs/player/getting-started.md`; `docs/player/inspectors.md`; `docs/player/lifecycle.md` |

## openspec/api/common.md

Action: retire. Original SHA-256: `d0cff445af2531b2ce491686036fe0790e9a10a780f1dc6a35bffdeb95d3cad2`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Shared Lua API contract, version 1 | `api/common.d.lua`; `api/events.d.lua`; `api/computer.d.lua`; `api/generated/limits.d.lua` |
| 5 — Calling convention and version | `api/common.d.lua`; `api/events.d.lua`; `api/computer.d.lua`; `api/generated/limits.d.lua` |
| 14 — Shared types | `api/common.d.lua`; `api/events.d.lua`; `api/computer.d.lua`; `api/generated/limits.d.lua` |
| 65 — Errors | `api/common.d.lua`; `api/events.d.lua`; `api/computer.d.lua`; `api/generated/limits.d.lua` |
| 88 — Scheduling and lifecycle | `api/common.d.lua`; `api/events.d.lua`; `api/computer.d.lua`; `api/generated/limits.d.lua` |
| 107 — Queryable limits | `api/common.d.lua`; `api/events.d.lua`; `api/computer.d.lua`; `api/generated/limits.d.lua` |
| 131 — Compatibility boundaries | `api/common.d.lua`; `api/events.d.lua`; `api/computer.d.lua`; `api/generated/limits.d.lua` |
| 138 — Console-specific boundary | `api/common.d.lua`; `api/events.d.lua`; `api/computer.d.lua`; `api/generated/limits.d.lua` |

## openspec/api/device-experience.md

Action: retire. Original SHA-256: `9b908d88c21de11181de774ffa0f06685f998bae743d17117297d828d963fe6a`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Lua and editor compatibility contract | `docs/editor-interaction-contract.md`; `docs/player/editor.md` |
| 3 — Public Lua remains version 1 | `docs/editor-interaction-contract.md`; `docs/player/editor.md` |
| 11 — Complete editor action placement | `docs/editor-interaction-contract.md`; `docs/player/editor.md` |
| 34 — Concrete user workflow acceptance | `docs/editor-interaction-contract.md`; `docs/player/editor.md` |

## openspec/api/examples.md

Action: retire. Original SHA-256: `1ad5379e65bedb593b866e881905cf2868f02150bad104d53ca4c088c6b71b01`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Integrated Lua examples and acceptance cases | `docs/player/factory.md`; `docs/api-migration-acceptance.md` |
| 5 — Case A: a configured, monitored stock controller | `docs/player/factory.md`; `docs/api-migration-acceptance.md`; `examples/api-contract/api-examples-1.lua` |
| 145 — Case B: discover both colors without mixing them | `docs/player/factory.md`; `docs/api-migration-acceptance.md` |
| 149 — Case C: precise cache expiration and type failures | `docs/player/factory.md`; `docs/api-migration-acceptance.md` |
| 153 — Case D: signal events and multiple writers | `docs/player/factory.md`; `docs/api-migration-acceptance.md` |
| 157 — Case E: configurator inspection and containment | `docs/player/factory.md`; `docs/api-migration-acceptance.md` |

## openspec/api/native-language.md

Action: retire. Original SHA-256: `02dda66cbe133ce41dbb52a5c4cfbe7bbc50fbadea3cd0d0526cc6c672e7f47f`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Bounded native Lua language contract | `docs/player/api/language.md`; `api/globals.d.lua`; `api/colors.d.lua`; `docs/api-migration-acceptance.md` |
| 7 — Accepted document shape | `docs/player/api/language.md`; `api/globals.d.lua`; `api/colors.d.lua`; `docs/api-migration-acceptance.md` |
| 15 — Exclusions | `docs/player/api/language.md`; `api/globals.d.lua`; `api/colors.d.lua`; `docs/api-migration-acceptance.md` |
| 26 — Approved standard surface | `docs/player/api/language.md`; `api/globals.d.lua`; `api/colors.d.lua`; `docs/api-migration-acceptance.md` |
| 37 — Enforced boundaries | `docs/player/api/language.md`; `api/globals.d.lua`; `api/colors.d.lua`; `docs/api-migration-acceptance.md` |
| 47 — Failure and acceptance | `docs/player/api/language.md`; `api/globals.d.lua`; `api/colors.d.lua`; `docs/api-migration-acceptance.md` |

## openspec/specs/computer-runtime/base-globals-api.md

Action: retire. Original SHA-256: `5d01f91637b4e0a57a9dd1abcd9b50dee96081bfd2eb42643369408874a87d21`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Expanded Lua base-global contract | `api/globals.d.lua`; `api/common.d.lua`; `docs/player/api/language.md`; `docs/player/console.md` |
| 5 — Compatibility target and inventory | `api/globals.d.lua`; `api/common.d.lua`; `docs/player/api/language.md`; `docs/player/console.md` |
| 26 — Printing | `api/globals.d.lua`; `api/common.d.lua`; `docs/player/api/language.md`; `docs/player/console.md` |
| 36 — Raw helpers and identity | `api/globals.d.lua`; `api/common.d.lua`; `docs/player/api/language.md`; `docs/player/console.md` |
| 59 — xpcall and fatal controls | `api/globals.d.lua`; `api/common.d.lua`; `docs/player/api/language.md`; `docs/player/console.md` |
| 70 — Errors, lifetime and versioning | `api/globals.d.lua`; `api/common.d.lua`; `docs/player/api/language.md`; `docs/player/console.md` |
| 78 — Explicit compatibility exclusions | `api/globals.d.lua`; `api/common.d.lua`; `docs/player/api/language.md`; `docs/player/console.md` |
| 82 — Illustrative acceptance programs | `api/globals.d.lua`; `api/common.d.lua`; `docs/player/api/language.md`; `docs/player/console.md`; `examples/api-contract/computer-runtime-base-globals-api-1.lua` |
| 111 — Reference basis | `api/globals.d.lua`; `api/common.d.lua`; `docs/player/api/language.md`; `docs/player/console.md` |

## openspec/specs/computer-runtime/lua-api.md

Action: retire. Original SHA-256: `8496b37b110f7bbf037817456fce408deb1e19ae822bf17e9cc2fd463531fc7e`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Computer Lua API v1 | `api/computer.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/computer-runtime/spec.md`; `api/globals.d.lua`; `api/events.d.lua`; `docs/player/api/language.md` |
| 5 — Source document | `api/computer.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/computer-runtime/spec.md`; `api/globals.d.lua`; `api/events.d.lua`; `docs/player/api/language.md`; `examples/api-contract/computer-runtime-lua-api-1.lua` |
| 27 — Identity, time, state and diagnostics | `api/computer.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/computer-runtime/spec.md`; `api/globals.d.lua`; `api/events.d.lua`; `docs/player/api/language.md` |
| 44 — General event registration | `api/computer.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/computer-runtime/spec.md`; `api/globals.d.lua`; `api/events.d.lua`; `docs/player/api/language.md` |
| 57 — Timers | `api/computer.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/computer-runtime/spec.md`; `api/globals.d.lua`; `api/events.d.lua`; `docs/player/api/language.md` |
| 89 — Recoverable and fatal errors | `api/computer.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/computer-runtime/spec.md`; `api/globals.d.lua`; `api/events.d.lua`; `docs/player/api/language.md`; `examples/api-contract/computer-runtime-lua-api-2.lua` |
| 113 — Expanded Lua base globals | `api/computer.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/computer-runtime/spec.md`; `api/globals.d.lua`; `api/events.d.lua`; `docs/player/api/language.md`; `examples/api-contract/computer-runtime-base-globals-api-1.lua` |
| 160 — Required contract checks | `api/computer.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/computer-runtime/spec.md`; `api/globals.d.lua`; `api/events.d.lua`; `docs/player/api/language.md`; `docs/api-migration-acceptance.md` |

## openspec/specs/console-shell/lua-api.md

Action: retire. Original SHA-256: `0e84655319b60a05995ba5e69613c637889198f8fdcca3d4fce8e3be0ad7efd3`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Console Lua shell contract | `docs/player/console.md`; `api/computer.d.lua`; `api/peripheral.d.lua`; `openspec/specs/console-shell/spec.md` |
| 5 — Entering and evaluating a line | `docs/player/console.md`; `api/computer.d.lua`; `api/peripheral.d.lua`; `openspec/specs/console-shell/spec.md` |
| 21 — Output | `docs/player/console.md`; `api/computer.d.lua`; `api/peripheral.d.lua`; `openspec/specs/console-shell/spec.md` |
| 34 — Retained values | `docs/player/console.md`; `api/computer.d.lua`; `api/peripheral.d.lua`; `openspec/specs/console-shell/spec.md` |
| 54 — Computer and peripheral APIs | `docs/player/console.md`; `api/computer.d.lua`; `api/peripheral.d.lua`; `openspec/specs/console-shell/spec.md` |
| 77 — Session lifetime | `docs/player/console.md`; `api/computer.d.lua`; `api/peripheral.d.lua`; `openspec/specs/console-shell/spec.md` |
| 95 — Admission, errors, and effects | `docs/player/console.md`; `api/computer.d.lua`; `api/peripheral.d.lua`; `openspec/specs/console-shell/spec.md` |
| 117 — Illustrative acceptance sequence | `docs/player/console.md`; `api/computer.d.lua`; `api/peripheral.d.lua`; `openspec/specs/console-shell/spec.md`; `examples/api-contract/console-shell-lua-api-1.lua` |

## openspec/specs/dashboard-interface/lua-api.md

Action: retire. Original SHA-256: `b6c98c261bc6ba8a3af79a0e0183b25ca788a7acdd67341854baec53ee1ccc83`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Dashboard Lua API v1 | `api/dashboard.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/dashboard-interface/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md` |
| 5 — Discovery and exact methods | `api/dashboard.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/dashboard-interface/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md` |
| 32 — Tabs and layout | `api/dashboard.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/dashboard-interface/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md` |
| 55 — Rolling line charts | `api/dashboard.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/dashboard-interface/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md` |
| 66 — Snapshot duration bars | `api/dashboard.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/dashboard-interface/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md` |
| 74 — Shared retained accounting and errors | `api/dashboard.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/dashboard-interface/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md` |
| 102 — Buttons and subscriptions | `api/dashboard.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/dashboard-interface/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md` |
| 121 — Lifecycle and optional dependency | `api/dashboard.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/dashboard-interface/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md` |
| 129 — Minimal base program | `api/dashboard.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/dashboard-interface/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md`; `examples/dashboard-program.lua` |

## openspec/specs/device-configurator/configuration-catalog.md

Action: retire. Original SHA-256: `464879614ba3d2075dd3df345590e243ba28ff9df92668ce8c2bf0df829a6ea8`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Factorio 2.0.77 configuration coverage catalogue | `tools/data/configuration-catalog.json`; `api/generated/configurator.d.lua`; `docs/configuration-catalog-provenance.md` |
| 9 — Coverage | `tools/data/configuration-catalog.json`; `api/generated/configurator.d.lua`; `docs/configuration-catalog-provenance.md` |
| 50 — Interpretation and authority | `tools/data/configuration-catalog.json`; `api/generated/configurator.d.lua`; `docs/configuration-catalog-provenance.md` |
| 62 — Verification obligation | `tools/data/configuration-catalog.json`; `api/generated/configurator.d.lua`; `docs/configuration-catalog-provenance.md` |

## openspec/specs/device-configurator/lua-api.md

Action: retire. Original SHA-256: `a95894959673a863c9a0f8a3a83e3e593fb819d53ede9669afaff3b27705e6e7`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Configurator Lua API v1 | `api/configurator.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/device-configurator/spec.md`; `api/generated/configurator.d.lua` |
| 7 — Device discovery and inspection | `api/configurator.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/device-configurator/spec.md`; `api/generated/configurator.d.lua` |
| 43 — Capability schemas | `api/configurator.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/device-configurator/spec.md`; `api/generated/configurator.d.lua` |
| 82 — Configuration reads and updates | `api/configurator.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/device-configurator/spec.md`; `api/generated/configurator.d.lua` |
| 102 — Constant-combinator sections | `api/configurator.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/device-configurator/spec.md`; `api/generated/configurator.d.lua` |
| 119 — Example: inspect devices, then configure only applicable inserters | `api/configurator.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/device-configurator/spec.md`; `api/generated/configurator.d.lua`; `examples/api-contract/device-configurator-lua-api-1.lua` |
| 151 — Required cases | `api/configurator.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/device-configurator/spec.md`; `api/generated/configurator.d.lua`; `docs/api-migration-acceptance.md` |

## openspec/specs/device-lifecycle/lua-api.md

Action: retire. Original SHA-256: `24bcd51b545ffacd0a97ad70c373975ad9bf58e8143559fd4d3f6bec5fa8d8a7`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Lifecycle effects on Lua APIs | `docs/player/lifecycle.md`; `docs/api-migration-acceptance.md`; `openspec/specs/device-lifecycle/spec.md` |
| 5 — Identity and data matrix | `docs/player/lifecycle.md`; `docs/api-migration-acceptance.md`; `openspec/specs/device-lifecycle/spec.md` |
| 38 — API observations | `docs/player/lifecycle.md`; `docs/api-migration-acceptance.md`; `openspec/specs/device-lifecycle/spec.md` |
| 57 — Persistence cases to exercise | `docs/player/lifecycle.md`; `docs/api-migration-acceptance.md`; `openspec/specs/device-lifecycle/spec.md` |

## openspec/specs/factoriopedia-interface/lua-api.md

Action: retire. Original SHA-256: `e0a41497151e62bd8a29a508ef7e836f1a0f76ef78b9b6df085e2664b467538f`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Factoriopedia Interface Lua API | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/factoriopedia-interface/spec.md` |
| 5 — Discovery and method inventory | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/factoriopedia-interface/spec.md` |
| 21 — Names and catalogue scope | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/factoriopedia-interface/spec.md` |
| 30 — Common record fields | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/factoriopedia-interface/spec.md` |
| 49 — Item record | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/factoriopedia-interface/spec.md` |
| 71 — Rocket-count semantics | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/factoriopedia-interface/spec.md` |
| 89 — Quality semantics | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/factoriopedia-interface/spec.md` |
| 93 — Fluid record | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/factoriopedia-interface/spec.md` |
| 110 — Completeness, ownership and limits | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/factoriopedia-interface/spec.md` |
| 120 — Authority, availability and persistence | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/factoriopedia-interface/spec.md` |
| 128 — Errors | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/factoriopedia-interface/spec.md` |
| 147 — Guest example | `api/factoriopedia-interface.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/factoriopedia-interface/spec.md`; `examples/api-contract/factoriopedia-interface-lua-api-1.lua` |

## openspec/specs/kv-database/lua-api.md

Action: retire. Original SHA-256: `005321fd01103046a587b9e8573bee15f32848354c6242732f936294ba6dc839`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — KV database Lua API v1 | `api/kv-database.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/kv-database/spec.md` |
| 5 — Data and commands | `api/kv-database.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/kv-database/spec.md` |
| 31 — Expiration | `api/kv-database.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/kv-database/spec.md` |
| 46 — Atomicity and errors | `api/kv-database.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/kv-database/spec.md` |
| 54 — Example: cache one machine's state | `api/kv-database.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/kv-database/spec.md`; `examples/api-contract/kv-database-lua-api-1.lua` |
| 76 — Required cases | `api/kv-database.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/kv-database/spec.md`; `docs/api-migration-acceptance.md` |

## openspec/specs/logic-handler/lua-api.md

Action: retire. Original SHA-256: `3bc39d72125e9718cf4b2cb3aeb031025decbb733e7fc2b59a6825ffe70492cf`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Logic handler Lua API v1 | `api/logic-handler.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/logic-handler/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md` |
| 5 — Methods | `api/logic-handler.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/logic-handler/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md` |
| 40 — Subscriptions | `api/logic-handler.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/logic-handler/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md` |
| 93 — Output ownership and failure | `api/logic-handler.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/logic-handler/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md` |
| 106 — Example: threshold control | `api/logic-handler.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/logic-handler/spec.md`; `api/events.d.lua`; `docs/player/console.md`; `docs/player/lifecycle.md`; `examples/api-contract/logic-handler-lua-api-1.lua` |

## openspec/specs/monitor-display/buffering-api.md

Action: retire. Original SHA-256: `a74c2428e64f591e7da2f54a3587dc810d9e9a97198e7d5c01ee3b9a8d232ddb`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Buffered monitor Lua API contract | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 5 — Compatibility and automatic buffering | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 13 — Supported geometry and buffer sizing | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 40 — Selection API | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 61 — Update rounds and group publication | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 69 — Status data | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 84 — Limits and errors | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 121 — Lifecycle | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 131 — Illustrative selection example | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md`; `examples/api-contract/monitor-display-buffering-api-1.lua` |

## openspec/specs/monitor-display/lua-api.md

Action: retire. Original SHA-256: `7883ecb8bf2512b52abe1a7152930a90b2b177cbe9cb6126b2af639b8f13ba4a`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Monitor Lua API v1 | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 7 — Methods | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 35 — Colors and cell geometry | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 71 — Merge, split and resize | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 79 — Events | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 102 — Example: a touchable status display | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md`; `examples/api-contract/monitor-display-lua-api-1.lua` |
| 137 — Demand-driven scheduling contract | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 139 — Public surface and exact results | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 158 — Presentation demand and synchronization | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 167 — Availability, authority and physical changes | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 175 — Events, errors and limits | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |
| 185 — Persistence and acceptance | `api/monitor.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/monitor-display/spec.md`; `api/events.d.lua`; `api/peripheral.d.lua`; `docs/monitor.md`; `docs/player/monitor-animation.md` |

## openspec/specs/peripheral-network/lua-api.md

Action: retire. Original SHA-256: `8d20beb054d38ffd3f92171895f71b0bf03da278111e25856515b82dbc72038e`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Peripheral discovery Lua API v1 | `api/peripheral.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/peripheral-network/spec.md`; `api/events.d.lua` |
| 5 — Discovery and calls | `api/peripheral.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/peripheral-network/spec.md`; `api/events.d.lua` |
| 42 — Reachability rules | `api/peripheral.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/peripheral-network/spec.md`; `api/events.d.lua` |
| 52 — Attachment events | `api/peripheral.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/peripheral-network/spec.md`; `api/events.d.lua` |
| 76 — Example: inspect both channels without bridging them | `api/peripheral.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/peripheral-network/spec.md`; `api/events.d.lua`; `examples/api-contract/peripheral-network-lua-api-1.lua` |
| 91 — Required cases | `api/peripheral.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/peripheral-network/spec.md`; `api/events.d.lua`; `docs/api-migration-acceptance.md` |

## openspec/specs/production-statistics/lua-api.md

Action: retire. Original SHA-256: `98b171c5cf69c9b508494af0bb3715115d04ed39489b38066df927408b0f3eb3`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Production Statistics Lua API v1 | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md` |
| 5 — Discovery and exact method set | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md` |
| 20 — Scope and inputs | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md` |
| 32 — Native time windows | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md` |
| 47 — Direction and units | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md` |
| 57 — Snapshot shapes | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md` |
| 61 — TotalsSnapshot | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md` |
| 87 — RatesSnapshot | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md` |
| 93 — HistorySnapshot | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md` |
| 107 — Freshness, safety and limits | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md` |
| 117 — Authority, errors and lifecycle | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md` |
| 137 — Example: query the three categories and operations | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md`; `examples/api-contract/production-statistics-lua-api-1.lua` |
| 164 — Pinned primary references and evidence status | `api/production-statistics.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/production-statistics/spec.md`; `docs/api-migration-acceptance.md` |

## openspec/specs/program-editor/lua-api.md

Action: retire. Original SHA-256: `6588a7e4d7c1b7e541e68979e0ad0d0d1b684a097d1ecc07d653c0a3b6e00cc3`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Editor-related Lua contract and authoring cases | `docs/editor-interaction-contract.md`; `docs/player/editor.md`; `api/computer.d.lua` |
| 5 — Source entry and lifecycle | `docs/editor-interaction-contract.md`; `docs/player/editor.md`; `api/computer.d.lua` |
| 21 — Guest-visible diagnostics | `docs/editor-interaction-contract.md`; `docs/player/editor.md`; `api/computer.d.lua` |
| 27 — Minimal in-game program | `docs/editor-interaction-contract.md`; `docs/player/editor.md`; `api/computer.d.lua`; `examples/api-contract/program-editor-lua-api-1.lua` |

## openspec/specs/program-source/lua-api.md

Action: retire. Original SHA-256: `4bac32a799c7515936fa6ae47a938441fe3ae8cf5edfe0617768361e0db41f5a`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Saved-program declaration contract | `docs/player/api/language.md`; `openspec/specs/program-source/spec.md`; `api/computer.d.lua`; `api/common.d.lua` |
| 5 — Grammar and names | `docs/player/api/language.md`; `openspec/specs/program-source/spec.md`; `api/computer.d.lua`; `api/common.d.lua` |
| 15 — Scope and values | `docs/player/api/language.md`; `openspec/specs/program-source/spec.md`; `api/computer.d.lua`; `api/common.d.lua` |
| 23 — Calls and registration | `docs/player/api/language.md`; `openspec/specs/program-source/spec.md`; `api/computer.d.lua`; `api/common.d.lua` |
| 39 — Example: immediate and recurring work | `docs/player/api/language.md`; `openspec/specs/program-source/spec.md`; `api/computer.d.lua`; `api/common.d.lua`; `examples/function-program.lua` |
| 61 — Errors, admission and lifecycle | `docs/player/api/language.md`; `openspec/specs/program-source/spec.md`; `api/computer.d.lua`; `api/common.d.lua` |

## openspec/specs/radar-modem/lua-api.md

Action: retire. Original SHA-256: `6e1077177a0e7c237860bf2211b1acb87e94089d6f0352a305c2235c088ebfcc`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Radar modem Lua API v1 | `api/modem.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/radar-modem/spec.md`; `api/events.d.lua` |
| 5 — Discovery and tiers | `api/modem.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/radar-modem/spec.md`; `api/events.d.lua` |
| 17 — Methods | `api/modem.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/radar-modem/spec.md`; `api/events.d.lua` |
| 37 — Shared channel ownership | `api/modem.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/radar-modem/spec.md`; `api/events.d.lua` |
| 45 — Payload | `api/modem.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/radar-modem/spec.md`; `api/events.d.lua` |
| 53 — Event registration and schema | `api/modem.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/radar-modem/spec.md`; `api/events.d.lua` |
| 83 — Routing and event admission | `api/modem.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/radar-modem/spec.md`; `api/events.d.lua` |
| 99 — Persistence and identity | `api/modem.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/radar-modem/spec.md`; `api/events.d.lua` |
| 107 — Queryable limits | `api/modem.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/radar-modem/spec.md`; `api/events.d.lua` |
| 120 — Required cases | `api/modem.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/radar-modem/spec.md`; `api/events.d.lua`; `docs/api-migration-acceptance.md` |

## openspec/specs/recipe-searcher/lua-api.md

Action: retire. Original SHA-256: `b1b7aed85c82656a9d3da0e840826cf528233ab81606a2fa4b122909685d3dca`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Recipe Searcher Lua API v1 | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/recipe-searcher/spec.md` |
| 5 — Discovery and calling convention | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/recipe-searcher/spec.md` |
| 20 — Query inputs | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/recipe-searcher/spec.md` |
| 31 — Completeness and limits | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/recipe-searcher/spec.md` |
| 40 — RecipeInfo | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/recipe-searcher/spec.md` |
| 62 — IngredientInfo | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/recipe-searcher/spec.md` |
| 74 — ProductInfo | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/recipe-searcher/spec.md` |
| 93 — SurfaceConditionInfo | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/recipe-searcher/spec.md` |
| 99 — Availability and freshness | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/recipe-searcher/spec.md` |
| 105 — Errors | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/recipe-searcher/spec.md` |
| 125 — Identity, persistence and lifecycle | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/recipe-searcher/spec.md` |
| 135 — Example: search, refine and read metadata | `api/recipe-searcher.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/recipe-searcher/spec.md`; `examples/recipe-searcher-program.lua` |

## openspec/specs/speaker-peripheral/lua-api.md

Action: retire. Original SHA-256: `36e55720b823c071191ffe23b2f7691b63bad779cf86cba3800ebf95d7b5e50b`.

| Old line / heading | Retained destinations |
| --- | --- |
| 1 — Speaker Lua API v1 | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/speaker-peripheral/spec.md` |
| 5 — Discovery and method inventory | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/speaker-peripheral/spec.md` |
| 22 — Notes | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/speaker-peripheral/spec.md` |
| 34 — Sound paths | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/speaker-peripheral/spec.md` |
| 42 — Sound discovery | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/speaker-peripheral/spec.md` |
| 63 — Admission, timing and audibility | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/speaker-peripheral/spec.md` |
| 75 — Availability, identity and native coexistence | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/speaker-peripheral/spec.md` |
| 86 — Limits | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/speaker-peripheral/spec.md` |
| 104 — Errors | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/speaker-peripheral/spec.md` |
| 123 — Example: discover, choose and play | `api/speaker.d.lua`; `api/generated/limits.d.lua`; `openspec/specs/speaker-peripheral/spec.md`; `examples/api-contract/speaker-peripheral-lua-api-1.lua` |

## Exact retained examples

| Old identity | Source | Kind | SHA-256 |
| --- | --- | --- | --- |
| `docs/player/api/kv.md:1` | `examples/api-contract/player-kv-1.lua` | program | `0cde28a197c4194ddeea29cfb1925edb6dc56f5d7c2879fa4f7cbcb9f33de0f1` |
| `docs/player/api/language.md:1` | `examples/function-program.lua` | program | `5f6fe0704335a87c30e7f1a448ce44524f9551e43b6fbd3945355d819a89204a` |
| `docs/player/api/recipe-searcher.md:1` | `examples/api-contract/player-recipe-searcher-1.lua` | program | `415ba1d6c28d6e62e606990afbd33739e332c4685cbd373e15a5513c09052a32` |
| `openspec/api/examples.md:1` | `examples/api-contract/api-examples-1.lua` | program | `2a428d4af089e1b618d9db595d886f7414ead10da1e85dcdec78e0b46e882ba3` |
| `openspec/specs/computer-runtime/base-globals-api.md:1` | `examples/api-contract/computer-runtime-base-globals-api-1.lua` | program | `0df13a8effb19503f4d63234dd22ca32e099272dfbaa5ddece6e99c8d7b5968b` |
| `openspec/specs/computer-runtime/lua-api.md:1` | `examples/api-contract/computer-runtime-lua-api-1.lua` | program | `4e274259f6d67150b063fabad2333646b347b536ac00e5b29715e0302298149a` |
| `openspec/specs/computer-runtime/lua-api.md:2` | `examples/api-contract/computer-runtime-lua-api-2.lua` | program | `d7355a43c3a2de8833c5facf27034b4e3e69445f8ff788c2181b3d014323dc77` |
| `openspec/specs/computer-runtime/lua-api.md:3` | `examples/api-contract/computer-runtime-base-globals-api-1.lua` | program | `0df13a8effb19503f4d63234dd22ca32e099272dfbaa5ddece6e99c8d7b5968b` |
| `openspec/specs/console-shell/lua-api.md:1` | `examples/api-contract/console-shell-lua-api-1.lua` | console | `00df9093341025cf35b4befba99ad87eb9ef3550990887167d4d135dbbf73a3a` |
| `openspec/specs/dashboard-interface/lua-api.md:1` | `examples/dashboard-program.lua` | program | `0f55e9c742893b0be3e598c540e2e4cf1c53f0540f0b2a5e3ffcc8d60345102a` |
| `openspec/specs/device-configurator/lua-api.md:1` | `examples/api-contract/device-configurator-lua-api-1.lua` | program | `bae1af66174bff388431f5404ff1bf96ea895a5b91d499054d30d232a09c38e2` |
| `openspec/specs/factoriopedia-interface/lua-api.md:1` | `examples/api-contract/factoriopedia-interface-lua-api-1.lua` | program | `bd98e21f71857afc2f4d68fa47344aaa6ff09ec8946198dc81079f5db6ae65c1` |
| `openspec/specs/kv-database/lua-api.md:1` | `examples/api-contract/kv-database-lua-api-1.lua` | program | `ded9ed5087f8ea708a508a65c37ac56a84faa519cd0dc2a49f13f3b979fd16ec` |
| `openspec/specs/logic-handler/lua-api.md:1` | `examples/api-contract/logic-handler-lua-api-1.lua` | program | `9742ca0d1385c0ce4ddf174d6009b7ab615875b39f23921c53632443f187800a` |
| `openspec/specs/monitor-display/buffering-api.md:1` | `examples/api-contract/monitor-display-buffering-api-1.lua` | program | `0bec2c3469ec9411d6d1a05b2b11d2810901add399579f14a0c06198c9fa806e` |
| `openspec/specs/monitor-display/lua-api.md:1` | `examples/api-contract/monitor-display-lua-api-1.lua` | program | `bc0e2c3a2e3e26d135eeafce2e0383cf74c474a7c55427f9e306ce0094b344a2` |
| `openspec/specs/peripheral-network/lua-api.md:1` | `examples/api-contract/peripheral-network-lua-api-1.lua` | program | `2f1e4ba118b5d9249711fd5278f83e5ee3a0bdbe9358e80d570783287b0775d9` |
| `openspec/specs/production-statistics/lua-api.md:1` | `examples/api-contract/production-statistics-lua-api-1.lua` | program | `f7dd0b7e912eb81ea446120bfca63740eb4e7caa0576b4d2d424e748f0fb4291` |
| `openspec/specs/program-editor/lua-api.md:1` | `examples/api-contract/program-editor-lua-api-1.lua` | program | `7fe080015a216b930484945e02a04d201973a9c2ff94e295452bbff2f9e4b211` |
| `openspec/specs/program-source/lua-api.md:1` | `examples/function-program.lua` | program | `5f6fe0704335a87c30e7f1a448ce44524f9551e43b6fbd3945355d819a89204a` |
| `openspec/specs/recipe-searcher/lua-api.md:1` | `examples/recipe-searcher-program.lua` | program | `846cfeadc91ce9611595b66bbbd73930ffd53881b9d89a1043b22685312fe96d` |
| `openspec/specs/speaker-peripheral/lua-api.md:1` | `examples/api-contract/speaker-peripheral-lua-api-1.lua` | program | `c0f0f988f5ceaac576dcf6a20dc1ad45f340e776fbee1d20361bbb03f12be908` |
