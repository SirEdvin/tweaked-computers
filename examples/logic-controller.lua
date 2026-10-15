-- Paste this single document into the computer editor, Save, then Run.
-- Red NETWORK chain: computer -> any mod NETWORK relay -> logic NETWORK.
-- Factory: stock chest -> logic INPUT red; logic OUTPUT red/green -> inserter.
-- Inserter's native circuit condition: signal-A > 0. Stock target: 100 iron plates.
return [[return {
  api_version = 1,
  handlers = {
    start = function(event)
      computer.setState("starts", (computer.getState("starts") or 0) + 1)
      local io = peripheral.find("logic_handler", "red")
      assert(io, "Wire a logic NETWORK port to the computer on red")
      io.subscribe({input="red", signals={{type="item",name="iron-plate",quality="normal"}}, initial=true}, "changed")
      computer.log("Controller subscribed")
    end,
    changed = function(event)
      local io = peripheral.wrap(event.peripheral, event.wire)
      if not io then return end
      local stock = 0
      for _,entry in ipairs(event.current) do stock=entry.count end
      local enabled = 0
      if stock < 100 then enabled=1 end
      io.setOutput({{signal={type="virtual",name="signal-A",quality="normal"},count=enabled}})
      computer.setState("stock", stock)
      computer.setState("sample_tick", event.sample_tick)
      computer.setState("last_changes", event.changes)
      computer.setState("input_connected", event.connected)
      computer.setState("resync", event.resync)
    end
  }
}]]
