-- A bounded value graph, not executable state. References are private records;
-- guest lookalikes remain ordinary tables. Stable scalar-key order is canonical.
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={}
local function fail(message,code) errors.raise(code or 'E_ARGUMENT',message) end
local function scalar(v)
  local t=type(v)
  return t=='boolean' or t=='number' and errors.finite(v) or t=='string' and #v<=limits.string_bytes
end
local rank={boolean=1,number=2,string=3}
local function sorted(t,guard)
  local keys={}
  for k in pairs(t) do
    guard.host_work(1,1)
    if not scalar(k) then fail('shell table keys must be finite scalars','E_UNSUPPORTED') end
    keys[#keys+1]=k
    if #keys>limits.table_entries then fail('shell table width exceeded','E_LIMIT') end
  end
  table.sort(keys,function(a,b)
    guard.spend(1+(type(a)=='string' and #a or 0)+(type(b)=='string' and #b or 0))
    if type(a)~=type(b) then return rank[type(a)]<rank[type(b)] end
    if type(a)=='boolean' then return a==false and b==true end
    return a<b
  end)
  return keys
end
local function meter(guard)
  local bytes,items=16,0
  return function(v)
    local n=type(v)=='string' and #v+16 or 16
    bytes=bytes+n; items=items+1
    if bytes>limits.shell_value_bytes or items>limits.shell_nodes then fail('retained shell graph capacity exceeded','E_LIMIT') end
    guard.host_work(n+1,n+1)
  end
end
function M.encode(root,guard)
  local charge=meter(guard)
  local nodes,values,ids={},{},{}
  local function value(v)
    charge(v)
    if scalar(v) then return v end
    if type(v)~='table' and type(v)~='function' then fail('unsupported retained shell value','E_UNSUPPORTED') end
    if not ids[v] then
      local descriptor=guard.binding(v)
      if not descriptor and not guard.is_plain(v) then fail('cannot retain functions, library namespaces or foreign objects','E_UNSUPPORTED') end
      local id=#values+1; ids[v]=id; values[id]=v; nodes[id]=false
    end
    return {ref=ids[v]}
  end
  local first=value(root)
  local cursor=1
  while cursor<=#values do
    charge(cursor)
    local v=values[cursor]; local descriptor=guard.binding(v)
    if descriptor then
      local d={}
      for _,k in ipairs({'name','wire','generation','kind','method'}) do
        if descriptor[k]~=nil then charge(descriptor[k]); d[k]=descriptor[k] end
      end
      if descriptor.facade then d.facade=value(descriptor.facade) end
      nodes[cursor]={kind='binding',binding=d}
    else
      local keys=sorted(v,guard)
      if cursor==1 and #keys>limits.shell_bindings then fail('shell global binding capacity exceeded','E_LIMIT') end
      local entries={}
      for _,k in ipairs(keys) do charge(k); entries[#entries+1]={key=k,value=value(v[k])} end
      nodes[cursor]={kind='table',entries=entries}
    end
    cursor=cursor+1
  end
  return {version=1,root=first.ref,nodes=nodes}
end
local function fields(t,allowed,guard)
  if type(t)~='table' or getmetatable(t) then fail('malformed shell graph record') end
  for k in pairs(t) do guard.spend(1); if not allowed[k] then fail('unknown shell graph field') end end
end
local function array(t,max,guard)
  if type(t)~='table' or getmetatable(t) then fail('malformed shell graph vector') end
  local n=0
  for k in pairs(t) do
    guard.spend(1); n=n+1
    if n>max or not errors.integer(k,1,max) then fail('shell graph vector limit','E_LIMIT') end
  end
  for i=1,n do if t[i]==nil then fail('sparse shell graph vector') end end
  return n
end
function M.decode(graph,guard)
  if graph==nil then return guard.new(0,function() return {} end) end
  fields(graph,{version=true,root=true,nodes=true},guard)
  if graph.version~=1 or graph.root~=1 then fail('unsupported retained shell graph','E_UNSUPPORTED') end
  local charge=meter(guard)
  charge(graph.root)
  local n=array(graph.nodes,limits.shell_nodes,guard)
  if n==0 then fail('missing shell root') end
  local values={}
  for i=1,n do
    local node=graph.nodes[i]
    fields(node,{kind=true,entries=true,binding=true},guard); charge(i)
    if node.kind=='table' and node.binding==nil then
      local count=array(node.entries,limits.table_entries,guard)
      if i==1 and count>limits.shell_bindings then fail('shell binding capacity exceeded','E_LIMIT') end
      values[i]=guard.new(count,function() return {} end)
    elseif node.kind=='binding' and node.entries==nil and i~=1 then
      fields(node.binding,{name=true,wire=true,generation=true,kind=true,method=true,facade=true},guard)
      for k,v in pairs(node.binding) do if k~='facade' then if not scalar(v) then fail('malformed binding scalar') end; charge(v) end end
      if not node.binding.method then
        if node.binding.facade then fail('facade cannot have a parent facade') end
        values[i]=guard.restore_binding(node.binding)
      end
    else fail('invalid shell graph node') end
  end
  local function value(v)
    charge(v)
    if scalar(v) then return v end
    fields(v,{ref=true},guard)
    if not errors.integer(v.ref,1,n) then fail('dangling shell graph reference') end
    return values[v.ref]
  end
  for i=1,n do
    local node=graph.nodes[i]
    if node.kind=='binding' and node.binding.method then
      local parent=node.binding.facade
      if parent then
        fields(parent,{ref=true},guard)
        if not errors.integer(parent.ref,1,n) or graph.nodes[parent.ref].kind~='binding' or graph.nodes[parent.ref].binding.method then fail('invalid captured facade reference') end
        charge(parent)
      end
      values[i]=guard.restore_binding(node.binding,parent and values[parent.ref])
    end
  end
  for i=1,n do
    local node=graph.nodes[i]
    if node.kind=='table' then
      local seen={}
      for _,entry in ipairs(node.entries) do
        fields(entry,{key=true,value=true},guard)
        local k=entry.key
        if not scalar(k) or seen[k] then fail('invalid or duplicate shell graph key') end
        seen[k]=true; charge(k)
        if i==1 and (type(k)~='string' or #k>limits.identifier_bytes or not k:match('^[a-zA-Z_][a-zA-Z_0-9]*$')) then fail('invalid shell global name') end
        if i==1 and guard.reserved_global(k) then
          fail('reserved shell global: '..k..'; data retained. Confirm Reset Shell to discard scratch values','E_UNSUPPORTED')
        end
        values[i][k]=value(entry.value)
      end
    end
  end
  return values[1]
end
return M
