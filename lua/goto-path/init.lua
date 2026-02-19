local parser = require('goto-path.parser')
local navigator = require('goto-path.navigator')

local M = {}
local config = {}
local setup_done = false

M.setup = function(opts)
    config = opts or {}

    if not setup_done then
        setup_done = true

        local has_telescope = pcall(require, 'telescope')
        if has_telescope then
            local telescope_navigator = require('goto-path.telescope_navigator')
            navigator.add_search_method(telescope_navigator.create_search())
        end
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

    local starting_string = vim.fn.expand('<cWORD>')
    if starting_string == "" then
        vim.notify("Move to valid string", vim.log.levels.WARN)
        return
    end

    open_file(starting_string, opts)
end

vim.api.nvim_create_user_command('OpenFile', function(args)
    if #args.fargs == 1 then
        local opts = { follow = true, no_ignore = true }
        open_file(args.fargs[1], opts)
    else
        vim.notify("OpenFile requires exactly one argument", vim.log.levels.ERROR)
    end
end, { nargs = 1 })

return M
