"""Documentation-only projection of normalized Configurator schemas."""
import copy
import json

# Meanings live beside the normalizer, not in a second signature/type catalogue.
FIELDS = {
    'output_signal': 'Signal used for this control behavior output (charge, gate sensor or combinator result).',
    'read_charge': 'Publish accumulator charge percentage to the circuit network.',
    'circuit_condition': 'Circuit comparison used by this native control behavior.',
    'circuit_enable_disable': 'Let the circuit condition control the entity enable state.',
    'connect_to_logistic_network': 'Enable the native logistic-network connection where applicable.',
    'logistic_condition': 'Logistic-network comparison; clearing uses native reset semantics.',
    'read_contents': 'Publish this entity inventory or fluid contents; belt mode is separately selected.',
    'parameters': 'Complete combinator parameter object, replacing rather than merging its prior fields.',
    'read_ammo': 'Publish contained ammunition/fluid; unavailable on an electric turret.',
    'circuit_read_contents': 'Publish ingredient/product/in-crafting contents and supported native inventories.',
    'circuit_read_ingredients': 'Publish the current recipe ingredient requirements as signals.',
    'circuit_read_recipe_finished': 'Publish the recipe-completion signal when a craft finishes.',
    'circuit_read_working': 'Publish the working-state signal.',
    'circuit_recipe_finished_signal': 'Signal identity used for recipe completion.',
    'circuit_set_recipe': 'Select the machine recipe from circuit signals.',
    'circuit_working_signal': 'Signal identity used for working state.',
    'include_fuel': 'Include the fuel inventory; compatibility name maps to native 2.1 read_fuel.',
    'include_in_crafting': 'Include materials currently committed to crafting.',
    'include_hands': 'Include asteroid contents captured in collector hands.',
    'read_content': 'Publish asteroid collector contents to the circuit network.',
    'set_filter': 'Select this native entity fluid/item filter from circuit signals.',
    'circuit_exclusive_mode_of_operation': 'Compatibility mode combining native read_contents and set_requests switches; both uses send_contents_and_set_requests.',
    'enabled': 'Enable the constant combinator output.',
    'messages': 'Complete display-panel message list; compatibility name maps to native 2.1 records.',
    'circuit_hand_read_mode': 'Choose hold versus pulse for inserter hand-content reporting.',
    'circuit_read_hand_contents': 'Publish inserter hand contents.',
    'circuit_set_filters': 'Select inserter/loader filters from circuit signals.',
    'circuit_set_stack_size': 'Use the configured stack-control signal to set inserter stack size.',
    'circuit_stack_control_signal': 'Signal whose count controls inserter stack size.',
    'blue_signal': 'Blue color-component input for lamps, or blue-state output for chain signals.',
    'color_mode': 'Select lamp color-mapping, separate-component or packed-RGB interpretation.',
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
    'read_items_mode': 'Select logistics contents, missing requests or no item reporting.',
    'read_logistics': 'Legacy logistics-content reporting switch; prefer read_items_mode.',
    'read_robot_stats': 'Publish native logistic/construction robot statistics.',
    'roboport_count_output_signal': 'Signal carrying the roboport count.',
    'total_construction_output_signal': 'Signal for total construction robots.',
    'total_logistic_output_signal': 'Signal for total logistic robots.',
    'read_mode': 'Select rocket-silo logistic inventory, orbital requests or no reporting.',
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
    'set_priority_list': 'Derive turret target priorities from circuit signals.',
    'open_gate': 'Control the associated gate using the circuit condition.',
    'read_sensor': 'Publish the associated gate sensor state.',
    'first_constant': 'First numeric operand; a supplied first_signal takes precedence in normalization.',
    'first_signal': 'First signal operand; wildcard permission depends on its enclosing concept/role.',
    'first_signal_networks': 'Networks contributing to the first operand; omitted members normalize true.',
    'operation': 'Exact operation discriminator; only that variant fields are accepted.',
    'second_constant': 'Second numeric operand; second_signal takes precedence in arithmetic normalization.',
    'second_signal': 'Second signal operand; wildcard pseudo-signals are not accepted here.',
    'second_signal_networks': 'Networks contributing to the second operand; omitted members normalize true.',
    'name': 'Exact prototype/quality identity named by the enclosing concept; no localization lookup.',
    'quality': 'Exact installed quality name; normalization defaults normal where this concept permits omission.',
    'type': 'Signal prototype namespace; SignalID/SignalIDBase require an explicit input type.',
    'comparator': 'Comparison symbol; >=, <= and != normalize to ≥, ≤ and ≠.',
    'constant': 'Numeric operand or output count; enclosing concept determines the normalization default.',
    'green': 'Include green circuit values; omitted member normalizes true.',
    'red': 'Include red circuit values; omitted member normalizes true.',
    'compare_type': 'Join this decider condition using and/or; default or.',
    'copy_count_from_input': 'Copy decider input count rather than fixed constant; default true.',
    'networks': 'Decider-output contributing networks; default includes both.',
    'signal': 'Decider output signal, required on input but absent in a cleared native output. An each signal requires an each condition.',
    'conditions': 'Complete ordered decider condition array.',
    'outputs': 'Complete ordered decider output array.',
    'condition': 'Display-message visibility condition.',
    'icon': 'Display-message signal icon identity.',
    'text': 'Display-message text, bounded and without NUL.',
    'import_from': 'Installed import location; current adapter defaults item imports to registered nauvis when available.',
    'max': 'Maximum requested count, not below a supplied minimum.',
    'min': 'Minimum requested count; defaults zero. Nonzero filtered counts require exact quality.',
    'minimum_delivery_count': 'Minimum native delivery quantity for this filter.',
    'value': 'Signal filter; absent value means an empty slot, not a numeric zero signal.',
    'instrument_id': 'Zero-based native instrument index, validated against this target speaker.',
    'note_id': 'Zero-based note index in the selected target instrument.',
    'signal_value_is_pitch': 'Use the circuit signal value as the native note pitch index.',
    'stop_playing_sounds': 'Native circuit-speaker stop-playing switch.',
    'count_signal': 'Optional selector count-output signal, only for count operation.',
    'quality_filter': 'Installed quality/comparator selector filter, only for quality-filter.',
    'quality_destination_signal': 'Quality-transfer destination signal; required on input but may be absent in native readback.',
    'quality_source_signal': 'Quality-transfer source when selecting quality from a signal.',
    'quality_source_static': 'Static quality-transfer source; default normal when not using a signal.',
    'select_quality_from_signal': 'Choose signal quality rather than static quality; default false.',
    'random_update_interval': 'Selector random refresh interval in simulation ticks; default zero.',
    'index_constant': 'Selector constant index; defaults zero when no index signal is supplied.',
    'index_signal': 'Selector index signal; when supplied normalization omits index_constant.',
    'select_max': 'Select from maximum rather than minimum end; default true.',
    'active': 'Section activation; addSection default true.',
    'group': 'Shared-group name; empty string is local and is addSection default.',
    'multiplier': 'Section output multiplier; addSection default 1, readback uses native float32 precision.',
    'filters': 'Complete section filter replacement; addSection defaults empty only for a local group.',
    'index': 'Explicit native filter slot index; sparse slots allowed in a dense unique-index array.',
}
NOTES = {
    'SignalID': 'Explicit type/name required on input; output includes explicit type/name/quality. Default quality normal. Wildcards depend on role, not general SignalID permission.',
    'SignalIDBase': 'Explicit type/name required; no quality member. Native references become exact installed names.',
    'CircuitConditionDefinition': 'constant and second_signal are exclusive. Default comparator < and constant 0 without a second signal. fulfilled is read-only and excluded. First operand permits anything/everything but not each; ordinary second/root signals reject wildcards.',
    'CircuitNetworkSelection': 'Omitted object or red/green members normalize to both colors enabled.',
    'ArithmeticCombinatorParameters': 'Default operation *, missing numeric operands 0, networks both. Signal operands replace corresponding constants. First each and output each are allowed; each output requires each first input.',
    'DeciderCombinatorCondition': 'Default comparator <, constant 0 without a second signal, compare_type or and both networks. First operand allows role-appropriate each/anything/everything.',
    'DeciderCombinatorOutput': 'Input requires an output signal; cleared native readback can omit it. Default constant 1, copy_count_from_input true and both networks. An each signal needs an each condition in the same parameters.',
    'DeciderCombinatorParameters': 'Complete required conditions/outputs arrays replace previous parameters. Each output requires an each first condition.',
    'SelectorCombinatorParameters': 'Default operation select. select defaults index_constant 0 and select_max true; a signal index replaces the constant. random defaults interval 0 ticks. Input quality-transfer requires quality_destination_signal, while native readback can omit it; defaults select_quality_from_signal false and static normal. Readback keeps only the selected source. stack-size and rocket-capacity have no operation-specific fields.',
    'QualityCondition': 'Input accepts a registered quality string or object. Readback is an object with explicit quality (default normal) and comparator (default =); comparator aliases normalize.',
    'SignalFilter': 'Input accepts a signal name string or object. String names select virtual when registered there, otherwise item. Object type defaults item. Readback always has name/type/quality/comparator, defaults normal and =. Wildcards are refused.',
    'BlueprintQualityID': 'Quality name defaults to installed normal; no native prototype object is exposed.',
    'LogisticFilter': 'Default minimum 0; current adapter defaults item import_from to registered nauvis when available. Maximum cannot be below minimum. Nonzero object-filter minimum requires explicit exact quality. Section filters additionally require index and reject duplicate slots/effective identities.',
    'ProgrammableSpeakerCircuitParameters': 'These native circuit settings are independent of Speaker API playback. Instrument/note indexes are zero-based and checked on the target.',
}
CONSTRAINTS = {
    'registered_signal': 'Installed signal identity required.',
    'explicit_signal_type': 'Input signal type must be explicit.',
    'condition_operand_exclusive': 'constant and second_signal cannot both be supplied.',
    'condition_signal_roles': 'Only role-appropriate wildcard signals are allowed.',
    'operation_variant': 'Only fields belonging to the selected operation are allowed.',
    'logistic_mode_requester_or_buffer': 'Writable only on requester/buffer containers.',
    'fuel_inventory_required': 'Requires an actual native fuel inventory.',
    'rail_chain_signal_only': 'Available only on chain signals; ordinary rail signals cannot read/write it.',
    'native_asteroid_no_logistic_connection': 'Native inherited connection switch is ineffective and not writable.',
    'ammo_or_fluid_turret_required': 'Requires an ammo/fluid turret, not an electric turret.',
    'set_requests_requires_space_travel': 'Request-setting modes require the space-travel feature; otherwise only none/send_contents.',
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
                    notes.append('Finite native numeric readback; generic Data limits still apply.')
                else:
                    notes.append('Finite ' + s['kind'] + '; domain ' + str(s.get('min', -9007199254740991)) + '..' + str(s.get('max', 9007199254740991)) + '.')
            if 'max_bytes' in s:
                notes.append(f"At most {s['max_bytes']} bytes; no NUL.")
            if 'max_items' in s:
                notes.append(f"Dense array of at most {s['max_items']} entries.")
            if s.get('additional_fields') is False:
                notes.append('Unknown fields refused.')
            if 'prototype_registry' in s:
                notes.append('Installed ' + s['prototype_registry'] + ' name, never a native object.')
            for code in s.get('constraints', []):
                notes.append(code + ': ' + CONSTRAINTS[code])
            if 'clearable' in s:
                notes.append('Explicit root patch clear: ' + ('accepted with native reset/readback' if s['clearable'] else 'not supported') + '.')
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
                details += ' Operation ' + variant + ' permits ' + ', '.join(spec['fields']) + '; required: ' + (', '.join(spec['required']) or 'none') + '.'
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
            families.append(emit(schema, prefix + name, 'Root settings for ' + name + '. All roots may be unset; inspect live capabilities before access.'))
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
        emit(section, prefix + 'SectionValues', 'Section values. Addition defaults active=true, group empty, multiplier=1; local filters empty. Group joins inherit shared filters.')
        lines += ['---' + ('Normalized current root values; unset roots are absent.' if readback else 'Root setting replacements; select the actual behavior via live capabilities.'),
                  '---@alias ' + prefix + 'Values ' + '|'.join(families), '']
    for native, name in (('wire_connector_id', 'TC.WireConnectorId'),
                         ('logistic_section_type', 'TC.LogisticSectionType')):
        values = metadata['catalog']['enum_values']['defines.' + native]
        lines.extend(['---Native ' + native + ' symbolic names, never host enum ordinals.',
                      '---@alias ' + name + ' ' + '|'.join(json.dumps(v) for v in values), ''])
    return '\n'.join(lines)
