#!/usr/bin/env python3
"""Exact-archive Dashboard robot/cold/optional-library lifecycle matrix."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
from smoke import ROOT, chart_archive, cold_phase


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def readable(path):
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None, path


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--factorio',required=True,type=Path)
    parser.add_argument('--archive',required=True,type=Path)
    parser.add_argument('--chart-archive',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--mode',choices=('base','space-age','both'),default='both')
    args=parser.parse_args()
    output=args.output.resolve()
    if output.exists() or output.is_relative_to(ROOT):
        parser.error('fresh output outside checkout required')
    output.mkdir(parents=True)
    charts=chart_archive(args.chart_archive)
    archive_hash=digest(args.archive)
    command=[sys.executable,str(ROOT/'tools/smoke.py'),'--factorio',str(args.factorio.resolve()),
             '--archive',str(args.archive.resolve()),'--chart-archive',str(args.chart_archive.resolve()),
             '--output',str(output/'initial'),'--mode',args.mode,'--fixture','tests.dashboard_lifecycle_engine',
             '--production-context','--cold']
    (output/'initial-command.json').write_text(json.dumps(command,indent=2)+'\n')
    with (output/'initial.log').open('w') as log:
        subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)
    initial=json.loads((output/'initial/summary.json').read_text())
    modes=['base','space-age'] if args.mode=='both' else [args.mode]
    assert [case['mode'] for case in initial['cases']]==modes
    assert initial['archive_sha256']==archive_hash and initial['charts']==charts
    receipts=[]
    for case in initial['cases']:
        mode=case['mode']; source=output/'initial'/mode
        assert case['passed'] and case['exit_code']==0 and len(case['cold_phases'])==2
        assert all(p['passed'] and p['exit_code']==0 and p['cleanup']['console_quit_acknowledged'] and not p['cleanup']['forced_kill'] for p in case['cold_phases'])
        save=source/'write/saves/tc-dashboard-dependency.zip'; readable(save)
        phases=list(case['cold_phases'])
        for enabled,name,marker,save_name in (
                (False,'absent','TC_DASHBOARD_DEPENDENCY_ABSENT_OK','tc-dashboard-reinstall'),
                (True,'reinstalled','TC_DASHBOARD_DEPENDENCY_PRESENT_OK','tc-dashboard-final')):
            folder=output/mode/name; folder.mkdir(parents=True)
            mods=folder/'mods'; shutil.copytree(source/'mods',mods)
            listing=json.loads((mods/'mod-list.json').read_text())
            for mod in listing['mods']:
                if mod['name']=='factorio-charts': mod['enabled']=enabled
                elif mod['name'] in ('space-age','quality','elevated-rails','recycler'): mod['enabled']=mode=='space-age'
            (mods/'mod-list.json').write_text(json.dumps(listing,indent=2)+'\n')
            write=folder/'write'; (write/'saves').mkdir(parents=True)
            config=folder/'config.ini'
            config.write_text((source/'config.ini').read_text().replace(str(source/'write'),str(write)))
            input_save=folder/'input.zip'; shutil.copy2(save,input_save)
            original_hash=digest(save); assert digest(input_save)==original_hash
            target=write/'saves'/(save_name+'.zip')
            result=cold_phase(args.factorio.resolve(),config,mods,input_save,folder,name,marker,target)
            assert digest(save)==original_hash,'previous phase save was overwritten'
            result.update(input_sha256=original_hash,output_sha256=digest(target),archive_sha256=archive_hash,
                          chart_enabled=enabled,chart_sha256=charts['sha256'])
            phases.append(result); save=target
        final=output/mode/'reinstalled/write/script-output/dashboard-lifecycle.json'
        observed=json.loads(final.read_text())
        assert observed['passed'] and observed['boots']==1 and observed['effects']==0
        assert observed['robot_mined'] and observed['robot_built'] and observed['bytes']==65536
        assert observed['original']!=observed['replacement']
        receipts.append({'mode':mode,'passed':True,'phases':phases,'observation_sha256':digest(final)})
    assert len(receipts)==len(modes) and all(len(c['phases'])==4 for c in receipts)
    summary={'engine':'2.1.23','passed':True,'archive_sha256':archive_hash,'charts':charts,
             'expected_mode_cases':len(modes),'expected_process_phases':len(modes)*4,'cases':receipts}
    (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary))


if __name__=='__main__':
    main()
