"""Documentation-only projection of normalized Configurator schemas."""
import copy
import json

# Meanings live beside the normalizer, not in a second signature/type catalogue.
FIELDS = {
    'output_signal': 'Output signal for this control behavior: accumulator charge, gate sensor, or combinator result.',
    'read_charge': 'Publish accumulator charge percentage to the circuit network.',
    'circuit_condition': 'Circuit comparison used by this native control behavior.',
    'circuit_enable_disable': 'Let the circuit condition control the entity enable state.',
    'connect_to_logistic_network': 'Enable the native logistic-network connection where applicable.',
    'logistic_condition': 'Logistic-network comparison. Clearing uses native reset rules.',
    'read_contents': 'Publish this entity inventory or fluid contents. Belt mode is selected separately.',
    'parameters': 'Complete combinator parameter object. It replaces previous fields; it does not merge them.',
    'read_ammo': 'Publish contained ammunition or fluid. This field is unavailable on an electric turret.',
    'circuit_read_contents': 'Publish ingredient, product, and in-crafting contents and supported native inventories.',
    'circuit_read_ingredients': 'Publish the current recipe ingredient requirements as signals.',
    'circuit_read_recipe_finished': 'Publish the recipe-completion signal when a craft finishes.',
    'circuit_read_working': 'Publish the working-state signal.',
    'circuit_recipe_finished_signal': 'Signal identity used for recipe completion.',
    'circuit_set_recipe': 'Select the machine recipe from circuit signals.',
    'circuit_working_signal': 'Signal identity used for working state.',
    'include_fuel': 'Include the fuel inventory. This compatibility name maps to native 2.1 read_fuel.',
    'include_in_crafting': 'Include materials already committed to crafting.',
    'include_hands': 'Include asteroid contents captured in collector hands.',
    'read_content': 'Publish asteroid collector contents to the circuit network.',
    'set_filter': 'Select this native entity fluid or item filter from circuit signals.',
    'circuit_exclusive_mode_of_operation': 'Compatibility mode for native read_contents and set_requests switches. Their combined mode is send_contents_and_set_requests.',
    'enabled': 'Enable the constant combinator output.',
    'messages': 'Complete display-panel message list. This compatibility name maps to native 2.1 records.',
    'circuit_hand_read_mode': 'Select hold or pulse for reporting inserter hand contents.',
    'circuit_read_hand_contents': 'Publish inserter hand contents.',
    'circuit_set_filters': 'Select inserter or loader filters from circuit signals.',
    'circuit_set_stack_size': 'Use the configured stack-control signal to set inserter stack size.',
    'circuit_stack_control_signal': 'Signal whose count controls inserter stack size.',
    'blue_signal': 'Blue color-component input for lamps, or blue-state output for chain signals.',
    'color_mode': 'Select lamp color-mapping, separate-component, or packed-RGB interpretation.',
    'green_signal': 'Green color-component input for lamps, or green-state rail output.',
    'red_signal': 'Red color-component input for lamps, or red-state rail output.',
    'rgb_signal': 'Signal carrying packed lamp RGB.',
    'use_colors': 'Enable circuit-selected lamp color.',
    'circuit_read_transfers': 'Pulse loader-to-container transfer counts to the circuit network.',
    'circuit_condition_enabled': 'Apply the logistic container circuit condition.',
    'circuit_read_resources': 'Publish mining resource amounts selected by resource_read_mode.',
    'resource_read_mode': 'Select this miner area versus the whole resource patch.',
    'circuit_parameters': 'Native circuit-triggered speaker settings, separate from the Speaker playback API.',
    'close_signal': 'Close the rail signal according to its circuit condition.',
    'orange_signal': 'Signal representing an orange rail-signal state.',
    'read_signal': 'Publish the native rail-signal state.',
    'read_fuel': 'Publish reactor fuel inventory and currently burning fuel.',
    'read_temperature': 'Publish reactor temperature.',
    'temperature_signal': 'Signal carrying reactor temperature.',
    'available_construction_output_signal': 'Signal for available construction robots.',
    'available_logistic_output_signal': 'Signal for available logistic robots.',
    'read_items_mode': 'Select logistics contents, missing requests, or no item reporting.',
    'read_logistics': 'Legacy switch for reporting logistics contents. Prefer read_items_mode.',
    'read_robot_stats': 'Publish native statistics for logistic and construction robots.',
    'roboport_count_output_signal': 'Signal carrying the roboport count.',
    'total_construction_output_signal': 'Signal for total construction robots.',
    'total_logistic_output_signal': 'Signal for total logistic robots.',
    'read_mode': 'Select rocket-silo logistic inventory, orbital requests, or no reporting.',
    'damage_taken_signal': 'Signal carrying platform damage taken.',
    'read_damage_taken': 'Publish platform damage taken.',
    'read_moving_from': 'Publish the current platform connection origin.',
    'read_moving_to': 'Publish the current platform connection destination.',
    'read_speed': 'Publish current platform speed.',
    'send_to_platform': 'Make circuit signals available to platform schedule conditions.',
    'speed_signal': 'Signal carrying current platform speed.',
    'input_left_condition': 'Condition selecting the splitter left input side.',
    'input_right_condition': 'Condition selecting the splitter right input side.',
    'output_left_condition': 'Condition selecting the splitter left output side.',
    'output_right_condition': 'Condition selecting the splitter right output side.',
    'set_input_side': 'Let native circuit conditions select splitter input priority.',
    'set_output_side': 'Let native circuit conditions select splitter output priority.',
    'priority_signal': 'Signal controlling train-stop priority.',
    'read_from_train': 'Publish stopped-train contents to the circuit network.',
    'read_stopped_train': 'Publish the stopped train identity signal.',
    'read_trains_count': 'Publish the count of trains assigned to this stop.',
    'send_to_train': 'Supply circuit signals to the stopped train.',
    'set_priority': 'Enable signal-controlled train-stop priority.',
    'set_trains_limit': 'Enable signal-controlled incoming-train limit.',
    'stopped_train_signal': 'Signal carrying stopped train identity.',
    'trains_count_signal': 'Signal carrying the incoming-train count.',
    'trains_limit_signal': 'Signal controlling the incoming-train limit.',
    'read_contents_mode': 'Select belt pulse, local hold or whole-belt hold reporting.',
    'ignore_unlisted_targets_condition': 'Condition for ignoring targets outside the turret priority list.',
    'set_ignore_unlisted_targets': 'Enable condition-controlled exclusion of unlisted targets.',
    'set_priority_list': 'Get turret target priorities from circuit signals.',
    'open_gate': 'Control the associated gate using the circuit condition.',
    'read_sensor': 'Publish the associated gate sensor state.',
    'first_constant': 'First numeric operand. A supplied first_signal replaces this constant during normalization.',
    'first_signal': 'First signal operand. Wildcard permission depends on the enclosing concept and role.',
    'first_signal_networks': 'Networks that supply the first operand. An omitted member becomes true during normalization.',
    'operation': 'Exact operation discriminator. Only fields for that variant are accepted.',
    'second_constant': 'Second numeric operand. A supplied second_signal replaces this constant during arithmetic normalization.',
    'second_signal': 'Second signal operand. Wildcard pseudo-signals are not accepted here.',
    'second_signal_networks': 'Networks that supply the second operand. An omitted member becomes true during normalization.',
    'name': 'Exact prototype or quality identity for the enclosing concept. No localization lookup occurs.',
    'quality': 'Exact installed quality name. Normalization uses normal when this concept permits omission.',
    'type': 'Signal prototype namespace. SignalID and SignalIDBase require an explicit input type.',
    'comparator': 'Comparison symbol. >=, <=, and != normalize to ≥, ≤, and ≠.',
    'constant': 'Numeric operand or output count. The enclosing concept determines the normalization default.',
    'green': 'Include green circuit values. An omitted member becomes true during normalization.',
    'red': 'Include red circuit values. An omitted member becomes true during normalization.',
    'compare_type': 'Join this decider condition with and or or. The default is or.',
    'copy_count_from_input': 'Copy the decider input count instead of using a fixed constant. The default is true.',
    'networks': 'Networks that supply decider outputs. The default includes both.',
    'signal': 'Decider output signal. It is required on input but can be absent in a cleared native output. An each signal requires an each condition.',
    'conditions': 'Complete ordered decider condition array.',
    'outputs': 'Complete ordered decider output array.',
    'condition': 'Display-message visibility condition.',
    'icon': 'Display-message signal icon identity.',
    'text': 'Display-message text within its byte limit. NUL is not permitted.',
    'import_from': 'Installed import location. The current adapter uses registered nauvis for item imports by default when available.',
    'max': 'Maximum requested count. This cannot be less than a supplied minimum.',
    'min': 'Minimum requested count. The default is zero. A nonzero filtered count requires exact quality.',
    'minimum_delivery_count': 'Minimum native delivery quantity for this filter.',
    'value': 'Signal filter. An absent value means an empty slot, not a numeric zero signal.',
    'instrument_id': 'Zero-based native instrument index. The target speaker determines valid indexes.',
    'note_id': 'Zero-based note index in the selected target instrument.',
    'signal_value_is_pitch': 'Use the circuit signal value as the native note pitch index.',
    'stop_playing_sounds': 'Native circuit-speaker stop-playing switch.',
    'count_signal': 'Optional selector count-output signal. This applies only to the count operation.',
    'quality_filter': 'Installed quality and comparator selector filter. This applies only to quality-filter.',
    'quality_destination_signal': 'Quality-transfer destination signal. Input requires this field; native readback can omit it.',
    'quality_source_signal': 'Quality-transfer source when selecting quality from a signal.',
    'quality_source_static': 'Static quality-transfer source. The default is normal when a signal is not used.',
    'select_quality_from_signal': 'Select quality from a signal instead of static quality. The default is false.',
    'random_update_interval': 'Selector random refresh interval in simulation ticks. The default is zero.',
    'index_constant': 'Selector constant index. The default is zero when no index signal is supplied.',
    'index_signal': 'Selector index signal. When supplied, normalization omits index_constant.',
    'select_max': 'Select from the maximum end instead of the minimum end. The default is true.',
    'active': 'Section activation. The addSection default is true.',
    'group': 'Shared-group name. An empty string means local. This is the addSection default.',
    'multiplier': 'Section output multiplier. The addSection default is 1. Readback uses native float32 precision.',
    'filters': 'Complete replacement for section filters. The addSection default is empty only for a local group.',
    'index': 'Explicit native filter slot index. A dense array can contain sparse slot indexes, but each index must be unique.',
}
NOTES = {
    'SignalID': 'Input requires explicit type and name. Output includes explicit type, name, and quality. The default quality is normal. Wildcard permission depends on the role, not general SignalID permission.',
    'SignalIDBase': 'Explicit type and name are required. There is no quality member. Native references become exact installed names.',
    'CircuitConditionDefinition': 'constant and second_signal cannot both be supplied. The default comparator is <. Without a second signal, constant defaults to 0. fulfilled is read-only and excluded. The first operand permits anything and everything, but not each. Ordinary second and root signals reject wildcards.',
    'CircuitNetworkSelection': 'An omitted object or omitted red and green members become both colors enabled during normalization.',
    'ArithmeticCombinatorParameters': 'The default operation is *. Missing numeric operands default to 0. Both networks are enabled by default. Signal operands replace their corresponding constants. The first and output signals can be each. An each output requires an each first input.',
    'DeciderCombinatorCondition': 'The default comparator is <. Without a second signal, constant defaults to 0. compare_type defaults to or. Both networks are enabled by default. The first operand permits each, anything, or everything where its role permits that wildcard.',
    'DeciderCombinatorOutput': 'Input requires an output signal. Cleared native readback can omit it. The default constant is 1. copy_count_from_input defaults to true. Both networks are enabled by default. An each signal requires an each condition in the same parameters.',
    'DeciderCombinatorParameters': 'Complete required conditions and outputs arrays replace previous parameters. Each output requires an each first condition.',
    'SelectorCombinatorParameters': 'The default operation is select. For select, index_constant defaults to 0 and select_max defaults to true. A signal index replaces the constant. For random, the interval defaults to 0 ticks. Input quality-transfer requires quality_destination_signal; native readback can omit it. select_quality_from_signal defaults to false. Static quality defaults to normal. Readback keeps only the selected source. stack-size and rocket-capacity have no operation-specific fields.',
    'QualityCondition': 'Input accepts a registered quality string or object. Readback is an object with explicit quality and comparator. Quality defaults to normal. The comparator defaults to =. Comparator aliases normalize.',
    'SignalFilter': 'Input accepts a signal name string or object. A string name selects virtual when registered there; otherwise, it selects item. The object type defaults to item. Readback always has name, type, quality, and comparator. Quality defaults to normal. The comparator defaults to =. Wildcards are refused.',
    'BlueprintQualityID': 'The quality name defaults to installed normal. No native prototype object is exposed.',
    'LogisticFilter': 'The minimum defaults to 0. The current adapter uses registered nauvis for item import_from by default when available. The maximum cannot be less than the minimum. A nonzero minimum in an object filter requires explicit exact quality. Section filters also require index. Duplicate slots and effective identities are refused.',
    'ProgrammableSpeakerCircuitParameters': 'These native circuit settings are independent of Speaker API playback. Instrument and note indexes are zero-based. The target determines valid indexes.',
}
CONSTRAINTS = {
    'registered_signal': 'An installed signal identity is required.',
    'explicit_signal_type': 'Input signal type must be explicit.',
    'condition_operand_exclusive': 'constant and second_signal cannot both be supplied.',
    'condition_signal_roles': 'Only wildcard signals permitted for this role are allowed.',
    'operation_variant': 'Only fields for the selected operation are allowed.',
    'logistic_mode_requester_or_buffer': 'Writable only on requester or buffer containers.',
    'fuel_inventory_required': 'An actual native fuel inventory is required.',
    'rail_chain_signal_only': 'Available only on chain signals. Ordinary rail signals cannot read or write this field.',
    'native_asteroid_no_logistic_connection': 'The inherited native connection switch has no effect and is not writable.',
    'ammo_or_fluid_turret_required': 'An ammunition or fluid turret is required. An electric turret is not permitted.',
    'set_requests_requires_space_travel': 'Modes that set requests require the space-travel feature. Otherwise, only none and send_contents are available.',
}


