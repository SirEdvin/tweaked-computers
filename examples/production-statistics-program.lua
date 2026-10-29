-- Complete guest document. Native maps may be empty; refusal is not zero data.
return [[function start()
  local stats=peripheral.find("production_statistics","red")
  assert(stats,"Connect a powered Production Statistics device on red")
  local function report()
    for _,kind in ipairs({"item","fluid","pollution"}) do
      local totals=stats.getTotals(kind)
      local rates=stats.getRates(kind,"one_minute")
      local count=0
      if kind=="item" then
        for quality,items in pairs(totals.input) do
          for name,amount in pairs(items) do
            count=count+1
            computer.log(quality.." "..name.." produced="..tostring(amount).." /min="..tostring(rates.input[quality][name]))
          end
        end
      else
        for name,amount in pairs(totals.input) do
          count=count+1
          computer.log(kind.." "..name.." input="..tostring(amount).." /min="..tostring(rates.input[name]))
        end
      end
      if count==0 then computer.log(kind..": no recorded input") end
    end
    local h=stats.getHistory("item","iron-plate","one_minute")
    computer.log("Iron produced/min newest="..tostring(h.input[1]).." oldest="..tostring(h.input[300]))
    computer.log("Iron consumed/min newest="..tostring(h.output[1]).." oldest="..tostring(h.output[300]))
  end
  local ok,e=pcall(report)
  if not ok then
    if type(e)=="table" and e.code=="E_LIMIT" then computer.log("Complete statistics query exceeds shared Data limits")
    else error(e) end
  end
  computer.setState("statistics_example",true)
end]]
