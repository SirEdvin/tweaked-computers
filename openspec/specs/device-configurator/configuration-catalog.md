# Factorio 2.0.77 configuration coverage catalogue

Generated from the pinned official runtime JSON, not a guessed list. The accompanying JSON contains the full inherited field inventory, reachable nested concepts and enum names. This is a planning reference, not executable mod code.

Source schema SHA-256: `594b4ec98cc5fbee322d7380db49a388ab38b0d69c06f00ead877cffbb37f578`.

Inventory: 36 control-behavior classes, 164 effective writable field entries (inherited repetitions included), 29 referenced concepts, 10 enum groups.

## Coverage

| Native behavior | Effective writable settings | Collection adaptation |
| --- | --- | --- |
| `LuaAccumulatorControlBehavior` | `output_signal`, `read_charge` | None |
| `LuaAgriculturalTowerControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `connect_to_logistic_network`, `logistic_condition`, `read_contents` | None |
| `LuaArithmeticCombinatorControlBehavior` | `parameters` | None |
| `LuaArtilleryTurretControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `connect_to_logistic_network`, `logistic_condition`, `read_ammo` | None |
| `LuaAssemblingMachineControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `circuit_read_contents`, `circuit_read_ingredients`, `circuit_read_recipe_finished`, `circuit_read_working`, `circuit_recipe_finished_signal`, `circuit_set_recipe`, `circuit_working_signal`, `connect_to_logistic_network`, `include_fuel`, `include_in_crafting`, `logistic_condition` | None |
| `LuaAsteroidCollectorControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `connect_to_logistic_network`, `include_hands`, `logistic_condition`, `read_content`, `set_filter` | None |
| `LuaCargoLandingPadControlBehavior` | `circuit_exclusive_mode_of_operation` | None |
| `LuaCombinatorControlBehavior` | None; report device/behavior without inventing setters | None |
| `LuaConstantCombinatorControlBehavior` | `enabled` | Manual sections: active, group, multiplier, filters; bounded create/update/remove |
| `LuaContainerControlBehavior` | `read_contents` | None |
| `LuaControlBehavior` | None; report device/behavior without inventing setters | None |
| `LuaDeciderCombinatorControlBehavior` | `parameters` | `parameters` replaces decider conditions/outputs |
| `LuaDisplayPanelControlBehavior` | `messages` | `messages` replaces panel message operations |
| `LuaFurnaceControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `circuit_read_contents`, `circuit_read_ingredients`, `circuit_read_recipe_finished`, `circuit_read_working`, `circuit_recipe_finished_signal`, `circuit_working_signal`, `connect_to_logistic_network`, `include_fuel`, `include_in_crafting`, `logistic_condition` | None |
| `LuaGenericOnOffControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `connect_to_logistic_network`, `logistic_condition` | None |
| `LuaInserterControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `circuit_hand_read_mode`, `circuit_read_hand_contents`, `circuit_set_filters`, `circuit_set_stack_size`, `circuit_stack_control_signal`, `connect_to_logistic_network`, `logistic_condition` | None |
| `LuaLampControlBehavior` | `blue_signal`, `circuit_condition`, `circuit_enable_disable`, `color_mode`, `connect_to_logistic_network`, `green_signal`, `logistic_condition`, `red_signal`, `rgb_signal`, `use_colors` | None |
| `LuaLoaderControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `circuit_read_transfers`, `circuit_set_filters`, `connect_to_logistic_network`, `logistic_condition` | None |
| `LuaLogisticContainerControlBehavior` | `circuit_condition`, `circuit_condition_enabled`, `circuit_exclusive_mode_of_operation` | None |
| `LuaMiningDrillControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `circuit_read_resources`, `connect_to_logistic_network`, `logistic_condition`, `resource_read_mode` | None |
| `LuaProgrammableSpeakerControlBehavior` | `circuit_condition`, `circuit_parameters` | None |
| `LuaProxyContainerControlBehavior` | `read_contents` | None |
| `LuaPumpControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `connect_to_logistic_network`, `logistic_condition`, `set_filter` | None |
| `LuaRadarControlBehavior` | None; report device/behavior without inventing setters | None |
| `LuaRailSignalBaseControlBehavior` | `blue_signal`, `circuit_condition`, `close_signal`, `green_signal`, `orange_signal`, `read_signal`, `red_signal` | None |
| `LuaReactorControlBehavior` | `read_fuel`, `read_temperature`, `temperature_signal` | None |
| `LuaRoboportControlBehavior` | `available_construction_output_signal`, `available_logistic_output_signal`, `read_items_mode`, `read_logistics`, `read_robot_stats`, `roboport_count_output_signal`, `total_construction_output_signal`, `total_logistic_output_signal` | None |
| `LuaRocketSiloControlBehavior` | `read_mode` | None |
| `LuaSelectorCombinatorControlBehavior` | `parameters` | None |
| `LuaSpacePlatformHubControlBehavior` | `damage_taken_signal`, `read_contents`, `read_damage_taken`, `read_moving_from`, `read_moving_to`, `read_speed`, `send_to_platform`, `speed_signal` | None |
| `LuaSplitterControlBehavior` | `input_left_condition`, `input_right_condition`, `output_left_condition`, `output_right_condition`, `set_filter`, `set_input_side`, `set_output_side` | None |
| `LuaStorageTankControlBehavior` | `read_contents` | None |
| `LuaTrainStopControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `connect_to_logistic_network`, `logistic_condition`, `priority_signal`, `read_from_train`, `read_stopped_train`, `read_trains_count`, `send_to_train`, `set_priority`, `set_trains_limit`, `stopped_train_signal`, `trains_count_signal`, `trains_limit_signal` | None |
| `LuaTransportBeltControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `connect_to_logistic_network`, `logistic_condition`, `read_contents`, `read_contents_mode` | None |
| `LuaTurretControlBehavior` | `circuit_condition`, `circuit_enable_disable`, `connect_to_logistic_network`, `ignore_unlisted_targets_condition`, `logistic_condition`, `read_ammo`, `set_ignore_unlisted_targets`, `set_priority_list` | None |
| `LuaWallControlBehavior` | `circuit_condition`, `open_gate`, `output_signal`, `read_sensor` | None |

