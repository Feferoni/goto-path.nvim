local parser = require('goto-path.parser')
local navigator = require('goto-path.navigator')

local M = {}

-- Built-in defaults. Lowest precedence in the merge chain:
--   defaults < config.open_file_opts (from setup) < per-call opts
local default_open_file_opts = {
    follow = true,
    no_ignore = true,
    no_ignore_vcs = false,
}

local config = {}
local setup_done = false

M.setup = function(opts)
    config = opts or {}

    config.open_file_opts = vim.tbl_extend('force', default_open_file_opts, config.open_file_opts or {})

    if not setup_done then
        setup_done = true

        local has_telescope = pcall(require, 'telescope')
        if has_telescope then
            local telescope_navigator = require('goto-path.telescope_navigator')
            navigator.add_search_method(telescope_navigator.create_search())
        end
    end
end

local resolve_opts = function(opts)
    local global = config.open_file_opts or default_open_file_opts
    return vim.tbl_extend('force', global, opts or {})
end

local open_file = function(line, opts)
    local parsed = parser.parse(line)
    navigator.open_file(parsed, resolve_opts(opts))
end

M.goto_file = function(opts)
    local starting_string = vim.fn.expand('<cWORD>')
    if starting_string == "" then
        vim.notify("Move to valid string", vim.log.levels.WARN)
        return
    end

    open_file(starting_string, opts)
end

vim.api.nvim_create_user_command('OpenFile', function(args)
    if #args.fargs == 1 then
        open_file(args.fargs[1], nil)
    else
        vim.notify("OpenFile requires exactly one argument", vim.log.levels.ERROR)
    end
end, { nargs = 1 })

return M
