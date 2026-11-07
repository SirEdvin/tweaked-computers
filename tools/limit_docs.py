"""Derive declaration fields from the existing closed limit tables, not copies."""
import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DESCRIPTIONS = {
    'api_version': 'Guest API representation version. This is not a capacity.',
    'compiler_version': 'Saved compiler representation version. This is not a capacity.',
    'storage_version': 'Saved storage representation version. This is not a capacity.',
    'source_bytes': 'Maximum number of bytes in saved program source.',
    'source_nodes': 'Maximum number of parsed source nodes.',
    'source_tokens': 'Maximum number of parsed source tokens.',
    'source_nesting': 'Maximum nesting depth of source syntax.',
    'handler_names': 'Maximum number of exported handler names in one program.',
    'identifier_bytes': 'Maximum bytes in an ordinary identifier or label. Individual APIs can have different limits.',
    'compile_work': 'Shared work units for validation and reconstruction per computer per tick.',
    'host_work_per_tick': 'Maximum world source/API/host work, not ordinary Lua execution. Reserved maintenance is included, not additional.',
    'active_computers': 'Maximum number of saved programs that can be active at the same time.',
    'aggregate_subscriptions': 'Maximum number of subscription registrations in the world.',
    'state_bytes': 'Accounting bytes for retained application Data per computer, including metadata.',
    'state_entries': 'Maximum number of explicit state keys per computer.',
    'data_nodes': 'Maximum nodes in a generic Data graph. Native Logic transfer is exempt.',
    'data_depth': 'Maximum nesting depth of generic Data. Native Logic transfer is exempt.',
    'string_bytes': 'Maximum bytes in an ordinary Data string, not a temporary Lua string.',
    'table_entries': 'Maximum entries in an ordinary Data table, not a temporary Lua table. Native Logic transfer remains separate.',
    'event_queue_entries': 'Maximum pending event entries per computer. Overflow faults the saved run.',
    'event_queue_bytes': 'Accounting bytes for pending event envelopes and payloads. Trusted native Logic graphs are excluded.',
    'timers': 'Maximum pending timers owned by a run, including queued one-shot deliveries.',
    'subscriptions': 'Maximum subscription registrations per computer or run. This limit is checked on registration.',
    'network_nodes': 'Maximum nodes in physical same-color discovery traversal.',
    'network_edges': 'Maximum edges in physical same-color discovery traversal.',
    'topology_latency_ticks': 'Published tick bound for topology observations. This is not a GPU or UPS guarantee.',
    'sync_group_refs': 'Maximum number of supplied physical monitor selection references.',
    'sync_group_members': 'Maximum unique logical monitors in one synchronization selection.',
    'sync_group_cells': 'Total terminal cells in one synchronization selection.',
    'sync_groups_per_run': 'Maximum monitor synchronization selections per execution owner.',
    'peripheral_call_bytes': 'Byte allowance for ordinary peripheral call transport and accounting.',
    'peripheral_call_entries': 'Entry allowance for ordinary peripheral call transport.',
    'console_entries': 'Maximum retained Console entries. The oldest entries can be removed.',
    'console_bytes': 'Maximum retained Console text bytes and maximum individual output size.',
    'fail_safe_latency_ticks': 'Published tick bound for observing cleanup of still-owned Logic output.',
    'shell_source_bytes': 'Maximum source bytes in one submitted Console line. CR and LF are not permitted.',
    'shell_bindings': 'Maximum number of retained Console root bindings.',
    'shell_value_bytes': 'Accounting units for retained Console graphs, including edges and metadata.',
    'shell_nodes': 'Maximum retained Console graph elements. These are not ordinary Data nodes.',
    'shell_pending_entries': 'Maximum queued Console commands per computer.',
    'shell_pending_bytes': 'Maximum total source bytes for queued Console commands per computer.',
    'shell_sessions': 'Maximum retained Console session records in the world, including idle sessions.',
    'registry_entries': 'Maximum registered physical device records.',
    'owned_children': 'Maximum host-owned child entities per device record.',
    'maintenance_work_per_tick': 'Effective world maintenance units: min(requested, host_work_per_tick - 1).',
    'host_hooks': 'Maximum trusted service-provider registrations. This does not permit guest extensions.',
    'width_tiles': 'Maximum logical monitor width along its display-local tile axis.',
    'height_tiles': 'Maximum logical monitor height along its display-local tile axis.',
    'cells': 'Maximum character cells per logical monitor.',
    'write_bytes': 'Maximum text bytes for one monitor write or blit operation.',
    'render_latency_ticks': 'Published tick bound for presentation. This is not a measured client FPS guarantee.',
    'tiles': 'Maximum retained physical monitor tiles.',
    'aggregate_cells': 'Maximum authoritative cells across logical monitors.',
    'render_cells_per_tick': 'Cell allowance for presentation preparation.',
    'render_snapshot_cells': 'Maximum cells retained by immutable presentation snapshots.',
    'render_staging_cells': 'Maximum cells reserved for staged presentation.',
    'render_retired_cells': 'Maximum cells awaiting removal from host presentation.',
    'render_staging_frames': 'Maximum staged presentation frames.',
    'render_retired_frames': 'Maximum presentation frames awaiting removal.',
    'render_commit_objects': 'Rendering-object allowance for an admitted commit.',
    'render_commit_work': 'Maximum indivisible render commit work. An increase to maintenance does not increase this limit.',
    'render_object_limit': 'Calculated native rendering-object allowance.',
    'render_retained_cells': 'Calculated allowance for all retained presentation cells.',
    'keys': 'Maximum live keys per physical KV database.',
    'bytes': 'Maximum accounting bytes for live content per physical KV database.',
    'key_bytes': 'Maximum bytes in a KV key or hash field. Empty strings and NUL are permitted.',
    'value_bytes': 'Maximum bytes in a KV string value. Values are never coerced.',
    'hash_fields': 'Maximum distinct fields in one live KV hash.',
    'hash_bytes': 'Maximum content accounting bytes in one live KV hash.',
    'total_hash_fields': 'Maximum distinct live hash fields in one physical KV database.',
    'command_arguments': 'Maximum total positional arguments in one KV command.',
    'snapshot_bytes': 'KV transfer and save snapshot allowance. This is separate from live content.',
    'reclaim_keys_per_device': 'Maximum expired-key maintenance visits per due database.',
    'reclaim_devices_per_tick': 'Maximum due-database maintenance visits per tick.',
    'channel_min': 'Smallest numeric modem channel. Zero is valid; it does not mean unlimited.',
    'channel_max': 'Largest numeric modem channel, inclusive.',
    'open_channels': 'Maximum shared open numeric channels per physical modem.',
    'message_bytes': 'Maximum accounted modem message bytes per transmit.',
    'message_nodes': 'Maximum modem message Data nodes per transmit.',
    'message_depth': 'Maximum modem message Data nesting depth per transmit.',
    'routing_candidates': 'Maximum candidate radar receivers per transmission.',
    'deliveries_per_transmit': 'Maximum handler deliveries per accepted transmission, including fan-out.',
    'transmits_per_computer_tick': 'Maximum accepted transmissions per computer per tick.',
    'transmits_per_tick': 'Maximum accepted transmissions in the world per tick.',
    'speaker_path_bytes': 'Maximum bytes in a sound path or instrument string.',
    'speaker_instruments': 'Maximum supported instrument catalogue entries.',
    'speaker_notes_per_instrument': 'Maximum supported note entries per instrument.',
    'speaker_sound_page_size': 'Maximum sound paths in one catalogue page.',
    'speaker_sound_catalog_entries': 'Supported sound-path catalogue size.',
    'speaker_notes_per_tick': 'Maximum note submissions per physical speaker per tick.',
    'speaker_sounds_per_tick': 'Maximum sound-effect submissions per physical speaker per tick.',
    'speaker_computer_submissions_per_tick': 'Maximum combined audio submissions per computer per tick.',
    'speaker_world_submissions_per_tick': 'Maximum combined audio submissions in the world per tick.',
    'target_nodes': 'Maximum nodes in Configurator target-network traversal.',
    'target_edges': 'Maximum edges in Configurator target-network traversal.',
    'configuration_bytes': 'Maximum accounting bytes in a normalized configuration.',
    'configuration_nodes': 'Maximum nodes in a normalized configuration.',
    'patch_fields': 'Maximum fields in one Configurator patch.',
    'sections': 'Maximum supported target sections.',
    'section_filters': 'Maximum supported filters in one Configurator section.',
    'recipe_search_results': 'Maximum complete recipe results. Excess results cause E_LIMIT, never a truncated list.',
    'sample_interval_ticks': 'Sampling interval for a watched physical Logic input, in simulation ticks.',
    'notification_latency_ticks': 'Published tick bound for Logic notifications. event.tick can be later than sample_tick.',
    'dashboard_tabs': 'Number of Dashboard tab slots. Empty slots do not require configuration.',
    'dashboard_state_bytes': 'Accounting bytes for the retained Dashboard model, shared by all writers and tabs.',
    'chart_line_series': 'Optional maximum line-series count supported by the renderer. This field is absent without factorio-charts.',
    'chart_bar_entries': 'Optional positive-width bar domain supported by the renderer. This field is absent without factorio-charts.',
}