def read_schema(source):
    """Document the explicit defaults/projections in validation.normal, not execute it."""
    s = copy.deepcopy(source)
    # Native readback is not validated against the caller-input size ceilings.
    s.pop('max_bytes', None)
    s.pop('max_items', None)
    concept = s.get('concept')
    if concept in ('SignalFilter', 'QualityCondition'):
        s = copy.deepcopy(next(x for x in s['alternatives'] if x['kind'] == 'object'))
        s['concept'] = concept
    for key, value in s.get('fields', {}).items():
        s['fields'][key] = read_schema(value)
    if 'items' in s:
        s['items'] = read_schema(s['items'])
    if 'alternatives' in s:
        s['alternatives'] = [read_schema(x) for x in s['alternatives']]
    required = {
        'SignalID': ['type', 'name', 'quality'], 'SignalIDBase': ['type', 'name'],
        'SignalFilter': ['type', 'name', 'quality', 'comparator'],
        'QualityCondition': ['quality', 'comparator'], 'CircuitNetworkSelection': ['red', 'green'],
        'CircuitConditionDefinition': ['comparator'],
        'ArithmeticCombinatorParameters': ['operation', 'first_signal_networks', 'second_signal_networks'],
        'DeciderCombinatorCondition': ['comparator', 'compare_type', 'first_signal_networks', 'second_signal_networks'],
        'DeciderCombinatorOutput': ['constant', 'copy_count_from_input', 'networks'],
        'SelectorCombinatorParameters': ['operation'], 'BlueprintQualityID': ['name'], 'LogisticFilter': ['min'],
    }
    if concept in required:
        s['required'] = sorted(set(s.get('required', [])) | set(required[concept]))
    if concept == 'DeciderCombinatorOutput':
        s['required'].remove('signal')
    if concept == 'ComparatorString':
        s['values'] = [value for value in s['values'] if value not in ('>=', '<=', '!=')]
    if concept == 'SelectorCombinatorParameters':
        defaults = {'select': ['select_max'], 'random': ['random_update_interval'],
                    'quality-transfer': ['select_quality_from_signal']}
        for operation, variant in s['variants'].items():
            variant['required'] = defaults.get(operation, [])
    return s


