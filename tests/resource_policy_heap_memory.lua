-- Guest-table lifetime admission; temporary/frame coverage is a separate gate.
local memory=require('scripts.runtime.memory')
local sandbox=require('scripts.runtime.sandbox')
local admission=require('scripts.runtime.admission')
local compiler=require('scripts.runtime.compiler')
local library_jobs=require('scripts.runtime.library-jobs')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={}; local loaded=false
local services
local function guard()
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ctx=admission.context(admission.new(),'heap-publication',0); ctx.memory_owner=owner
  local checkpoint={owned={},owned_order={}}
  local g=sandbox.new(ctx,{},nil,checkpoint); g.initialize()
  return g,account,owner,checkpoint,ctx
end
local function same(account,used,count,owner)
  assert(account.used==used and account.reserved==0 and owner.count==count,'partial retained admission')
end
local function bulk()
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local a,b={},{}
  memory.acquire_all(owner,{{a,192},{a,192},{'alias',37},{'alias',37}})
  assert(owner.count==2,'duplicate bulk payload charged more than once')
  local used,count=account.used,owner.count
  memory.configure(account,used+48)
  local ok,e=pcall(memory.acquire_all,owner,{{a,240},{b,192}})
  assert(not ok and errors.resource_diagnostic(e) and account.values[a].bytes==192 and not owner.values[b])
  same(account,used,count,owner)
  ok=pcall(memory.acquire_all,owner,{{a,240},{a,256}})
  assert(not ok and account.values[a].bytes==192); same(account,used,count,owner)
  memory.configure(account,1000000); memory.resize(owner,a,1000); used=account.used
  memory.configure(account,1)
  memory.acquire_all(owner,{{b,192},{a,192}})
  assert(owner.values[b] and account.values[a].bytes==192 and account.used<used,'non-growing replacement refused below a lowered limit')
  memory.close(owner,function() end)
  local baseline=account.used
  memory.configure(account,1000000)
  local sponsor=memory.owner(account,1024); owner=memory.owner(account)
  used=account.used+account.reserved; memory.configure(account,1)
  memory.acquire_all(owner,{{a,192},{'alias',37}},sponsor)
  assert(account.used+account.reserved==used and owner.count==2,'prepaid bulk delivery grew after a decrease')
  local remaining=sponsor.reserved
  ok,e=pcall(memory.acquire_all,owner,{{a,10000},{b,192}},sponsor)
  assert(not ok and errors.resource_diagnostic(e) and sponsor.reserved==remaining and account.values[a].bytes==192)
  memory.close(sponsor,function() end); memory.close(owner,function() end)
  assert(account.used==baseline and account.reserved==0 and next(account.values)==nil)
  log('TC_CONTRACT atomic-bulk-alias-refusal-shrink-and-sponsored-retained-admission')
