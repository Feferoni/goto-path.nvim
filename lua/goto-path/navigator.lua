local M = {}

local search_methods = {}

local getLnum = function(lnum, bufnr)
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count then
        return math.max(1, math.min(lnum, line_count))
    end
    return 0
end

local getCnum = function(lnum, cnum, bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)
    if lines and lines[1] then
        return math.max(0, math.min(string.len(lines[1]), cnum) - 1)
    else
        return 0
    end
end

local try_open_file = function(file_path, row, column)
    local file_exists = vim.fn.filereadable(file_path) == 1
    if file_exists then
        vim.api.nvim_command("edit " .. vim.fn.fnameescape(file_path))
        vim.api.nvim_win_set_cursor(0, { getLnum(row, 0), getCnum(row, column, 0) })
        vim.cmd("normal! zz")
        return true
    end

    local directory_exists = vim.fn.isdirectory(file_path) == 1
    if directory_exists then
        require('telescope.builtin').find_files({ search_dirs = { file_path } })
        return true
    end

    return false
end

local search_direct = function(parsed, opts)
    local file_string = parsed:get_full_path()
    return try_open_file(file_string, parsed.row, parsed.column)
end

local search_with_root_prefix = function(parsed, opts)
    for _, prefix in ipairs(opts.prefix_paths) do
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
end

return M