def typed_declarations(result, metadata):
    lines = ['---@meta', '-- Generated by tools/configuration_catalog.py; do not edit.',
             '-- Historical inventory sha256: ' + result['source_sha256'],
             '-- Guest normalization: scripts/configuration/validation.lua and adapters.lua.', '']
    for readback in (False, True):
        prefix = 'TC.Config.Read.' if readback else 'TC.Config.'
        concepts = {k: (read_schema(v) if readback else v) for k, v in result['concepts'].items()
                    if k not in ('boolean', 'float', 'int32', 'nil', 'string', 'table', 'uint32')}
        emitted = set()

        def domain(s):
            notes = []
            if s['kind'] in ('integer', 'number'):
                if readback and 'min' not in s and 'max' not in s:
                    notes.append('Native numeric readback must be finite. Generic Data limits still apply.')
                else:
                    notes.append('Finite ' + s['kind'] + '. Domain: ' + str(s.get('min', -9007199254740991)) + '..' + str(s.get('max', 9007199254740991)) + '.')
            if 'max_bytes' in s:
                notes.append(f"At most {s['max_bytes']} bytes. NUL is not permitted.")
            if 'max_items' in s:
                notes.append(f"Dense array of at most {s['max_items']} entries.")
            if s.get('additional_fields') is False:
                notes.append('Unknown fields are refused.')
            if 'prototype_registry' in s:
                notes.append('Use an installed ' + s['prototype_registry'] + ' name, not a native object.')
            for code in s.get('constraints', []):
                notes.append(code + ': ' + CONSTRAINTS[code])
            if 'clearable' in s:
                notes.append('Explicit root patch clear: ' + ('accepted with native reset and readback' if s['clearable'] else 'not supported') + '.')
            return ' '.join(notes)

        def shape(s):
            if isinstance(s, dict):
                return {k: shape(v) for k, v in s.items() if k not in ('readable', 'writable', 'clearable')}
            return [shape(v) for v in s] if isinstance(s, list) else s

        def emit(s, name, description):
            concept = s.get('concept')
            if concept in concepts and name != prefix + concept and shape(s) == shape(concepts[concept]):
                return prefix + concept
            kind = s['kind']
            if s.get('variants'):
                if concept != 'SelectorCombinatorParameters':
                    raise ValueError('unsupported public configuration variants: ' + str(concept))
                if name in emitted:
                    return name
                emitted.add(name)
                variants = []
                for operation in s['fields']['operation']['values']:
                    specification = s['variants'].get(operation, {'fields': [], 'required': []})
                    variant = copy.deepcopy(s)
                    variant.pop('variants')
                    variant.pop('concept')
                    variant['fields'] = {key: value for key, value in variant['fields'].items()
                                         if key == 'operation' or key in specification['fields']}
                    variant['fields']['operation'] = {'kind': 'enum', 'values': [operation]}
                    variant['required'] = list(specification['required'])
                    if readback or operation != 'select':
                        variant['required'].append('operation')
                    suffix = ''.join(word.title() for word in operation.split('-'))
                    variants.append(emit(variant, name + '.' + suffix,
                                         description + ' Operation ' + operation + '. ' + NOTES[concept]))
                lines.extend(['---' + description + ' ' + NOTES[concept],
                              '---@alias ' + name + ' ' + '|'.join(variants), ''])
                return name
            if kind in ('boolean', 'number', 'integer', 'string'):
                value_type = kind
            elif kind == 'enum':
                value_type = '|'.join(json.dumps(v, ensure_ascii=False) for v in s['values'])
            elif kind == 'array':
                value_type = '(' + emit(s['items'], name + '.Item', 'Array item. ' + domain(s['items'])) + ')[]'
            elif kind == 'union':
                value_type = '|'.join(emit(v, name + '.Variant' + str(i), 'Union alternative. ' + domain(v)) for i, v in enumerate(s['alternatives'], 1))
            elif kind == 'object':
                value_type = name
            else:
                raise ValueError('unsupported public configuration schema: ' + kind)
            # Scalar/array/union uses remain inline unless this is a named concept.
            if kind != 'object' and name not in {prefix + k for k in concepts}:
                return value_type
            if name in emitted:
                return name
            emitted.add(name)
            fields = []
            for key, child in sorted(s.get('fields', {}).items()):
                fields.append((key, child, emit(child, name + '.' + key, FIELDS[key] + ' ' + domain(child))))
            details = description + ' ' + domain(s) + ' ' + NOTES.get(concept or name.removeprefix(prefix), '')
            for variant, spec in sorted(s.get('variants', {}).items()):
                details += ' Operation ' + variant + ' permits ' + ', '.join(spec['fields']) + '. Required fields: ' + (', '.join(spec['required']) or 'none') + '.'
            lines.extend(['---' + details.strip(), ('---@class ' if kind == 'object' else '---@alias ') + name + ('' if kind == 'object' else ' ' + value_type)])
            for key, child, typ in fields:
                optional = '?' if key not in s.get('required', []) else ''
                lines.append(('---@field ' + key + optional + ' ' + typ + ' ' + FIELDS[key] + ' ' + domain(child)).rstrip())
            lines.append('')
            return name

        for key, s in sorted(concepts.items()):
            emit(s, prefix + key, ('Normalized readback for ' if readback else 'Accepted input for ') + key + '.')
        families = []
        for name, fields in sorted(result['schemas'].items()):
            schema = {'kind': 'object', 'fields': fields, 'required': [], 'additional_fields': False}
            if readback:
                schema = read_schema(schema)
            families.append(emit(schema, prefix + name, 'Root settings for ' + name + '. All roots can be unset. Examine live capabilities before access.'))
        section = {'kind': 'object', 'fields': copy.deepcopy(result['section_fields']), 'required': [], 'additional_fields': False}
        section['fields']['filters']['items'].pop('concept', None)
        filter_schema = section['fields']['filters']['items']
        if readback:
            section = read_schema(section)
            filter_schema = section['fields']['filters']['items']
            filter_schema['required'] = sorted(set(filter_schema['required']) | {'value', 'min'})
        # Public section filters add indexes; they are not ordinary LogisticFilter.
        emit(filter_schema, prefix + 'SectionFilter', 'Indexed native section filter. Dense array with unique slot indexes and effective identities. ' + NOTES['LogisticFilter'])
        section['fields']['filters']['items'] = dict(filter_schema, concept='SectionFilter')
        concepts['SectionFilter'] = section['fields']['filters']['items']
        emit(section, prefix + 'SectionValues', 'Section values. Addition defaults: active=true, empty group, multiplier=1, and empty local filters. Group joins inherit shared filters.')
        lines += ['---' + ('Normalized current root values. Unset roots are absent.' if readback else 'Root setting replacements. Select the actual behavior through live capabilities.'),
                  '---@alias ' + prefix + 'Values ' + '|'.join(families), '']
    for native, name in (('wire_connector_id', 'TC.WireConnectorId'),
                         ('logistic_section_type', 'TC.LogisticSectionType')):
        values = metadata['catalog']['enum_values']['defines.' + native]
        lines.extend(['---Native ' + native + ' symbolic names, never host enum ordinals.',
                      '---@alias ' + name + ' ' + '|'.join(json.dumps(v) for v in values), ''])
    return '\n'.join(lines)
