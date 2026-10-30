-- Lines are sample-order values, duration bars are seconds; no production-widget parity.
return [[function start()
  local p=peripheral.find('dashboard','red'); assert(p,'Connect a Dashboard on red')
  local available=false
  for _,name in ipairs(peripheral.getMethods(peripheral.getName(p),'red')) do if name=='appendSample' then available=true end end
  local children={{type='label',id='status',text='Ready — explicit samples, duration bars in seconds'},
    {type='button',id='ack',text='Acknowledge'},
    {type='label',id='heartbeat',text='Updates 0'}}
  if available then
    children[4]={type='line',id='trend',series={'input','output'},capacity=8,format='number'}
    children[5]={type='stacked_bars',id='durations',phases={'work','wait'}}
  end
  p.setTab(1,{title='Overview',content={type='column',id='root',children=children}})
  for slot=2,6 do p.setTab(slot,{title='Panel '..slot,content={type='column',id='root',children={
    {type='label',id='note',text='Independent viewer tab '..slot},
    {type='button',id='ack',text='Acknowledge'}}}}) end
  if available then
    for i=1,12 do p.appendSample(1,'trend',{input=i,output=i/2}) end
    p.setBars(1,'durations',{{work=1,wait=2},{work=3,wait=1},{work=2,wait=0}})
  end
  p.subscribe('clicked')
  computer.every(60,'refresh')
  computer.setState('boots',(computer.getState('boots') or 0)+1)
end

function refresh()
  local p=peripheral.find('dashboard','red')
  local n=(computer.getState('updates') or 0)+1
  computer.setState('updates',n)
  p.setText(1,'heartbeat','Updates '..n)
end

function clicked(event)
  local p=peripheral.wrap(event.peripheral,event.wire)
  local count=(computer.getState('clicks') or 0)+1
  computer.setState('clicks',count)
  p.setText(1,'status','Acknowledged '..count)
end]]
