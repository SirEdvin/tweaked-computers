#!/usr/bin/env python3
"""Prepare exact-archive native Console and localhost late-join scenes.

Does not drive GUI keys or claim acceptance. Run returned commands on owned
private displays; use independent write-data paths for two connected clients.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import socket
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def prepare(archive, engine, client, output, mode, config_template=None, fixture_module='tests.shell_client_engine'):
    if fixture_module not in ('tests.ui_live_client_engine', 'tests.editor_reference_client_engine', 'tests.speaker_client_engine', 'tests.radar_client_engine', 'tests.peripheral_inspector_client_engine', 'tests.shell_client_engine', 'tests.recipe_searcher_client_engine', 'tests.acceptance_client_engine', 'tests.acceptance_monitor_engine'):
        raise ValueError('fixed native client fixture required')
    output = output.resolve()
    if output.exists() or output.is_relative_to(ROOT):
        raise ValueError('use a fresh output directory outside the checkout')
    version = subprocess.check_output([str(engine), '--version'], text=True)
    client_version = subprocess.check_output([str(client / 'bin/x64/factorio'), '--version'], text=True)
    if not version.startswith('Version: 2.0.77 ') or not client_version.startswith('Version: 2.0.77 ') or 'full' not in client_version:
        raise ValueError('matching complete 2.0.77 headless and graphical engines required')
    with zipfile.ZipFile(archive) as package:
        info = json.loads(package.read(next(n for n in package.namelist() if n.endswith('/info.json'))))
        assert any(n.endswith('/' + fixture_module.replace('.', '/') + '.lua') for n in package.namelist())
    template = (config_template or client / 'config/config.ini').read_text()
    output.mkdir(parents=True)
    mods = output / 'mods'
    mods.mkdir()
    copied = mods / archive.name
    shutil.copy2(archive, copied)
    assert copied.read_bytes() == archive.read_bytes()
    fixture = mods / 'tc-smoke_0.0.1'
    fixture.mkdir()
    (fixture / 'info.json').write_text(json.dumps(dict(name='tc-smoke', version='0.0.1', title='Isolated Console client fixture', author='test fixture', factorio_version='2.0', dependencies=['base', info['name']])))
    (fixture / 'control.lua').write_text('-- Fixture lives in the production mod event/storage context.\n')
    value=json.dumps(fixture_module)
    (fixture / 'settings.lua').write_text("data:extend{{type='string-setting',name='tc-smoke-production-fixture',setting_type='startup',default_value="+value+",allowed_values={"+value+"}}}\n")
    enabled = [dict(name=n, enabled=True) for n in ('base', info['name'], 'tc-smoke')]
    enabled += [dict(name=n, enabled=mode == 'space-age') for n in ('space-age', 'quality', 'elevated-rails')]
    (mods / 'mod-list.json').write_text(json.dumps(dict(mods=enabled)))
    configs = {}
    for name in ('server', 'client1', 'client2'):
        folder = output / name
        folder.mkdir()
        write = folder / 'write'
        write.mkdir()
        # /server-save resolves its name through this directory; a fresh
        # headless write-data tree has not necessarily had an autosave yet.
        (write / 'saves').mkdir()
        data = engine.resolve().parents[2] / 'data' if name == 'server' else client / 'data'
        text = template.replace('read-data=__PATH__executable__/../../data', 'read-data=' + str(data))
        text = text.replace('write-data=__PATH__executable__/../..', 'write-data=' + str(write))
        text = text.replace('locale=auto', 'locale=en').replace('; check-updates=true', 'check-updates=false')
        text = text.replace('; autosave-interval=5', 'autosave-interval=0').replace('; cache-sprite-atlas=true', 'cache-sprite-atlas=false')
        config = folder / 'config.ini'
        config.write_text(text)
        configs[name] = config
    save = output / 'scene.zip'
    common = [str(engine), '--config', str(configs['server']), '--mod-directory', str(mods)]
    create = common + ['--create', str(save), '--map-gen-seed', '1']
    result = subprocess.run(create, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
    (output / 'create.log').write_text(result.stdout)
    if result.returncode or 'TC_SMOKE_OK' not in result.stdout or not save.is_file():
        raise RuntimeError('scene creation failed; inspect ' + str(output / 'create.log'))
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    settings = output / 'server-settings.json'
    settings.write_text(json.dumps(dict(name='Isolated Console acceptance', description='localhost only', visibility=dict(public=False, lan=False), require_user_verification=False, auto_pause=False, max_players=2)))
    commands = {'server': common + ['--start-server', str(save), '--bind', '127.0.0.1', '--port', str(port), '--server-settings', str(settings)]}
    for name in ('client1', 'client2'):
        command = [str(client / 'bin/x64/factorio'), '--config', str(configs[name]), '--mod-directory', str(mods), '--disable-audio', '--window-size', '1280x720', '--force-graphics-preset', 'low']
        commands[name] = command + ['--mp-connect', '127.0.0.1:' + str(port)]
        if name == 'client1':
            commands['singleplayer'] = command + ['--load-game', str(save)]
    (output / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
    provenance = dict(engine_version=version, client_version=client_version, mode=mode,
                      archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
                      save_sha256=hashlib.sha256(save.read_bytes()).hexdigest(),
                      prepared_only=True, client_acceptance=False, multiplayer_acceptance=False)
    (output / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    return commands


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--factorio', required=True, type=Path)
    parser.add_argument('--client', required=True, type=Path, help='complete graphical distribution root')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--mode', required=True, choices=('base', 'space-age'))
    parser.add_argument('--config-template', type=Path, help='engine-generated matching-version template if distribution has none')
    parser.add_argument('--fixture', default='tests.shell_client_engine', choices=('tests.ui_live_client_engine', 'tests.editor_reference_client_engine', 'tests.speaker_client_engine', 'tests.radar_client_engine', 'tests.peripheral_inspector_client_engine', 'tests.shell_client_engine', 'tests.recipe_searcher_client_engine', 'tests.acceptance_client_engine', 'tests.acceptance_monitor_engine'))
    args = parser.parse_args()
    print(json.dumps(prepare(args.archive.resolve(), args.factorio.resolve(), args.client.resolve(), args.output, args.mode, args.config_template, args.fixture), indent=2))


if __name__ == '__main__':
    main()
