local parsing=require('scripts.runtime.parse_admission')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local M={}
function M.run()
  local reserve,cache,work=memory.reserve,limits.compiler_cache_bytes,limits.compile_work
  local events={}; for i=1,33 do events[i]=i%2==0 and -i or i end
  local observed,context,account
  memory.reserve=function(owner,bytes)
    if observed then observed[#observed+1]={used=account.used+account.reserved,bytes=bytes,work=context.machine.compile} end
    return reserve(owner,bytes)
  end
  local function run(ceiling,work_ceiling,cache_ceiling,proof,watch)
    limits.compile_work,limits.compiler_cache_bytes=work_ceiling,cache_ceiling
    account=memory.new(ceiling,0,'host_memory')
    local owner=memory.owner(account)
    context=admission.context(admission.new(),'proof-memory',0)
    observed=watch and {} or nil
    parsing.begin(context); parsing.attach(owner)
    local ok,result=pcall(function()
      if proof then
        if parsing.replay(proof) then return proof end
        assert(context.machine.compile==0 and owner.reserved==0,'unfitting summary paid before cold fallback')
      end
      local charges=parsing.record()
      assert(owner.reserved==192+2*48,'compiler summary root allocation is not fixed and prepaid')
      local bytes=0
      for _,cost in ipairs(events) do
        if cost<0 then parsing.allocate(-cost); bytes=bytes-cost else parsing.enter(cost) end
        assert(#charges==0 and owner.reserved==192+2*48+bytes,'compiler retained a per-event proof vector')
      end
      return charges
    end)
    local requests,spent,peak=observed,context.machine.compile,owner.reserved
    observed=nil; parsing.finish(); memory.close(owner,function() end)
    assert(owner.closed and account.used==256 and account.reserved==0,'proof refusal retained temporary ownership')
    return ok,result,spent,peak,requests
  end
  local passed,problem=pcall(function()
    local ok,proof,spent,peak,requests=run(limits.host_memory_bytes,work,cache,nil,true)
    assert(ok,type(proof)=='table' and proof.message or tostring(proof))
    assert(#proof==0)
    for key in pairs(proof) do assert(key=='total' or key=='bytes','unexpected compiler summary metadata') end
    assert(parsing.proof_bytes()+proof.bytes==peak,'cache weight differs from proof admission')
    local snapshot=serpent.line(proof)
    local admitted,copy,cost,bytes=run(limits.host_memory_bytes,work,cache,proof)
    assert(admitted and copy==proof and cost==spent and bytes==peak,'fitting proof replay changed admission')
    assert(serpent.line(proof)==snapshot,'replay mutated its cached proof')
    local boundaries=0
    for _,step in ipairs(requests) do
      for _,short_work in ipairs({false,true}) do
        if not short_work or step.work>0 then
          local available=short_work and step.work-1 or work
          local expected,paid
          for _,variant in ipairs({'warm','cold','evicted','small-cache'}) do
            local keep=variant=='evicted' and 1 or variant=='small-cache' and 1024 or cache
            local accepted,reason,cost=run(step.used+step.bytes-1,available,keep,variant=='warm' and proof or nil)
            assert(not accepted and reason.recoverable,'proof storage shortage did not refuse recoverably')
            if expected then
              for _,key in ipairs({'code','resource','setting','used','requested','limit'}) do
                assert(reason[key]==expected[key],'proof refusal changed with cache state: '..key)
              end
              assert(cost==paid,'proof refusal changed accepted work')
            else expected,paid=reason,cost end
          end
          boundaries=boundaries+1
        end
      end
    end
    for _,keep in ipairs({1,1024}) do
      local accepted,p,cost,bytes=run(limits.host_memory_bytes,work,keep)
      assert(accepted and #p==0 and cost==spent and bytes==peak,'cache allowance changed compilation admission')
    end
    for _,sequence in ipairs({{},{5,9,17},{-5,-9,-17},{0,0,0}}) do
      events=sequence
      local accepted,p,cost,bytes=run(limits.host_memory_bytes,work,cache)
      assert(accepted and #p==0 and parsing.proof_bytes()+p.bytes==bytes)
      local replayed,_,replay_cost,replay_bytes=run(limits.host_memory_bytes,work,cache,p)
      assert(replayed and replay_cost==cost and replay_bytes==bytes,'empty/work-only/byte-only proof changed admission')
    end
    log('TC_PROOF_MEMORY events=33 retained_events='..#proof..' boundaries='..boundaries)
  end)
  memory.reserve=reserve; limits.compiler_cache_bytes,limits.compile_work=cache,work
  assert(passed,type(problem)=='table' and problem.message or tostring(problem))
  log('TC_CONTRACT constant-summary-warm-cold-evicted-refusal-prefix-and-cleanup')
end
return M
