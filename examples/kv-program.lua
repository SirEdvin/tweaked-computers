-- Native API v1 program; no OS, filesystem or Redis client.
return [=[return {
  api_version=1,
  handlers={
    start=function(event)
      local db=peripheral.find('kv_database','red')
      if not db then return end
      db.hset('machine','status','ready','owner',computer.getID())
      db.expire('machine',30)
      computer.after(60,'inspect')
    end,
    inspect=function(event)
      local db=peripheral.find('kv_database','red')
      if not db then return end
      local fields=db.hgetall('machine')
      computer.log(fields.status or 'expired')
      computer.log('TTL='..tostring(db.ttl('machine')))
    end
  }
}]=]