## Interpretation and authority

- Abstract/base classes are included to audit inheritance; they are not extra craftable targets.
- `configuration-catalog.json` preserves the engine type grammar for traceability. The guest-facing schema shape and normalization are specified in `lua-api.md`; clients do not receive raw engine type tables.
- Every listed field must have a supported adapter/test or an engine-applicability reason visible in capabilities. “Not implemented” is a failing release gate, not a valid permanent unsupported reason for an applicable listed setting.
- Devices from base, optional expansions and mods are matched by native behavior class and applicability, not a hard-coded prototype-name whitelist. Third-party remote interfaces and settings unrelated to circuit control are outside scope.
- Read-only runtime objects (`entity`, `owner`, validity, section handles) never become guest handles. Prototype-object unions use names. `fulfilled` and behavior `disabled` are observations, not settable values.
- Constant-combinator section ordering/indexes are native indexes, not stable identities. Every section call revalidates its current index; no retained section object is returned. Nonmanual sections remain protected.
- Shared group identity/assignment is inspectable. A write may not mutate an out-of-scope group member: refuse with `E_SHARED_SCOPE`, or edit only after explicit detachment to a manual local section.
- Signal identities retain type, name and quality. Combinator wildcard and comparator applicability follows the exact nested concept and selected operation, not the simpler ordinary-signal API.
- A target lacking a behavior still appears in discovery with an empty capability list and a reason. A target losing its wire is inaccessible regardless of previously cached capability data.

## Verification obligation

Mechanically compare the implementation catalogue against this inventory, then exercise each applicable setting in the exact packaged 2.0.77 engine. Record engine-inapplicable cases with concrete prototypes/modes; do not count an unexercised field as passed. Test nested parameter/section mutations, rejected patches, native GUI readback, expansion-off safety and shared-group containment.
