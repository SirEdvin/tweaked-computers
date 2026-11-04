"""Derive declaration fields from the existing closed limit tables, not copies."""
import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DESCRIPTIONS = {
    'api_version': 'Guest API representation version, not a capacity.',
    'compiler_version': 'Saved compiler representation version, not a capacity.',
    'storage_version': 'Saved storage representation version, not a capacity.',
    'source_bytes': 'Maximum saved program source bytes.',
    'generated_source_bytes': 'Maximum instrumented native source bytes.',
    'source_nodes': 'Maximum parsed source nodes.',
    'source_tokens': 'Maximum parsed source tokens.',
    'source_nesting': 'Maximum source syntax nesting depth.',
    'handler_names': 'Maximum exported handler names in one program.',
    'identifier_bytes': 'Maximum ordinary identifier/label bytes; specific APIs may differ.',
    'tuple_entries': 'Maximum argument/return tuple positions, including explicit nil/status.',
    'callback_work': 'Execution work units per computer per tick; not milliseconds.',
    'callback_depth': 'Maximum guarded guest call depth.',
    'callback_allocations': 'Guest allocation admission units per computer per tick; not measured heap bytes.',
    'compile_work': 'Shared validation/reconstruction work units per computer per tick.',
    'host_work_per_tick': 'World host work ceiling; maintenance is reserved inside it, not added.',
    'active_computers': 'Maximum simultaneously active saved programs.',
    'aggregate_subscriptions': 'World subscription registration ceiling.',
    'state_bytes': 'Per-computer retained application Data accounting bytes, including metadata.',
    'state_entries': 'Per-computer explicit state key ceiling.',
    'data_nodes': 'Generic Data graph node ceiling; native Logic transfer is exempt.',
    'data_depth': 'Generic Data nesting ceiling; native Logic transfer is exempt.',
    'string_bytes': 'Ordinary guest/Data string byte ceiling.',
    'table_entries': 'Ordinary guest-created table entry ceiling; native Logic non-growing edits are distinct.',
    'event_queue_entries': 'Pending event entries per computer; overflow faults the saved run.',
    'event_queue_bytes': 'Pending event envelope/payload accounting bytes; excludes trusted native Logic graphs.',
    'timers': 'Pending timer ownership per run, including queued one-shot deliveries.',
    'subscriptions': 'Subscription registrations per computer/run, checked on registration.',
    'network_nodes': 'Physical same-color discovery traversal nodes.',
    'network_edges': 'Physical same-color discovery traversal edges.',
    'topology_latency_ticks': 'Published topology observation envelope in simulation ticks; not a GPU/UPS promise.',
    'sync_group_refs': 'Maximum supplied physical monitor selection references.',
    'sync_group_members': 'Maximum unique logical monitors in one synchronization selection.',
    'sync_group_cells': 'Aggregate terminal cells in one synchronization selection.',
    'sync_groups_per_run': 'Monitor synchronization selections per execution owner.',
    'peripheral_call_bytes': 'Ordinary peripheral call transport/accounting byte envelope.',
    'peripheral_call_entries': 'Ordinary peripheral call transport entry envelope.',
    'console_entries': 'Retained Console entry ceiling; oldest entries may be evicted.',
    'console_bytes': 'Retained Console text bytes and individual output limit.',
    'fail_safe_latency_ticks': 'Published still-owned Logic cleanup observation envelope in ticks.',
    'shell_source_bytes': 'Single submitted Console line source bytes; CR/LF remain forbidden.',
    'shell_bindings': 'Retained Console root binding count.',
    'shell_value_bytes': 'Retained Console graph accounting units, including edges/metadata.',
    'shell_nodes': 'Retained Console graph elements, not ordinary Data nodes.',
    'shell_pending_entries': 'Queued Console commands per computer.',
    'shell_pending_bytes': 'Total queued Console command source bytes per computer.',
    'shell_sessions': 'World retained Console session records, including idle sessions.',
    'registry_entries': 'Registered physical device records.',
    'owned_children': 'Host-owned child entities per device record.',
    'maintenance_work_per_tick': 'Effective world maintenance units, min(requested, host_work_per_tick - 1).',
    'host_hooks': 'Trusted service-provider registrations; not guest extension permission.',
    'width_tiles': 'Maximum logical monitor width along its display-local tile axis.',
    'height_tiles': 'Maximum logical monitor height along its display-local tile axis.',
    'cells': 'Maximum character cells per logical monitor.',
    'write_bytes': 'Maximum text bytes supplied to one monitor write/blit operation.',
    'render_latency_ticks': 'Presentation envelope in ticks; not a measured client FPS guarantee.',
    'tiles': 'Maximum retained physical monitor tiles.',
    'aggregate_cells': 'Maximum authoritative cells across logical monitors.',
    'render_cells_per_tick': 'Bounded presentation preparation cell allowance.',
    'render_snapshot_cells': 'Cells retained by immutable presentation snapshots.',
    'render_staging_cells': 'Cells reserved for staged presentation.',
    'render_retired_cells': 'Cells awaiting host presentation retirement.',
    'render_staging_frames': 'Staged presentation frame count.',
    'render_retired_frames': 'Presentation frames awaiting retirement.',
    'render_commit_objects': 'Rendering-object envelope for an admitted commit.',
    'render_commit_work': 'Maximum indivisible render commit work; raising maintenance does not widen it.',
    'render_object_limit': 'Derived native rendering-object envelope.',
    'render_retained_cells': 'Derived total retained presentation-cell envelope.',
    'keys': 'Live keys per physical KV database.',
    'bytes': 'Live KV content accounting bytes per physical database.',
    'key_bytes': 'KV key/hash-field byte ceiling; empty strings and NUL are legal.',
    'value_bytes': 'KV string-value byte ceiling; values are never coerced.',
    'hash_fields': 'Distinct fields in one live KV hash.',
    'hash_bytes': 'Content accounting bytes in one live KV hash.',
    'total_hash_fields': 'Distinct live hash fields across a physical KV database.',
    'command_arguments': 'Total positional arguments to one KV command.',
    'snapshot_bytes': 'KV transfer/save snapshot allowance, separate from live content.',
    'reclaim_keys_per_device': 'Bounded expired-key maintenance visits per due database.',
    'reclaim_devices_per_tick': 'Bounded due-database maintenance visits per tick.',
    'channel_min': 'Smallest numeric modem channel; zero is valid, not unlimited.',
    'channel_max': 'Largest numeric modem channel, inclusive.',
    'open_channels': 'Shared open numeric channels per physical modem.',
    'message_bytes': 'Accounted modem message bytes per transmit.',
    'message_nodes': 'Modem message Data nodes per transmit.',
    'message_depth': 'Modem message Data nesting per transmit.',
    'routing_candidates': 'Candidate radar receiver inventory per transmission.',
    'deliveries_per_transmit': 'Handler deliveries per accepted transmission, including fan-out.',
    'transmits_per_computer_tick': 'Accepted transmissions per computer/tick.',
    'transmits_per_tick': 'World accepted transmissions per tick.',
    'speaker_path_bytes': 'Sound path/instrument string byte ceiling.',
    'speaker_instruments': 'Supported instrument catalogue entries.',
    'speaker_notes_per_instrument': 'Supported note entries per instrument.',
    'speaker_sound_page_size': 'Maximum sound paths in one catalogue page.',
    'speaker_sound_catalog_entries': 'Supported sound-path catalogue envelope.',
    'speaker_notes_per_tick': 'Note submissions per physical speaker/tick.',
    'speaker_sounds_per_tick': 'Sound-effect submissions per physical speaker/tick.',
    'speaker_computer_submissions_per_tick': 'Combined audio submissions per computer/tick.',
    'speaker_world_submissions_per_tick': 'Combined world audio submissions per tick.',
    'target_nodes': 'Configurator target-network traversal node ceiling.',
    'target_edges': 'Configurator target-network traversal edge ceiling.',
    'configuration_bytes': 'Normalized configuration accounting byte ceiling.',
    'configuration_nodes': 'Normalized configuration node ceiling.',
    'patch_fields': 'Fields in one Configurator patch.',
    'sections': 'Supported target section count.',
    'section_filters': 'Supported filters in one Configurator section.',
    'recipe_search_results': 'Complete recipe result ceiling; excess is E_LIMIT, never a truncated prefix.',
    'sample_interval_ticks': 'Physical watched Logic input sampling interval in simulation ticks.',
    'notification_latency_ticks': 'Published Logic notification envelope; event.tick may follow sample_tick.',
    'dashboard_tabs': 'Numbered Dashboard tab slots; empty slots need not be configured.',
    'dashboard_state_bytes': 'Retained dashboard model accounting bytes shared by all writers/tabs.',
    'chart_line_series': 'Optional renderer-supported line-series count; absent without factorio-charts.',
    'chart_bar_entries': 'Optional renderer positive-width bar domain; absent without factorio-charts.',
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
    if set(settings) != {'compile_work', 'callback_work', 'callback_allocations', 'host_work_per_tick', 'maintenance_work_per_tick'}:
        raise ValueError('runtime setting inventory changed; review public limit domains')
    all_keys = set().union(*(values.keys() for _, values in groups.values()))
    if all_keys != set(DESCRIPTIONS):
        raise ValueError(f'limit description coverage: missing={sorted(all_keys - DESCRIPTIONS.keys())}, stale={sorted(DESCRIPTIONS.keys() - all_keys)}')
    lines = ['---@meta', '-- Generated by tools/player_docs.py from runtime constants; do not edit.',
             '-- Sources: ' + '; '.join(path + ' sha256=' + digest for path, digest in sorted(sources.items())), '']
    for name, (parent, fields) in groups.items():
        lines += ['---Defensive effective limit map. Defaults below are not live values.',
                  '---Counts are admission envelopes, not calibrated heap, latency or FPS promises.',
                  '---Settings changes preserve spent credits; lower limits never authorize data loss.',
                  '---@class TC.' + name + (': TC.' + parent if parent else '')]
        for key, value in sorted(fields.items()):
            description = DESCRIPTIONS[key]
            if value is not None:
                description += ' Default: ' + str(value) + '.'
            if key in settings:
                setting, minimum, maximum = settings[key]
                description += f' Runtime-global {setting}; requested integer domain {minimum}..{maximum}.'
            lines.append('---@field ' + key + ('?' if value is None else '') + ' integer ' + description)
        lines.append('')
    return '\n'.join(lines)
