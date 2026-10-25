# Supported configurator settings

Guest circuit-control settings supported on Factorio 2.1.23, preserving the 2.0 field vocabulary.
Fuel/display fields map to native read_fuel/records; logistic-container and landing-pad
modes also accept send_contents_and_set_requests for simultaneous reading/requesting.
Storage-tank read_contents=true preserves an existing segment-read mode; false disables reading.
These tables include inherited roots. Read current getCapabilities before writing:
prototype/expansion/mode restrictions can make a listed field unavailable.
Types link to the [complete nested schemas](schemas.md). All calls, patch semantics
and target-network rules are in the [configurator reference](configurator.md).

Boolean values are true/false, not numeric modes. Clearable means explicit patch
clear is accepted; it can normalize to native defaults rather than nil.

## Accumulator

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `output_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `read_charge` | boolean | no | Current native applicability |

## AgriculturalTower

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `read_contents` | boolean | no | Current native applicability |

## ArithmeticCombinator

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `parameters` | [ArithmeticCombinatorParameters](schemas.md#schema-arithmeticcombinatorparameters) | yes | Current native applicability |

## ArtilleryTurret

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `read_ammo` | boolean | no | Current native applicability |

## AssemblingMachine

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `circuit_read_contents` | boolean | no | Current native applicability |
| `circuit_read_ingredients` | boolean | no | Current native applicability |
| `circuit_read_recipe_finished` | boolean | no | Current native applicability |
| `circuit_read_working` | boolean | no | Current native applicability |
| `circuit_recipe_finished_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `circuit_set_recipe` | boolean | no | Current native applicability |
| `circuit_working_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `include_fuel` | boolean | no | Requires fuel inventory |
| `include_in_crafting` | boolean | no | Current native applicability |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |

## AsteroidCollector

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `connect_to_logistic_network` | boolean | no | Unavailable: native inherited switch is ineffective |
| `include_hands` | boolean | no | Current native applicability |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `read_content` | boolean | no | Current native applicability |
| `set_filter` | boolean | no | Current native applicability |

## CargoLandingPad

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_exclusive_mode_of_operation` | `none`, `send_contents`, `set_requests` | no | set_requests requires space travel |

## Combinator

No writable root settings on this base behavior; derived families list their inherited settings below.

## ConstantCombinator

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `enabled` | boolean | no | Current native applicability |

