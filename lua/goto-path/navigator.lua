local utils = require('goto-path.utils')

local M = {}

local search_methods = {}

local try_open_file = function(file_path, row, column)
    local file_exists = vim.fn.filereadable(file_path) == 1
    if file_exists then
        vim.api.nvim_command("edit " .. vim.fn.fnameescape(file_path))
        vim.api.nvim_win_set_cursor(0, { utils.getLnum(row, 0), utils.getCnum(row, column, 0) })
        vim.cmd("normal! zz")
        return true
    end

    local directory_exists = vim.fn.isdirectory(file_path) == 1
    if directory_exists then
        local ok, telescope = pcall(require, 'telescope.builtin')
        if ok then
            telescope.find_files({ search_dirs = { file_path } })
            return true
        end
    end

    return false
end

local search_direct = function(parsed, _)
    local file_string = parsed:get_full_path()
    return try_open_file(file_string, parsed.row, parsed.column)
end

local search_with_root_prefix = function(parsed, opts)
    for _, prefix in ipairs(opts.prefix_paths or {}) do
        local file_string = prefix .. parsed:get_full_path()
        if try_open_file(file_string, parsed.row, parsed.column) then
            return true
        end
    end

    return false
end

M.add_search_method = function(fn)
    table.insert(search_methods, fn)
end

M.open_file = function(parsed, opts)
    opts = opts or {}

    if search_direct(parsed, opts) then
        return
    end

    if search_with_root_prefix(parsed, opts) then
        return
    end

    for _, search_fn in ipairs(search_methods) do
        if search_fn(parsed, opts) then
            return
        end
    end

    vim.notify("goto-path: could not find '" .. parsed:get_full_path() .. "'", vim.log.levels.WARN)
end

return M
