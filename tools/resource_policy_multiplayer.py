#!/usr/bin/env python3
"""Real localhost server + two full clients, second launched at a durable boundary.

Run under the coordination native flock. Test-only archive instrumentation replaces
an already allowlisted fixture, never production code. No credentials are copied.
A passing case is NOT all of task 11.4: partial broadcast requires its own fixture.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import zipfile
from shell_client import prepare

ROOT = Path(__file__).resolve().parents[1]
CASES = {'nested-console': 'tests.resource_policy_multiplayer',
         'render-preparing': 'tests.resource_policy_multiplayer_render'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def instrument(archive, destination, module):
    """Keep every non-test payload byte identical, including control and version."""
    with zipfile.ZipFile(archive) as original:
        info_path = next(n for n in original.namelist() if n.endswith('/info.json'))
        prefix = info_path.rsplit('/', 1)[0] + '/'
        payload = {n: original.read(n) for n in original.namelist()}
    before = dict(payload)
    payload[prefix + 'tests/resource_policy_multiplayer_scene.lua'] = payload[prefix + 'tests/shell_client_engine.lua']
    payload[prefix + 'tests/shell_client_engine.lua'] = ('return require(' + json.dumps(module) + ')\n').encode()
    for source in (ROOT / 'tests').glob('resource_policy_multiplayer*.lua'):
        payload[prefix + 'tests/' + source.name] = source.read_bytes()
    changed = sorted(n for n, data in payload.items() if before.get(n) != data)
    assert changed and all(n.startswith(prefix + 'tests/') for n in changed)
    destination.parent.mkdir(parents=True)
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as output:
        for name, data in payload.items():
            output.writestr(name, data)
    with zipfile.ZipFile(destination) as result:
        assert all(result.read(n) == data for n, data in before.items() if not n.startswith(prefix + 'tests/'))
    return {'source_archive_sha256': digest(archive), 'instrumented_archive_sha256': digest(destination),
            'production_payloads_unchanged': True, 'changed_test_payloads': changed}


def wait(predicate, label, processes=(), timeout=180.0):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        for process in processes:
            if process.poll() is not None:
                raise RuntimeError(f'process exited ({process.returncode}) waiting for {label}')
        try:
            value = predicate()
            if value:
                return value
        except (FileNotFoundError, json.JSONDecodeError):
            pass
        time.sleep(.2)
    raise RuntimeError('timeout: ' + label)


def worker(folder):
    """Runs inside its own xvfb-run; no display cookie leaves this process tree."""
    from resource_policy_multiplayer_x11 import close_factorio
    command = json.loads((folder / 'command.json').read_text())
    forced = False
    with (folder / 'client.log').open('w') as output:
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 600
            while process.poll() is None and not (folder / 'stop').exists():
                if time.monotonic() >= deadline:
                    raise TimeoutError('client driver deadline')
                time.sleep(.2)
            subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-f', 'x11grab',
                            '-video_size', '1280x720', '-i', os.environ['DISPLAY'], '-frames:v', '1',
                            str(folder / 'window.png')], check=True, timeout=30)
            if process.poll() is None:
                close_factorio()
                process.wait(timeout=30)
        finally:
            if process.poll() is None:
                forced = True
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait(timeout=10)
    text = (folder / 'client.log').read_text()
    result = {'exit_code': process.returncode, 'forced_cleanup': forced, 'goodbye': 'Goodbye' in text}
    (folder / 'shutdown.json').write_text(json.dumps(result, indent=2))
    return 0 if result['exit_code'] == 0 and not forced and result['goodbye'] else 1


def run(args):
    output = args.output.resolve()
    if output.exists() or output.is_relative_to(ROOT):
        raise ValueError('fresh output directory outside git required')
    output.mkdir(parents=True)
    (output / 'invocation.json').write_text(json.dumps([sys.executable] + sys.argv, indent=2))
    summary = {'passed': False, 'case': args.case, 'mode': args.mode, 'connected_clients': 0,
               'partial_broadcast': 'not exercised; pending integrated radio continuation fixture',
               'visual_acceptance': 'inspect actual window.png files separately', 'errors': []}
    clients, handles = [], []
    server = None
    try:
        for name, engine in [('server', args.factorio), ('client', args.client / 'bin/x64/factorio')]:
            for flag in ('--version', '--help'):
                text = subprocess.check_output([str(engine), flag], text=True)
                (output / (name + flag + '.txt')).write_text(text)
        package = output / 'instrumented' / args.archive.name
        summary.update(instrument(args.archive, package, CASES[args.case]))
        template = output / 'config-template.ini'
        template.write_text('[path]\nread-data=__PATH__executable__/../../data\nwrite-data=__PATH__executable__/../..\n[other]\ncheck-updates=false\nautosave-interval=0\nlocale=en\n[graphics]\ncache-sprite-atlas=false\n')
        scene = output / 'scene'
        commands = prepare(package, args.factorio, args.client, scene, args.mode, template)
        (output / 'commands.json').write_text(json.dumps(commands, indent=2))
        log = output / 'server.log'
        handle = log.open('w'); handles.append(handle)
        server = subprocess.Popen(commands['server'], stdin=subprocess.PIPE, stdout=handle,
                                  stderr=subprocess.STDOUT, text=True)
        wait(lambda: 'Hosting game at IP ADDR' in log.read_text(), 'server listening', [server])
        for number in (1, 2):
            folder = scene / ('client' + str(number))
            (folder / 'write/player-data.json').write_text(json.dumps({'service-username': 'PolicyPeer' + str(number), 'service-token': ''}))
            (folder / 'command.json').write_text(json.dumps(commands['client' + str(number)]))
            handle = (folder / 'driver.log').open('w'); handles.append(handle)
            process = subprocess.Popen(['xvfb-run', '-a', '-s', '-screen 0 1280x720x24 -nolisten tcp',
                                        sys.executable, str(Path(__file__).resolve()), '--client-worker', str(folder)],
                                       stdout=handle, stderr=subprocess.STDOUT)
            clients.append((folder, process))
            marker = 'TC_MP_BOUNDARY_READY' if number == 1 else 'TC_MP_OK'
            wait(lambda: marker in log.read_text(), marker, [server] + [p for _, p in clients])
            summary['connected_clients'] = number
        def matching():
            states = [json.loads((scene / name / 'write/script-output/resource-policy-peer.json').read_text())
                      for name in ('server', 'client1', 'client2')]
            if states[0] == states[1] == states[2] and states[0]['phase'] == 'done' and len(states[0]['peers']) == 2:
                return states[0]
        state = wait(matching, 'identical independently evaluated peer snapshots', [server] + [p for _, p in clients])
        (output / 'agreed-state.json').write_text(json.dumps(state, indent=2))
        # Keep peers connected across additional engine checksum intervals.
        time.sleep(5)
        assert matching(), 'postjoin state/effect order diverged'
        summary['state_equal_on_three_processes'] = True
        summary['passed'] = True
    except Exception as error:
        summary['errors'].append(str(error))
    finally:
        for folder, process in clients:
            (folder / 'stop').touch()
        for folder, process in clients:
            try:
                process.wait(timeout=65)
                receipt = json.loads((folder / 'shutdown.json').read_text())
                if process.returncode or receipt['forced_cleanup'] or receipt['exit_code'] or not receipt['goodbye']:
                    raise RuntimeError('unclean client shutdown: ' + str(receipt))
            except Exception as error:
                summary['errors'].append(str(error))
                if process.poll() is None:
                    process.terminate(); process.wait(timeout=10)
        if server is not None:
            assert server.stdin is not None
            forced = False
            if server.poll() is None:
                server.stdin.write('/quit\n'); server.stdin.flush()
                try:
                    server.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    forced = True; server.kill(); server.wait(timeout=10)
            server.stdin.close()
            summary['server_shutdown'] = {'exit_code': server.returncode, 'forced_cleanup': forced,
                                          'goodbye': 'Goodbye' in (output / 'server.log').read_text()}
            if forced or server.returncode or not summary['server_shutdown']['goodbye']:
                summary['errors'].append('unclean server shutdown')
        for handle in handles:
            handle.close()
        # Exclude normal declarations such as 'desync history' from error matching.
        bad = re.compile(r'(desynchroni[sz]|Desync detected|desync-report|Exception at tick|Error while running event)', re.I)
        summary['desync_or_runtime_errors'] = []
        for path in [output / 'server.log'] + [folder / 'client.log' for folder, _ in clients]:
            if path.exists():
                summary['desync_or_runtime_errors'] += [str(path) + ': ' + line for line in path.read_text().splitlines() if bad.search(line)]
        summary['desync_archives'] = [str(p) for p in output.rglob('*desync*.zip')]
        summary['passed'] = summary['passed'] and not summary['errors'] and not summary['desync_or_runtime_errors'] and not summary['desync_archives']
        (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))
    return 0 if summary['passed'] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--client-worker', type=Path)
    parser.add_argument('--factorio', type=Path)
    parser.add_argument('--client', type=Path, help='complete licensed distribution root')
    parser.add_argument('--archive', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--case', choices=CASES, default='nested-console')
    parser.add_argument('--mode', choices=('base', 'space-age'), default='base')
    args = parser.parse_args()
    if args.client_worker:
        return worker(args.client_worker)
    if not all((args.factorio, args.client, args.archive, args.output)):
        parser.error('--factorio --client --archive --output required')
    return run(args)


if __name__ == '__main__':
    raise SystemExit(main())
