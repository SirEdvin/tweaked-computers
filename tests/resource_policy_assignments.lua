-- Exact result adjustment and atomic scalar assignment on the durable path.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local M={}
function M.run()
  local cases={
    [[local a,b,c; assert(a==nil and b==nil and c==nil)
      a,b,c=1,false,3; a,b=b,a; assert(a==false and b==1 and c==3)
      a,a=4,5; assert(a==4)
      a,b,c=computer.tuple(); assert(a==false and b==nil and c==7)
      assert(select('#',computer.tuple())==3)
      a,b,c=(computer.tuple()); assert(a==false and b==nil and c==nil)
      a,b,c=8,computer.empty(); assert(a==8 and b==nil and c==nil)
      a,b=computer.mark(1),computer.mark(2),computer.mark(3)
      assert(a==1 and b==2)]],
    [[local a,b=10,20
      local n=0; while n<300000 do a,b=b,a; n=n+1 end
      assert(a==10 and b==20); computer.mark(n)]],
    [[local total,chosen=0,0
      for i=1,20 do
        local a,b=i,2*i
        if i%2==0 then total=total+a else total=total+b end
        if i==17 then chosen=total; break end
      end
      local i=0
      repeat local v=i; i=i+1; total=total+v until i==5
      assert(total==chosen+10)
      for j=10,1,-2 do i=i+j end
      assert(i==35)
      local a=table.pack(false); local alias=a; a=nil
      local n=0; while n<300000 do n=n+1 end
      assert(alias[1]==false); computer.mark(n)]],
  }
  for _,body in ipairs(cases) do
    for _,source in ipairs({'function start() '..body..' end',
      'return {api_version=1,handlers={start=function() '..body..' end}}'}) do
      local ledger=admission.new(); local effects={}
      local plan,e=compiler.compile(source,admission.context(ledger,'assignments',0)); assert(plan,e and e.message)
      local checkpoint={}; local tick=1
      local services={computer={tuple=function() return false,nil,7 end,empty=function() end,
        mark=function(v) effects[#effects+1]=v; return v end}}
      repeat
        local ok,problem,control=compiler.run(plan,'start',{},services,admission.context(ledger,'assignments',tick),checkpoint)
        assert(ok or control=='wait',problem and problem.message)
        tick=tick+1; assert(tick<300,'assignment continuation made no progress')
        if ok then break end
      until false
      if body==cases[1] then
        assert(#effects==3 and effects[1]==1 and effects[2]==2 and effects[3]==3,'RHS evaluation order/arity changed')
      else assert(#effects==1 and effects[1]==300000 and tick>2,'swap lost or effect replayed') end
    end
  end
  log('TC_CONTRACT durable-multiple-assignment-nil-tuples-evaluation-order')
end
return M
