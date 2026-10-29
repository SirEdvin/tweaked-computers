return [[function start(event)
    local panel = peripheral.find("dashboard", "red")
    assert(panel, "Connect a powered Dashboard on red")
    panel.setTab(1, {
        title = "Overview",
        content = {type = "column", id = "root", children = {
            {type = "label", id = "status", text = "Ready"},
            {type = "button", id = "ack", text = "Acknowledge"}
        }}
    })
    panel.subscribe("clicked")
end

function clicked(event)
    local panel = peripheral.wrap(event.peripheral, event.wire)
    if event.tab == 1 and event.button == "ack" then
        panel.setText(1, "status", "Acknowledged")
    end
end]]
