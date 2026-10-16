return {
api_version=1,
handlers={
start=function()
computer.deleteState("smooth_chart")
computer.every(2,"plot")
end,
plot=function()
local C,P,M,S=computer,peripheral,math,string
local ok=pcall(function()
local c=C.getState("smooth_chart") or {next=0}
local tick=C.getTick()
if tick>=c.next then
local refs={}
for _,wire in ipairs({"red","green"}) do
local names=P.getNames(wire)
for i=1,M.min(#names,16) do
local name=names[i]
local info=P.describe(name,wire)
if #refs<8 and info.type=="monitor" and info.powered then
local m=P.wrap(name,wire)
local scale=M.max(info.footprint.width,info.footprint.height)>3 and 2 or 1
if m.getTextScale()~=scale then m.setTextScale(scale) end
refs[#refs+1]={name=name,wire=wire}
end
end
end
P.setMonitorSyncGroup(refs)
local views=P.getMonitorSyncGroup().members
for _,v in ipairs(views) do
for _,old in ipairs(c.views or {}) do
if v.name==old.name then v.width=old.width;v.height=old.height end
end
end
c.views=views;c.next=tick+600
end
c.phase=tick/120
local previous=c.frames or {}
local frames={}
for _,v in ipairs(c.views) do
local m=P.wrap(v.name,v.wire)
local w,h=m.getSize()
if w<3 or h<3 or w>32 or h>22 then error("Resized") end
if v.width~=w or v.height~=h then m.setCursorBlink(false) end
m.setCursorPos(1,1)
local key=w.."/"..h
local old=v.width==w and v.height==h and previous[key]
local rows=frames[key]
if not rows then
rows={}
local middle=2+M.floor((h-2)/2)
for y=1,h do rows[y]=S.rep(y==middle and "-" or " ",w) end
rows[1]=S.sub(" SINE / LIVE"..rows[1],1,w)
for x=2,w do
local y=2+M.floor((1-M.sin(c.phase+(x-2)*6.283185307179586/(w-2)))*(h-2)/2+0.5)
rows[y]=S.sub(rows[y],1,x-1).."*"..S.sub(rows[y],x+1)
end
frames[key]=rows
end
for y=1,h do
if not old or rows[y]~=old[y] then
m.setCursorPos(1,y)
m.blit(rows[y],S.rep(y==1 and "0" or "5",w),S.rep("f",w))
end
end
v.width=w;v.height=h
v.phase=c.phase
end
c.frames=frames
C.setState("smooth_chart",c)
end)
if not ok then C.deleteState("smooth_chart") end
end
}
}
