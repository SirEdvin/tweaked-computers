-- Private lifetime ledger. Callers must reserve preparation peaks before effects.
local errors=require('scripts.runtime.errors')
local M={}
local MAX=9007199254740991
local ACCOUNT,OWNER,RECORD,LINK=256,128,128,128
local function integer(value) assert(errors.integer(value,0,MAX),'invalid memory accounting') end
local function capacity(account,amount)
  integer(amount)
  if amount>0 and amount>account.limit-account.used-account.reserved then
    errors.refuse('runtime_memory','tc-runtime-memory-bytes',account.used+account.reserved,amount,account.limit,
      'runtime memory growth refused; release retained values or raise tc-runtime-memory-bytes')
  end
end
local function active(owner)
  assert(type(owner)=='table' and not owner.closed and owner.account.version==1
    and owner.account.owners[owner.id]==owner,'inactive memory owner')
end
local function growth(owner,amount,sponsor)
  if sponsor then
    active(sponsor)
    assert(sponsor.account==owner.account and not sponsor.closing,'inactive or foreign memory sponsor')
  end
  if amount<=0 then return end
  assert(not owner.closing,'memory owner is closing')
  local funding=sponsor or owner
  local prepaid=math.min(funding.reserved,amount)
  capacity(owner.account,amount-prepaid)
  funding.reserved=funding.reserved-prepaid
  owner.account.reserved=owner.account.reserved-prepaid
end
function M.new(limit,control)
  integer(limit); integer(control)
  assert(limit>0,'positive memory allowance required')
  local account={version=1,limit=limit,used=0,reserved=0,control_reserved=control,
    owners={},values={},next_id=1}
  capacity(account,ACCOUNT); account.used=ACCOUNT
  capacity(account,control); account.used=account.used+control
  return account
end
function M.configure(account,limit)
  assert(account.version==1); integer(limit); assert(limit>0,'positive memory allowance required')
  account.limit=limit -- Admission changes, never retained validity or spent reservations.
end
function M.owner(account,reserved)
  assert(account.version==1 and errors.integer(account.next_id,1,MAX-1),'invalid memory owner identity')
  if reserved==nil then reserved=0 end; integer(reserved)
  capacity(account,reserved)
  capacity(account,OWNER+reserved)
  local owner={id=account.next_id,account=account,values={},reserved=reserved,count=0}
  account.next_id=account.next_id+1; account.owners[owner.id]=owner; account.used=account.used+OWNER
  account.reserved=account.reserved+reserved
  return owner
end
function M.reserve(owner,bytes)
  active(owner); assert(not owner.closing,'memory owner is closing'); integer(bytes)
  capacity(owner.account,bytes)
  owner.reserved=owner.reserved+bytes; owner.account.reserved=owner.account.reserved+bytes
end
function M.unreserve(owner,bytes)
  active(owner); bytes=bytes or owner.reserved; integer(bytes)
  assert(bytes<=owner.reserved,'memory reservation underflow')
  owner.reserved=owner.reserved-bytes; owner.account.reserved=owner.account.reserved-bytes
end
function M.resize(owner,value,bytes,sponsor)
  active(owner); integer(bytes)
  local node=assert(owner.values[value],'unowned memory value')
  local record=node.record
  assert(type(value)=='table' or bytes==record.bytes,'immutable string charge changed')
  local delta=bytes-record.bytes
  growth(owner,delta,sponsor)
  record.bytes=bytes; owner.account.used=owner.account.used+delta
end
function M.acquire(owner,value,bytes,sponsor)
  active(owner); integer(bytes)
  assert(type(value)=='string' or type(value)=='table' and getmetatable(value)==nil,'plain accounted object or string required')
  if owner.values[value] then return M.resize(owner,value,bytes,sponsor) end
  local account=owner.account
  local record=account.values[value]
  assert(not record or record.bytes==bytes,'shared object charge mismatch')
  local delta=LINK+(record and 0 or RECORD+bytes)
  growth(owner,delta,sponsor)
  if not record then record={bytes=bytes,owners=0}; account.values[value]=record end
  local node={value=value,record=record,previous=owner.tail}
  if owner.tail then owner.tail.next=node else owner.head=node end
  owner.tail=node; owner.values[value]=node; owner.count=owner.count+1
  record.owners=record.owners+1; account.used=account.used+delta
end
function M.release(owner,value)
  active(owner)
  local node=owner.values[value]
  if not node then return false end
  local record=node.record; local account=owner.account
  if node.previous then node.previous.next=node.next else owner.head=node.next end
  if node.next then node.next.previous=node.previous else owner.tail=node.previous end
  owner.values[value]=nil; owner.count=owner.count-1
  record.owners=record.owners-1
  local released=LINK
  if record.owners==0 then account.values[value]=nil; released=released+RECORD+record.bytes end
  account.used=account.used-released
  node.value=nil; node.record=nil; node.previous=nil; node.next=nil
  return true
end
-- The linked owner list is also the durable cleanup cursor; no tombstone vector.
function M.close(owner,spend)
  active(owner)
  if not owner.closing then spend(1); owner.closing=true end
  while owner.head do
    spend(1)
    M.release(owner,owner.head.value)
  end
  spend(1)
  M.unreserve(owner)
  local account=owner.account
  account.owners[owner.id]=nil; account.used=account.used-OWNER; owner.closed=true
end
return M
