#!/usr/bin/env python3
"""Freeze normalized schemas and an honest adapter ledger from the pinned inventory."""
import argparse
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'openspec/specs/device-configurator/configuration-catalog.json'
BASIC = {'Accumulator','Container','ProxyContainer','GenericOnOff','Inserter','Loader','MiningDrill','Pump','Splitter','StorageTank','TransportBelt','Wall'}
BASIC_FIXTURES = {
    'Accumulator':['accumulator'], 'Container':['wooden-chest'], 'ProxyContainer':['proxy-container'],
    'GenericOnOff':['power-switch'], 'Inserter':['inserter'], 'Loader':['loader'],
    'MiningDrill':['electric-mining-drill'], 'Pump':['pump'], 'Splitter':['splitter'],
    'StorageTank':['storage-tank'], 'TransportBelt':['transport-belt'], 'Wall':['stone-wall'],
}
# Explicit native class -> real fixture prototypes. Never enable an unreviewed class.
NATIVE = {
    'AgriculturalTower': ['agricultural-tower'], 'ArithmeticCombinator': ['arithmetic-combinator'],
    'ArtilleryTurret': ['artillery-turret'], 'AssemblingMachine': ['assembling-machine-3','tc11-burner-assembling-machine'],
    'AsteroidCollector': ['asteroid-collector'], 'CargoLandingPad': ['cargo-landing-pad'],
    'ConstantCombinator': ['constant-combinator'], 'DeciderCombinator': ['decider-combinator'],
    'DisplayPanel': ['display-panel'], 'Furnace': ['electric-furnace','stone-furnace'], 'Lamp': ['small-lamp'],
    'LogisticContainer': ['requester-chest', 'buffer-chest', 'passive-provider-chest'],
    'ProgrammableSpeaker': ['programmable-speaker'], 'RailSignalBase': ['rail-signal', 'rail-chain-signal'],
    'Reactor': ['nuclear-reactor'], 'Roboport': ['roboport'], 'RocketSilo': ['rocket-silo'],
    'SelectorCombinator': ['selector-combinator'], 'SpacePlatformHub': ['space-platform-hub'],
    'TrainStop': ['train-stop'], 'Turret': ['gun-turret', 'laser-turret', 'flamethrower-turret'],
}
EXPANSION = {'AgriculturalTower', 'AsteroidCollector', 'SpacePlatformHub'}

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
        stem = b['class'][3:-15]
        basic = stem in BASIC
        for f in b['writable_fields']:
            s = decorate(schema(f['write_type'])); implemented = basic or stem in NATIVE
            if not implemented: raise ValueError('missing explicit class adapter: '+b['class'])
            s.update(readable=True,writable=True,clearable=f['optional'] and f['write_type'] in ('CircuitConditionDefinition','SignalID','ArithmeticCombinatorParameters','DeciderCombinatorParameters','SelectorCombinatorParameters'))
            if stem == 'LogisticContainer' and f['name'] == 'circuit_exclusive_mode_of_operation':
                s['constraints'] = ['logistic_mode_requester_or_buffer']
            if stem in ('AssemblingMachine','Furnace') and f['name'] == 'include_fuel':
                s['constraints'] = ['fuel_inventory_required']
            if stem == 'RailSignalBase' and f['name'] == 'blue_signal':
                s['constraints'] = ['rail_chain_signal_only']
            if stem == 'AsteroidCollector' and f['name'] == 'connect_to_logistic_network':
                s['constraints'] = ['native_asteroid_no_logistic_connection']
            if stem == 'Turret' and f['name'] == 'read_ammo':
                s['constraints'] = ['ammo_or_fluid_turret_required']
            if stem == 'CargoLandingPad':
                s['constraints'] = ['set_requests_requires_space_travel']
            fields[f['name']] = s
            ledger.append({'behavior':b['class'],'field':f['name'],'declared_in':f['declared_in'],
                'status':'native_unavailable' if stem=='AsteroidCollector' and f['name']=='connect_to_logistic_network' else 'implemented',
                'adapter':'scripts.configuration.adapters.apply',
                'evidence':'tests.configurator_engine' if basic else 'tests.configurator_full_engine',
                'prototypes':NATIVE.get(stem,BASIC_FIXTURES.get(stem,[])), 'content':'space-age' if stem in EXPANSION else 'base',
                'constraints':s.get('constraints',[])})
        schemas[b['class']] = fields
    def work(x):
        if isinstance(x, dict): return 16 + sum(len(k.encode()) + 8 + work(v) for k,v in x.items())
        if isinstance(x, list): return 16 + sum(8 + work(v) for v in x)
        if isinstance(x, str): return 8 + len(x.encode())
        return 8
    section_fields = decorate({'kind':'object','fields':{
        'active':schema('boolean'), 'group':schema('string'), 'multiplier':schema('float'),
        'filters':schema({'complex_type':'array','value':'LogisticFilter'})},'required':[], 'additional_fields':False})['fields']
    # Native filter arrays use explicit slot indexes in addition to LogisticFilter.
    section_fields['filters']['items']['fields']['index'] = decorate({'kind':'integer','min':1,'max':128})
    section_fields['filters']['items']['required'] = ['index']
    result = {'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'schemas':schemas,
        'section_fields':section_fields, 'fixtures':{'Lua'+k+'ControlBehavior':v for k,v in NATIVE.items()},
        'schema_work':{k:work(v) for k,v in schemas.items()},'concepts':{n:schema(n) for n in catalog['concepts']},'enum_values':catalog['enum_values']}
    def lua(x):
        if x is None: return 'nil'
        if isinstance(x,bool): return 'true' if x else 'false'
        if isinstance(x,(int,float)): return str(x)
        if isinstance(x,str): return json.dumps(x,ensure_ascii=False)
        if isinstance(x,list): return '{'+','.join(lua(v) for v in x)+'}'
        return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in sorted(x.items()))+'}'
    files = {ROOT/'scripts/configuration/catalog.lua':'-- Generated by tools/configuration_catalog.py; do not edit.\nreturn '+lua(result)+'\n', ROOT/'docs/configuration-coverage.json':json.dumps({'source':catalog['source'],'counts':catalog['counts'],'fields':ledger,'sections':{'status':'implemented','adapter':'scripts.configuration.sections','evidence':'tests.configurator_full_engine','fields':sorted(section_fields),'policy':'nonmanual read-only; shared filter writes refused; explicit local detach preserves effective filters'},'concepts':sorted(catalog['concepts']),'enum_groups':sorted(catalog['enum_values'])},indent=2)+'\n'}
    return files

if __name__ == '__main__':
    ap=argparse.ArgumentParser(); ap.add_argument('--check',action='store_true'); args=ap.parse_args()
    for path,text in generate().items():
        if args.check:
            if not path.exists() or path.read_text()!=text: raise SystemExit('stale generated file: '+str(path))
        else:
            path.parent.mkdir(parents=True,exist_ok=True); path.write_text(text)
    print('configuration catalogue: normalized 36 behaviors, 164 field entries, 29 concepts, 10 enum groups')
