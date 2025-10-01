#!/bin/lua

local curses = require("curses")

local function main()
    if not arg[1] then print("Usage: lua " .. arg[0] .. " [filename]") os.exit(1) end

    local filename = arg[1]

    local buffer = {""}
    local f = io.open(filename, "r")
    if f then
        buffer = {}
        for line in f:lines() do
            table.insert(buffer, line)
        end
        f:close()
        if #buffer == 0 then buffer = {""} end
    end

    local stdscr = curses.initscr()
    curses.cbreak()
    curses.raw()

    if curses.noecho then curses.noecho()
    else curses.echo(false) end

    stdscr:keypad(true)
    if stdscr.meta then stdscr:meta(true) end

    curses.curs_set(1)

    local cx, cy = 0, 0
    local dirty = false

    local function redraw()
        stdscr:clear()
        for i, line in ipairs(buffer) do
            stdscr:mvaddstr(i - 1, 0, line)
        end
        stdscr:move(cy, cx)
        stdscr:refresh()
    end

    local function insert_char(ch)
        local line = buffer[cy + 1]
        buffer[cy + 1] = line:sub(1, cx) .. ch .. line:sub(cx + 1)
        cx = cx + 1
        dirty = true
    end

    local function backspace()
        if cx > 0 then
            local line = buffer[cy + 1]
            buffer[cy + 1] = line:sub(1, cx - 1) .. line:sub(cx + 1)
            cx = cx - 1
            dirty = true
        elseif cy > 0 then
            local prev_line = buffer[cy]
            local line = buffer[cy + 1]
            cx = #prev_line
            buffer[cy] = prev_line .. line
            table.remove(buffer, cy + 1)
            cy = cy - 1
            dirty = true
        end
    end

    local function newline()
        local line = buffer[cy + 1]
        local new_line = line:sub(cx + 1)
        buffer[cy + 1] = line:sub(1, cx)
        table.insert(buffer, cy + 2, new_line)
        cy = cy + 1
        cx = 0
        dirty = true
    end

    redraw()

    while true do
        local ch = stdscr:getch()

        if ch == 3 then
            curses.endwin()
            if dirty then
                io.write("Write on '" .. filename .. "'? (y/n): ")
                io.flush()
                local ans = io.read()
                if ans and ans:lower() == "y" then
                    print("Writing on '" .. filename .. "'...")
                    f = io.open(filename, "w")
                    if f then
                        for _, line in ipairs(buffer) do f:write(line .. "\n") end
                        f:close()
                    end
                else print("Trashed.") end
            end
            break

        elseif ch == curses.KEY_BACKSPACE or ch == 127 or ch == 8 then backspace()
        elseif ch == 10 or ch == 13 then newline()
        elseif ch == curses.KEY_LEFT then
            if cx > 0 then cx = cx - 1
            elseif cy > 0 then cy = cy - 1 cx = #buffer[cy + 1] end
        elseif ch == curses.KEY_RIGHT then
            if cx < #buffer[cy + 1] then cx = cx + 1
            elseif cy < #buffer - 1 then cy = cy + 1 cx = 0 end
        elseif ch == curses.KEY_UP then
            if cy > 0 then
                cy = cy - 1

                if cx > #buffer[cy + 1] then cx = #buffer[cy + 1] end
            end
        elseif ch == curses.KEY_DOWN then
            if cy < #buffer - 1 then
                cy = cy + 1

                if cx > #buffer[cy + 1] then cx = #buffer[cy + 1] end
            end
        elseif ch >= 32 and ch <= 126 then insert_char(string.char(ch)) end

        redraw()
    end
end

main()