Also supports [constant-combinator section methods](configurator.md#constant-combinator-sections).

## Container

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `read_contents` | boolean | no | Current native applicability |

## Base control behavior

No writable root settings on this base behavior; derived families list their inherited settings below.

## DeciderCombinator

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `parameters` | [DeciderCombinatorParameters](schemas.md#schema-decidercombinatorparameters) | yes | Current native applicability |

## DisplayPanel

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `messages` | dense array ≤128 of [DisplayPanelMessageDefinition](schemas.md#schema-displaypanelmessagedefinition) | no | Current native applicability |

## Furnace

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `circuit_read_contents` | boolean | no | Current native applicability |
| `circuit_read_ingredients` | boolean | no | Current native applicability |
| `circuit_read_recipe_finished` | boolean | no | Current native applicability |
| `circuit_read_working` | boolean | no | Current native applicability |
| `circuit_recipe_finished_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `circuit_working_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `include_fuel` | boolean | no | Requires fuel inventory |
| `include_in_crafting` | boolean | no | Current native applicability |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |

## GenericOnOff

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |

## Inserter

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `circuit_hand_read_mode` | `hold`, `pulse` | no | Current native applicability |
| `circuit_read_hand_contents` | boolean | no | Current native applicability |
| `circuit_set_filters` | boolean | no | Current native applicability |
| `circuit_set_stack_size` | boolean | no | Current native applicability |
| `circuit_stack_control_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |

## Lamp

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `blue_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `color_mode` | `color_mapping`, `components`, `packed_rgb` | no | Current native applicability |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `green_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `red_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `rgb_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `use_colors` | boolean | no | Current native applicability |

## Loader

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `circuit_read_transfers` | boolean | no | Current native applicability |
| `circuit_set_filters` | boolean | no | Current native applicability |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |

## LogisticContainer

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | no | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_condition_enabled` | boolean | no | Current native applicability |
| `circuit_exclusive_mode_of_operation` | `none`, `send_contents`, `set_requests` | no | Requester/buffer only |

## MiningDrill

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `circuit_read_resources` | boolean | no | Current native applicability |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `resource_read_mode` | `entire_patch`, `this_miner` | no | Current native applicability |

## ProgrammableSpeaker

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | no | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_parameters` | [ProgrammableSpeakerCircuitParameters](schemas.md#schema-programmablespeakercircuitparameters) | no | Current native applicability |

## ProxyContainer

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `read_contents` | boolean | no | Current native applicability |

## Pump

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `set_filter` | boolean | no | Current native applicability |

## Radar

No writable root settings on this base behavior; derived families list their inherited settings below.

## RailSignalBase

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `blue_signal` | [SignalID](schemas.md#schema-signalid) | yes | Chain signal only |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | no | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `close_signal` | boolean | no | Current native applicability |
| `green_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `orange_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `read_signal` | boolean | no | Current native applicability |
| `red_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |

## Reactor

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `read_fuel` | boolean | no | Current native applicability |
| `read_temperature` | boolean | no | Current native applicability |
| `temperature_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |

## Roboport

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `available_construction_output_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `available_logistic_output_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `read_items_mode` | `logistics`, `missing_requests`, `none` | no | Current native applicability |
| `read_logistics` | boolean | no | Current native applicability |
| `read_robot_stats` | boolean | no | Current native applicability |
| `roboport_count_output_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `total_construction_output_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `total_logistic_output_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |

## RocketSilo

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `read_mode` | `logistic_inventory`, `none`, `orbital_requests` | no | Current native applicability |

## SelectorCombinator

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `parameters` | [SelectorCombinatorParameters](schemas.md#schema-selectorcombinatorparameters) | no | operation_variant |

## SpacePlatformHub

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `damage_taken_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `read_contents` | boolean | no | Current native applicability |
| `read_damage_taken` | boolean | no | Current native applicability |
| `read_moving_from` | boolean | no | Current native applicability |
| `read_moving_to` | boolean | no | Current native applicability |
| `read_speed` | boolean | no | Current native applicability |
| `send_to_platform` | boolean | no | Current native applicability |
| `speed_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |

## Splitter

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `input_left_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | no | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `input_right_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | no | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `output_left_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | no | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `output_right_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | no | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `set_filter` | boolean | no | Current native applicability |
| `set_input_side` | boolean | no | Current native applicability |
| `set_output_side` | boolean | no | Current native applicability |

## StorageTank

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `read_contents` | boolean | no | Current native applicability |

## TrainStop

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `priority_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `read_from_train` | boolean | no | Current native applicability |
| `read_stopped_train` | boolean | no | Current native applicability |
| `read_trains_count` | boolean | no | Current native applicability |
| `send_to_train` | boolean | no | Current native applicability |
| `set_priority` | boolean | no | Current native applicability |
| `set_trains_limit` | boolean | no | Current native applicability |
| `stopped_train_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `trains_count_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `trains_limit_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |

## TransportBelt

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `read_contents` | boolean | no | Current native applicability |
| `read_contents_mode` | `entire_belt_hold`, `hold`, `pulse` | no | Current native applicability |

## Turret

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `circuit_enable_disable` | boolean | no | Current native applicability |
| `connect_to_logistic_network` | boolean | no | Current native applicability |
| `ignore_unlisted_targets_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | no | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `logistic_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `read_ammo` | boolean | no | Ammo/fluid turret only |
| `set_ignore_unlisted_targets` | boolean | no | Current native applicability |
| `set_priority_list` | boolean | no | Current native applicability |

## Wall

| Setting | Type | Clearable | Restriction |
| --- | --- | --- | --- |
| `circuit_condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | no | Use constant or second_signal, not both; Only role-appropriate wildcards |
| `open_gate` | boolean | no | Current native applicability |
| `output_signal` | [SignalID](schemas.md#schema-signalid) | yes | Installed signal prototype; Explicit signal type required |
| `read_sensor` | boolean | no | Current native applicability |
