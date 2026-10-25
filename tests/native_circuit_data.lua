-- Distinct native identities, including a name beyond the old 64-byte gate.
for i=1,1100 do
  local p=table.deepcopy(data.raw['virtual-signal']['signal-A'])
  p.name=string.format('tc-native-%04d',i); p.order=string.format('z-%04d',1101-i)
  data:extend{p}
end
local long=table.deepcopy(data.raw['virtual-signal']['signal-A'])
long.name='tc-native-'..string.rep('long-name-',12)
data:extend{long}
