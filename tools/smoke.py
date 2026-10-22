#!/usr/bin/env python3
"""One isolated archive-based official-engine smoke; no GUI or public server."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import socket
import subprocess
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def cold_phase(engine, cfg, mods, save, folder, name, marker, snapshot=None, timeout=90):
    """Bounded localhost-only cold phase; freeze fixture, then verified console quit."""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    settings = folder / 'server-settings.json'
    settings.write_text(json.dumps({'name':'TC isolated cold smoke', 'description':'test fixture',
        'visibility':{'public':False,'lan':False}, 'require_user_verification':False,
        'auto_pause':False, 'max_players':1}))
    command = [str(engine),'--config',str(cfg),'--mod-directory',str(mods),
        '--start-server',str(save),'--bind','127.0.0.1','--port',str(port),
        '--server-settings',str(settings)]
    (folder / (name+'-command.json')).write_text(json.dumps(command,indent=2)+'\n')
    path = folder / (name+'-engine.log')
    cleanup = {'console_quit_requested':False,'console_quit_acknowledged':False,
               'sigint_attempted':False,'forced_kill':False}
    passed = False
    with path.open('w') as output:
        process = subprocess.Popen(command,stdin=subprocess.PIPE,stdout=output,stderr=subprocess.STDOUT,text=True)
        assert process.stdin is not None
        try:
            deadline = time.monotonic()+timeout
            while time.monotonic()<deadline and process.poll() is None:
                text = path.read_text()
                ready = marker in text
                if snapshot is not None:
                    try:
                        with zipfile.ZipFile(snapshot) as saved:
                            ready = ready and saved.testzip() is None
                    except (FileNotFoundError,zipfile.BadZipFile):
                        ready = False
                if ready:
                    passed = True
                    break
                time.sleep(0.1)
            if process.poll() is None:
                cleanup['console_quit_requested'] = True
                process.stdin.write('/quit\n'); process.stdin.flush()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    import signal
                    cleanup['sigint_attempted'] = True
                    process.send_signal(signal.SIGINT)
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        cleanup['forced_kill'] = True
                        process.kill(); process.wait(timeout=5)
        finally:
            if process.poll() is None:
                cleanup['forced_kill'] = True
                process.kill(); process.wait(timeout=5)
            process.stdin.close()
    text = path.read_text()
    cleanup['console_quit_acknowledged'] = cleanup['console_quit_requested'] and process.returncode==0 and 'Goodbye' in text and 'Exception at tick' not in text
    result = {'phase':name,'passed':passed and cleanup['console_quit_acknowledged'] and not cleanup['sigint_attempted'] and not cleanup['forced_kill'],
              'exit_code':process.returncode,'marker':marker,'cleanup':cleanup}
    if name=='cold-first' and 'TC_COLD_OK' in text:
        result['passed'] = False
    (folder / (name+'-result.json')).write_text(json.dumps(result,indent=2)+'\n')
    if not result['passed']:
        print(text)
        raise RuntimeError('cold phase failed: '+json.dumps(result))
    return result

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--factorio', required=True, type=Path)
    ap.add_argument('--archive', required=True, type=Path)
    ap.add_argument('--output', required=True, type=Path)
    ap.add_argument('--mode', choices=['base', 'space-age', 'both'], default='both')
    ap.add_argument('--fixture', default='tests.runtime_contract', help='Packaged Lua module exposing run()')
    ap.add_argument('--data-fixture', help='Optional packaged data-stage fixture module')
    ap.add_argument('--final-data-fixture', help='Optional packaged final-fixes fixture after catalogue capture')
    ap.add_argument('--production-context', action='store_true', help='Run the fixed lifecycle fixture in the production mod storage/event context; avoid duplicate native entity owners')
    ap.add_argument('--cold', action='store_true', help='Fixture also exposes on_load/on_tick; exercise two cold server processes')
    ap.add_argument('--cold-timeout', type=int, help='Explicit wall deadline per cold phase for sustained fixtures (1..1800 seconds)')
    ap.add_argument('--upgrade-fixture', action='store_true', help='After ordinary cold reload, change only test mod version and verify researched migration in another process')
    args = ap.parse_args()
    if args.cold_timeout is not None and not 1 <= args.cold_timeout <= 1800:
        ap.error('--cold-timeout must be 1..1800 seconds')
    args.output = args.output.resolve()
    if args.output.is_relative_to(ROOT) or args.output.exists():
        ap.error('use a fresh output directory outside git')
    args.output.mkdir(parents=True)
    version = subprocess.check_output([str(args.factorio), '--version'], text=True)
    (args.output / 'engine-version.txt').write_text(version)
    if not version.startswith('Version: 2.0.77 '):
        raise RuntimeError('exact Factorio 2.0.77 required')
    with zipfile.ZipFile(args.archive) as archive:
        info_path = next(n for n in archive.namelist() if n.endswith('/info.json'))
        info = json.loads(archive.read(info_path))
    summary = {'engine': '2.0.77', 'archive_sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest(), 'cases': []}
    for mode in (['base','space-age'] if args.mode=='both' else [args.mode]):
        folder = args.output / mode
        mods,write = folder / 'mods',folder / 'write'
        mods.mkdir(parents=True); write.mkdir()
        (write / 'saves').mkdir()
        shutil.copy2(args.archive, mods / args.archive.name)
        fixture = mods / 'tc-smoke_0.0.1'
        fixture.mkdir()
        (fixture / 'info.json').write_text(json.dumps({'name':'tc-smoke','version':'0.0.1','title':'TC isolated smoke', 'author':'test fixture','factorio_version':'2.0','dependencies':['base',info['name']]}))
        # Read fixture source from the same ZIP as production code.
        module = '__' + info['name'] + '__.' + args.fixture
        control = 'local test = require(' + json.dumps(module) + ')\nscript.on_init(function() test.run(); log("TC_SMOKE_OK") end)\n'
        if args.cold:
            control += 'script.on_load(test.on_load)\nscript.on_event(defines.events.on_tick,test.on_tick)\n'
        if args.upgrade_fixture:
            if not args.cold:
                ap.error('--upgrade-fixture requires --cold')
            control += 'script.on_configuration_changed(test.on_configuration_changed)\n'
        if args.production_context:
            if args.fixture not in ('tests.resource_policy_engine', 'tests.reference_tutorials_engine', 'tests.peripheral_inspector_engine', 'tests.speaker_competition_engine', 'tests.speaker_engine', 'tests.speaker_client_engine', 'tests.modem_competition_engine', 'tests.radar_engine', 'tests.modem_engine', 'tests.monitor_state_waiting', 'tests.monitor_state_preparing', 'tests.monitor_state_ready', 'tests.monitor_state_retiring', 'tests.logic_recipe_engine', 'tests.recipe_searcher_engine', 'tests.shell_cold', 'tests.lifecycle_engine', 'tests.integration_engine', 'tests.redesign_engine', 'tests.monitor_feedback_engine', 'tests.rd1_upgrade_engine', 'tests.monitor_budget_engine', 'tests.monitor_presentation_engine', 'tests.monitor_plot_baseline_engine', 'tests.runtime_budget_engine', 'tests.monitor_animation_engine') or not args.cold:
                ap.error('--production-context requires a fixed supported fixture and --cold')
            control = '-- Native lifecycle fixture runs once in production context.\n'
            (fixture / 'settings.lua').write_text("data:extend{{type='string-setting',name='tc-smoke-production-fixture',setting_type='startup',default_value="+json.dumps(args.fixture)+",allowed_values={"+json.dumps(args.fixture)+"}}}\n")
        (fixture / 'control.lua').write_text(control)
        if args.data_fixture:
            (fixture / 'data.lua').write_text('require('+json.dumps('__'+info['name']+'__.'+args.data_fixture)+')\n')
        if args.final_data_fixture:
            (fixture / 'data-final-fixes.lua').write_text('require('+json.dumps('__'+info['name']+'__.'+args.final_data_fixture)+')\n')
        enabled = [{'name':'base','enabled':True},{'name':info['name'],'enabled':True},{'name':'tc-smoke','enabled':True}]
        enabled += [{'name':name,'enabled':mode=='space-age'} for name in ('space-age','quality','elevated-rails')]
        (mods / 'mod-list.json').write_text(json.dumps({'mods':enabled}))
        cfg = folder / 'config.ini'
        cfg.write_text('[path]\nread-data='+str(args.factorio.resolve().parents[2] / 'data')+'\nwrite-data='+str(write)+'\n[other]\ncheck-updates=false\n')
        cmd = [str(args.factorio), '--config',str(cfg),'--mod-directory',str(mods),'--create',str(folder/'smoke.zip'),'--map-gen-seed','1']
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
        (folder / 'engine.log').write_text(result.stdout)
        (folder / 'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
        groups = re.findall(r'TC_CONTRACT ([^\r\n]+)', result.stdout)
        totals = [int(n) for n in re.findall(r'TC_CONTRACT_TOTAL (\d+)', result.stdout)]
        counts_match = not totals or (totals == [len(groups)] and len(groups) == len(set(groups)))
        passed = result.returncode==0 and 'TC_SMOKE_OK' in result.stdout and (folder/'smoke.zip').is_file() and counts_match
        summary['cases'].append({'mode':mode,'exit_code':result.returncode,'passed':passed,'contract_groups':len(groups)})
        (args.output / 'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps(summary['cases'][-1]),flush=True)
        if not passed:
            print(result.stdout)
            raise SystemExit(1)
        if args.cold:
            snapshot = write / 'saves/tc03-snapshot.zip'
            phases = [cold_phase(args.factorio,cfg,mods,folder/'smoke.zip',folder,'cold-first','TC_COLD_SNAPSHOT_REQUESTED',snapshot,timeout=args.cold_timeout or 90)]
            ordinary_save = write / 'saves/tc-cold-ordinary.zip'
            shutil.copy2(snapshot, ordinary_save)  # /quit saves over its input map.
            # This fixture additionally drives four complete rediscovery/resize
            # cycles through production timers. Extend wall time, not its tick
            # deadline or any guest/shared resource ceiling.
            phase_timeout = args.cold_timeout or (240 if args.fixture=='tests.monitor_presentation_engine' else 90)
            phases.append(cold_phase(args.factorio,cfg,mods,ordinary_save,folder,'cold-second','TC_COLD_OK',timeout=phase_timeout))
            if args.upgrade_fixture and (mode=='base' or args.fixture in ('tests.speaker_engine', 'tests.recipe_searcher_engine', 'tests.radar_engine')):
                # Only the copied fixture changes; the tested production ZIP is immutable.
                fixture_info = json.loads((fixture / 'info.json').read_text())
                fixture_info['version'] = '0.0.2'
                (fixture / 'info.json').write_text(json.dumps(fixture_info))
                fixture.rename(mods / 'tc-smoke_0.0.2')
                upgrade_save = write / 'saves/tc-configuration-change.zip'
                shutil.copy2(snapshot, upgrade_save)
                phases.append(cold_phase(args.factorio,cfg,mods,upgrade_save,folder,'configuration-change','TC_UPGRADE_OK'))
            summary['cases'][-1]['cold_phases'] = phases
            summary['cases'][-1]['snapshot_sha256'] = hashlib.sha256(snapshot.read_bytes()).hexdigest()
            (args.output / 'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary))

if __name__ == '__main__':
    main()