def declarations(root=ROOT):
    sources = {}
    def source(path):
        text = (root / path).read_text()
        sources[path] = hashlib.sha256(text.encode()).hexdigest()
        return text

    def integer(pattern, text):
        matches = re.findall(pattern, text)
        if len(matches) != 1:
            raise ValueError('expected one limit constant: ' + pattern)
        return int(matches[0])

    def closed_table(path, prefix, shared=None):
        # These existing constant tables contain only integers and shared references.
        # Reject a changed shape rather than guessing how to evaluate general Lua.
        match = re.search(re.escape(prefix) + r'(.*?)\}', source(path), re.S)
        if not match:
            raise ValueError('limit table not found: ' + path)
        result = {}
        body = re.sub(r'--[^\n]*', '', match[1])
        for part in body.split(','):
            if not part.strip():
                continue
            field = re.fullmatch(r'\s*(\w+)\s*=\s*(\d+|shared\.\w+)\s*', part)
            if not field or field[1] in result:
                raise ValueError('unsupported or duplicate limit constant: ' + path + ': ' + part)
            if field[2].startswith('shared.'):
                if shared is None:
                    raise ValueError('unexpected shared limit reference: ' + part)
                result[field[1]] = shared[field[2][7:]]
            else:
                result[field[1]] = int(field[2])
        return result

    common = closed_table('scripts/runtime/limits.lua', 'return {')
    groups = {
        'Limits': (None, common),
        'MonitorLimits': (None, closed_table('scripts/monitor-model.lua', 'local M={limits={')),
        'KVLimits': (None, closed_table('scripts/services/kv.lua', 'local L={', common)),
        'ConfiguratorLimits': ('Limits', closed_table('scripts/configuration/adapters.lua', 'M.limits={')),
        'ModemLimits': (None, closed_table('scripts/services/modem.lua', 'local limits={')),
        'SpeakerLimits': ('Limits', closed_table('scripts/speaker-limits.lua', 'return {')),
    }
    for key in ('string_bytes', 'table_entries', 'data_nodes', 'data_depth'):
        groups['ModemLimits'][1][key] = common[key]
    recipe_source = source('scripts/services/recipe-searcher.lua')
    groups['RecipeSearcherLimits'] = ('Limits', {'recipe_search_results': integer(r'local MAX_RESULTS=(\d+)', recipe_source)})
    logic_source = source('scripts/services/logic.lua')
    groups['LogicLimits'] = ('Limits', {
        'sample_interval_ticks': integer(r'result.sample_interval_ticks=(\d+)', logic_source),
        'notification_latency_ticks': common['topology_latency_ticks'],
    })
    dashboard_source = source('scripts/dashboard-model.lua')
    groups['DashboardLimits'] = ('Limits', {
        'dashboard_tabs': integer(r'local M=\{tabs=(\d+)', dashboard_source),
        'dashboard_state_bytes': common['state_bytes'],
        'chart_line_series': None, 'chart_bar_entries': None,
    })
    settings = {}
    settings_source = source('scripts/runtime/budget-settings.lua')
    def bound(expression):
        if expression.isdecimal():
            return int(expression)
        if expression == 'maintenance_max':
            return integer(r'local maintenance_max=(\d+)', settings_source)
        match = re.fullmatch(r'limits\.(\w+)(\+1)?', expression)
        if match:
            return common[match[1]] + bool(match[2])
        raise ValueError('unsupported setting domain: ' + expression)
    for key, name, minimum, maximum in re.findall(
        r"\{key='(\w+)',name='([^']+)',minimum_value=([^,]+),maximum_value=([^}]+)\}", settings_source
    ):
        settings[key] = (name, bound(minimum), bound(maximum))
    if set(settings) != {'compile_work', 'host_work_per_tick', 'maintenance_work_per_tick'}:
        raise ValueError('runtime setting inventory changed; review public limit domains')
    all_keys = set().union(*(values.keys() for _, values in groups.values()))
    if all_keys != set(DESCRIPTIONS):
        raise ValueError(f'limit description coverage: missing={sorted(all_keys - DESCRIPTIONS.keys())}, stale={sorted(DESCRIPTIONS.keys() - all_keys)}')
    lines = ['---@meta', '-- Generated by tools/player_docs.py from runtime constants; do not edit.',
             '-- Sources: ' + '; '.join(path + ' sha256=' + digest for path, digest in sorted(sources.items())), '']
    for name, (parent, fields) in groups.items():
        lines += ['---Independent copy of effective limits. These defaults are not current values.',
                  '---Counts limit admission. They do not give calibrated heap, latency, or FPS guarantees.',
                  '---Settings changes keep spent credits. Lower limits never permit data loss.',
                  '---@class TC.' + name + (': TC.' + parent if parent else '')]
        for key, value in sorted(fields.items()):
            description = DESCRIPTIONS[key]
            if value is not None:
                description += ' Default: ' + str(value) + '.'
            if key in settings:
                setting, minimum, maximum = settings[key]
                description += f' Runtime-global setting: {setting}. Requested integer domain: {minimum}..{maximum}.'
            lines.append('---@field ' + key + ('?' if value is None else '') + ' integer ' + description)
        lines.append('')
    return '\n'.join(lines)
