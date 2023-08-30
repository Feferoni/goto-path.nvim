local builtin = require('telescope.builtin')

local replacement_table = nil

local is_whitespace = function(line, pos)
    local char_at_cursor = line:sub(pos, pos)
    if char_at_cursor:match('%s') then
        return true
    end
    return false
end

local M = {}

M.setup = function(opts)
    opts = opts or {}

    if opts.replacement_table then
        replacement_table = opts.replacement_table
    end
end


M.go = function()
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
    local file_string = line:sub(start_pos, end_pos)



    if replacement_table then
        for _, replacement in ipairs(replacement_table) do
            file_string = file_string:gsub(replacement[1], replacement[2])
        end
    end

    local file_exists = vim.fn.filereadable(file_string) == 1
    if not file_exists then
        local root            = vim.fn.expand("#1:p")
        local tmp_file        = root .. file_string
        local tmp_file_exists = vim.fn.filereadable(tmp_file) == 1
        if tmp_file_exists then
            file_string = tmp_file
            file_exists = true
        end
    end


    if file_exists then
        vim.api.nvim_command("edit " .. vim.fn.fnameescape(file_string))
        return
    end

    file_string = file_string:gsub("%.%.%/", "") -- remove all instances of ../
    file_string = file_string:gsub("%.%/", "")   -- remove all instances of ./
    file_string = file_string:gsub("//+", "/")   -- remove duplicate //
    file_string = string.match(file_string, "[^/]+$")

    if builtin then
        local opts = {}
        opts.search_file = file_string
        builtin.find_files(opts)
    end
end

return M
