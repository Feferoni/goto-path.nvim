local parser = require('goto-path.parser')
local navigator = require('goto-path.navigator')

local is_whitespace = function(line, pos)
    return line:sub(pos, pos):match('%s') ~= nil
end

local M = {}
local config = {}

M.setup = function(opts)
    config = opts or {}

    local has_telescope = pcall(require, 'telescope')
    if has_telescope then
        local telescope_navigator = require('goto-path.telescope_navigator')
        navigator.add_search_method(telescope_navigator.create_search())
    end
end

local open_file = function(line, opts)
    opts = opts or {}
    opts = vim.tbl_extend('force', config, opts)

    local parsed = parser.parse(line)
    navigator.open_file(parsed, opts)
end

M.goto_file = function(opts)
    opts = opts or {}
    opts = vim.tbl_extend('force', config, opts)

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
    if string.len(starting_string) == 0 then
        print("Empty string")
        return
    end

    open_file(starting_string, opts)
end

vim.api.nvim_create_user_command('OpenFile', function(args)
    if #args.fargs == 1 then
        local opts = { follow = true, no_ignore = true }
        open_file(args.fargs[1], opts)
    else
        print("Error: OpenFile command requires exactly one argument.")
    end
end, { nargs = 1 })

return M
