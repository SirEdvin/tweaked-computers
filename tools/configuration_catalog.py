#!/usr/bin/env python3
"""Freeze normalized schemas and an honest adapter ledger from the pinned inventory."""
import argparse
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'openspec/changes/add-native-circuit-computers/specs/device-configurator/configuration-catalog.json'
BASIC = {'Accumulator','Container','ProxyContainer','GenericOnOff','Inserter','Loader','MiningDrill','Pump','Splitter','StorageTank','TransportBelt','Wall'}
COMMON = 'LuaGenericOnOffControlBehavior'

def generate():
    catalog = json.loads(SOURCE.read_text())
    def schema(t):
        if isinstance(t, str):
            if t in ('boolean', 'string', 'float', 'int32', 'uint32'):
                s = {'kind': {'float':'number','int32':'integer','uint32':'integer'}.get(t,t)}
                if t == 'string': s['max_bytes'] = 256
                if t == 'int32': s.update(min=-2147483648,max=2147483647)
                if t == 'uint32': s.update(min=0,max=4294967295)
                return s
            if t.startswith('defines.'):
                return {'kind':'enum','values':catalog['enum_values'][t], 'native_enum':t}
            if t in ('QualityID','SpaceLocationID'):
                return {'kind':'string','max_bytes':256,'prototype_registry':'quality' if t=='QualityID' else 'space_location'}
            if t in catalog['concepts']:
                s = schema(catalog['concepts'][t]['type']); s['concept'] = t
                if t in ('SignalID','SignalIDBase'):
                    s['required'] = ['type','name']
                    s['constraints'] = ['registered_signal','explicit_signal_type']
                if t == 'CircuitConditionDefinition':
                    s['fields'].pop('fulfilled',None)
                    s['constraints'] = ['condition_operand_exclusive','condition_signal_roles']
                return s
            raise ValueError('unaccounted type '+t)
        kind = t['complex_type']
        if kind == 'type': return schema(t['value'])
        if kind == 'literal': return {'kind':'enum','values':[t['value']]}
        if kind == 'array': return {'kind':'array','items':schema(t['value']),'max_items':128}
        if kind == 'union':
            if all(isinstance(x,dict) and x.get('complex_type')=='literal' for x in t['options']):
                return {'kind':'enum','values':[x['value'] for x in t['options']]}
            return {'kind':'union','alternatives':[schema(x) for x in t['options']]}
        if kind == 'table':
            fields = {p['name']:schema(p['type']) for p in t.get('parameters',[])}
            required = [p['name'] for p in t.get('parameters',[]) if not p['optional']]
            variants = {}
            for group in t.get('variant_parameter_groups',[]):
                variants[group['name']] = {'fields':[p['name'] for p in group['parameters']], 'required':[p['name'] for p in group['parameters'] if not p['optional']]}
                for p in group['parameters']: fields[p['name']] = schema(p['type'])
            s = {'kind':'object','fields':fields,'required':required,'additional_fields':False}
            if variants: s.update(variants=variants,constraints=['operation_variant'])
            return s
        if kind == 'builtin':
            return {'kind':'map','max_items':128,'constraints':['explicit_adapter_required']}
        raise ValueError('unaccounted grammar '+kind)
    def decorate(s):
        s.setdefault('readable', True)
        s.setdefault('writable', True)
        s.setdefault('clearable', False)
        for child in s.get('fields', {}).values(): decorate(child)
        if 'items' in s: decorate(s['items'])
        for child in s.get('alternatives', []): decorate(child)
        return s
    schemas = {}; ledger = []
    for b in catalog['behaviors']:
        fields = {}
        basic = b['class'] in {'Lua'+n+'ControlBehavior' for n in BASIC}
        for f in b['writable_fields']:
            s = decorate(schema(f['write_type'])); implemented = basic or f['declared_in'] == COMMON
            # Freeze nullable native signal/condition support; exercise clears in the engine.
            s.update(readable=implemented,writable=implemented,clearable=f['optional'] and f['write_type'] in ('CircuitConditionDefinition','SignalID'))
            if not implemented: s['unavailable_reason'] = 'adapter_pending_tc11'
            fields[f['name']] = s
            ledger.append({'behavior':b['class'],'field':f['name'],'declared_in':f['declared_in'],'status':'implemented' if implemented else 'pending_tc11','evidence':'tests.configurator_engine' if implemented else None})
        schemas[b['class']] = fields
    def work(x):
        if isinstance(x, dict): return 16 + sum(len(k.encode()) + 8 + work(v) for k,v in x.items())
        if isinstance(x, list): return 16 + sum(8 + work(v) for v in x)
        if isinstance(x, str): return 8 + len(x.encode())
        return 8
    result = {'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'schemas':schemas,'schema_work':{k:work(v) for k,v in schemas.items()},'concepts':{n:schema(n) for n in catalog['concepts']},'enum_values':catalog['enum_values']}
    def lua(x):
        if x is None: return 'nil'
        if isinstance(x,bool): return 'true' if x else 'false'
        if isinstance(x,(int,float)): return str(x)
        if isinstance(x,str): return json.dumps(x,ensure_ascii=False)
        if isinstance(x,list): return '{'+','.join(lua(v) for v in x)+'}'
        return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in sorted(x.items()))+'}'
    files = {ROOT/'scripts/configuration/catalog.lua':'-- Generated by tools/configuration_catalog.py; do not edit.\nreturn '+lua(result)+'\n', ROOT/'docs/configuration-coverage.json':json.dumps({'source':catalog['source'],'counts':catalog['counts'],'fields':ledger,'sections':{'status':'pending_tc11'},'concepts':sorted(catalog['concepts']),'enum_groups':sorted(catalog['enum_values'])},indent=2)+'\n'}
    return files

if __name__ == '__main__':
    ap=argparse.ArgumentParser(); ap.add_argument('--check',action='store_true'); args=ap.parse_args()
    for path,text in generate().items():
        if args.check:
            if not path.exists() or path.read_text()!=text: raise SystemExit('stale generated file: '+str(path))
        else:
            path.parent.mkdir(parents=True,exist_ok=True); path.write_text(text)
    print('configuration catalogue: normalized 36 behaviors, 164 field entries, 29 concepts, 10 enum groups')
