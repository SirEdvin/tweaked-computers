# Configurator nested types and enums

This is the player-readable schema companion to [supported settings](settings.md).
Fields marked optional may be omitted; required fields must be present.
Unknown fields are refused. Arrays are dense; strings and arrays have no
independent mod size ceiling. Native field rules and configured resource
admission still apply. Numbers are finite and retain their native ranges.
Prototype identities use installed names, never objects.

SignalID/SignalIDBase require explicit type and name; quality defaults normal
where supported. Conditional fulfilled is read-only and excluded. Quality/location
object unions normalize to registered name strings. Selector fields must belong
to the selected operation; default select. See [normalization](#normalization).

<a id="schema-arithmeticcombinatorparameteroperation"></a>

## ArithmeticCombinatorParameterOperation

`*` or `/` or `+` or `-` or `%` or `^` or `<<` or `>>` or `AND` or `OR` or `XOR`

<a id="schema-arithmeticcombinatorparameters"></a>

## ArithmeticCombinatorParameters

| Field | Type | Required |
| --- | --- | --- |
| `first_constant` | integer −2147483648…2147483647 | no |
| `first_signal` | [SignalID](schemas.md#schema-signalid) | no |
| `first_signal_networks` | [CircuitNetworkSelection](schemas.md#schema-circuitnetworkselection) | no |
| `operation` | [ArithmeticCombinatorParameterOperation](schemas.md#schema-arithmeticcombinatorparameteroperation) | no |
| `output_signal` | [SignalID](schemas.md#schema-signalid) | no |
| `second_constant` | integer −2147483648…2147483647 | no |
| `second_signal` | [SignalID](schemas.md#schema-signalid) | no |
| `second_signal_networks` | [CircuitNetworkSelection](schemas.md#schema-circuitnetworkselection) | no |

<a id="schema-blueprintqualityid"></a>

## BlueprintQualityID

| Field | Type | Required |
| --- | --- | --- |
| `name` | string (native field rules) | no |

<a id="schema-circuitconditiondefinition"></a>

## CircuitConditionDefinition

| Field | Type | Required |
| --- | --- | --- |
| `comparator` | [ComparatorString](schemas.md#schema-comparatorstring) | no |
| `constant` | integer −2147483648…2147483647 | no |
| `first_signal` | [SignalID](schemas.md#schema-signalid) | no |
| `second_signal` | [SignalID](schemas.md#schema-signalid) | no |

<a id="schema-circuitnetworkselection"></a>

## CircuitNetworkSelection

| Field | Type | Required |
| --- | --- | --- |
| `green` | boolean | no |
| `red` | boolean | no |

<a id="schema-comparatorstring"></a>

## ComparatorString

`=` or `>` or `<` or `≥` or `>=` or `≤` or `<=` or `≠` or `!=`

<a id="schema-decidercombinatorcondition"></a>

## DeciderCombinatorCondition

| Field | Type | Required |
| --- | --- | --- |
| `comparator` | [ComparatorString](schemas.md#schema-comparatorstring) | no |
| `compare_type` | `and` or `or` | no |
| `constant` | integer −2147483648…2147483647 | no |
| `first_signal` | [SignalID](schemas.md#schema-signalid) | no |
| `first_signal_networks` | [CircuitNetworkSelection](schemas.md#schema-circuitnetworkselection) | no |
| `second_signal` | [SignalID](schemas.md#schema-signalid) | no |
| `second_signal_networks` | [CircuitNetworkSelection](schemas.md#schema-circuitnetworkselection) | no |

<a id="schema-decidercombinatoroutput"></a>

## DeciderCombinatorOutput

| Field | Type | Required |
| --- | --- | --- |
| `constant` | integer −2147483648…2147483647 | no |
| `copy_count_from_input` | boolean | no |
| `networks` | [CircuitNetworkSelection](schemas.md#schema-circuitnetworkselection) | no |
| `signal` | [SignalID](schemas.md#schema-signalid) | yes |

<a id="schema-decidercombinatorparameters"></a>

## DeciderCombinatorParameters

| Field | Type | Required |
| --- | --- | --- |
| `conditions` | dense array of [DeciderCombinatorCondition](schemas.md#schema-decidercombinatorcondition) | yes |
| `outputs` | dense array of [DeciderCombinatorOutput](schemas.md#schema-decidercombinatoroutput) | yes |

<a id="schema-displaypanelmessagedefinition"></a>

## DisplayPanelMessageDefinition

| Field | Type | Required |
| --- | --- | --- |
| `condition` | [CircuitConditionDefinition](schemas.md#schema-circuitconditiondefinition) | yes |
| `icon` | [SignalID](schemas.md#schema-signalid) | yes |
| `text` | string (native field rules) | yes |

<a id="schema-itemcounttype"></a>

## ItemCountType

integer 0…4294967295

<a id="schema-logisticfilter"></a>

## LogisticFilter

| Field | Type | Required |
| --- | --- | --- |
| `import_from` | registered location name string | no |
| `max` | [ItemCountType](schemas.md#schema-itemcounttype) | no |
| `min` | integer −2147483648…2147483647 | no |
| `minimum_delivery_count` | [ItemCountType](schemas.md#schema-itemcounttype) | no |
| `value` | [SignalFilter](schemas.md#schema-signalfilter) | no |

Section filters additionally require `index`: integer 1–65535 (native uint16). The list is dense
but indexes can be sparse. Duplicate indexes/identities refuse; nonzero min
requires explicit exact quality. max must not be below min.

<a id="schema-programmablespeakercircuitparameters"></a>

## ProgrammableSpeakerCircuitParameters

| Field | Type | Required |
| --- | --- | --- |
| `instrument_id` | integer 0…4294967295 | yes |
| `note_id` | integer 0…4294967295 | yes |
| `signal_value_is_pitch` | boolean | yes |
| `stop_playing_sounds` | boolean | yes |

<a id="schema-qualitycondition"></a>

## QualityCondition

{`comparator?`: [ComparatorString](schemas.md#schema-comparatorstring); `quality?`: string (native field rules)} or string (native field rules)

<a id="schema-qualityid"></a>

## QualityID

registered quality name string

<a id="schema-selectorcombinatorparameteroperation"></a>

## SelectorCombinatorParameterOperation

`select` or `count` or `random` or `quality-transfer` or `rocket-capacity` or `stack-size` or `quality-filter`

<a id="schema-selectorcombinatorparameters"></a>

## SelectorCombinatorParameters

| Field | Type | Required |
| --- | --- | --- |
| `operation` | [SelectorCombinatorParameterOperation](schemas.md#schema-selectorcombinatorparameteroperation) | no |

For operation **count** only:

| Field | Type | Required |
| --- | --- | --- |
| `count_signal` | [SignalID](schemas.md#schema-signalid) | no |

For operation **quality-filter** only:

| Field | Type | Required |
| --- | --- | --- |
| `quality_filter` | [QualityCondition](schemas.md#schema-qualitycondition) | no |

For operation **quality-transfer** only:

| Field | Type | Required |
| --- | --- | --- |
| `quality_destination_signal` | [SignalID](schemas.md#schema-signalid) | yes |
| `quality_source_signal` | [SignalIDBase](schemas.md#schema-signalidbase) | no |
| `quality_source_static` | [BlueprintQualityID](schemas.md#schema-blueprintqualityid) | no |
| `select_quality_from_signal` | boolean | no |

For operation **random** only:

| Field | Type | Required |
| --- | --- | --- |
| `random_update_interval` | integer 0…4294967295 | no |

For operation **select** only:

| Field | Type | Required |
| --- | --- | --- |
| `index_constant` | integer −2147483648…2147483647 | no |
| `index_signal` | [SignalID](schemas.md#schema-signalid) | no |
| `select_max` | boolean | no |

<a id="schema-signalfilter"></a>

## SignalFilter

{`comparator?`: [ComparatorString](schemas.md#schema-comparatorstring); `name`: string (native field rules); `quality?`: registered quality name string; `type?`: [SignalIDType](schemas.md#schema-signalidtype)} or string (native field rules)

<a id="schema-signalid"></a>

## SignalID

| Field | Type | Required |
| --- | --- | --- |
| `name` | string (native field rules) | yes |
| `quality` | registered quality name string | no |
| `type` | [SignalIDType](schemas.md#schema-signalidtype) | yes |

<a id="schema-signalidbase"></a>

## SignalIDBase

| Field | Type | Required |
| --- | --- | --- |
| `name` | string (native field rules) | yes |
| `type` | [SignalIDType](schemas.md#schema-signalidtype) | yes |

<a id="schema-signalidtype"></a>

## SignalIDType

`item` or `fluid` or `virtual` or `entity` or `recipe` or `space-location` or `asteroid-chunk` or `quality`

<a id="schema-spacelocationid"></a>

## SpaceLocationID

registered location name string

<a id="schema-boolean"></a>

## boolean

boolean

<a id="schema-float"></a>

## float

finite float32 number

<a id="schema-int32"></a>

## int32

integer −2147483648…2147483647

<a id="schema-nil"></a>

## nil

Absence only, never a stored Data value or implicit clear patch.

<a id="schema-string"></a>

## string

string (native field rules)

<a id="schema-table"></a>

## table

plain table

<a id="schema-uint32"></a>

## uint32

integer 0…4294967295

## Normalization

- Conditions: constant/second_signal exclusive; comparator defaults <, constant 0.
  >=, <=, != normalize to ≥, ≤, ≠. fulfilled is observation-only.
- CircuitNetworkSelection omitted red/green means true for each.
- Arithmetic defaults operation *, missing numeric operands 0; signal operands
  replace corresponding constants. Each output needs each first input.
- Decider compare_type defaults or; output constant defaults 1,
  copy_count_from_input defaults true, networks default both. Each output needs
  an each condition. Ordinary condition first allows anything/everything;
  ordinary second and ordinary signal roots reject wildcards.
- Selector defaults select, index_constant 0, select_max true. count has optional
  count_signal; random defaults random_update_interval 0 (ticks). stack-size
  and rocket-capacity accept no operation-specific fields. quality-filter accepts
  registered quality/quality-comparator; quality-transfer requires destination
  signal, defaults select_quality_from_signal false and static normal; selecting
  signal quality uses quality_source_signal instead of static source.
- SignalFilter/QualityCondition readback includes normal and comparator = defaults.
  BlueprintQualityID defaults name normal. Ordinary signal quality defaults normal.
- LogisticFilter min defaults 0; an omitted item import location uses that item
  prototype's `default_import_location`, when present, not a universal planet.
  Section multiplier readback preserves native float32 precision.
- Native enum values are strings, not defines ordinals. Speaker instrument/note
  IDs are zero-based and validated against the actual target catalogue.

## Native enum names

### defines.control_behavior.cargo_landing_pad.exclusive_mode

`none`, `send_contents`, `set_requests`

### defines.control_behavior.inserter.hand_read_mode

`hold`, `pulse`

### defines.control_behavior.lamp.color_mode

`color_mapping`, `components`, `packed_rgb`

### defines.control_behavior.logistic_container.exclusive_mode

`none`, `send_contents`, `set_requests`

### defines.control_behavior.mining_drill.resource_read_mode

`entire_patch`, `this_miner`

### defines.control_behavior.roboport.read_items_mode

`logistics`, `missing_requests`, `none`

### defines.control_behavior.rocket_silo.read_mode

`logistic_inventory`, `none`, `orbital_requests`

### defines.control_behavior.transport_belt.content_read_mode

`entire_belt_hold`, `hold`, `pulse`

### defines.logistic_section_type

`circuit_controlled`, `manual`, `request_missing_materials_controlled`, `transitional_request_controlled`

### defines.wire_connector_id

`circuit_green`, `circuit_red`, `combinator_input_green`, `combinator_input_red`, `combinator_output_green`, `combinator_output_red`, `pole_copper`, `power_switch_left_copper`, `power_switch_right_copper`
