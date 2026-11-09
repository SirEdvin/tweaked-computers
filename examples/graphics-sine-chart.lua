return [==[
local function wave(w, h, phase)
    -- A thick curve as a triangle strip: one upper and one lower vertex per sample.
    local top, bottom = 16, h - 6
    local mid, amp = (top + bottom) / 2, (bottom - top) / 2 - 2
    local n = math.max(8, math.floor((w - 16) / 4))
    local points = {}
    for i = 0, n do
        local x = 8 + i * (w - 16) / n
        local y = mid - amp * math.sin(phase + i * 6.283185307179586 / n)
        points[#points + 1] = { x, y - 1.5 }
        points[#points + 1] = { x, y + 1.5 }
    end
    return points
end

function start()
    computer.on("monitor_resize", "setup")
    setup()
    computer.every(2, "plot")
end

function setup()
    local views, seen = {}, {}
    for _, wire in ipairs({ "red", "green" }) do
        for _, name in ipairs(peripheral.getNames(wire)) do
            if #views < 4 and not seen[name] and peripheral.getType(name, wire) == "monitor" then
                seen[name] = true
                local m = peripheral.wrap(name, wire)
                m.setMode("graphics")
                m.clear()
                local w, h = m.getSize()
                local mid = math.floor((16 + h - 6) / 2)
                m.drawLine({ from = { 6, mid }, to = { w - 6, mid }, color = { 0.45, 0.45, 0.45 }, width = 1 })
                m.drawLine({ from = { 6, 16 }, to = { 6, h - 6 }, color = { 0.45, 0.45, 0.45 }, width = 1 })
                if w >= 72 then
                    m.drawText({ text = "SINE / LIVE", target = { 6, 3 }, color = { 0.94, 0.94, 0.94 } })
                end
                if w >= 100 then
                    m.drawSprite({ sprite = "item/iron-plate", target = { w - 12, 10 }, x_scale = 0.25, y_scale = 0.25 })
                end
                local curve = m.drawPolygon({ vertices = wave(w, h, 0), color = { 0.5, 0.8, 0.1 } })
                views[#views + 1] = { name = name, wire = wire, curve = curve, w = w, h = h }
            end
        end
    end
    assert(#views > 0, "Connect a monitor NETWORK on red or green")
    computer.setState("graphics_chart", views)
end

function plot()
    local phase = computer.getTick() / 120
    for _, v in ipairs(computer.getState("graphics_chart") or {}) do
        local m = peripheral.wrap(v.name, v.wire)
        if m then
            m.set(v.curve, { vertices = wave(v.w, v.h, phase) })
        end
    end
end
]==]
