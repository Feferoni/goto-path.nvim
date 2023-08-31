local builtin = require('telescope.builtin')

-- init.lua
-- init.lua:2
-- init.lua:2:2
-- init.lua:2:2:
-- <init.lua>
-- "init.lua"

local is_whitespace = function(line, pos)
    local char_at_cursor = line:sub(pos, pos)
    if char_at_cursor:match('%s') then
        return true
    end
    return false
end

local try_open_file = function(file_path, line_number, column_number)
    local file_exists = vim.fn.filereadable(file_path) == 1
    if file_exists then
        vim.api.nvim_command("edit " .. vim.fn.fnameescape(file_path))
        vim.api.nvim_win_set_cursor(0, { line_number, column_number })
        return true
    end
    return false
end

local parse_numbers_and_clean_end = function(file_string)
    local file_string = file_string:gsub('[<>"]', '')
    local line_number, column_number = file_string:match(":(%d+):(%d+)$")
    file_string = file_string:gsub(":%d+:%d+$", "")

    if line_number == nil and column_number == nil then
        line_number, column_number = file_string:match(":(%d+):(%d+):$")
        file_string = file_string:gsub(":%d+:%d+:$", "")
    end

    if line_number == nil then
        line_number = file_string:match(":(%d+)$")
        file_string = file_string:gsub(":%d+$", "")
    end

    if line_number == nil then
        line_number = 1
    end

    if column_number == nil then
        column_number = 0
    end
    line_number = tonumber(line_number)
    column_number = tonumber(column_number)

    file_string = file_string:gsub(":", "")

    return file_string, line_number, column_number
end

local replacement_table = nil
local M = {}

M.setup = function(opts)
    opts = opts or {}

    if opts.replacement_table then
        replacement_table = opts.replacement_table
    end
end


M.go = function(opts)
    opts = opts or {}
    local line = vim.api.nvim_get_current_line()
    local cursor_pos = vim.fn.col('.')

    if is_whitespace(line, cursor_pos) then
        print("Move to valid string")
        return
    end

    local current_pos = cursor_pos
    while current_pos > 0 and not is_whitespace(line, current_pos) do
        current_pos = current_pos - 1
    end

    current_pos = current_pos + 1
    local start_pos, end_pos = line:find('[^%s]*', current_pos)
    local starting_string = line:sub(start_pos, end_pos)

    local file_string, line_number, column_number = parse_numbers_and_clean_end(starting_string)

    if replacement_table then
        for _, replacement in ipairs(replacement_table) do
            file_string = file_string:gsub(replacement[1], replacement[2])
            file_string = file_string:gsub("//+", "/") -- remove duplicate //
        end
    end

    if try_open_file(file_string, line_number, column_number) then
        return
    end

    local root_and_file_string = vim.fn.expand("#1:p") .. file_string
    if try_open_file(root_and_file_string, line_number, column_number) then
        return
    end

    file_string = file_string:gsub("%.%.%/", "") -- remove all instances of ../
    file_string = file_string:gsub("%.%/", "")   -- remove all instances of ./
    file_string = file_string:gsub("//+", "/")   -- remove duplicate //
    file_string = string.match(file_string, "[^/]+$")

    opts.search_file = file_string
    if opts.telescope_pretty then
        opts.telescope_pretty.project_files(opts, builtin.find_files)
    elseif builtin then
        builtin.find_files(opts)
    end
end

return M
