-- Fixed host adapter for the native editor. No separate discovery graph/cache.
local runtime=require('scripts.runtime.computer')
local admission=require('scripts.runtime.admission')
local peripheral=require('scripts.services.peripheral')
local errors=require('scripts.runtime.errors')
return function(record,wire,tick)
  local ok,result=pcall(function()
    local context=runtime.context(record,tick)
    local function spend(n)
      if not admission.reserve(context,'work',n) then errors.raise('E_BUSY','discovery inspection work deferred') end
    end
    local inventory=peripheral.inventory(record,wire,spend); local names={}
    for name in pairs(inventory) do spend(1); names[#names+1]=name end
    table.sort(names,function(a,b) spend(#a+#b+1); return a<b end)
    local result={}
    for _,name in ipairs(names) do
      spend(8); local rec=peripheral.resolve_inventory_item(inventory,name)
      if not rec then errors.raise('E_NETWORK_PENDING','discovered identity changed') end
      result[#result+1]={name=name,type=inventory[name].type,powered=rec.powered}
    end
    return result
  end)
  if ok then return result end
  return nil,type(result)=='table' and result.code and result or errors.new('E_ENGINE','discovery inspection failed')
end
