local utils = require('goto-path.utils')

local M = {}

local current_job_id = nil

local stop_current_job = function()
    if current_job_id then
        vim.fn.jobstop(current_job_id)
        current_job_id = nil
    end
end

M.cancel_search = function()
    if current_job_id then
        stop_current_job()
        vim.notify("goto-path: search cancelled", vim.log.levels.INFO)
    end
end

vim.api.nvim_create_user_command('CancelSearch', function()
    M.cancel_search()
end, {})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "TelescopeResults",
    callback = function(ctx)
        vim.api.nvim_buf_call(ctx.buf, function()
            vim.fn.matchadd("TelescopeParent", "\t\t.*$")
            vim.api.nvim_set_hl(0, "TelescopeParent", { link = "Comment" })
        end)
    end,
})

local jump_to_line = function(lnum, bufnr)
    local ns_highlight = vim.api.nvim_create_namespace "telescope.highlight"
    vim.api.nvim_buf_call(bufnr, function()
        lnum = utils.getLnum(lnum, bufnr)
        vim.api.nvim_win_set_cursor(0, { lnum, 0 })
        vim.cmd("normal! zz")
        vim.api.nvim_buf_clear_namespace(bufnr, ns_highlight, 0, -1)
        vim.api.nvim_buf_set_extmark(bufnr, ns_highlight, lnum - 1, 0, {
            end_line = lnum,
            hl_group = "TelescopePreviewLine",
        })
    end)
end

local get_custom_previwer = function(opts, lnum)
    local previewers = require "telescope.previewers"
    local from_entry = require "telescope.from_entry"
    local conf = require("telescope.config").values
    local Path = require "plenary.path"

    return previewers.new_buffer_previewer {
        title = "Custom preview",
        dyn_title = function(_, entry)
            return Path:new(from_entry.path(entry, false, false)):normalize("")
        end,
        get_buffer_by_name = function(_, entry)
            return from_entry.path(entry, false)
        end,
        define_preview = function(self, entry)
            local has_buftype = entry.bufnr
                and vim.api.nvim_buf_is_valid(entry.bufnr)
                and vim.bo[entry.bufnr].buftype ~= ""
                or false
            local p
            if not has_buftype then
                p = from_entry.path(entry, true)
                if p == nil or p == "" then
                    return
                end
            end
            if entry.bufnr and (p == "[No Name]" or has_buftype) then
                jump_to_line(lnum, entry.bufnr)
            else
                conf.buffer_previewer_maker(p, self.state.bufnr, {
                    bufname = self.state.bufname,
                    winid = self.state.winid,
                    preview = opts.preview,
                    callback = function(bufnr)
                        jump_to_line(lnum, bufnr)
                    end,
                    file_encoding = opts.file_encoding,
                })
            end
        end
    }
end

local get_attach_mapping = function(lnum, cnum)
    return function()
        local actions = require('telescope.actions')
        actions.select_default:enhance {
            post = function()
                vim.api.nvim_win_set_cursor(0, { utils.getLnum(lnum, 0), utils.getCnum(lnum, cnum, 0) })
                vim.cmd("normal! zz")
            end,
        }
        return true
    end
end

local filenameFirst = function(_, path)
    local tail = vim.fs.basename(path)
    local parent = vim.fs.dirname(path)
    if parent == "." then return tail end
    return string.format("%s\t\t%s", tail, parent)
end

local get_find_command = function()
    if vim.fn.executable("fd") == 1 then
        return { "fd", "--type", "f", "--color", "never", "--hidden", "--no-ignore", "-L" }
    elseif vim.fn.executable("fdfind") == 1 then
        return { "fdfind", "--type", "f", "--color", "never", "--hidden", "--no-ignore", "-L" }
    elseif vim.fn.executable("find") == 1 and vim.fn.has("win32") == 0 then
        return { "find", ".", "-type", "f", "-name" }
    end
    return nil
end

M.create_search = function()
    return function(parsed, opts)
        local find_command = get_find_command()
        if not find_command then
            require("telescope.utils").notify("builtin.find_files", {
                msg = "You need to install either find, fd, or rg",
                level = "ERROR",
            })
            return false
        end

        local search_name = parsed.file_name
        local cmd = vim.list_extend(vim.deepcopy(find_command), { search_name })
        local ignore_patterns = require("telescope.config").values.file_ignore_patterns or {}

        stop_current_job()
        vim.notify("goto-path: searching for '" .. search_name .. "'...", vim.log.levels.INFO)

        current_job_id = vim.fn.jobstart(cmd, {
            stdout_buffered = true,
            on_stdout = function(_, data)
                current_job_id = nil
                local results = vim.tbl_filter(function(path)
                    if path == "" then return false end
                    for _, pattern in ipairs(ignore_patterns) do
                        if path:find(pattern) then return false end
                    end
                    return true
                end, data)

                if #results == 0 then
                    vim.notify("goto-path: no match for '" .. search_name .. "'", vim.log.levels.WARN)
                    return
                end

                if #results == 1 then
                    vim.cmd("edit " .. vim.fn.fnameescape(results[1]))
                    vim.api.nvim_win_set_cursor(0,
                        { utils.getLnum(parsed.row, 0), utils.getCnum(parsed.row, parsed.column, 0) })
                    vim.cmd("normal! zz")
                    return
                end

                local finders = require "telescope.finders"
                local make_entry = require "telescope.make_entry"
                local pickers = require "telescope.pickers"
                local conf = require("telescope.config").values

                opts.on_complete = {
                    function(picker)
                        if picker.manager.linked_states.size == 1 then
                            local actions = require('telescope.actions')
                            actions.select_default(picker.prompt_bufnr)
                        end
                    end
                }
                opts.path_display = filenameFirst
                opts.attach_mappings = get_attach_mapping(parsed.row, parsed.column)
                opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)
                pickers
                    .new(opts, {
                        prompt_title = "Find File: " .. search_name,
                        finder = finders.new_table({ results = results, entry_maker = opts.entry_maker }),
                        previewer = get_custom_previwer(opts, parsed.row),
                        sorter = conf.file_sorter(opts),
                    })
                    :find()
            end,
        })
        return true
    end
end

return M
