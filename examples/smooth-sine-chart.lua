function start()
    computer.deleteState("smooth_chart")
    computer.every(2, "plot")
end

function plot()
    local C, P, M, S = computer, peripheral, math, string
    local ok = pcall(function()
        local c = C.getState("smooth_chart") or { next = 0 }
        local tick = C.getTick()

        if tick >= c.next then
            local refs = {}
            for _, wire in ipairs({ "red", "green" }) do
                local names = P.getNames(wire)
                for i = 1, M.min(#names, 16) do
                    local name = names[i]
                    local info = P.describe(name, wire)
                    if #refs < 8 and info.type == "monitor" and info.powered then
                        local m = P.wrap(name, wire)
                        local scale = M.max(info.footprint.width, info.footprint.height) > 3 and 2 or 1
                        if m.getTextScale() ~= scale then
                            m.setTextScale(scale)
                        end
                        refs[#refs + 1] = { name = name, wire = wire }
                    end
                end
            end

            P.setMonitorSyncGroup(refs)
            local views = P.getMonitorSyncGroup().members
            for _, v in ipairs(views) do
                for _, old in ipairs(c.views or {}) do
                    if v.name == old.name then
                        v.width = old.width;
                        v.height = old.height
                    end
                end
            end
            c.views = views;
            c.next = tick + 600
        end

        c.phase = tick / 120
        local previous = c.frames or {}
        local frames = {}
        for _, v in ipairs(c.views) do
            local m = P.wrap(v.name, v.wire)
            local w, h = m.getSize()
            if w < 3 or h < 3 or w > 32 or h > 22 then
                error("Resized")
            end
            if v.width ~= w or v.height ~= h then
                m.setCursorBlink(false)
            end
            m.setCursorPos(1, 1)

            local key = w .. "/" .. h
            local old = v.width == w and v.height == h and previous[key]
            local rows = frames[key]
            if not rows then
                rows = {}
                local pw, ph = w * 2, (h - 1) * 3
                local masks = {}
                local previous_y

                -- Join samples on a 2x3-subpixel grid, not with text markers.
                -- Store only occupied cell masks, not a full pixel canvas.
                for px = 0, pw - 1 do
                    local py = 1 + M.floor(
                        (1 - M.sin(c.phase + px * 6.283185307179586 / (pw - 1)))
                            * (ph - 3) / 2 + 0.5
                    )
                    local from = previous_y or py
                    for sy = M.min(from, py), M.max(from, py) do
                        local cell = M.floor(sy / 3) * w + M.floor(px / 2) + 1
                        local bit = 2 ^ ((sy % 3) * 2 + px % 2)
                        local mask = masks[cell] or 0
                        if mask % (bit * 2) < bit then
                            masks[cell] = mask + bit
                        end
                    end
                    previous_y = py
                end

                -- Pack text/foreground/background together so row-cache
                -- comparisons include color inversions as well as glyphs.
                rows[1] = S.sub(" SINE / LIVE" .. S.rep(" ", w), 1, w)
                    .. S.rep("0", w) .. S.rep("f", w)
                local blank = S.rep(" ", w) .. S.rep("5", w) .. S.rep("f", w)
                for y = 2, h do
                    rows[y] = blank
                end
                local middle = M.floor(ph / 2)
                local axis = 3 * 2 ^ ((middle % 3) * 2)
                local af, ab = "7", "f"
                if axis >= 32 then
                    axis = 63 - axis
                    af, ab = ab, af
                end
                rows[M.floor(middle / 3) + 2] = S.rep(S.char(128 + axis), w)
                    .. S.rep(af, w) .. S.rep(ab, w)

                -- Encode only occupied cells; never scan a dense pixel canvas.
                for cell, mask in pairs(masks) do
                    local y = M.floor((cell - 1) / w) + 2
                    local x = (cell - 1) % w + 1
                    local fg, bg = "5", "f"
                    -- The sixth subpixel is always the background.
                    -- Complement the mask and swap colors when it is lit.
                    if mask >= 32 then
                        mask = 63 - mask
                        fg, bg = bg, fg
                    end
                    local glyph = mask == 0 and " " or S.char(128 + mask)
                    local row = rows[y]
                    rows[y] = S.sub(row, 1, x - 1) .. glyph
                        .. S.sub(row, x + 1, w + x - 1) .. fg
                        .. S.sub(row, w + x + 1, w * 2 + x - 1) .. bg
                        .. S.sub(row, w * 2 + x + 1)
                end
                frames[key] = rows
            end

            for y = 1, h do
                if not old or rows[y] ~= old[y] then
                    m.setCursorPos(1, y)
                    m.blit(S.sub(rows[y], 1, w), S.sub(rows[y], w + 1, w * 2), S.sub(rows[y], w * 2 + 1))
                end
            end
            v.width = w;
            v.height = h
            v.phase = c.phase
        end

        c.frames = frames
        C.setState("smooth_chart", c)
    end)

    if not ok then
        C.deleteState("smooth_chart")
    end
end