end
local function mutations()
  local g,account,owner,checkpoint=guard()
  local a=g.new(2,function() return {'old','shared'} end)
  local b=g.new(1,function() return {kept='shared'} end)
  local before,count=account.used,owner.count
  assert(owner.values[a] and owner.values[b] and owner.values.shared)
  local keys_a,keys_b=checkpoint.owned[a].keys,checkpoint.owned[b].keys
  memory.configure(account,before+48+256+#'fresh'+32)
  local ok,e=pcall(g.assignment_check,2,{{a,'fresh'},{b,'fresh'}},{true,true})
  assert(not ok and errors.resource_diagnostic(e),'multi-target growth bypassed shared capacity')
  same(account,before,count,owner)
  assert(checkpoint.owned[a].keys==keys_a and checkpoint.owned[b].keys==keys_b and a.fresh==nil and b.fresh==nil)
  local tab=g.global('table'); local insert=g.get(tab,'insert'); local remove=g.get(tab,'remove'); local sort=g.get(tab,'sort')
  memory.configure(account,before+48)
  ok,e=pcall(g.call,insert,a,1,'new retained value')
  assert(not ok and errors.resource_diagnostic(e) and #a==2 and a[1]=='old' and a[2]=='shared')
  same(account,before,count,owner)
  memory.configure(account,1000000)
  g.call(insert,a,1,'new retained value')
  assert(#a==3 and owner.values['new retained value'] and account.values[a].bytes==192+48*3)
  local used=account.used; memory.configure(account,1)
  assert(g.call(remove,a,1)=='new retained value' and #a==2 and account.used==used-48)
  g.call(sort,a); assert(a[1]=='old' and a[2]=='shared')
  g.call(g.global('rawset'),b,'kept',nil)
  assert(b.kept==nil and account.values[b].bytes==192,'over-limit deletion could not reduce retained storage')
  memory.close(owner,function() end)
  assert(next(account.values)==nil and account.reserved==0)
  log('TC_CONTRACT actual-sandbox-multi-target-insert-remove-sort-decrease-and-atomic-refusal')
end
local function lazy_bindings()
  local g,account,owner,checkpoint,ctx=guard()
  local fn=g.service(function() return true end)
  local facade=g.namespace({probe=fn},'lazy binding fixture')
  local descriptor={name='fixture-1',wire='red',generation=1,kind='heap-test'}
  g.bind_value(facade,descriptor)
  g.bind_value(fn,facade,'probe')
  local before=ctx.machine.allocations
  assert(g.binding(facade)==descriptor and ctx.machine.allocations==before)
  local method=g.binding(fn)
  assert(method.facade==facade and method.method=='probe' and method.name==descriptor.name
    and method.wire==descriptor.wire and method.generation==descriptor.generation and method.kind==descriptor.kind,
    'captured method has no resolved binding descriptor')
  assert(ctx.machine.allocations>before,'binding materialization was uncharged')
  local spent=ctx.machine.allocations
  assert(g.binding(fn)==method and ctx.machine.allocations==spent,'binding lookup repeated descriptor allocation')
  memory.close(owner,function() end)
  log('TC_CONTRACT method-descriptor-materializes-once-at-binding-boundary')
end
local function stable_keys()
  local g,account,owner,checkpoint,ctx=guard()
  local a=g.new(2,function() return {1,2} end)
  local b=g.new(1,function() return {kept=true} end)
  local keys=checkpoint.owned[a].keys
  local function assign(targets,values)
    g.assignment_check(#targets,targets,values)
    for i=#targets,1,-1 do targets[i][1][targets[i][2]]=values[i] end
  end
  assign({{a,1},{a,1}},{3,nil})
  assert(a[1]==3 and checkpoint.owned[a].keys==keys,'unchanged membership rebuilt ownership keys')
  assign({{a,'absent'},{a,'absent'}},{nil,4})
  assert(a.absent==nil and checkpoint.owned[a].keys==keys,'temporary duplicate-target growth changed final membership')
  local rawset=g.global('rawset')
  g.call(rawset,a,2,false)
  assert(a[2]==false and checkpoint.owned[a].keys==keys,'rawset replacement rebuilt ownership keys')
  local before,count=account.used,owner.count
  local keys_b=checkpoint.owned[b].keys
  memory.configure(account,before)
  local ok,e=pcall(assign,{{a,1},{b,'kept'}},{5,'new retained payload'})
  assert(not ok and errors.resource_diagnostic(e),'same-membership replacement bypassed retained admission')
  assert(a[1]==3 and b.kept==true and checkpoint.owned[a].keys==keys and checkpoint.owned[b].keys==keys_b)
  same(account,before,count,owner)
  memory.configure(account,1000000)
  assign({{a,1},{b,'kept'}},{5,'new retained payload'})
  assert(a[1]==5 and b.kept=='new retained payload' and owner.values['new retained payload'])
  assert(checkpoint.owned[a].keys==keys and checkpoint.owned[b].keys==keys_b)
  assign({{a,3},{a,3},{a,4}},{false,nil,'appended value'})
  assert(a[3]==false and a[4]=='appended value' and checkpoint.owned[a].keys==keys and #keys==4,
    'append-only growth copied existing ownership keys')
  assert(account.values[a].bytes==192+48*4 and owner.values['appended value'])
  assign({{a,3},{a,4}},{})
  keys=checkpoint.owned[a].keys
  assign({{a,1}},{})
  assert(a[1]==nil and checkpoint.owned[a].keys~=keys and #checkpoint.owned[a].keys==1)
  local allocations=ctx.machine.allocations
  local keys=checkpoint.owned[a].keys
  for _=1,20 do g.call(rawset,a,2,false) end
  log('TC_KEY_REUSE allocations='..(ctx.machine.allocations-allocations))
  assert(checkpoint.owned[a].keys==keys)
  memory.close(owner,function() end)
  assert(next(account.values)==nil and account.reserved==0)
  log('TC_CONTRACT unchanged-membership-duplicate-targets-rawset-and-retained-refusal')
end
local function single_replacement()
  local function cost(width)
    local g,account,owner,checkpoint,ctx=guard()
    local value=g.new(width,function()
      local result={}; for i=1,width do result[i]=false end; return result
    end)
    local keys=checkpoint.owned[value].keys
    local work,allocations=ctx.machine.work,ctx.machine.allocations
    g.assignment_one(value,width,true); value[width]=true
    local spent,allocated=ctx.machine.work-work,ctx.machine.allocations-allocations
    assert(checkpoint.owned[value].keys==keys and #keys==width)
    local used,count=account.used,owner.count
    memory.configure(account,used)
    local ok,e=pcall(g.assignment_one,value,width,'unadmitted replacement')
    assert(not ok and errors.resource_diagnostic(e) and value[width]==true)
    same(account,used,count,owner)
    memory.configure(account,1)
    g.assignment_one(value,width,false); value[width]=false
    assert(checkpoint.owned[value].keys==keys)
    same(account,used,count,owner)
    memory.close(owner,function() end)
    return spent,allocated
  end
  local small_work,small_allocations=cost(4)
  local large_work,large_allocations=cost(1024)
  assert(large_work==small_work and large_allocations==small_allocations,
    'single replacement rescanned unchanged table ownership')
  log('TC_CONTRACT single-replacement-constant-shape-cost-and-atomic-retained-refusal')
end
local function single_insertion()
  local function cost(width)
    local g,account,owner,checkpoint,ctx=guard()
    local value=g.new(width,function()
      local result={}; for i=1,width do result[i]=false end; return result
    end)
    local keys=checkpoint.owned[value].keys
    local used,count=account.used,owner.count
    memory.configure(account,used+47)
    local ok,e=pcall(g.assignment_one,value,width+1,false)
    assert(not ok and errors.resource_diagnostic(e) and value[width+1]==nil and #keys==width)
    same(account,used,count,owner)
    memory.configure(account,1000000)
    local work,allocations=ctx.machine.work,ctx.machine.allocations
    g.assignment_one(value,width+1,false); value[width+1]=false
    local spent,allocated=ctx.machine.work-work,ctx.machine.allocations-allocations
    assert(checkpoint.owned[value].keys==keys and #keys==width+1 and keys[width+1]==width+1)
    assert(account.values[value].bytes==192+48*(width+1))
    used,count=account.used,owner.count
    memory.configure(account,used+48)
    ok,e=pcall(g.assignment_one,value,'new string key','new string value')
    assert(not ok and errors.resource_diagnostic(e) and value['new string key']==nil and #keys==width+1)
    assert(not owner.values['new string key'] and not owner.values['new string value'])
    same(account,used,count,owner)
    memory.close(owner,function() end)
    return spent,allocated
  end
  local small_work,small_allocations=cost(4)
  local large_work,large_allocations=cost(1000)
  assert(large_work==small_work and large_allocations==small_allocations,
    'single insertion rescanned unchanged table ownership')
  log('TC_CONTRACT single-insertion-constant-shape-cost-and-atomic-retained-refusal')
end
local function native_copy_admission()
  for _,name in ipairs({'sub','lower','upper','reverse'}) do
    local g,account,owner=guard()
    local fn=g.get(g.global('string'),name)
    local native=string[name]; local calls=0
    string[name]=function(...) calls=calls+1; return native(...) end
    local used,count=account.used,owner.count
    memory.configure(account,used)
    local ok,e=pcall(g.call,fn,'Unowned native copy',2,4)
    string[name]=native
    assert(not ok and errors.resource_diagnostic(e) and calls==0,'native copy occurred before retained admission')
    same(account,used,count,owner)
    memory.configure(account,1000000)
    local value=g.call(fn,'Unowned native copy',2,4)
    assert(value==native('Unowned native copy',2,4) and owner.values[value])
    assert(account.reserved==0)
    memory.close(owner,function() end)
  end
  log('TC_CONTRACT bounded-native-copy-prepaid-peak-and-owned-result')
end
local function scalar_results()
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ctx=admission.context(admission.new(),'scalar-results',0); ctx.memory_owner=owner
  local source=[[function start()
    for i=1,100 do assert(math.abs(-i)==i and string.char(65)=='A') end
    assert(string.sub('abcdef',1,-8)=='')
    assert(string.sub('abcdef',2,-2)=='bcde')
    assert(string.lower('AbC')=='abc' and string.upper('AbC')=='ABC' and string.reverse('AbC')=='CbA')
    local ok,value=pcall(string.sub,'abcdef',2,3); assert(ok and value=='bc')
    local left='left'; assert(left..'-'..'right'=='left-right')
    local half=string.rep('x',128); assert(#(half..half)==256 and #(half..half..'x')==257)
    assert(left..''..''..''..''..''..''..''..''==left)
    assert(left..12=='left12')
    local ok=pcall(function() return left..false end); assert(not ok)
    assert(string.char()=='' and string.char(0)==string.sub('x\0',2))
    assert(string.char(65,66)=='AB')
    local ok=pcall(string.char,256); assert(not ok)
    local ok,value,extra=pcall(tonumber,'not-a-number'); assert(ok and value==nil and extra==nil)
    computer.finished()
  end]]
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  local acquire_all=memory.acquire_all; local redundant=0
  local advance=library_jobs.advance; local small_transforms=0
  library_jobs.advance=function(name,g,job,args,...)
    local bounded=(name=='string.sub' or name=='string.lower' or name=='string.upper' or name=='string.reverse')
      and type(args[1])=='string' and #args[1]<=256
    if name=='@concat' and args.n<=8 then
      local bytes=0
      for i=1,args.n do
        if type(args[i])~='string' then bytes=257; break end
        bytes=bytes+#args[i]
      end
      bounded=bytes<=256
    end
    if bounded then small_transforms=small_transforms+1 end
    return advance(name,g,job,args,...)
  end
  memory.acquire_all=function(o,items,...)
    for _,item in ipairs(items) do
      local value=item[1]
      if type(value)=='table' and value.tuple_capacities and o.values[value]
        and o.values[value].record.bytes==item[2] then redundant=redundant+1 end
    end
    return acquire_all(o,items,...)
  end
  local effects,scalar_transfers,scalar_copies=0,0,0
  local codecs={}
  local function services(g)
    local checkpoint=g.call_checkpoint
    g.call_checkpoint=function(p,codec)
      if codec and not codecs[codec] then
        codecs[codec]=true
        for _,name in ipairs({'encode','decode'}) do
          local transfer=codec[name]
          codec[name]=function(tuple,...)
            local primitive=true
            for i=1,tuple.n do
              local kind=type(tuple[i])
              if kind=='table' or kind=='function' then primitive=false; break end
            end
            local result=transfer(tuple,...)
            if primitive then
              scalar_transfers=scalar_transfers+1
              if result~=tuple then scalar_copies=scalar_copies+1 end
            end
            return result
          end
        end
      end
      return checkpoint(p,codec)
    end
    return {computer={finished=function() g.prepare_empty_result(); effects=effects+1 end}}
  end
  local called,ok,diagnostic=pcall(compiler.run,plan,'start',nil,services,ctx,{})
  memory.acquire_all=acquire_all
  library_jobs.advance=advance
  assert(called and ok,diagnostic and diagnostic.message or tostring(ok))
  assert(small_transforms==0,'bounded native transforms allocated library continuation frames')
  assert(effects==1 and redundant==0,'scalar tuples rebuilt already-admitted frame storage')
  assert(scalar_transfers>0 and scalar_copies==0,'primitive-only transfer tuples were defensively copied')
  memory.close(owner,function() end)
  assert(next(account.values)==nil and next(account.owners)==nil)
  log('TC_CONTRACT scalar-tuple-storage-reuse-and-bounded-character-results')
end
local function bounded_transforms()
  for _,args in ipairs({
    {n=3,'abcdef',1,-8},
    {n=3,string.rep('x',10000),1,-10003},
    {n=3,'abcdef',7,-1},
    {n=3,'abcdef',3,2},
    {n=3,'',1,-2},
  }) do
    local g,account,owner,checkpoint,ctx=guard()
    local allocations=ctx.machine.allocations
    local job={}
    local result=library_jobs.advance('string.sub',g,job,args)
    assert(result.n==1 and result[1]==string.sub(args[1],args[2],args[3]) and result[1]=='',
      'empty normalized substring range copied input')
    assert(ctx.machine.allocations-allocations==2,'empty substring admitted payload allocation')
    memory.configure(account,1)
    assert(library_jobs.advance('string.sub',g,job,args)==result)
    memory.close(owner,function() end)
    assert(next(account.values)==nil and next(account.owners)==nil)
  end
  for _,name in ipairs({'sub','lower','upper','reverse'}) do
    for _,width in ipairs({0,256,257}) do
      local g,account,owner,checkpoint,ctx=guard()
      local text=string.rep('aB',math.ceil(width/2)):sub(1,width)
      local job,args={},{n=1,text}
      if name=='sub' then args={n=3,text,1,width} end
      local result=library_jobs.advance('string.'..name,g,job,args)
      local expected=name=='sub' and text or string[name](text)
      assert(result.n==1 and result[1]==expected)
      if width<=256 then
        local work,allocations,used=ctx.machine.work,ctx.machine.allocations,account.used
        assert(library_jobs.advance('string.'..name,g,job,args)==result)
        assert(ctx.machine.work==work and ctx.machine.allocations==allocations and account.used==used,
          'completed native transform repeated paid copy before result delivery')
      end
      memory.close(owner,function() end)
      assert(next(account.values)==nil and next(account.owners)==nil)
    end
  end
  log('TC_CONTRACT bounded-native-transform-boundary-and-paid-result-reuse')
end
local function copies()
  local g,account,owner,checkpoint=guard()
  local first=g.snapshot({left='shared',right='shared'})
  local used,count=account.used,owner.count
  local second=g.snapshot({left='shared',right='shared'})
  assert(first~=second and account.used-used==256+192+48*2 and owner.count==count+1,'copy aliases charged string payload twice')
  used=account.used; count=owner.count
  local order=#checkpoint.owned_order
  memory.configure(account,used+256+192)
  local ok,e=pcall(g.snapshot,{unexpected='new snapshot payload'})
  assert(not ok and errors.resource_diagnostic(e)); same(account,used,count,owner)
  assert(#checkpoint.owned_order==order,'refused snapshot published ownership metadata')
  memory.close(owner,function() end)
  log('TC_CONTRACT snapshot-table-string-lifetimes-and-refusal-before-owned-publication')
end
local function metered(kind,available)
  local g,account,owner,checkpoint,ctx=guard()
  local value=g.new(2,function() return {2,1} end)
  local fn=kind=='rawset' and g.global(kind) or g.get(g.global('table'),kind)
  local keys=checkpoint.owned[value].keys
  local used,count=account.used,owner.count
  ctx.machine.work=limits.callback_work-available
  local ok,e
  if kind=='rawset' then ok,e=pcall(g.call,fn,value,'new',false)
  elseif kind=='insert' then ok,e=pcall(g.call,fn,value,1,'new')
  elseif kind=='remove' then ok,e=pcall(g.call,fn,value,1)
  else ok,e=pcall(g.call,fn,value) end
  if not ok then
    assert(g.work_suspended(),type(e)=='table' and e.message or tostring(e))
    assert(#value==2 and value[1]==2 and value[2]==1 and value.new==nil and checkpoint.owned[value].keys==keys)
    same(account,used,count,owner)
  end
  local cost=ctx.machine.work-(limits.callback_work-available)
  memory.close(owner,function() end)
  return ok,cost
end
local function growth()
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ledger=admission.new(); local ctx=admission.context(ledger,'real-heap-growth',0); ctx.memory_owner=owner
  local source='function start() local root=table.pack(); local node=root; while true do assert(rawget(root,"n")==0); local child=table.pack(); rawset(node,"next",child); node=child end end'
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  local checkpoint={}; local waited=false; local refused=false
  ctx=admission.context(ledger,'real-heap-growth',1); ctx.memory_owner=owner
  assert(admission.reserve(ctx,'work',limits.callback_work-1))
  local ok,e,control=compiler.run(plan,'start',{}, {},ctx,checkpoint)
  assert(not ok and control=='wait',e and e.message)
  memory.configure(account,account.used+4096) -- Isolate guest growth from the source-derived initial footprint.
  for tick=2,101 do
    ctx=admission.context(ledger,'real-heap-growth',tick); ctx.memory_owner=owner
    assert(admission.reserve(ctx,'work',limits.callback_work-1024))
    local ok,diagnostic,control=compiler.run(plan,'start',{}, {},ctx,checkpoint)
    assert(not ok and (control=='wait' or control=='resource'),diagnostic and diagnostic.message)
    assert(account.used+account.reserved<=account.limit,'guest retention exceeded aggregate allowance')
    if control=='resource' then
      assert(waited and diagnostic.code=='E_CAPACITY' and diagnostic.recoverable and owner.count>4)
      refused=true; break
    end
    waited=true
  end
  assert(refused,'cross-tick guest heap growth did not reach retained admission')
  memory.close(owner,function() end)
  assert(next(account.values)==nil and next(account.owners)==nil)
  log('TC_CONTRACT actual-guest-cross-tick-allocation-refuses-without-retained-credit-renewal')
end
local function frame_storage(account,checkpoint)
  local strings={[checkpoint.source]=true,[checkpoint.handler]=true}
  local payload=account.values[checkpoint].bytes+256
  local count,shared=1,payload
  for _,value in ipairs(checkpoint.symbol_roots) do
    if type(value)=='table' then
      assert(account.values[value] and account.values[checkpoint.symbols[value]])
      payload=payload+account.values[value].bytes+256; shared=shared+account.values[value].bytes+256
      count=count+1; strings[checkpoint.symbols[value]]=true
    else assert(type(value)=='string' and account.values[value]); strings[value]=true end
  end
  for _,token in ipairs(checkpoint.functions_order) do
    local bytes=assert(account.values[token]).bytes+256
    payload=payload+bytes; shared=shared+bytes; count=count+1
  end
  for value in pairs(strings) do payload=payload+#value+32+256; shared=shared+128; count=count+1 end
  return payload,count,shared
end
local function frames()
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ledger=admission.new(); local ctx=admission.context(ledger,'frame-admission',0); ctx.memory_owner=owner
  local source='function start() computer.finished() end'
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  memory.configure(account,account.used)
  local checkpoint,effects={},0
  local function services(g)
    return {computer={finished=function() g.prepare_empty_result(); effects=effects+1 end}}
  end
  local used,count=account.used,owner.count
  local ok,diagnostic,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
  assert(not ok and control=='resource' and diagnostic.recoverable and effects==0 and next(checkpoint)==nil,
    'unadmitted frame/source was initialized or executed')
  same(account,used,count,owner)
  memory.configure(account,1000000)
  ctx=admission.context(ledger,'frame-admission',1); ctx.memory_owner=owner
  assert(compiler.run(plan,'start',nil,services,ctx,checkpoint))
  assert(effects==1 and owner.values[checkpoint] and owner.values[source] and owner.values.start,
    'accepted frame/source storage has no lifetime ownership')
  local other=memory.owner(account); local second={}
  local before=account.used
  local _,_,shared=frame_storage(account,checkpoint)
  ctx=admission.context(ledger,'frame-admission-other',2); ctx.memory_owner=other
  assert(compiler.run(plan,'start',nil,services,ctx,second))
  assert(effects==2 and account.used-before==shared,
    'shared source/handler payloads were charged twice across frames')
  memory.close(owner,function() end)
  assert(other.values[source] and other.values.start and other.values[second] and not account.values[checkpoint])
  memory.close(other,function() end)
  assert(next(account.values)==nil and next(account.owners)==nil)
  log('TC_CONTRACT initial-frame-source-and-handler-admission-precedes-checkpoint-publication')
end
local function binding_refusal()
  local source='function start() local p=peripheral.wrap(); computer.finished() end'
  local function setup(key)
    local account=memory.new(1000000,256); local owner=memory.owner(account)
    local ledger=admission.new(); local ctx=admission.context(ledger,key,0); ctx.memory_owner=owner
    local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
    return {account=account,owner=owner,ledger=ledger,checkpoint={},plan=plan,wraps=0,probes=0,effects=0},ctx
  end
  local reference,ctx=setup('binding-reference')
  assert(compiler.run(reference.plan,'start',nil,function(g) return services(reference,g) end,ctx,reference.checkpoint))
  local bytes,count=frame_storage(reference.account,reference.checkpoint)
  memory.close(reference.owner,function() end)
  local f; f,ctx=setup('binding-refusal')
  local admitted=f.account.used+bytes
  memory.configure(f.account,admitted+2*192+6*48+16+48+256)
  local ok,e,control=compiler.run(f.plan,'start',nil,function(g) return services(f,g) end,ctx,f.checkpoint)
  assert(not ok and control=='resource' and e.recoverable and f.wraps==0 and f.effects==0
    and #f.checkpoint.bindings_order==0 and next(f.checkpoint.bindings)==nil,
    'binding refusal published an effect or partial descriptor')
  same(f.account,admitted,count,f.owner)
  memory.configure(f.account,1000000)
  ctx=admission.context(f.ledger,'binding-refusal',1); ctx.memory_owner=f.owner
  assert(compiler.run(f.plan,'start',nil,function(g) return services(f,g) end,ctx,f.checkpoint))
  assert(f.wraps==1 and f.effects==1 and #f.checkpoint.bindings_order==1)
  memory.close(f.owner,function() end)
  log('TC_CONTRACT binding-batch-refusal-precedes-descriptor-publication-and-prepared-effect')
end
local function binding_shell()
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ctx=admission.context(admission.new(),'binding-shell',0); ctx.memory_owner=owner
  local graph={version=1,root=1,nodes={
    {kind='table',entries={{key='p',value={ref=2}},{key='probe',value={ref=3}}}},
    {kind='binding',binding={name='fixture-1',wire='red',generation=1,kind='heap-test'}},
    {kind='binding',binding={name='fixture-1',wire='red',generation=1,kind='heap-test',method='probe',facade={ref=2}}},
  }}
  local shell={values=graph,output=function() error('unexpected shell output') end}
  local f={probes=0,wraps=0,effects=0}
  local plan,e=compiler.compile('assert(probe==p.probe and rawequal(p.probe,probe)); probe(); assert(rawequal(p.probe,probe))',ctx,'shell'); assert(plan,e and e.message)
  local checkpoint={}
  local ok,e=compiler.run(plan,'command',nil,function(g) return services(f,g) end,ctx,checkpoint,shell)
  assert(ok,e and e.message)
  assert(f.probes==1 and f.wraps==0 and checkpoint.value_graph~=graph and #checkpoint.bindings_order==2)
  for token,d in pairs(checkpoint.bindings) do
    assert(owner.values[token] and owner.values[d.name] and owner.values[d.wire] and owner.values[d.kind])
    if d.method then assert(owner.values[d.facade] and owner.values[d.method]) end
  end
  memory.close(owner,function() end)
  assert(next(account.values)==nil and next(account.owners)==nil)
  log('TC_CONTRACT shell-graph-binding-restoration-shares-accounted-parent-and-method-identities')
end
function M.run()
  single_replacement(); single_insertion(); native_copy_admission(); scalar_results(); bounded_transforms(); lazy_bindings(); stable_keys(); frames(); bulk(); mutations(); copies(); growth(); binding_refusal(); binding_shell()
  for _,kind in ipairs({'rawset','insert','remove','sort'}) do
    local ok,cost=metered(kind,limits.callback_work); assert(ok)
    for available=0,cost-1 do assert(not metered(kind,available),'short heap allowance published a mutation') end
  end
  log('TC_CONTRACT heap-publication-prepays-every-shorter-work-allowance')
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ledger=admission.new(); local ctx=admission.context(ledger,'heap-cold',0); ctx.memory_owner=owner
  local source=[[function start()
    local p=peripheral.wrap(); local probe=p.probe; probe()
    local key=string.char(102,108,111,111,114); local floor=math[key]
    local text=string.rep('z',128)
    local root=table.pack(); local child=table.pack('kept')
    rawset(root,'self',root); rawset(root,'child',child)
    local n=0; while n<300000 do n=n+1 end
    assert(rawequal(root,rawget(root,'self'))); assert(rawget(child,1)=='kept'); assert(floor(1.5)==1); assert(#text==128)
    rawset(root,'child',nil); probe(); computer.finished()
  end]]
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  storage.tc_heap_memory={phase='armed',account=account,owner=owner,ledger=ledger,plan=plan,checkpoint={},effects=0,probes=0,wraps=0}
end
services=function(f,g)
  local facade
  local probe=g.service(function() g.prepare_empty_result(); f.probes=f.probes+1 end)
  facade=g.namespace({probe=probe},'heap binding fixture')
  g.bind_value(facade,{name='fixture-1',wire='red',generation=1,kind='heap-test'})
  g.bind_value(probe,{name='fixture-1',wire='red',generation=1,kind='heap-test',method='probe',facade=facade})
  g.binding_resolver(function(d,parent)
    assert(d.name=='fixture-1' and d.wire=='red' and d.generation==1 and d.kind=='heap-test')
    if d.method then assert(d.method=='probe' and parent==facade); return probe end
    assert(parent==nil); return facade
  end)
  return {computer={finished=function() g.prepare_empty_result(); f.effects=f.effects+1 end},
    peripheral={wrap=function() local result=g.prepare_result(facade); f.wraps=f.wraps+1; return result end}}
end
local function step(f,tick)
  local ctx=admission.context(f.ledger,'heap-cold',tick); ctx.memory_owner=f.owner
  return compiler.run(f.plan,'start',{},function(g) return services(f,g) end,ctx,f.checkpoint)
end
function M.on_load()
  local f=storage.tc_heap_memory
  if f.phase=='frozen' then
    assert(f.account.used==f.used and f.account.limit==1 and f.account.reserved==f.reserved
      and f.owner.count==f.count and f.ledger.total==f.spent and f.checkpoint.frame.pc==f.pc
      and f.checkpoint.collection==f.collection and f.root.self==f.root and f.root.child==f.child
      and f.child[1]=='kept' and f.owner.values[f.root] and f.owner.values[f.child] and f.effects==0 and f.probes==1 and f.wraps==1
      and f.owner.values[f.checkpoint] and f.owner.values[f.plan.source] and f.owner.values.start)
    loaded=true; log('TC_HEAP_MEMORY_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local f=storage.tc_heap_memory
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if f.phase=='armed' then
    local ok,e,control=step(f,event.tick)
    assert(not ok and control=='wait',e and e.message)
    local count=0
    for token,d in pairs(f.checkpoint.bindings) do
      count=count+1
      assert(f.owner.values[token] and f.owner.values[d.name] and f.owner.values[d.wire] and f.owner.values[d.kind],
        'saved binding descriptor bypassed lifetime admission')
      if d.method then assert(f.owner.values[d.method] and f.owner.values[d.facade]) end
    end
    assert(count==2 and f.probes==1,'binding facade/method alias or effect prefix missing')
    assert(f.owner.values[f.checkpoint.intern['math.floor']] and f.owner.values['math.floor'])
    assert(f.owner.values[string.rep('z',128)],'cold string result was not admitted')
    for _,token in ipairs(f.checkpoint.symbol_roots) do
      assert(f.owner.values[token] and (type(token)=='string' or f.owner.values[f.checkpoint.symbols[token]]))
    end
    for value in pairs(f.checkpoint.owned) do if value.self==value then f.root=value; f.child=value.child end end
    assert(f.root and f.child and f.child[1]=='kept' and f.owner.values[f.root] and f.owner.values[f.child])
    memory.configure(f.account,1)
    f.used=f.account.used; f.reserved=f.account.reserved; f.count=f.owner.count; f.spent=f.ledger.total
    f.tick=event.tick; f.pc=f.checkpoint.frame.pc; f.collection=f.checkpoint.collection; f.phase='frozen'
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if loaded then
    local ok,e,control=step(f,f.tick)
    assert(not ok and control=='wait' and f.account.used==f.used and f.owner.count==f.count and f.ledger.total==f.spent
      and f.checkpoint.frame.pc==f.pc and f.checkpoint.collection==f.collection and f.effects==0,e and e.message)
    loaded=false; f.phase='resuming'; f.resumed=event.tick
  end
  local ok,e,control=step(f,event.tick)
  assert(ok or control=='wait',e and e.message)
  assert(event.tick-f.resumed<100 and f.account.used<=f.used and f.root.self==f.root and f.child[1]=='kept'
    and f.owner.values[f.checkpoint] and f.owner.values[f.plan.source] and f.owner.values.start)
  if ok then
    assert(f.effects==1 and f.probes==2 and f.wraps==1 and f.root.child==nil and f.account.limit==1 and f.owner.values[f.root])
    memory.close(f.owner,function() end)
    assert(next(f.account.values)==nil and next(f.account.owners)==nil and f.account.reserved==0)
    f.phase='done'; log('TC_CONTRACT guest-heap-cold-cycle-alias-lowered-limit-read-delete-and-once-only-completion')
    log('TC_COLD_OK')
  end
end
return M
