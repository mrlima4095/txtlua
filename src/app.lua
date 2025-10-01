#!/bin/lua

local version = "1.0"
local curses = require("curses")

local function main(filename)
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
    local scroll, hscroll = 0, 0

    local function redraw()
        stdscr:clear()
        local rows, cols = stdscr:getmaxyx()

        local filename_display = "[" .. filename .. "]"
        if dirty then filename_display = filename_display .. "*" end
        local title_left = " TxTLua (" .. version .. ")"
        local filetype = "(text)"

        stdscr:mvaddstr(0, 0, string.rep(" ", cols))
        stdscr:mvaddstr(0, 0, title_left)
        stdscr:mvaddstr(0, math.floor((cols - #filename_display) / 2), filename_display)
        stdscr:mvaddstr(0, cols - #filetype - 1, filetype)

        for i = 2, rows do
            local line_index = scroll + i - 1
            if line_index <= #buffer then
                local line = buffer[line_index]
                if #line > hscroll then stdscr:mvaddstr(i - 1, 0, line:sub(hscroll + 1, hscroll + cols)) end
            end
        end

        stdscr:move(cy - scroll + 1, cx - hscroll)
        stdscr:refresh()
    end

    local function ensure_cursor_visible()
        local rows, cols = stdscr:getmaxyx()

        if cy < scroll then scroll = cy
        elseif cy >= scroll + rows - 1 then scroll = cy - rows + 2 end

        if cx < hscroll then hscroll = cx
        elseif cx >= hscroll + cols then hscroll = cx - cols + 1  end
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
            stdscr:clear()
            stdscr:mvaddstr(0, 0, "Save? [Y] yes, [N] no, [B] back: ")
            stdscr:refresh()
            local answer = stdscr:getch()
            if answer == string.byte("Y") or answer == string.byte("y") then
                curses.endwin()
                if dirty then
                    print("Writing on '" .. filename .. "'...")
                    f = io.open(filename, "w")
                    if f then
                        for _, line in ipairs(buffer) do f:write(line .. "\n") end
                        f:close()
                    end
                end
                break
            elseif answer == string.byte("N") or answer == string.byte("n") then
                curses.endwin()
                print("Trashed.")
                break
            else redraw() end
        elseif ch == 19 then
            f = io.open(filename, "w")
            if f then
                for _, line in ipairs(buffer) do f:write(line .. "\n") end
                f:close()
                dirty = false
                redraw()
                stdscr:mvaddstr(0, 0, " TxTLua (" .. version .. ") - Saved!")
                stdscr:refresh()
                curses.napms(500)
            end
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

        ensure_cursor_visible()
        redraw()
    end
end

if arg[1] then main(arg[1])
else print("Usage: lua " .. arg[0] .. " [filename]") end
